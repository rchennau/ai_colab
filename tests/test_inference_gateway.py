"""
Inference Gateway Tests
"""

import pytest
import asyncio
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))

from inference.gateway import (
    InferenceGateway,
    InferenceRequest,
    InferenceResponse,
    RequestValidator,
    ModelRouter,
    ModelConfig,
    TaskType,
    ModelStatus,
    CacheManager,
    RateLimiter,
    AnalyticsEngine
)


class TestRequestValidator:
    """Test request validation"""
    
    def test_valid_request(self):
        """Test valid request passes validation"""
        validator = RequestValidator()
        
        request = validator.validate({
            'prompt': 'Hello, how are you?',
            'max_tokens': 100,
            'temperature': 0.7
        })
        
        assert request is not None
        assert request.prompt == 'Hello, how are you?'
        assert request.max_tokens == 100
        assert request.temperature == 0.7
    
    def test_empty_prompt_fails(self):
        """Test empty prompt fails validation"""
        validator = RequestValidator()
        
        with pytest.raises(ValueError):
            validator.validate({
                'prompt': '',
                'max_tokens': 100
            })
    
    def test_long_prompt_fails(self):
        """Test overly long prompt fails validation"""
        validator = RequestValidator()
        
        with pytest.raises(ValueError):
            validator.validate({
                'prompt': 'x' * 200000,  # Too long
                'max_tokens': 100
            })
    
    def test_temperature_clamped(self):
        """Test temperature is clamped to valid range"""
        validator = RequestValidator()
        
        # Too high
        request = validator.validate({
            'prompt': 'Test',
            'temperature': 5.0  # Max is 2.0
        })
        assert request.temperature <= 2.0
        
        # Too low
        request = validator.validate({
            'prompt': 'Test',
            'temperature': -1.0  # Min is 0.0
        })
        assert request.temperature >= 0.0


class TestModelRouter:
    """Test model routing"""
    
    def test_task_based_routing_code(self):
        """Test code tasks route to code models"""
        models = {
            'qwen': ModelConfig(id='qwen', name='Qwen', provider='alibaba', endpoint=''),
            'gemini': ModelConfig(id='gemini', name='Gemini', provider='google', endpoint=''),
            'vllm_local': ModelConfig(id='vllm_local', name='vLLM', provider='local', endpoint='')
        }
        
        router = ModelRouter(models)
        
        request = InferenceRequest(
            request_id='test',
            prompt='Write a function',
            task_type=TaskType.CODE
        )
        
        model = router.select_model(request)
        assert model in ['qwen', 'vllm_local', 'gemini']
    
    def test_task_based_routing_chat(self):
        """Test chat tasks route to chat models"""
        models = {
            'gemini': ModelConfig(id='gemini', name='Gemini', provider='google', endpoint=''),
            'claude': ModelConfig(id='claude', name='Claude', provider='anthropic', endpoint='')
        }
        
        router = ModelRouter(models)
        
        request = InferenceRequest(
            request_id='test',
            prompt='Hello',
            task_type=TaskType.CHAT
        )
        
        model = router.select_model(request)
        assert model in ['gemini', 'claude']
    
    def test_hint_based_routing_fast(self):
        """Test fast hint routes to low latency models"""
        models = {
            'vllm_local': ModelConfig(
                id='vllm_local', name='vLLM', provider='local', endpoint='',
                avg_latency_ms=100  # Fast
            ),
            'claude': ModelConfig(
                id='claude', name='Claude', provider='anthropic', endpoint='',
                avg_latency_ms=2000  # Slow
            )
        }
        
        router = ModelRouter(models)
        
        request = InferenceRequest(
            request_id='test',
            prompt='Quick',
            model_hint='fast'
        )
        
        model = router.select_model(request)
        assert model == 'vllm_local'


