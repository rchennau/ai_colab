"""
RAG System Unit Tests

Run with: python -m pytest rag/tests/test_rag.py -v
"""

import pytest
import sys
import tempfile
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


class TestDocumentChunker:
    """Tests for document chunking."""
    
    @pytest.fixture
    def chunker(self):
        from rag.indexer.chunker import DocumentChunker
        return DocumentChunker(chunk_size=100, chunk_overlap=10)
    
    def test_chunk_markdown(self, chunker):
        """Test markdown chunking by headers."""
        content = """# Header 1

Content for header 1.

## Header 2

Content for header 2.

## Header 3

More content here.
"""
        chunks = chunker.chunk(content, "test.md", doc_type='md')
        
        assert len(chunks) > 0
        assert all('content' in chunk for chunk in chunks)
        assert all('source' in chunk for chunk in chunks)
        assert all('section' in chunk for chunk in chunks)
    
    def test_chunk_generic(self, chunker):
        """Test generic text chunking."""
        content = "This is a test document. " * 50
        chunks = chunker.chunk(content, "test.txt", doc_type='txt')
        
        assert len(chunks) > 0
        # Should split into multiple chunks
        assert sum(len(chunk['content']) for chunk in chunks) > 0
    
    def test_detect_type(self, chunker):
        """Test file type detection."""
        assert chunker._detect_type("test.md") == 'md'
        assert chunker._detect_type("test.py") == 'py'
        assert chunker._detect_type("test.sh") == 'sh'
        assert chunker._detect_type("test.txt") == 'txt'


class TestEmbedder:
    """Tests for embedding generation."""
    
    @pytest.fixture
    def embedder(self):
        from rag.indexer.embedder import Embedder
        return Embedder()
    
    def test_embed_single_text(self, embedder):
        """Test embedding a single text."""
        texts = ["Hello world"]
        embeddings = embedder.embed(texts)
        
        assert len(embeddings) == 1
        assert len(embeddings[0]) == embedder.embedding_dim
    
    def test_embed_multiple_texts(self, embedder):
        """Test embedding multiple texts."""
        texts = ["Hello world", "Goodbye world"]
        embeddings = embedder.embed(texts)
        
        assert len(embeddings) == 2
        assert all(len(emb) == embedder.embedding_dim for emb in embeddings)
    
    def test_embed_query(self, embedder):
        """Test query embedding."""
        embedding = embedder.embed_query("test query")
        
        assert len(embedding) == embedder.embedding_dim
    
    def test_mock_embeddings_normalized(self, embedder):
        """Test that mock embeddings are normalized."""
        texts = ["test"]
        embeddings = embedder.embed(texts)
        
        # Check normalization (magnitude should be ~1)
        magnitude = sum(x * x for x in embeddings[0]) ** 0.5
        assert abs(magnitude - 1.0) < 0.01


class TestVectorStore:
    """Tests for SQLite vector storage."""
    
    @pytest.fixture
    def vector_store(self):
        from rag.storage.database import VectorStore
        import tempfile
        
        with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
            db_path = f.name
        
        store = VectorStore(db_path)
        yield store
        
        # Cleanup
        store.close()
        Path(db_path).unlink(missing_ok=True)
    
    def test_insert_and_search(self, vector_store):
        """Test inserting and searching documents."""
        # Insert
        doc_id = "test_doc_1"
        embedding = [0.1] * 384
        metadata = {'source': 'test.md', 'section': 'Test'}
        
        success = vector_store.insert(doc_id, "Test content", embedding, metadata)
        assert success
        
        # Search
        results = vector_store.similarity_search(embedding, top_k=1)
        
        assert len(results) > 0
        assert results[0]['doc_id'] == doc_id
    
    def test_batch_insert(self, vector_store):
        """Test batch insertion."""
        documents = [
            {'id': f'doc_{i}', 'content': f'Content {i}'}
            for i in range(5)
        ]
        embeddings = [[0.1] * 384 for _ in range(5)]
        
        count = vector_store.insert_batch(documents, embeddings)
        assert count == 5
        
        # Verify
        stats = vector_store.get_stats()
        assert stats['document_count'] == 5
    
    def test_delete(self, vector_store):
        """Test document deletion."""
        # Insert
        vector_store.insert("doc_1", "content", [0.1] * 384, {})
        
        # Delete
        success = vector_store.delete("doc_1")
        assert success
        
        # Verify deleted
        stats = vector_store.get_stats()
        assert stats['document_count'] == 0
    
    def test_clear(self, vector_store):
        """Test clearing all documents."""
        # Insert some docs
        for i in range(3):
            vector_store.insert(f"doc_{i}", "content", [0.1] * 384, {})
        
        # Clear
        success = vector_store.clear()
        assert success
        
        # Verify empty
        stats = vector_store.get_stats()
        assert stats['document_count'] == 0


