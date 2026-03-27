"""
Embedding module for RAG system.
Generates vector embeddings for document chunks.
"""

import logging
from typing import List, Union, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

# Try to import sentence-transformers, fall back to mock if not available
try:
    from sentence_transformers import SentenceTransformer
    SENTENCE_TRANSFORMERS_AVAILABLE = True
except ImportError:
    SENTENCE_TRANSFORMERS_AVAILABLE = False
    logger.warning("sentence-transformers not installed. Using mock embeddings.")


class Embedder:
    """
    Generates embeddings for text chunks.
    
    Uses sentence-transformers for semantic embeddings.
    Falls back to mock embeddings if not available.
    """
    
    DEFAULT_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
    
    def __init__(self, model_name: Optional[str] = None, device: Optional[str] = None):
        """
        Initialize embedder.
        
        Args:
            model_name: Model name for sentence-transformers
            device: Device to run model on (cpu, cuda, mps)
        """
        self.model_name = model_name or self.DEFAULT_MODEL
        self.device = device
        self.model = None
        self.embedding_dim = 384  # Default for MiniLM-L6-v2
        
        if SENTENCE_TRANSFORMERS_AVAILABLE:
            self._load_model()
        else:
            logger.info("Using mock embedder (install sentence-transformers for real embeddings)")
    
    def _load_model(self):
        """Load the embedding model."""
        try:
            logger.info(f"Loading embedding model: {self.model_name}")
            self.model = SentenceTransformer(self.model_name, device=self.device)
            self.embedding_dim = self.model.get_sentence_embedding_dimension()
            logger.info(f"Model loaded. Embedding dimension: {self.embedding_dim}")
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            logger.warning("Falling back to mock embeddings")
            self.model = None
    
    def embed(self, texts: Union[str, List[str]]) -> List[List[float]]:
        """
        Generate embeddings for text(s).
        
        Args:
            texts: Single text or list of texts
            
        Returns:
            List of embedding vectors
        """
        if isinstance(texts, str):
            texts = [texts]
        
        if self.model is not None and SENTENCE_TRANSFORMERS_AVAILABLE:
            return self._embed_real(texts)
        else:
            return self._embed_mock(texts)
    
    def _embed_real(self, texts: List[str]) -> List[List[float]]:
        """Generate real embeddings using sentence-transformers."""
        try:
            embeddings = self.model.encode(
                texts,
                batch_size=32,
                show_progress_bar=len(texts) > 10,
                convert_to_numpy=True
            )
            return embeddings.tolist()
        except Exception as e:
            logger.error(f"Embedding failed: {e}")
            logger.warning("Falling back to mock embeddings")
            return self._embed_mock(texts)
    
    def _embed_mock(self, texts: List[str]) -> List[List[float]]:
        """Generate mock embeddings (hash-based)."""
        import hashlib
        
        embeddings = []
        for text in texts:
            # Create deterministic pseudo-embedding based on text hash
            hash_bytes = hashlib.sha256(text.encode()).digest()
            # Convert to float vector (normalized)
            embedding = []
            for i in range(self.embedding_dim):
                byte_idx = i % len(hash_bytes)
                # Map byte value to [-1, 1] range
                val = (hash_bytes[byte_idx] / 127.5) - 1.0
                embedding.append(val)
            
            # Normalize
            norm = sum(x * x for x in embedding) ** 0.5
            if norm > 0:
                embedding = [x / norm for x in embedding]
            
            embeddings.append(embedding)
        
        return embeddings
    
    def embed_query(self, query: str) -> List[float]:
        """
        Generate embedding for a search query.
        
        Args:
            query: Search query string
            
        Returns:
            Embedding vector
        """
        # For some models, queries need special prefix
        if self.model_name and 'instruction' in self.model_name.lower():
            query = f"Represent this query for searching: {query}"
        
        embeddings = self.embed(query)
        return embeddings[0] if embeddings else []
    
    def embed_documents(self, documents: List[str], batch_size: int = 32) -> List[List[float]]:
        """
        Generate embeddings for multiple documents.
        
        Args:
            documents: List of document texts
            batch_size: Batch size for embedding
            
        Returns:
            List of embedding vectors
        """
        all_embeddings = []
        
        for i in range(0, len(documents), batch_size):
            batch = documents[i:i + batch_size]
            batch_embeddings = self.embed(batch)
            all_embeddings.extend(batch_embeddings)
            
            if (i // batch_size) % 10 == 0:
                logger.info(f"Embedded {min(i + batch_size, len(documents))}/{len(documents)} documents")
        
        return all_embeddings


# Convenience functions
_default_embedder = None


def get_embedder() -> Embedder:
    """Get or create default embedder."""
    global _default_embedder
    if _default_embedder is None:
        _default_embedder = Embedder()
    return _default_embedder


def embed_text(text: str) -> List[float]:
    """Quick embedding function."""
    embedder = get_embedder()
    return embedder.embed_query(text)
