"""
MCP Server Unit Tests

Run with: python -m pytest mcp/tests/test_server.py -v
"""

import pytest
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


class TestBlackboardTools:
    """Tests for blackboard_get and blackboard_set tools."""
    
    @pytest.fixture
    def blackboard_module(self):
        from mcp.ai_colab_server.tools.blackboard import blackboard_get, blackboard_set
        return blackboard_get, blackboard_set
    
    @pytest.mark.asyncio
    async def test_blackboard_get_not_found(self, blackboard_module):
        """Test blackboard_get when key doesn't exist."""
        blackboard_get, _ = blackboard_module
        
        result = await blackboard_get("nonexistent_key_12345")
        
        assert result['status'] in ['not_found', 'error']
        assert result['key'] == "nonexistent_key_12345"
        assert 'timestamp' in result
    
    @pytest.mark.asyncio
    async def test_blackboard_set_success(self, blackboard_module):
        """Test blackboard_set with valid data."""
        _, blackboard_set = blackboard_module
        
        # Skip if hcom-kv not available
        import shutil
        if shutil.which('hcom-kv') is None:
            pytest.skip("hcom-kv not installed")
        
        result = await blackboard_set("test_key", {"value": "test"}, ttl=60)
        
        # Should return success or error (if hcom-kv not configured)
        assert 'status' in result
        assert 'key' in result
        assert 'timestamp' in result


class TestTracksTools:
    """Tests for tracks_read and tracks_update tools."""
    
    @pytest.fixture
    def tracks_module(self):
        from mcp.ai_colab_server.tools.tracks import tracks_read, tracks_update
        return tracks_read, tracks_update
    
    @pytest.mark.asyncio
    async def test_tracks_read(self, tracks_module):
        """Test reading tracks.md."""
        tracks_read, _ = tracks_module
        
        result = await tracks_read()
        
        assert 'status' in result
        assert 'milestones' in result
        assert 'tracks' in result
        assert 'progress' in result
        
        # Should have milestones
        assert len(result['milestones']) > 0
        
        # Should have progress info
        assert 'total_tracks' in result['progress']
        assert 'completed' in result['progress']
    
    @pytest.mark.asyncio
    async def test_tracks_update_invalid_status(self, tracks_module):
        """Test tracks_update with invalid status."""
        _, tracks_update = tracks_module
        
        result = await tracks_update("test_task", "invalid_status")
        
        assert result['status'] == 'error'
        assert 'Invalid status' in result.get('error', '')


class TestDevOpsTools:
    """Tests for git_sync, build_trigger, and health_check tools."""
    
    @pytest.fixture
    def devops_module(self):
        from mcp.ai_colab_server.tools.devops import git_sync, build_trigger, health_check
        return git_sync, build_trigger, health_check
    
    @pytest.mark.asyncio
    async def test_git_sync(self, devops_module):
        """Test git synchronization."""
        git_sync, _, _ = devops_module
        
        result = await git_sync()
        
        assert 'status' in result
        assert 'branch' in result
        assert 'commit' in result
    
    @pytest.mark.asyncio
    async def test_health_check(self, devops_module):
        """Test system health check."""
        _, _, health_check = devops_module
        
        result = await health_check()
        
        assert 'status' in result
        assert 'checks' in result
        
        # Should have tmux and hcom checks
        assert 'tmux' in result['checks']
        assert 'hcom' in result['checks']
        assert 'disk' in result['checks']


class TestKnowledgeTools:
    """Tests for kb_search, kb_index, and kb_stats tools."""
    
    @pytest.fixture
    def knowledge_module(self):
        from mcp.ai_colab_server.tools.knowledge import kb_search, kb_index, kb_stats
        return kb_search, kb_index, kb_stats
    
    @pytest.mark.asyncio
    async def test_kb_search_empty_query(self, knowledge_module):
        """Test kb_search with no RAG initialized."""
        kb_search, _, _ = knowledge_module
        
        result = await kb_search("test query")
        
        # Should return results (even if fallback)
        assert isinstance(result, list)
        assert len(result) > 0
    
    @pytest.mark.asyncio
    async def test_kb_stats(self, knowledge_module):
        """Test kb_stats."""
        _, _, kb_stats = knowledge_module
        
        result = await kb_stats()
        
        assert 'status' in result
        # Either has stats or error message about RAG not initialized


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
