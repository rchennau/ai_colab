"""
ai-colab Inference Gateway
Centralized LLM inference management with routing, batching, caching, and optimization.
"""

import asyncio
import hashlib
import json
import logging
import os
import time
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from abc import ABC, abstractmethod

# Add parent directory to path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

# Import metrics
try:
    from metrics import (
        get_metrics_registry,
        record_api_request,
        record_error,
        record_health_check
    )
    METRICS_AVAILABLE = True
except ImportError:
    METRICS_AVAILABLE = False

logger = logging.getLogger('ai_colab.inference')


# ============================================================================
# Data Classes
# ============================================================================

class TaskType(str, Enum):
    """Supported task types"""
    CHAT = "chat"
    COMPLETION = "completion"
    CODE = "code"
    ANALYSIS = "analysis"
    ARCHITECTURE = "architecture"
    REVIEW = "review"


class ModelStatus(str, Enum):
    """Model availability status"""
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"
    UNKNOWN = "unknown"


@dataclass
class InferenceRequest:
    """Inference request object"""
    request_id: str
    prompt: str
    model_hint: Optional[str] = None  # "fast", "accurate", "code"
    task_type: TaskType = TaskType.CHAT
    max_tokens: int = 1024
    temperature: float = 0.7
    top_p: float = 0.9
    priority: int = 5  # 1-10
    timeout_ms: int = 30000
    metadata: Dict[str, Any] = field(default_factory=dict)
    created_at: float = field(default_factory=time.time)


@dataclass
class InferenceResponse:
    """Inference response object"""
    request_id: str
    response: str
    model_used: str
    tokens_used: Dict[str, int]
    latency_ms: float
    cached: bool
    cost_usd: float
    status: str = "success"
    error: Optional[str] = None
    created_at: float = field(default_factory=time.time)


@dataclass
class ModelConfig:
    """Model configuration"""
    id: str
    name: str
    provider: str
    access_method: str = 'cli'  # 'cli' or 'api'
    cli_command: Optional[str] = None
    cli_args: List[str] = field(default_factory=list)
    api_endpoint: Optional[str] = None
    api_key_env: Optional[str] = None
    model_id: Optional[str] = None
    max_tokens: int = 32768
    cost_per_1k_input: float = 0.0
    cost_per_1k_output: float = 0.0
    status: ModelStatus = ModelStatus.UNKNOWN
    avg_latency_ms: float = 0.0


# ============================================================================
# Model Client Interface
# ============================================================================

class ModelClient(ABC):
    """Abstract base class for model clients"""
    
    def __init__(self, config: ModelConfig):
        self.config = config
        self.request_count = 0
        self.total_tokens = 0
    
    @abstractmethod
    async def execute(self, request: InferenceRequest) -> InferenceResponse:
        """Execute inference request"""
        pass
    
    def calculate_cost(self, input_tokens: int, output_tokens: int) -> float:
        """Calculate cost in USD (0 for CLI-based access)"""
        # CLI-based access is free
        return 0.0


# ============================================================================
# Gemini Client (CLI or API)
# ============================================================================

