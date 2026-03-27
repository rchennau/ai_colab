"""
RAG (Retrieval-Augmented Generation) system for ai-colab.
Provides semantic search and context retrieval for LLM-CLIs.
"""

__version__ = "0.1.0"
__author__ = "ai-colab team"

from .client import RAGClient

__all__ = ["RAGClient"]
