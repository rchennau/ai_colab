"""
MCP Server initialization and configuration.
"""

import os
import sys
import logging
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from fastmcp import FastMCP

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize MCP server
server = FastMCP(
    name="ai-colab",
    version="0.1.0",
    description="ai-colab orchestration server with MCP tools for LLM-CLI integration"
)

# Import tools to register them with the server
# This is done at the end to avoid circular imports
from .tools import blackboard, tracks, knowledge, agents, devops

logger.info("ai-colab MCP server initialized")


def main():
    """Run the MCP server with stdio transport."""
    logger.info("Starting ai-colab MCP server (stdio transport)")
    server.run()


if __name__ == "__main__":
    main()