class GeminiClient(ModelClient):
    """Google Gemini via CLI (FREE) or API (PAID)"""
    
    def __init__(self, config: ModelConfig):
        super().__init__(config)
        self.api_key = os.environ.get(config.api_key_env or 'GEMINI_API_KEY') if config.access_method == 'api' else None
        self.base_url = config.api_endpoint if config.access_method == 'api' else None
    
    async def execute(self, request: InferenceRequest) -> InferenceResponse:
        """Execute request via CLI or API based on config"""
        if self.config.access_method == 'api' and self.api_key:
            return await self._execute_api(request)
        else:
            return await self._execute_cli(request)
    
    async def _execute_cli(self, request: InferenceRequest) -> InferenceResponse:
        """Execute via gemini-cli (FREE)"""
        start_time = time.time()
        
        try:
            cmd = ['gemini', 'shell', '--prompt', request.prompt]
            if self.config.model_id:
                cmd.extend(['--model', self.config.model_id])
            cmd.extend(['--max-tokens', str(request.max_tokens)])
            cmd.extend(['--temperature', str(request.temperature)])
            
            process = await asyncio.create_subprocess_exec(
                *cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
                cwd=str(PROJECT_ROOT)
            )
            
            stdout, stderr = await asyncio.wait_for(
                process.communicate(), timeout=request.timeout_ms / 1000
            )
            
            if process.returncode != 0:
                raise Exception(f"gemini-cli error: {stderr.decode()}")
            
            return self._create_response(request, stdout.decode().strip(), start_time)
        
        except Exception as e:
            # Fallback to API if CLI fails and API is configured
            if self.api_key:
                logger.warning(f"gemini-cli failed, falling back to API: {e}")
                return await self._execute_api(request)
            raise
    
    async def _execute_api(self, request: InferenceRequest) -> InferenceResponse:
        """Execute via Gemini API (PAID)"""
        import aiohttp
        
        start_time = time.time()
        
        try:
            url = f"{self.base_url}/models/{self.config.model_id}:generateContent"
            headers = {'Content-Type': 'application/json', 'x-goog-api-key': self.api_key}
            payload = {
                'contents': [{'parts': [{'text': request.prompt}]}],
                'generationConfig': {
                    'maxOutputTokens': request.max_tokens,
                    'temperature': request.temperature,
                    'topP': request.top_p
                }
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(url, headers=headers, json=payload,
                                       timeout=aiohttp.ClientTimeout(total=request.timeout_ms/1000)) as resp:
                    if resp.status != 200:
                        raise Exception(f"Gemini API error: {resp.status}")
                    result = await resp.json()
                    response_text = result['candidates'][0]['content']['parts'][0]['text']
                    input_tokens = len(request.prompt) // 4
                    output_tokens = len(response_text) // 4
                    latency_ms = (time.time() - start_time) * 1000
                    cost = self.calculate_cost(input_tokens, output_tokens)
                    
                    self.request_count += 1
                    self.total_tokens += input_tokens + output_tokens
                    
                    return InferenceResponse(
                        request_id=request.request_id, response=response_text,
                        model_used=self.config.id,
                        tokens_used={'input': input_tokens, 'output': output_tokens},
                        latency_ms=latency_ms, cached=False, cost_usd=cost
                    )
        except Exception as e:
            raise Exception(f"Gemini API request failed: {e}")
    
    def _create_response(self, request: InferenceRequest, response_text: str, start_time: float) -> InferenceResponse:
        """Create response object"""
        input_tokens = len(request.prompt) // 4
        output_tokens = len(response_text) // 4
        latency_ms = (time.time() - start_time) * 1000
        self.request_count += 1
        self.total_tokens += input_tokens + output_tokens
        
        return InferenceResponse(
            request_id=request.request_id, response=response_text,
            model_used=self.config.id,
            tokens_used={'input': input_tokens, 'output': output_tokens},
            latency_ms=latency_ms, cached=False, cost_usd=0.0  # FREE via CLI
        )


# ============================================================================
# Qwen CLI Client (FREE via qwen-code)
# ============================================================================

class QwenClient(ModelClient):
    """Alibaba Qwen via qwen-code CLI (FREE)"""
    
    def __init__(self, config: ModelConfig):
        super().__init__(config)
        # No API key needed - uses qwen-code's authenticated session
    
    async def execute(self, request: InferenceRequest) -> InferenceResponse:
        """Execute request via qwen-code"""
        start_time = time.time()
        
        try:
            # Build qwen-code command
            cmd = [
                'qwen',
                '--prompt', request.prompt,
                '--model', self.config.id,
                '--max-tokens', str(request.max_tokens),
                '--temperature', str(request.temperature)
            ]
            
            # Execute via subprocess
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(PROJECT_ROOT)
            )
            
            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=request.timeout_ms / 1000
            )
            
            if process.returncode != 0:
                raise Exception(f"qwen-code error: {stderr.decode()}")
            
            response_text = stdout.decode().strip()
            
            # Estimate tokens
            input_tokens = len(request.prompt) // 4
            output_tokens = len(response_text) // 4
            
            latency_ms = (time.time() - start_time) * 1000
            
            self.request_count += 1
            self.total_tokens += input_tokens + output_tokens
            
            return InferenceResponse(
                request_id=request.request_id,
                response=response_text,
                model_used=self.config.id,
                tokens_used={'input': input_tokens, 'output': output_tokens},
                latency_ms=latency_ms,
                cached=False,
                cost_usd=0.0  # FREE via CLI
            )
        
        except Exception as e:
            latency_ms = (time.time() - start_time) * 1000
            raise Exception(f"qwen-code request failed: {e}")