class TestQueryCache:
    """Tests for query caching."""
    
    @pytest.fixture
    def cache(self):
        from rag.search.cache import QueryCache
        return QueryCache(ttl=60, max_size=100)
    
    def test_cache_set_get(self, cache):
        """Test basic cache operations."""
        cache.set("test_key", {"result": "test"})
        
        result = cache.get("test_key")
        assert result == {"result": "test"}
    
    def test_cache_miss(self, cache):
        """Test cache miss."""
        result = cache.get("nonexistent_key")
        assert result is None
    
    def test_cache_expiration(self, cache):
        """Test cache entry expiration."""
        # Set with very short TTL
        cache.ttl = 0
        cache.set("expiring_key", "value")
        
        import time
        time.sleep(0.1)
        
        result = cache.get("expiring_key")
        assert result is None
    
    def test_cache_stats(self, cache):
        """Test cache statistics."""
        cache.set("key1", "value1")
        cache.set("key2", "value2")
        cache.get("key1")  # Hit
        cache.get("nonexistent")  # Miss
        
        stats = cache.get_stats()
        
        assert stats['entries'] == 2
        assert stats['hits'] == 1
        assert stats['misses'] == 1
        assert stats['hit_rate_percent'] == 50.0
    
    def test_cache_clear(self, cache):
        """Test clearing cache."""
        cache.set("key1", "value1")
        cache.set("key2", "value2")
        
        cache.clear()
        
        stats = cache.get_stats()
        assert stats['entries'] == 0


class TestRetriever:
    """Tests for semantic retrieval."""
    
    @pytest.fixture
    def retriever(self):
        from rag.search.retriever import Retriever
        import tempfile
        
        with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
            db_path = f.name
        
        retriever = Retriever(db_path)
        yield retriever
        
        # Cleanup
        retriever.close()
        Path(db_path).unlink(missing_ok=True)
    
    def test_search_empty_index(self, retriever):
        """Test search with empty index."""
        results = retriever.search("test query")
        
        assert isinstance(results, list)
        # Should return empty or minimal results
    
    def test_search_with_filters(self, retriever):
        """Test search with source filters."""
        # Insert test documents
        retriever.vector_store.insert(
            "doc_1",
            "Test content about blackboards",
            [0.1] * 384,
            {'source': 'conductor/test.md'}
        )
        
        results = retriever.search(
            "blackboard",
            top_k=5,
            filters={'source': 'conductor/*'}
        )
        
        assert isinstance(results, list)


class TestIndexingPipeline:
    """Tests for indexing pipeline."""
    
    @pytest.fixture
    def pipeline(self):
        from rag.indexer.pipeline import IndexingPipeline
        import tempfile
        
        with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
            db_path = f.name
        
        pipeline = IndexingPipeline(db_path, sources=["test/*.md"])
        yield pipeline
        
        # Cleanup
        pipeline.close()
        Path(db_path).unlink(missing_ok=True)
    
    def test_pipeline_initialization(self, pipeline):
        """Test pipeline initializes correctly."""
        assert pipeline.chunker is not None
        assert pipeline.embedder is not None
        assert pipeline.vector_store is not None
    
    def test_get_stats(self, pipeline):
        """Test getting pipeline stats."""
        stats = pipeline.get_stats()
        
        assert 'document_count' in stats
        assert 'embedding_count' in stats


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
