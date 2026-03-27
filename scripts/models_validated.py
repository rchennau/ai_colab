"""
Pydantic Models for Validation
Replaces dataclasses with validated models.
"""

from pydantic import BaseModel, Field, validator
from typing import Any, Dict, List, Optional
from datetime import datetime
from enum import Enum


# ============================================================================
# Enums
# ============================================================================

class TaskType(str, Enum):
    """Task types"""
    CHAT = "chat"
    COMPLETION = "completion"
    CODE = "code"
    ANALYSIS = "analysis"
    ARCHITECTURE = "architecture"
    REVIEW = "review"


class ModelStatus(str, Enum):
    """Model deployment status"""
    STAGING = "staging"
    ACTIVE = "active"
    INACTIVE = "inactive"
    DEPRECATED = "deprecated"


class TaskStatus(str, Enum):
    """Task execution status"""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    BLOCKED = "blocked"
    COMPLETED = "completed"
    FAILED = "failed"


# ============================================================================
# Inference Models
# ============================================================================

class InferenceRequest(BaseModel):
    """Validated inference request"""
    
    request_id: str = Field(..., min_length=1, description="Unique request ID")
    prompt: str = Field(..., min_length=1, max_length=100000, description="Input prompt")
    model_hint: Optional[str] = Field(None, description="Preferred model")
    task_type: TaskType = Field(default=TaskType.CHAT, description="Task type")
    max_tokens: int = Field(default=1024, ge=1, le=32768, description="Max tokens")
    temperature: float = Field(default=0.7, ge=0.0, le=2.0, description="Temperature")
    top_p: float = Field(default=0.9, ge=0.0, le=1.0, description="Top-p sampling")
    priority: int = Field(default=5, ge=1, le=10, description="Priority 1-10")
    timeout_ms: int = Field(default=30000, ge=1000, le=300000, description="Timeout")
    
    class Config:
        use_enum_values = True


class InferenceResponse(BaseModel):
    """Validated inference response"""
    
    request_id: str = Field(..., description="Request ID")
    response: str = Field(..., description="Response text")
    model_used: str = Field(..., description="Model used")
    tokens_used: Dict[str, int] = Field(..., description="Token usage")
    latency_ms: float = Field(..., ge=0, description="Latency in ms")
    cached: bool = Field(default=False, description="Was cached")
    cost_usd: float = Field(default=0.0, ge=0, description="Cost in USD")
    status: str = Field(default="success", description="Status")
    error: Optional[str] = Field(None, description="Error message if failed")


# ============================================================================
# Model Registry Models
# ============================================================================

class ModelConfig(BaseModel):
    """Model configuration"""
    
    id: str = Field(..., min_length=1, description="Model ID")
    name: str = Field(..., min_length=1, description="Model name")
    provider: str = Field(..., min_length=1, description="Provider")
    access_method: str = Field(default="cli", description="cli or api")
    cli_command: Optional[str] = Field(None, description="CLI command")
    cli_args: List[str] = Field(default_factory=list, description="CLI args")
    api_endpoint: Optional[str] = Field(None, description="API endpoint")
    api_key_env: Optional[str] = Field(None, description="API key env var")
    model_id: Optional[str] = Field(None, description="Model identifier")
    max_tokens: int = Field(default=32768, ge=1, description="Max tokens")
    cost_per_1k_input: float = Field(default=0.0, ge=0, description="Cost per 1K input")
    cost_per_1k_output: float = Field(default=0.0, ge=0, description="Cost per 1K output")
    status: ModelStatus = Field(default=ModelStatus.UNKNOWN, description="Status")
    avg_latency_ms: float = Field(default=0.0, ge=0, description="Avg latency")
    
    class Config:
        use_enum_values = True


class ModelVersion(BaseModel):
    """Model version information"""
    
    model_id: str = Field(..., description="Model ID")
    version: str = Field(..., description="Version string")
    provider: str = Field(..., description="Provider")
    endpoint: str = Field(..., description="Endpoint URL")
    config: Dict[str, Any] = Field(default_factory=dict, description="Config")
    status: ModelStatus = Field(default=ModelStatus.STAGING, description="Status")
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    deployed_at: Optional[str] = Field(None, description="Deployment time")
    metrics: Dict[str, float] = Field(default_factory=dict, description="Metrics")
    
    class Config:
        use_enum_values = True


# ============================================================================
# Agent Federation Models
# ============================================================================

class AgentRole(str, Enum):
    """Agent roles"""
    LEADER = "leader"
    WORKER = "worker"
    REVIEWER = "reviewer"
    ARCHITECT = "architect"
    SPECIALIST = "specialist"


class Agent(BaseModel):
    """Agent information"""
    
    agent_id: str = Field(..., min_length=1, description="Agent ID")
    name: str = Field(..., min_length=1, description="Agent name")
    role: AgentRole = Field(default=AgentRole.WORKER, description="Role")
    capabilities: List[str] = Field(default_factory=list, description="Capabilities")
    expertise_areas: List[str] = Field(default_factory=list, description="Expertise")
    status: str = Field(default="available", description="Status")
    current_task: Optional[str] = Field(None, description="Current task")
    performance_score: float = Field(default=0.0, ge=0.0, le=10.0, description="Score")
    knowledge_version: int = Field(default=0, description="Knowledge version")
    last_seen: str = Field(default_factory=lambda: datetime.now().isoformat())
    
    class Config:
        use_enum_values = True


class Task(BaseModel):
    """Task definition"""
    
    task_id: str = Field(..., min_length=1, description="Task ID")
    title: str = Field(..., min_length=1, description="Title")
    description: str = Field(..., description="Description")
    assigned_to: List[str] = Field(default_factory=list, description="Agent IDs")
    status: TaskStatus = Field(default=TaskStatus.PENDING, description="Status")
    priority: int = Field(default=5, ge=1, le=10, description="Priority")
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    started_at: Optional[str] = Field(None, description="Start time")
    completed_at: Optional[str] = Field(None, description="Completion time")
    dependencies: List[str] = Field(default_factory=list, description="Dependencies")
    requires_consensus: bool = Field(default=False, description="Needs consensus")
    consensus_type: str = Field(default="majority", description="Consensus type")
    results: Dict[str, Any] = Field(default_factory=dict, description="Results")
    
    class Config:
        use_enum_values = True


# ============================================================================
# Vision Models
# ============================================================================

class ImageInput(BaseModel):
    """Image input for vision analysis"""
    
    image_path: str = Field(..., description="Path to image")
    image_type: str = Field(default="screenshot", description="Image type")
    description: Optional[str] = Field(None, description="Description")
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())


# ============================================================================
# Validation Helpers
# ============================================================================

def validate_prompt(prompt: str, max_length: int = 100000) -> str:
    """Validate prompt"""
    if not prompt or not prompt.strip():
        raise ValueError("Prompt cannot be empty")
    if len(prompt) > max_length:
        raise ValueError(f"Prompt too long (max {max_length} chars)")
    return prompt.strip()


def validate_model_id(model_id: str) -> str:
    """Validate model ID"""
    if not model_id or not model_id.strip():
        raise ValueError("Model ID cannot be empty")
    return model_id.strip()


def validate_api_key(api_key: str) -> str:
    """Validate API key format"""
    if not api_key or len(api_key) < 10:
        raise ValueError("Invalid API key format")
    return api_key
