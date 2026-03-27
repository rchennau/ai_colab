"""
Semantic retriever for RAG system.
"""

import logging
from typing import List, Dict, Any, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

from .cache import QueryCache
from ..indexer.embedder import Embedder
from ..storage.database import VectorStore


class Retriever:
    """
    Semantic retriever for finding relevant documents.
    
    Features:
    - Cosine similarity search
    - Query caching
    - Result ranking
    - Source filtering
    """
    
    def __init__(self, index_path: str, cache_ttl: int = 3600):
        """
        Initialize retriever.
        
        Args:
            index_path: Path to SQLite index database
            cache_ttl: Cache TTL in seconds
        """
        self.vector_store = VectorStore(index_path)
        self.embedder = Embedder()
        self.cache = QueryCache(ttl=cache_ttl)
        
        logger.info(f"Retriever initialized with index: {index_path}")
    
    def search(self, query: str, top_k: int = 5, 
               filters: Optional[Dict[str, Any]] = None,
               use_cache: bool = True) -> List[Dict[str, Any]]:
        """
        Search for relevant documents.
        
        Args:
            query: Search query
            top_k: Number of results to return
            filters: Optional filters (source, tags, etc.)
            use_cache: Whether to use query cache
            
        Returns:
            List of results sorted by relevance
        """
        # Check cache first
        cache_key = self._make_cache_key(query, filters)
        if use_cache:
            cached = self.cache.get(cache_key)
            if cached:
                logger.info(f"Cache hit for query: {query[:50]}...")
                return cached
        
        logger.info(f"Searching for: {query[:50]}...")
        
        # Generate query embedding
        query_embedding = self.embedder.embed_query(query)
        
        # Search vector store
        results = self.vector_store.similarity_search(
            query_embedding, 
            top_k=top_k * 2,  # Get more for re-ranking
            filters=filters
        )
        
        # Re-rank results
        ranked_results = self._rerank(results, query)
        
        # Take top_k after re-ranking
        final_results = ranked_results[:top_k]
        
        # Format results
        formatted = self._format_results(final_results)
        
        # Cache results
        if use_cache and formatted:
            self.cache.set(cache_key, formatted)
        
        return formatted
    
    def _make_cache_key(self, query: str, filters: Optional[Dict[str, Any]]) -> str:
        """Create cache key from query and filters."""
        import hashlib
        key_data = f"{query}:{str(filters)}"
        return hashlib.md5(key_data.encode()).hexdigest()
    
    def _rerank(self, results: List[Dict[str, Any]], query: str) -> List[Dict[str, Any]]:
        """
        Re-rank results using additional scoring factors.
        
        Factors:
        - Base similarity score
        - Recency bonus
        - Source priority
        """
        # Source priority (higher = more important)
        source_priority = {
            'conductor/': 1.2,
            'system-prompts/': 1.1,
            'docs/': 1.0,
            'tracks/': 0.9,
        }
        
        for result in results:
            score = result['score']
            
            # Source bonus
            source = result.get('source', '')
            for prefix, multiplier in source_priority.items():
                if prefix in source:
                    score *= multiplier
                    break
            
            # Recency bonus (slight preference for recent)
            indexed_at = result.get('indexed_at', '')
            if indexed_at:
                try:
                    from datetime import datetime
                    indexed_time = datetime.fromisoformat(indexed_at)
                    days_old = (datetime.now() - indexed_time).days
                    recency_bonus = 1.0 + (0.1 / (days_old + 1))
                    score *= recency_bonus
                except Exception:
                    pass
            
            result['adjusted_score'] = score
        
        # Sort by adjusted score
        results.sort(key=lambda x: x.get('adjusted_score', x['score']), reverse=True)
        
        return results
    
    def _format_results(self, results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Format results for return."""
        formatted = []
        
        for result in results:
            # Create excerpt (first 200 chars)
            content = result.get('content', '')
            excerpt = content[:200] + '...' if len(content) > 200 else content
            
            formatted.append({
                'doc': result.get('source', 'unknown'),
                'section': result.get('section', ''),
                'score': round(result.get('adjusted_score', result['score']), 4),
                'source': result.get('source', ''),
                'excerpt': excerpt,
                'content': content,  # Full content available
                'indexed_at': result.get('indexed_at', '')
            })
        
        return formatted
    
    def similar(self, doc_id: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """
        Find documents similar to a given document.
        
        Args:
            doc_id: Document ID
            top_k: Number of similar documents
            
        Returns:
            List of similar documents
        """
        # Get document embedding
        embedding = self.vector_store.get_embedding(doc_id)
        if not embedding:
            logger.warning(f"Document not found: {doc_id}")
            return []
        
        # Search for similar
        results = self.vector_store.similarity_search(embedding, top_k=top_k + 1)
        
        # Filter out the original document
        results = [r for r in results if r['doc_id'] != doc_id]
        
        return self._format_results(results[:top_k])
    
    def get_stats(self) -> Dict[str, Any]:
        """Get retriever statistics."""
        stats = self.vector_store.get_stats()
        cache_stats = self.cache.get_stats()
        
        return {
            **stats,
            'cache': cache_stats
        }
    
    def clear_cache(self):
        """Clear query cache."""
        self.cache.clear()
        logger.info("Query cache cleared")
    
    def close(self):
        """Clean up resources."""
        self.vector_store.close()


# Convenience function
def search(query: str, **kwargs) -> List[Dict[str, Any]]:
    """Quick search function."""
    project_root = Path(__file__).parent.parent.parent
    index_path = str(project_root / ".ai-colab" / "rag" / "index.db")
    
    retriever = Retriever(index_path)
    results = retriever.search(query, **kwargs)
    retriever.close()
    
    return results
