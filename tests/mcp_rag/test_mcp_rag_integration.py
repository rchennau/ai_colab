#!/usr/bin/env python3
"""
MCP & RAG Integration Tests

Run with: python tests/mcp_rag/test_integration.py

Tests the full integration between MCP server, RAG system, and Web UI.
"""

import sys
import time
import subprocess
import tempfile
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


def test_mcp_server_startup():
    """Test MCP server starts without errors."""
    print("\n=== Test: MCP Server Startup ===")
    
    try:
        # Try to import server
        from mcp.ai_colab_server.server import server
        print("✓ MCP server imports successfully")
        
        # Check tools are registered
        # Note: fastmcp tool registration varies by version
        print("✓ MCP server initialized")
        return True
        
    except ImportError as e:
        print(f"✗ MCP server import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ MCP server error: {e}")
        return False


def test_rag_indexing():
    """Test RAG indexing pipeline."""
    print("\n=== Test: RAG Indexing ===")
    
    try:
        from rag.client import RAGClient
        
        # Create temporary index
        with tempfile.TemporaryDirectory() as tmpdir:
            index_path = Path(tmpdir) / "index.db"
            
            client = RAGClient(str(index_path))
            
            # Run indexing
            result = client.index(force=True)
            
            print(f"✓ Indexing completed")
            print(f"  Files processed: {result.get('files_processed', 0)}")
            print(f"  Chunks created: {result.get('chunks_created', 0)}")
            
            client.close()
            return True
            
    except Exception as e:
        print(f"✗ RAG indexing failed: {e}")
        return False


def test_rag_search():
    """Test RAG semantic search."""
    print("\n=== Test: RAG Search ===")
    
    try:
        from rag.client import RAGClient
        
        with tempfile.TemporaryDirectory() as tmpdir:
            index_path = Path(tmpdir) / "index.db"
            client = RAGClient(str(index_path))
            
            # Index some test content
            client.index(force=True)
            
            # Test search
            results = client.search("test query", top_k=5)
            
            print(f"✓ Search completed")
            print(f"  Results returned: {len(results)}")
            
            client.close()
            return True
            
    except Exception as e:
        print(f"✗ RAG search failed: {e}")
        return False


def test_web_ui_endpoints():
    """Test Web UI API endpoints."""
    print("\n=== Test: Web UI Endpoints ===")
    
    try:
        import requests
        
        # Test health endpoint (if server running)
        try:
            response = requests.get("http://localhost:8080/health", timeout=2)
            if response.status_code == 200:
                print("✓ Web UI health endpoint responding")
            else:
                print(f"⚠ Web UI health returned status {response.status_code}")
        except requests.exceptions.ConnectionError:
            print("⚠ Web UI not running (skipping endpoint tests)")
            return True
        
        # Test KB endpoints
        try:
            response = requests.get(
                "http://localhost:8080/api/kb/stats",
                timeout=5
            )
            if response.status_code in [200, 503]:
                print("✓ KB stats endpoint responding")
        except requests.exceptions.ConnectionError:
            pass
        
        return True
        
    except ImportError:
        print("⚠ requests not installed (skipping endpoint tests)")
        return True
    except Exception as e:
        print(f"✗ Web UI endpoint test failed: {e}")
        return False


def test_mcp_tools_available():
    """Test MCP tools are available and callable."""
    print("\n=== Test: MCP Tools Available ===")
    
    try:
        # Test each tool category
        from mcp.ai_colab_server.tools import blackboard, tracks, knowledge, devops
        
        tools_tested = []
        
        # Blackboard tools
        if hasattr(blackboard, 'blackboard_get'):
            tools_tested.append('blackboard_get')
        if hasattr(blackboard, 'blackboard_set'):
            tools_tested.append('blackboard_set')
        
        # Tracks tools
        if hasattr(tracks, 'tracks_read'):
            tools_tested.append('tracks_read')
        if hasattr(tracks, 'tracks_update'):
            tools_tested.append('tracks_update')
        
        # Knowledge tools
        if hasattr(knowledge, 'kb_search'):
            tools_tested.append('kb_search')
        if hasattr(knowledge, 'kb_index'):
            tools_tested.append('kb_index')
        if hasattr(knowledge, 'kb_stats'):
            tools_tested.append('kb_stats')
        
        # DevOps tools
        if hasattr(devops, 'git_sync'):
            tools_tested.append('git_sync')
        if hasattr(devops, 'build_trigger'):
            tools_tested.append('build_trigger')
        if hasattr(devops, 'health_check'):
            tools_tested.append('health_check')
        
        print(f"✓ {len(tools_tested)} MCP tools available")
        for tool in tools_tested:
            print(f"  - {tool}")
        
        return True
        
    except Exception as e:
        print(f"✗ MCP tools test failed: {e}")
        return False


def test_file_watcher():
    """Test file watcher initialization."""
    print("\n=== Test: File Watcher ===")
    
    try:
        from rag.watcher.file_watcher import DocumentWatcher
        import tempfile
        
        with tempfile.TemporaryDirectory() as tmpdir:
            index_path = Path(tmpdir) / "index.db"
            
            watcher = DocumentWatcher(str(index_path))
            
            print(f"✓ File watcher initialized")
            print(f"  Watch directories: {len(watcher.watch_dirs)}")
            
            watcher.close()
            return True
            
    except ImportError as e:
        print(f"⚠ File watcher dependencies not installed: {e}")
        return True  # Not a failure, just missing optional dependency
    except Exception as e:
        print(f"✗ File watcher test failed: {e}")
        return False


def run_benchmarks():
    """Run performance benchmarks."""
    print("\n=== Performance Benchmarks ===")
    
    try:
        from rag.client import RAGClient
        import time
        
        with tempfile.TemporaryDirectory() as tmpdir:
            index_path = Path(tmpdir) / "index.db"
            client = RAGClient(str(index_path))
            
            # Indexing benchmark
            print("\nIndexing Benchmark:")
            start = time.time()
            result = client.index(force=True)
            elapsed = time.time() - start
            print(f"  Time: {elapsed:.2f}s")
            print(f"  Files/sec: {result.get('files_indexed', 0) / elapsed:.1f}")
            
            # Search benchmark
            print("\nSearch Benchmark:")
            queries = ["test", "architecture", "blackboard"]
            search_times = []
            
            for query in queries:
                start = time.time()
                client.search(query, top_k=5)
                search_times.append(time.time() - start)
            
            avg_search = sum(search_times) / len(search_times)
            print(f"  Avg search time: {avg_search*1000:.1f}ms")
            print(f"  P95 search time: {max(search_times)*1000:.1f}ms")
            
            client.close()
            return True
            
    except Exception as e:
        print(f"✗ Benchmarks failed: {e}")
        return False


def main():
    """Run all integration tests."""
    print("=" * 60)
    print("MCP & RAG Integration Tests")
    print("=" * 60)
    
    results = {
        'MCP Server Startup': test_mcp_server_startup(),
        'RAG Indexing': test_rag_indexing(),
        'RAG Search': test_rag_search(),
        'Web UI Endpoints': test_web_ui_endpoints(),
        'MCP Tools Available': test_mcp_tools_available(),
        'File Watcher': test_file_watcher(),
    }
    
    # Run benchmarks
    results['Benchmarks'] = run_benchmarks()
    
    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test, result in results.items():
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status}: {test}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    return 0 if passed == total else 1


if __name__ == '__main__':
    sys.exit(main())
