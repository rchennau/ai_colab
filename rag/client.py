"""
RAG Client - High-level API for semantic search.
"""

import logging
from pathlib import Path
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

from .search.retriever import Retriever
from .indexer.pipeline import IndexingPipeline


class RAGClient:
    """
    High-level client for RAG operations.
    
    Usage:
        client = RAGClient()
        results = client.search("How does the blackboard work?")
    """
    
    def __init__(self, index_path: Optional[str] = None):
        """
        Initialize RAG client.
        
        Args:
            index_path: Path to SQLite index database.
                       Defaults to .ai-colab/rag/index.db
        """
        self.project_root = Path(__file__).parent.parent
        self.index_path = Path(index_path) if index_path else self.project_root / ".ai-colab" / "rag" / "index.db"
        
        # Ensure index directory exists
        self.index_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize retriever (lazy loading)
        self._retriever = None
        
        logger.info(f"RAGClient initialized with index: {self.index_path}")
    
    @property
    def retriever(self) -> Retriever:
        """Get or create retriever instance."""
        if self._retriever is None:
            self._retriever = Retriever(str(self.index_path))
        return self._retriever
    
    def search(self, query: str, top_k: int = 5, **kwargs) -> List[Dict[str, Any]]:
        """
        Search the knowledge base.
        
        Args:
            query: Search query string
            top_k: Number of results to return
            **kwargs: Additional filters (sources, tags, etc.)
            
        Returns:
            List of results with doc, score, source, and excerpt
        """
        logger.info(f"Search called: query='{query[:50]}...', top_k={top_k}")
        
        # Check if index exists
        if not self.index_path.exists():
            logger.warning("Index not found. Running initial indexing...")
            self.index()
        
        return self.retriever.search(query, top_k=top_k, **kwargs)
    
    def similar(self, document_id: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """
        Find similar documents.
        
        Args:
            document_id: ID of the reference document
            top_k: Number of similar documents to return
            
        Returns:
            List of similar documents
        """
        logger.info(f"Similarity search called: doc_id={document_id}")
        return self.retriever.similar(document_id, top_k=top_k)
    
    def index(self, sources: Optional[List[str]] = None, force: bool = False) -> Dict[str, Any]:
        """
        Trigger indexing of documents.
        
        Args:
            sources: Optional list of source patterns to index
            force: Force re-indexing even if files unchanged
            
        Returns:
            Indexing statistics
        """
        logger.info(f"Indexing triggered: sources={sources}, force={force}")
        
        pipeline = IndexingPipeline(
            str(self.index_path),
            sources=sources
        )
        
        try:
            result = pipeline.run(force=force)
            return result
        finally:
            pipeline.close()
    
    def get_stats(self) -> Dict[str, Any]:
        """Get RAG system statistics."""
        stats = {
            'index_path': str(self.index_path),
            'index_exists': self.index_path.exists()
        }
        
        if self.index_path.exists():
            stats.update(self.retriever.get_stats())
        
        return stats
    
    def clear_cache(self):
        """Clear query cache."""
        self.retriever.clear_cache()
    
    def close(self):
        """Clean up resources."""
        if self._retriever:
            self._retriever.close()


# Convenience function for CLI usage
def search(query: str, top_k: int = 5):
    """Quick search function."""
    client = RAGClient()
    results = client.search(query, top_k)
    client.close()
    return results

