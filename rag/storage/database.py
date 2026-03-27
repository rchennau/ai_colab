"""
SQLite vector storage for RAG system.
Stores document chunks and embeddings.
"""

import json
import logging
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

logger = logging.getLogger(__name__)


class VectorStore:
    """
    SQLite-based vector storage for RAG.
    
    Stores document chunks with embeddings and metadata.
    Supports similarity search using cosine similarity.
    """
    
    def __init__(self, db_path: str):
        """
        Initialize vector store.
        
        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        self.conn = sqlite3.connect(str(self.db_path), check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        
        self._init_schema()
        logger.info(f"VectorStore initialized: {self.db_path}")
    
    def _init_schema(self):
        """Initialize database schema."""
        cursor = self.conn.cursor()
        
        # Documents table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                section TEXT,
                chunk_index INTEGER,
                content TEXT NOT NULL,
                char_count INTEGER,
                token_estimate INTEGER,
                indexed_at TEXT NOT NULL,
                tags TEXT
            )
        ''')
        
        # Embeddings table (stores as JSON array)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS embeddings (
                doc_id TEXT PRIMARY KEY,
                embedding TEXT NOT NULL,
                dimension INTEGER,
                FOREIGN KEY (doc_id) REFERENCES documents(id)
            )
        ''')
        
        # Metadata table for index info
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS index_metadata (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        ''')
        
        # Index for faster lookups
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_source ON documents(source)
        ''')
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_tags ON documents(tags)
        ''')
        
        self.conn.commit()
        logger.info("Database schema initialized")
    
    def insert(self, doc_id: str, content: str, embedding: List[float], 
               metadata: Dict[str, Any]) -> bool:
        """
        Insert a document chunk with embedding.
        
        Args:
            doc_id: Unique document ID
            content: Document content
            embedding: Embedding vector
            metadata: Document metadata
            
        Returns:
            True if successful
        """
        try:
            cursor = self.conn.cursor()
            
            # Insert document
            cursor.execute('''
                INSERT OR REPLACE INTO documents 
                (id, source, section, chunk_index, content, char_count, token_estimate, indexed_at, tags)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                doc_id,
                metadata.get('source', ''),
                metadata.get('section'),
                metadata.get('chunk_index', 0),
                content,
                metadata.get('char_count', len(content)),
                metadata.get('token_estimate', len(content) // 4),
                metadata.get('indexed_at', datetime.now().isoformat()),
                json.dumps(metadata.get('tags', []))
            ))
            
            # Insert embedding
            cursor.execute('''
                INSERT OR REPLACE INTO embeddings (doc_id, embedding, dimension)
                VALUES (?, ?, ?)
            ''', (
                doc_id,
                json.dumps(embedding),
                len(embedding)
            ))
            
            self.conn.commit()
            return True
            
        except Exception as e:
            logger.error(f"Insert failed: {e}")
            self.conn.rollback()
            return False
    
    def insert_batch(self, documents: List[Dict[str, Any]], 
                     embeddings: List[List[float]]) -> int:
        """
        Insert multiple documents in a batch.
        
        Args:
            documents: List of document dicts with content and metadata
            embeddings: List of embedding vectors
            
        Returns:
            Number of documents inserted
        """
        count = 0
        for doc, embedding in zip(documents, embeddings):
            doc_id = doc.get('id', f"doc_{count}")
            if self.insert(doc_id, doc['content'], embedding, doc):
                count += 1
        return count
    
    def similarity_search(self, query_embedding: List[float], 
                          top_k: int = 5,
                          filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """
        Search for similar documents using cosine similarity.
        
        Args:
            query_embedding: Query embedding vector
            top_k: Number of results to return
            filters: Optional filters (source, tags, etc.)
            
        Returns:
            List of results with document info and similarity score
        """
        try:
            cursor = self.conn.cursor()
            
            # Get all embeddings (for now - optimize later with ANN)
            cursor.execute('SELECT doc_id, embedding FROM embeddings')
            rows = cursor.fetchall()
            
            results = []
            for row in rows:
                doc_id = row['doc_id']
                stored_embedding = json.loads(row['embedding'])
                
                # Calculate cosine similarity
                similarity = self._cosine_similarity(query_embedding, stored_embedding)
                
                # Get document metadata
                cursor.execute('SELECT * FROM documents WHERE id = ?', (doc_id,))
                doc_row = cursor.fetchone()
                
                if doc_row:
                    # Apply filters
                    if filters:
                        if not self._matches_filters(dict(doc_row), filters):
                            continue
                    
                    results.append({
                        'doc_id': doc_id,
                        'source': doc_row['source'],
                        'section': doc_row['section'],
                        'content': doc_row['content'],
                        'score': float(similarity),
                        'indexed_at': doc_row['indexed_at']
                    })
            
            # Sort by score descending
            results.sort(key=lambda x: x['score'], reverse=True)
            
            return results[:top_k]
            
        except Exception as e:
            logger.error(f"Similarity search failed: {e}")
            return []
    
    def _cosine_similarity(self, a: List[float], b: List[float]) -> float:
        """Calculate cosine similarity between two vectors."""
        if len(a) != len(b):
            return 0.0
        
        dot_product = sum(x * y for x, y in zip(a, b))
        norm_a = sum(x * x for x in a) ** 0.5
        norm_b = sum(x * x for x in b) ** 0.5
        
        if norm_a == 0 or norm_b == 0:
            return 0.0
        
        return dot_product / (norm_a * norm_b)
    
    def _matches_filters(self, doc: Dict[str, Any], 
                         filters: Dict[str, Any]) -> bool:
        """Check if document matches filters."""
        for key, value in filters.items():
            if key == 'source':
                # Support glob patterns
                import fnmatch
                if not fnmatch.fnmatch(doc.get('source', ''), value):
                    return False
            elif key == 'tags':
                doc_tags = json.loads(doc.get('tags', '[]'))
                if not any(tag in doc_tags for tag in value):
                    return False
            else:
                if doc.get(key) != value:
                    return False
        return True
    
    def get_document(self, doc_id: str) -> Optional[Dict[str, Any]]:
        """Get a document by ID."""
        cursor = self.conn.cursor()
        cursor.execute('SELECT * FROM documents WHERE id = ?', (doc_id,))
        row = cursor.fetchone()
        
        if row:
            return dict(row)
        return None
    
    def get_embedding(self, doc_id: str) -> Optional[List[float]]:
        """Get embedding for a document."""
        cursor = self.conn.cursor()
        cursor.execute('SELECT embedding FROM embeddings WHERE doc_id = ?', (doc_id,))
        row = cursor.fetchone()
        
        if row:
            return json.loads(row['embedding'])
        return None
    
    def delete(self, doc_id: str) -> bool:
        """Delete a document and its embedding."""
        try:
            cursor = self.conn.cursor()
            cursor.execute('DELETE FROM embeddings WHERE doc_id = ?', (doc_id,))
            cursor.execute('DELETE FROM documents WHERE id = ?', (doc_id,))
            self.conn.commit()
            return True
        except Exception as e:
            logger.error(f"Delete failed: {e}")
            self.conn.rollback()
            return False
    
    def clear(self) -> bool:
        """Clear all documents and embeddings."""
        try:
            cursor = self.conn.cursor()
            cursor.execute('DELETE FROM embeddings')
            cursor.execute('DELETE FROM documents')
            self.conn.commit()
            logger.info("Vector store cleared")
            return True
        except Exception as e:
            logger.error(f"Clear failed: {e}")
            self.conn.rollback()
            return False
    
    def get_stats(self) -> Dict[str, Any]:
        """Get index statistics."""
        cursor = self.conn.cursor()
        
        cursor.execute('SELECT COUNT(*) FROM documents')
        doc_count = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(*) FROM embeddings')
        emb_count = cursor.fetchone()[0]
        
        cursor.execute('SELECT SUM(char_count) FROM documents')
        total_chars = cursor.fetchone()[0] or 0
        
        return {
            'document_count': doc_count,
            'embedding_count': emb_count,
            'total_characters': total_chars,
            'database_path': str(self.db_path),
            'database_size_mb': round(self.db_path.stat().st_size / 1024 / 1024, 2)
        }
    
    def update_metadata(self, key: str, value: Any) -> bool:
        """Update index metadata."""
        try:
            cursor = self.conn.cursor()
            cursor.execute('''
                INSERT OR REPLACE INTO index_metadata (key, value)
                VALUES (?, ?)
            ''', (key, json.dumps(value)))
            self.conn.commit()
            return True
        except Exception as e:
            logger.error(f"Metadata update failed: {e}")
            return False
    
    def get_metadata(self, key: str, default: Any = None) -> Any:
        """Get index metadata."""
        cursor = self.conn.cursor()
        cursor.execute('SELECT value FROM index_metadata WHERE key = ?', (key,))
        row = cursor.fetchone()
        
        if row:
            return json.loads(row['value'])
        return default
    
    def close(self):
        """Close database connection."""
        self.conn.close()
        logger.info("VectorStore connection closed")
