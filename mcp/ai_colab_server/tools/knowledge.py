"""
Knowledge search tools for MCP server.
Integrates with RAG system for semantic search.
"""

import logging
from typing import List, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

from ..server import server

# Lazy import RAG client
_rag_client = None


def get_rag_client():
    """Get or create RAG client instance."""
    global _rag_client
    if _rag_client is None:
        try:
            from ....rag.client import RAGClient
            _rag_client = RAGClient()
        except ImportError as e:
            logger.warning(f"RAG not available: {e}")
            _rag_client = None
    return _rag_client


@server.tool()
async def kb_search(query: str, top_k: int = 5, sources: Optional[str] = None) -> list:
    """
    Search the knowledge base using semantic similarity.
    
    Args:
        query: The search query
        top_k: Number of results to return (default: 5)
        sources: Optional source filter (glob pattern, e.g., "conductor/*")
        
    Returns:
        list: [{'doc': str, 'score': float, 'source': str, 'excerpt': str}]
    """
    try:
        logger.info(f"kb_search called: query='{query[:50]}...', top_k={top_k}")
        
        rag_client = get_rag_client()
        
        if rag_client is None:
            # Fallback: return helpful message
            return [
                {
                    'doc': 'RAG System',
                    'score': 1.0,
                    'source': 'system',
                    'excerpt': 'RAG system not initialized. Install dependencies: pip install -r requirements-rag.txt'
                }
            ]
        
        # Build filters
        filters = None
        if sources:
            filters = {'source': sources}
        
        # Search
        results = rag_client.search(query, top_k=top_k, filters=filters)
        
        # Format results for MCP
        formatted = []
        for result in results:
            formatted.append({
                'doc': result.get('doc', 'unknown'),
                'section': result.get('section', ''),
                'score': result.get('score', 0.0),
                'source': result.get('source', ''),
                'excerpt': result.get('excerpt', '')[:500]  # Limit excerpt length
            })
        
        if not formatted:
            formatted.append({
                'doc': 'No Results',
                'score': 0.0,
                'source': 'system',
                'excerpt': f'No documents found matching: {query}'
            })
        
        return formatted
        
    except Exception as e:
        logger.error(f"kb_search error: {e}")
        return [
            {
                'doc': 'Error',
                'score': 0.0,
                'source': 'system',
                'excerpt': f'Search failed: {str(e)}'
            }
        ]


@server.tool()
async def kb_index(force: bool = False) -> dict:
    """
    Trigger knowledge base indexing.
    
    Args:
        force: Force re-indexing even if files unchanged
        
    Returns:
        dict: Indexing statistics
    """
    try:
        logger.info(f"kb_index called: force={force}")
        
        rag_client = get_rag_client()
        
        if rag_client is None:
            return {
                'status': 'error',
                'error': 'RAG system not initialized'
            }
        
        result = rag_client.index(force=force)
        
        return result
        
    except Exception as e:
        logger.error(f"kb_index error: {e}")
        return {
            'status': 'error',
            'error': str(e)
        }


@server.tool()
async def kb_stats() -> dict:
    """
    Get knowledge base statistics.
    
    Returns:
        dict: Index statistics
    """
    try:
        logger.info("kb_stats called")
        
        rag_client = get_rag_client()
        
        if rag_client is None:
            return {
                'status': 'error',
                'error': 'RAG system not initialized'
            }
        
        return rag_client.get_stats()
        
    except Exception as e:
        logger.error(f"kb_stats error: {e}")
        return {
            'status': 'error',
            'error': str(e)
        }
