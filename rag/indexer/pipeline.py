"""
Indexing pipeline for RAG system.
Orchestrates document loading, chunking, embedding, and storage.
"""

import glob
import hashlib
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional, Set

logger = logging.getLogger(__name__)

from .chunker import DocumentChunker
from .embedder import Embedder
from ..storage.database import VectorStore


class IndexingPipeline:
    """
    Pipeline for indexing documents into the RAG system.
    
    Workflow:
    1. Load documents from source patterns
    2. Chunk documents into semantic units
    3. Generate embeddings for each chunk
    4. Store chunks and embeddings in vector store
    """
    
    def __init__(self, 
                 index_path: str,
                 sources: Optional[List[str]] = None,
                 exclude: Optional[List[str]] = None):
        """
        Initialize indexing pipeline.
        
        Args:
            index_path: Path to SQLite index database
            sources: List of source patterns to index
            exclude: List of patterns to exclude
        """
        self.index_path = index_path
        self.sources = sources or [
            "conductor/*.md",
            "conductor/tracks/**/*.md",
            "system-prompts/*.md",
            "docs/*.md",
            "scripts/*.sh",
            "webui/*.py",
            "mcp/**/*.py",
            "rag/**/*.py"
        ]
        self.exclude = exclude or [
            "**/node_modules/**",
            "**/.git/**",
            "**/*.pyc",
            "**/__pycache__/**",
            "**/*.log"
        ]
        
        # Project root (parent of rag directory)
        self.project_root = Path(__file__).parent.parent.parent
        
        # Initialize components
        self.vector_store = VectorStore(index_path)
        self.chunker = DocumentChunker(chunk_size=500, chunk_overlap=50)
        self.embedder = Embedder()
        
        logger.info(f"IndexingPipeline initialized for {self.project_root}")
    
    def run(self, force: bool = False) -> Dict[str, Any]:
        """
        Run the indexing pipeline.
        
        Args:
            force: Force re-indexing even if files unchanged
            
        Returns:
            Indexing statistics
        """
        logger.info("Starting indexing pipeline")
        start_time = datetime.now()
        
        # Get files to index
        files = self._collect_files()
        logger.info(f"Found {len(files)} files to index")
        
        if not files:
            return {
                'status': 'warning',
                'message': 'No files found to index',
                'files_indexed': 0
            }
        
        # Get already indexed files (for incremental indexing)
        indexed_files = self._get_indexed_files() if not force else set()
        
        # Filter out unchanged files
        files_to_index = []
        for file_path in files:
            if force or file_path not in indexed_files or self._file_changed(file_path):
                files_to_index.append(file_path)
        
        logger.info(f"Files to index: {len(files_to_index)} (skipping {len(files) - len(files_to_index)} unchanged)")
        
        # Index files
        stats = {
            'files_processed': 0,
            'files_indexed': 0,
            'chunks_created': 0,
            'errors': []
        }
        
        for file_path in files_to_index:
            try:
                result = self._index_file(file_path)
                stats['files_processed'] += 1
                if result['chunks'] > 0:
                    stats['files_indexed'] += 1
                    stats['chunks_created'] += result['chunks']
                
                # Update indexed file tracking
                self._mark_file_indexed(file_path)
                
            except Exception as e:
                logger.error(f"Failed to index {file_path}: {e}")
                stats['errors'].append(str(file_path))
        
        # Update metadata
        self.vector_store.update_metadata('last_indexed', datetime.now().isoformat())
        self.vector_store.update_metadata('total_files', stats['files_indexed'])
        self.vector_store.update_metadata('total_chunks', 
            self.vector_store.get_stats()['document_count'])
        
        # Log summary
        elapsed = (datetime.now() - start_time).total_seconds()
        logger.info(f"Indexing complete: {stats['files_indexed']} files, "
                   f"{stats['chunks_created']} chunks in {elapsed:.1f}s")
        
        return {
            'status': 'success',
            'files_processed': stats['files_processed'],
            'files_indexed': stats['files_indexed'],
            'chunks_created': stats['chunks_created'],
            'errors': stats['errors'],
            'elapsed_seconds': elapsed
        }
    
    def _collect_files(self) -> List[Path]:
        """Collect all files matching source patterns."""
        files = []
        
        for pattern in self.sources:
            # Resolve relative to project root
            full_pattern = str(self.project_root / pattern)
            matches = glob.glob(full_pattern, recursive=True)
            
            for match in matches:
                file_path = Path(match)
                
                # Skip excluded patterns
                if self._is_excluded(file_path):
                    continue
                
                # Skip directories
                if file_path.is_dir():
                    continue
                
                files.append(file_path)
        
        return files
    
    def _is_excluded(self, file_path: Path) -> bool:
        """Check if file matches exclusion patterns."""
        file_str = str(file_path)
        
        for pattern in self.exclude:
            if pattern.startswith('**/'):
                # Match anywhere in path
                if pattern[3:] in file_str:
                    return True
            elif pattern.startswith('*'):
                # Match extension
                if file_path.suffix == pattern[1:]:
                    return True
        
        return False
    
    def _get_indexed_files(self) -> Set[str]:
        """Get set of already indexed file paths."""
        # Get from metadata or return empty set
        indexed = self.vector_store.get_metadata('indexed_files', {})
        return set(indexed.keys()) if isinstance(indexed, dict) else set()
    
    def _file_changed(self, file_path: Path) -> bool:
        """Check if file has changed since last indexing."""
        indexed = self.vector_store.get_metadata('indexed_files', {})
        
        if not isinstance(indexed, dict):
            return True
        
        file_str = str(file_path)
        if file_str not in indexed:
            return True
        
        # Check modification time
        try:
            current_mtime = file_path.stat().st_mtime
            indexed_mtime = indexed[file_str].get('mtime', 0)
            return current_mtime != indexed_mtime
        except Exception:
            return True
    
    def _mark_file_indexed(self, file_path: Path):
        """Mark file as indexed with metadata."""
        indexed = self.vector_store.get_metadata('indexed_files', {})
        if not isinstance(indexed, dict):
            indexed = {}
        
        try:
            stat = file_path.stat()
            indexed[str(file_path)] = {
                'mtime': stat.st_mtime,
                'size': stat.st_size,
                'indexed_at': datetime.now().isoformat()
            }
            self.vector_store.update_metadata('indexed_files', indexed)
        except Exception as e:
            logger.error(f"Failed to mark file indexed: {e}")
    
    def _index_file(self, file_path: Path) -> Dict[str, Any]:
        """
        Index a single file.
        
        Returns:
            Indexing result with chunk count
        """
        # Read file content
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        if not content.strip():
            return {'chunks': 0, 'message': 'Empty file'}
        
        # Chunk the document
        chunks = self.chunker.chunk(content, str(file_path))
        
        if not chunks:
            return {'chunks': 0, 'message': 'No chunks created'}
        
        # Extract texts for embedding
        texts = [chunk['content'] for chunk in chunks]
        
        # Generate embeddings
        embeddings = self.embedder.embed_documents(texts)
        
        # Store in vector store
        documents = []
        for chunk in chunks:
            doc = {
                'id': self._generate_doc_id(str(chunk['source']), chunk['chunk_index']),
                'content': chunk['content'],
                **chunk
            }
            documents.append(doc)
        
        count = self.vector_store.insert_batch(documents, embeddings)
        
        return {'chunks': count}
    
    def _generate_doc_id(self, source: str, chunk_index: int) -> str:
        """Generate unique document ID."""
        # Use hash of source and index
        key = f"{source}:{chunk_index}"
        hash_hex = hashlib.md5(key.encode()).hexdigest()[:12]
        return f"doc_{hash_hex}"
    
    def get_stats(self) -> Dict[str, Any]:
        """Get index statistics."""
        return self.vector_store.get_stats()
    
    def close(self):
        """Clean up resources."""
        self.vector_store.close()


# Convenience function
def index_documents(index_path: Optional[str] = None, **kwargs) -> Dict[str, Any]:
    """
    Quick indexing function.
    
    Args:
        index_path: Path to index database (default: .ai-colab/rag/index.db)
        **kwargs: Additional arguments for IndexingPipeline
        
    Returns:
        Indexing statistics
    """
    if index_path is None:
        project_root = Path(__file__).parent.parent.parent
        index_path = str(project_root / ".ai-colab" / "rag" / "index.db")
    
    pipeline = IndexingPipeline(index_path, **kwargs)
    result = pipeline.run()
    pipeline.close()
    
    return result