# ============================================================================
# Claude CLI Client (FREE via claude-code)
# ============================================================================

class ClaudeClient(ModelClient):
    """Anthropic Claude via claude-code CLI (FREE during beta)"""
    
    def __init__(self, config: ModelConfig):
        super().__init__(config)
        # No API key needed - uses claude-code's authenticated session
    
    async def execute(self, request: InferenceRequest) -> InferenceResponse:
        """Execute request via claude-code"""
        start_time = time.time()
        
        try:
            # Build claude-code command
            cmd = [
                'claude',
                '--prompt', request.prompt,
                '--model', self.config.id,
                '--max-tokens', str(request.max_tokens)
            ]
            
            # Execute via subprocess
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(PROJECT_ROOT)
            )
            
            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=request.timeout_ms / 1000
            )
            
            if process.returncode != 0:
                raise Exception(f"claude-code error: {stderr.decode()}")
            
            response_text = stdout.decode().strip()
            
            # Estimate tokens
            input_tokens = len(request.prompt) // 4
            output_tokens = len(response_text) // 4
            
            latency_ms = (time.time() - start_time) * 1000
            
            self.request_count += 1
            self.total_tokens += input_tokens + output_tokens
            
            return InferenceResponse(
                request_id=request.request_id,
                response=response_text,
                model_used=self.config.id,
                tokens_used={'input': input_tokens, 'output': output_tokens},
                latency_ms=latency_ms,
                cached=False,
                cost_usd=0.0  # FREE via CLI
            )
        
        except Exception as e:
            latency_ms = (time.time() - start_time) * 1000
            raise Exception(f"claude-code request failed: {e}")


# ============================================================================
# vLLM Local Client
# ============================================================================