class TestCacheManager:
    """Test caching"""
    
    @pytest.mark.asyncio
    async def test_cache_miss(self):
        """Test cache miss returns None"""
        cache = CacheManager(ttl_seconds=300)
        
        result = await cache.get('nonexistent_key')
        assert result is None
    
    @pytest.mark.asyncio
    async def test_cache_hit(self):
        """Test cache hit returns cached response"""
        cache = CacheManager(ttl_seconds=300)
        
        response = InferenceResponse(
            request_id='test',
            response='Cached response',
            model_used='gemini',
            tokens_used={'input': 10, 'output': 20},
            latency_ms=100,
            cached=True,
            cost_usd=0.001
        )
        
        await cache.set('test_key', response)
        result = await cache.get('test_key')
        
        assert result is not None
        assert result.response == 'Cached response'
    
    @pytest.mark.asyncio
    async def test_cache_hit_rate(self):
        """Test cache hit rate calculation"""
        cache = CacheManager(ttl_seconds=300)
        
        # 5 misses
        for i in range(5):
            await cache.get(f'miss_{i}')
        
        # 5 hits
        for i in range(5):
            response = InferenceResponse(
                request_id=f'test_{i}',
                response=f'Response {i}',
                model_used='gemini',
                tokens_used={'input': 10, 'output': 20},
                latency_ms=100,
                cached=True,
                cost_usd=0.001
            )
            await cache.set(f'hit_{i}', response)
            await cache.get(f'hit_{i}')
        
        hit_rate = cache.hit_rate
        assert hit_rate == 0.5  # 5 hits / 10 total


class TestRateLimiter:
    """Test rate limiting"""
    
    @pytest.mark.asyncio
    async def test_rate_limit_allowed(self):
        """Test requests within limit are allowed"""
        config = {
            'test_model': {
                'requests_per_minute': 10,
                'tokens_per_minute': 1000,
                'concurrent_requests': 5
            }
        }
        
        limiter = RateLimiter(config)
        
        # Should allow first request
        result = await limiter.acquire('test_model', 100)
        assert result is True
        
        limiter.release('test_model')
    
    @pytest.mark.asyncio
    async def test_rate_limit_exceeded(self):
        """Test requests over limit are rejected"""
        config = {
            'test_model': {
                'requests_per_minute': 2,
                'tokens_per_minute': 100,
                'concurrent_requests': 1
            }
        }
        
        limiter = RateLimiter(config)
        
        # First two should succeed
        assert await limiter.acquire('test_model', 10)
        assert await limiter.acquire('test_model', 10)
        
        # Third should fail (over limit)
        result = await limiter.acquire('test_model', 10)
        assert result is False


class TestAnalyticsEngine:
    """Test analytics"""
    
    @pytest.mark.asyncio
    async def test_record_request(self):
        """Test request recording"""
        analytics = AnalyticsEngine()
        
        response = InferenceResponse(
            request_id='test',
            response='Test response',
            model_used='gemini',
            tokens_used={'input': 10, 'output': 20},
            latency_ms=100,
            cached=False,
            cost_usd=0.001
        )
        
        await analytics.record_request(response, TaskType.CHAT)
        
        summary = analytics.get_summary()
        
        assert summary['total_requests'] == 1
        assert summary['successful_requests'] == 1
        assert summary['model_usage']['gemini'] == 1
    
    @pytest.mark.asyncio
    async def test_latency_percentiles(self):
        """Test latency percentile calculation"""
        analytics = AnalyticsEngine()
        
        # Record requests with different latencies
        for latency in [50, 100, 150, 200, 250, 300, 350, 400, 450, 500]:
            response = InferenceResponse(
                request_id=f'test_{latency}',
                response='Test',
                model_used='gemini',
                tokens_used={'input': 10, 'output': 10},
                latency_ms=latency,
                cached=False,
                cost_usd=0.001
            )
            await analytics.record_request(response, TaskType.CHAT)
        
        summary = analytics.get_summary()
        
        assert summary['p50_latency_ms'] > 0
        assert summary['p95_latency_ms'] > summary['p50_latency_ms']
        assert summary['p99_latency_ms'] >= summary['p95_latency_ms']


class TestInferenceGateway:
    """Test main gateway"""
    
    def test_gateway_initialization(self):
        """Test gateway initializes correctly"""
        # This will use default config (may not have models configured)
        gateway = InferenceGateway()
        
        assert gateway is not None
        assert gateway.validator is not None
        assert gateway.cache_manager is not None
        assert gateway.rate_limiter is not None
        assert gateway.analytics is not None
    
    def test_get_metrics_empty(self):
        """Test metrics with no requests"""
        gateway = InferenceGateway()
        metrics = gateway.get_metrics()
        
        assert metrics['total_requests'] == 0
        assert metrics['success_rate'] == 0
        assert metrics['cache_hit_rate'] == 0
    
    def test_get_model_status(self):
        """Test model status reporting"""
        gateway = InferenceGateway()
        status = gateway.get_model_status()
        
        # Should return dict even if no models configured
        assert isinstance(status, dict)


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
