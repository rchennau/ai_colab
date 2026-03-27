"""
ai-colab MCP Server v0.1.0

Model Context Protocol server for ai-colab orchestration.
Provides standardized tool access for LLM-CLIs and IDE integration.
"""

__version__ = "0.1.0"
__author__ = "ai-colab team"

from .server import server

__all__ = ["server"]