class VLLMClient(ModelClient):
    """Local vLLM server client"""
    
    def __init__(self, config: ModelConfig):
        super().__init__(config)
        self.base_url = config.endpoint
    
    async def execute(self, request: InferenceRequest) -> InferenceResponse:
        """Execute request via local vLLM"""
        import aiohttp
        
        start_time = time.time()
        
        try:
            url = f"{self.base_url}/completions"
            headers = {
                'Content-Type': 'application/json'
            }
            
            payload = {
                'model': self.config.id,
                'prompt': request.prompt,
                'max_tokens': request.max_tokens,
                'temperature': request.temperature,
                'top_p': request.top_p
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(url, headers=headers, json=payload,
                                       timeout=aiohttp.ClientTimeout(total=request.timeout_ms/1000)) as resp:
                    
                    if resp.status != 200:
                        error_text = await resp.text()
                        raise Exception(f"vLLM error: {resp.status} - {error_text}")
                    
                    result = await resp.json()
                    
                    # Parse response
                    response_text = result['choices'][0]['text']
                    
                    # Get actual token usage if available
                    usage = result.get('usage', {})
                    input_tokens = usage.get('prompt_tokens', len(request.prompt) // 4)
                    output_tokens = usage.get('completion_tokens', len(response_text) // 4)
                    
                    latency_ms = (time.time() - start_time) * 1000
                    cost = self.calculate_cost(input_tokens, output_tokens)  # Should be 0 for local
                    
                    self.request_count += 1
                    self.total_tokens += input_tokens + output_tokens
                    
                    return InferenceResponse(
                        request_id=request.request_id,
                        response=response_text,
                        model_used=self.config.id,
                        tokens_used={'input': input_tokens, 'output': output_tokens},
                        latency_ms=latency_ms,
                        cached=False,
                        cost_usd=cost
                    )
        
        except Exception as e:
            latency_ms = (time.time() - start_time) * 1000
            raise Exception(f"vLLM request failed: {e}")


# ============================================================================
# Request Validator
# ============================================================================

class RequestValidator:
    """Validates and normalizes inference requests"""
    
    MAX_PROMPT_LENGTH = 100000
    MAX_TOKENS = 32768
    MIN_TEMPERATURE = 0.0
    MAX_TEMPERATURE = 2.0
    
    def validate(self, data: Dict[str, Any]) -> InferenceRequest:
        """Validate request data and return InferenceRequest"""
        import uuid
        
        # Validate prompt
        prompt = data.get('prompt', '')
        if not prompt or not prompt.strip():
            raise ValueError("Prompt is required")
        if len(prompt) > self.MAX_PROMPT_LENGTH:
            raise ValueError(f"Prompt too long (max {self.MAX_PROMPT_LENGTH} chars)")
        
        # Validate task type
        task_type_str = data.get('task_type', 'chat')
        try:
            task_type = TaskType(task_type_str)
        except ValueError:
            task_type = TaskType.CHAT
        
        # Validate parameters
        max_tokens = min(data.get('max_tokens', 1024), self.MAX_TOKENS)
        temperature = max(self.MIN_TEMPERATURE, min(data.get('temperature', 0.7), self.MAX_TEMPERATURE))
        top_p = max(0.0, min(data.get('top_p', 0.9), 1.0))
        priority = max(1, min(data.get('priority', 5), 10))
        timeout_ms = max(1000, min(data.get('timeout_ms', 30000), 300000))
        
        return InferenceRequest(
            request_id=str(uuid.uuid4()),
            prompt=prompt.strip(),
            model_hint=data.get('model_hint'),
            task_type=task_type,
            max_tokens=max_tokens,
            temperature=temperature,
            top_p=top_p,
            priority=priority,
            timeout_ms=timeout_ms,
            metadata=data.get('metadata', {})
        )


# ============================================================================
# Model Router
# ============================================================================

class ModelRouter:
    """Routes requests to optimal model"""
    
    def __init__(self, models: Dict[str, ModelConfig]):
        self.models = models
        
        # Task-based routing rules
        self.task_routing = {
            TaskType.CODE: ['qwen', 'deepseek', 'vllm_local'],
            TaskType.CHAT: ['gemini', 'claude', 'qwen'],
            TaskType.ANALYSIS: ['gemini', 'claude'],
            TaskType.ARCHITECTURE: ['nemoclaw', 'gemini', 'claude'],
            TaskType.REVIEW: ['claude', 'gemini'],
            TaskType.COMPLETION: ['gemini', 'qwen', 'vllm_local']
        }
        
        # Model hints
        self.hint_routing = {
            'fast': lambda m: m.avg_latency_ms < 500,
            'accurate': lambda m: 'claude' in m.id or 'gemini' in m.id,
            'code': lambda m: 'qwen' in m.id or 'deepseek' in m.id or 'vllm' in m.id,
            'cheap': lambda m: m.cost_per_1k_input < 0.001
        }
    
    def select_model(self, request: InferenceRequest) -> Optional[str]:
        """Select optimal model for request"""
        available_models = [
            m for m in self.models.values()
            if m.status in [ModelStatus.HEALTHY, ModelStatus.DEGRADED]
        ]
        
        if not available_models:
            return None
        
        # Try hint-based routing first
        if request.model_hint and request.model_hint in self.hint_routing:
            hint_filter = self.hint_routing[request.model_hint]
            filtered = [m for m in available_models if hint_filter(m)]
            if filtered:
                return filtered[0].id
        
        # Fall back to task-based routing
        preferred_models = self.task_routing.get(request.task_type, [])
        
        for model_id in preferred_models:
            for model in available_models:
                if model_id in model.id.lower():
                    return model.id
        
        # Default to first available model
        return available_models[0].id


# ============================================================================
# Batch Manager
# ============================================================================

class BatchManager:
    """Manages request batching for efficiency"""
    
    def __init__(self, max_batch_size: int = 10, max_wait_ms: int = 100):
        self.max_batch_size = max_batch_size
        self.max_wait_ms = max_wait_ms
        self.pending_requests: Dict[str, List[Tuple[InferenceRequest, asyncio.Future]]] = {}
        self.batch_timers: Dict[str, asyncio.Task] = {}
        self._lock = asyncio.Lock()
    
    async def add_request(self, request: InferenceRequest, model_id: str,
                         executor_func) -> InferenceResponse:
        """Add request to batch, return when complete"""
        future = asyncio.Future()
        
        async with self._lock:
            if model_id not in self.pending_requests:
                self.pending_requests[model_id] = []
            
            self.pending_requests[model_id].append((request, future))
            
            # Flush if batch is full
            if len(self.pending_requests[model_id]) >= self.max_batch_size:
                await self._flush_batch(model_id, executor_func)
            else:
                # Schedule flush after delay
                if model_id not in self.batch_timers:
                    self.batch_timers[model_id] = asyncio.create_task(
                        self._delayed_flush(model_id, executor_func)
                    )
        
        # Wait for result
        return await future
    
    async def _delayed_flush(self, model_id: str, executor_func):
        """Flush batch after delay"""
        await asyncio.sleep(self.max_wait_ms / 1000)
        async with self._lock:
            if model_id in self.pending_requests:
                await self._flush_batch(model_id, executor_func)
            if model_id in self.batch_timers:
                del self.batch_timers[model_id]
    
    async def _flush_batch(self, model_id: str, executor_func):
        """Execute batched requests"""
        requests_futures = self.pending_requests.pop(model_id, [])
        
        if not requests_futures:
            return
        
        # For now, execute individually (batching would require model-specific logic)
        for request, future in requests_futures:
            try:
                result = await executor_func(request)
                if not future.done():
                    future.set_result(result)
            except Exception as e:
                if not future.done():
                    future.set_exception(e)


# ============================================================================
# Cache Manager
# ============================================================================

class CacheManager:
    """Manages response caching"""
    
    def __init__(self, redis_client=None, ttl_seconds: int = 300):
        self.redis = redis_client
        self.ttl = ttl_seconds
        self._local_cache: Dict[str, Tuple[InferenceResponse, float]] = {}
        self._hit_count = 0
        self._miss_count = 0
    
    def generate_cache_key(self, request: InferenceRequest) -> str:
        """Generate unique cache key"""
        content = f"{request.prompt}:{request.max_tokens}:{request.temperature}"
        return f"inference:{hashlib.md5(content.encode()).hexdigest()}"
    
    async def get(self, key: str) -> Optional[InferenceResponse]:
        """Get cached response"""
        # Try local cache first
        if key in self._local_cache:
            response, timestamp = self._local_cache[key]
            if time.time() - timestamp < self.ttl:
                self._hit_count += 1
                return response
            else:
                del self._local_cache[key]
        
        # Try Redis
        if self.redis:
            try:
                cached = await self.redis.get(key)
                if cached:
                    response_data = json.loads(cached)
                    response = InferenceResponse(**response_data)
                    self._hit_count += 1
                    return response
            except Exception as e:
                logger.warning(f"Cache get error: {e}")
        
        self._miss_count += 1
        return None
    
    async def set(self, key: str, response: InferenceResponse):
        """Cache response"""
        # Store in local cache
        self._local_cache[key] = (response, time.time())
        
        # Store in Redis
        if self.redis:
            try:
                response_dict = {
                    'request_id': response.request_id,
                    'response': response.response,
                    'model_used': response.model_used,
                    'tokens_used': response.tokens_used,
                    'latency_ms': response.latency_ms,
                    'cached': True,
                    'cost_usd': response.cost_usd,
                    'status': response.status
                }
                await self.redis.setex(key, self.ttl, json.dumps(response_dict))
            except Exception as e:
                logger.warning(f"Cache set error: {e}")
    
    @property
    def hit_rate(self) -> float:
        """Calculate cache hit rate"""
        total = self._hit_count + self._miss_count
        if total == 0:
            return 0.0
        return self._hit_count / total


# ============================================================================
# Rate Limiter
# ============================================================================

class RateLimiter:
    """Manages rate limiting per model"""
    
    def __init__(self, config: Dict[str, Dict[str, int]]):
        self.config = config
        self.counters: Dict[str, Dict[str, Any]] = {}
        self._lock = asyncio.Lock()
    
    def _get_counter(self, model: str) -> Dict[str, Any]:
        """Get or create counter for model"""
        if model not in self.counters:
            self.counters[model] = {
                'requests': [],  # List of timestamps
                'tokens': [],    # List of (timestamp, count) tuples
                'concurrent': 0,
                'lock': asyncio.Lock()
            }
        return self.counters[model]
    
    async def acquire(self, model: str, tokens: int) -> bool:
        """Acquire rate limit permission"""
        if model not in self.config:
            return True  # No limit configured
        
        limit = self.config[model]
        counter = self._get_counter(model)
        
        async with counter['lock']:
            now = time.time()
            window_start = now - 60  # 1 minute window
            
            # Clean old requests
            counter['requests'] = [t for t in counter['requests'] if t > window_start]
            counter['tokens'] = [(t, c) for t, c in counter['tokens'] if t > window_start]
            
            # Check request rate
            if len(counter['requests']) >= limit.get('requests_per_minute', float('inf')):
                return False
            
            # Check token rate
            total_tokens = sum(c for _, c in counter['tokens'])
            if total_tokens + tokens > limit.get('tokens_per_minute', float('inf')):
                return False
            
            # Check concurrent requests
            if counter['concurrent'] >= limit.get('concurrent_requests', float('inf')):
                return False
            
            # Record usage
            counter['requests'].append(now)
            counter['tokens'].append((now, tokens))
            counter['concurrent'] += 1
            
            return True
    
    def release(self, model: str):
        """Release concurrent request slot"""
        if model in self.counters:
            counter = self.counters[model]
            counter['concurrent'] = max(0, counter['concurrent'] - 1)


# ============================================================================
# Fallback Handler
# ============================================================================

class FallbackHandler:
    """Handles failures with automatic fallback"""
    
    def __init__(self, model_clients: Dict[str, ModelClient],
                 fallback_order: List[str] = None):
        self.model_clients = model_clients
        self.fallback_order = fallback_order or list(model_clients.keys())
        self.failure_counts: Dict[str, int] = {}
        self.circuit_breakers: Dict[str, float] = {}
        self.circuit_threshold = 5
        self.circuit_timeout = 60  # seconds
    
    async def execute_with_fallback(self, request: InferenceRequest,
                                   model_id: str) -> InferenceResponse:
        """Execute request with automatic fallback"""
        last_error = None
        attempted_models = []
        
        # Build fallback chain starting from requested model
        models_to_try = [model_id]
        for m in self.fallback_order:
            if m != model_id and m not in models_to_try:
                models_to_try.append(m)
        
        for model in models_to_try:
            if model not in self.model_clients:
                continue
            
            # Check circuit breaker
            if self._is_circuit_open(model):
                logger.warning(f"Circuit breaker open for {model}, skipping")
                continue
            
            attempted_models.append(model)
            
            try:
                client = self.model_clients[model]
                result = await client.execute(request)
                
                # Record success
                self._record_success(model)
                return result
                
            except Exception as e:
                last_error = e
                self._record_failure(model)
                logger.warning(f"Model {model} failed: {e}")
                continue
        
        # All models failed
        raise InferenceError(
            f"All models failed. Attempted: {attempted_models}. Last error: {last_error}"
        )
    
    def _record_failure(self, model: str):
        """Record failure for circuit breaker"""
        self.failure_counts[model] = self.failure_counts.get(model, 0) + 1
        
        # Open circuit after threshold failures
        if self.failure_counts[model] >= self.circuit_threshold:
            self.circuit_breakers[model] = time.time()
            logger.warning(f"Circuit breaker opened for {model}")
    
    def _record_success(self, model: str):
        """Record success, reset failure count"""
        self.failure_counts[model] = 0
    
    def _is_circuit_open(self, model: str) -> bool:
        """Check if circuit breaker is open"""
        if model not in self.circuit_breakers:
            return False
        
        # Close circuit after timeout
        if time.time() - self.circuit_breakers[model] > self.circuit_timeout:
            del self.circuit_breakers[model]
            return False
        
        return True


# ============================================================================
# Analytics Engine
# ============================================================================

class AnalyticsEngine:
    """Tracks inference metrics and analytics"""
    
    def __init__(self):
        self.metrics = {
            'total_requests': 0,
            'successful_requests': 0,
            'failed_requests': 0,
            'cached_requests': 0,
            'fallback_requests': 0,
            'total_input_tokens': 0,
            'total_output_tokens': 0,
            'total_cost_usd': 0.0,
            'latencies': [],  # Last 1000 latencies
            'model_usage': {},
            'task_type_usage': {},
            'errors': []  # Last 100 errors
        }
        self._lock = asyncio.Lock()
    
    async def record_request(self, response: InferenceResponse,
                            task_type: TaskType, cached: bool = False,
                            fallback: bool = False):
        """Record inference request metrics"""
        async with self._lock:
            self.metrics['total_requests'] += 1
            
            if response.status == 'success':
                self.metrics['successful_requests'] += 1
            else:
                self.metrics['failed_requests'] += 1
                self.metrics['errors'].append({
                    'request_id': response.request_id,
                    'error': response.error,
                    'timestamp': time.time()
                })
                # Keep only last 100 errors
                self.metrics['errors'] = self.metrics['errors'][-100:]
            
            if cached:
                self.metrics['cached_requests'] += 1
            
            if fallback:
                self.metrics['fallback_requests'] += 1
            
            self.metrics['total_input_tokens'] += response.tokens_used.get('input', 0)
            self.metrics['total_output_tokens'] += response.tokens_used.get('output', 0)
            self.metrics['total_cost_usd'] += response.cost_usd
            
            # Track latency (keep last 1000)
            self.metrics['latencies'].append(response.latency_ms)
            self.metrics['latencies'] = self.metrics['latencies'][-1000:]
            
            # Track model usage
            model = response.model_used
            self.metrics['model_usage'][model] = self.metrics['model_usage'].get(model, 0) + 1
            
            # Track task type usage
            task = task_type.value
            self.metrics['task_type_usage'][task] = self.metrics['task_type_usage'].get(task, 0) + 1
    
    def get_summary(self) -> Dict[str, Any]:
        """Get metrics summary"""
        latencies = self.metrics['latencies']
        
        if latencies:
            sorted_latencies = sorted(latencies)
            p50 = sorted_latencies[len(sorted_latencies) // 2]
            p95_idx = int(len(sorted_latencies) * 0.95)
            p99_idx = int(len(sorted_latencies) * 0.99)
            p95 = sorted_latencies[min(p95_idx, len(sorted_latencies) - 1)]
            p99 = sorted_latencies[min(p99_idx, len(sorted_latencies) - 1)]
        else:
            p50 = p95 = p99 = 0
        
        total = self.metrics['total_requests']
        cache_hit_rate = self.metrics['cached_requests'] / total if total > 0 else 0
        fallback_rate = self.metrics['fallback_requests'] / total if total > 0 else 0
        success_rate = self.metrics['successful_requests'] / total if total > 0 else 0
        
        return {
            'total_requests': total,
            'success_rate': round(success_rate, 4),
            'cache_hit_rate': round(cache_hit_rate, 4),
            'fallback_rate': round(fallback_rate, 4),
            'avg_latency_ms': round(sum(latencies) / len(latencies), 2) if latencies else 0,
            'p50_latency_ms': round(p50, 2),
            'p95_latency_ms': round(p95, 2),
            'p99_latency_ms': round(p99, 2),
            'total_tokens': self.metrics['total_input_tokens'] + self.metrics['total_output_tokens'],
            'total_cost_usd': round(self.metrics['total_cost_usd'], 4),
            'model_usage': self.metrics['model_usage'],
            'task_type_usage': self.metrics['task_type_usage']
        }


# ============================================================================
# Main Inference Gateway
# ============================================================================

class InferenceError(Exception):
    """Inference gateway error"""
    pass


class InferenceGateway:
    """Main inference gateway orchestrator"""
    
    def __init__(self, config_path: str = None):
        self.config_path = config_path or Path(__file__).parent.parent / 'config' / 'inference_gateway.yaml'
        self.config = self._load_config()
        
        # Initialize components
        self.validator = RequestValidator()
        self.model_clients: Dict[str, ModelClient] = {}
        self.models: Dict[str, ModelConfig] = {}
        
        self._init_model_clients()
        
        self.router = ModelRouter(self.models)
        self.batch_manager = BatchManager(
            max_batch_size=self.config.get('batching', {}).get('max_batch_size', 10),
            max_wait_ms=self.config.get('batching', {}).get('max_wait_ms', 100)
        )
        self.cache_manager = CacheManager(
            ttl_seconds=self.config.get('cache', {}).get('ttl_seconds', 300)
        )
        self.rate_limiter = RateLimiter(
            self.config.get('rate_limits', {})
        )
        self.fallback_handler = FallbackHandler(
            self.model_clients,
            self.config.get('fallback', {}).get('order')
        )
        self.analytics = AnalyticsEngine()
        
        logger.info("InferenceGateway initialized")
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration"""
        import yaml
        
        config_file = Path(self.config_path)
        if config_file.exists():
            with open(config_file) as f:
                return yaml.safe_load(f)
        else:
            logger.warning(f"Config file not found: {config_file}, using defaults")
            return {}
    
    def _init_model_clients(self):
        """Initialize model clients from config"""
        models_config = self.config.get('models', {})
        
        for model_id, model_data in models_config.items():
            config = ModelConfig(
                id=model_id,
                name=model_data.get('name', model_id),
                provider=model_data.get('provider', 'unknown'),
                endpoint=model_data.get('endpoint', ''),
                api_key_env=model_data.get('api_key_env'),
                max_tokens=model_data.get('max_tokens', 32768),
                cost_per_1k_input=model_data.get('cost_per_1k_input', 0),
                cost_per_1k_output=model_data.get('cost_per_1k_output', 0)
            )
            
            self.models[model_id] = config
            
            # Create appropriate client
            provider = model_data.get('provider', '').lower()
            if 'gemini' in provider or 'google' in provider:
                self.model_clients[model_id] = GeminiClient(config)
            elif 'qwen' in provider or 'alibaba' in provider:
                self.model_clients[model_id] = QwenClient(config)
            elif 'vllm' in provider or 'local' in provider:
                self.model_clients[model_id] = VLLMClient(config)
            else:
                logger.warning(f"Unknown provider {provider} for model {model_id}")
    
    async def complete(self, **kwargs) -> InferenceResponse:
        """
        Execute inference request.
        
        Args:
            **kwargs: Request parameters (prompt, model_hint, task_type, etc.)
        
        Returns:
            InferenceResponse object
        """
        start_time = time.time()
        
        try:
            # Validate request
            request = self.validator.validate(kwargs)
            
            # Check cache
            cache_key = self.cache_manager.generate_cache_key(request)
            cached_response = await self.cache_manager.get(cache_key)
            
            if cached_response:
                logger.debug(f"Cache hit for request {request.request_id}")
                await self.analytics.record_request(
                    cached_response, request.task_type, cached=True
                )
                return cached_response
            
            # Select model
            model_id = self.router.select_model(request)
            if not model_id:
                raise InferenceError("No available models")
            
            # Check rate limit
            if not await self.rate_limiter.acquire(model_id, request.max_tokens):
                raise InferenceError(f"Rate limit exceeded for model {model_id}")
            
            # Execute with fallback
            try:
                response = await self.fallback_handler.execute_with_fallback(
                    request, model_id
                )
            except Exception as e:
                self.rate_limiter.release(model_id)
                raise
            
            self.rate_limiter.release(model_id)
            
            # Cache response
            await self.cache_manager.set(cache_key, response)
            
            # Record analytics
            await self.analytics.record_request(response, request.task_type)
            
            # Record metrics
            if METRICS_AVAILABLE:
                try:
                    registry = get_metrics_registry()
                    registry.counter('inference_requests_total', labels={
                        'model': response.model_used,
                        'status': response.status,
                        'task_type': request.task_type.value
                    })
                    registry.histogram('inference_latency_ms', response.latency_ms, labels={
                        'model': response.model_used
                    })
                except Exception as e:
                    logger.warning(f"Failed to record metrics: {e}")
            
            return response
        
        except Exception as e:
            latency_ms = (time.time() - start_time) * 1000
            logger.error(f"Inference request failed: {e}")
            
            # Record error
            if METRICS_AVAILABLE:
                try:
                    record_error('inference_gateway', type(e).__name__)
                except:
                    pass
            
            raise InferenceError(f"Request failed: {e}")
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get inference metrics summary"""
        return self.analytics.get_summary()
    
    def get_model_status(self) -> Dict[str, Dict[str, Any]]:
        """Get status of all models"""
        status = {}
        for model_id, config in self.models.items():
            client = self.model_clients.get(model_id)
            status[model_id] = {
                'name': config.name,
                'status': config.status.value,
                'avg_latency_ms': config.avg_latency_ms,
                'request_count': client.request_count if client else 0,
                'total_tokens': client.total_tokens if client else 0
            }
        return status


# Convenience function
_gateway_instance: Optional[InferenceGateway] = None

def get_gateway() -> InferenceGateway:
    """Get or create gateway instance"""
    global _gateway_instance
    if _gateway_instance is None:
        _gateway_instance = InferenceGateway()
    return _gateway_instance
