"""
SSE (Server-Sent Events) transport for MCP server.
Enables HTTP-based MCP connections for web clients.
"""

import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# Check for required dependencies
try:
    from fastapi import FastAPI, Request
    from fastapi.responses import HTMLResponse
    from fastapi.middleware.cors import CORSMiddleware
    from sse_starlette.sse import EventSourceResponse
    import uvicorn
    SSE_AVAILABLE = True
except ImportError as e:
    logger.warning(f"SSE transport dependencies not installed: {e}")
    logger.warning("Install with: pip install fastapi uvicorn sse-starlette")
    SSE_AVAILABLE = False


class SSETransport:
    """
    SSE transport for MCP server.
    
    Provides HTTP-based MCP connections using Server-Sent Events.
    Useful for browser-based clients and web integrations.
    """
    
    def __init__(self, host: str = "0.0.0.0", port: int = 8765):
        """
        Initialize SSE transport.
        
        Args:
            host: Host to bind to
            port: Port to listen on
        """
        self.host = host
        self.port = port
        self.app = None
        self.server = None
        self._running = False
        
        if SSE_AVAILABLE:
            self._create_app()
    
    def _create_app(self):
        """Create FastAPI application for SSE transport."""
        if not SSE_AVAILABLE:
            return
        
        self.app = FastAPI(
            title="ai-colab MCP Server",
            description="Model Context Protocol server with SSE transport",
            version="0.1.0"
        )
        
        # Enable CORS
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
        
        # Register routes
        self._register_routes()
    
    def _register_routes(self):
        """Register SSE routes."""
        if not self.app:
            return
        
        @self.app.get("/")
        async def root():
            """Root endpoint with server info."""
            return {
                "name": "ai-colab MCP Server",
                "version": "0.1.0",
                "transport": "sse",
                "endpoints": {
                    "sse": "/sse",
                    "messages": "/messages"
                }
            }
        
        @self.app.get("/sse")
        async def sse_endpoint(request: Request):
            """SSE endpoint for MCP messages."""
            # This is a simplified SSE endpoint
            # Full MCP SSE implementation would handle the MCP protocol
            
            async def event_generator():
                """Generate SSE events."""
                yield {
                    "event": "connected",
                    "data": '{"message": "Connected to ai-colab MCP server"}'
                }
                
                # Keep connection alive
                while self._running:
                    yield {
                        "event": "ping",
                        "data": '{"timestamp": "heartbeat"}'
                    }
                    await asyncio.sleep(30)
            
            return EventSourceResponse(event_generator())
        
        @self.app.post("/messages")
        async def messages_endpoint(request: Request):
            """MCP message endpoint."""
            try:
                body = await request.json()
                logger.info(f"Received MCP message: {body}")
                
                # Process MCP message (simplified)
                # In production, this would integrate with the MCP server
                
                return {
                    "status": "received",
                    "message_id": body.get("id"),
                    "result": {
                        "message": "Message processing not fully implemented in SSE transport"
                    }
                }
            except Exception as e:
                logger.error(f"Message processing error: {e}")
                return {
                    "status": "error",
                    "error": str(e)
                }
        
        @self.app.get("/health")
        async def health():
            """Health check endpoint."""
            return {
                "status": "healthy",
                "transport": "sse",
                "running": self._running
            }
    
    def start(self, background: bool = False):
        """
        Start SSE server.
        
        Args:
            background: Run in background thread
        """
        if not SSE_AVAILABLE:
            logger.error("SSE transport dependencies not installed")
            return False
        
        if self._running:
            logger.warning("SSE transport already running")
            return True
        
        logger.info(f"Starting SSE transport on {self.host}:{self.port}")
        
        self._running = True
        
        if background:
            import threading
            thread = threading.Thread(target=self._run_server, daemon=True)
            thread.start()
            logger.info("SSE transport started in background")
        else:
            self._run_server()
        
        return True
    
    def _run_server(self):
        """Run the uvicorn server."""
        if not self.app:
            return
        
        config = uvicorn.Config(
            self.app,
            host=self.host,
            port=self.port,
            log_level="info",
            access_log=False
        )
        
        self.server = uvicorn.Server(config)
        
        try:
            self.server.run()
        except KeyboardInterrupt:
            logger.info("SSE transport stopped")
        finally:
            self._running = False
    
    def stop(self):
        """Stop SSE server."""
        if not self._running:
            return
        
        logger.info("Stopping SSE transport")
        
        if self.server:
            self.server.should_exit = True
        
        self._running = False
    
    def is_running(self) -> bool:
        """Check if server is running."""
        return self._running


# Convenience function to create and start transport
def create_sse_transport(host: str = "0.0.0.0", port: int = 8765, 
                         background: bool = False) -> Optional[SSETransport]:
    """
    Create and start SSE transport.
    
    Args:
        host: Host to bind to
        port: Port to listen on
        background: Run in background
        
    Returns:
        SSETransport instance or None if unavailable
    """
    if not SSE_AVAILABLE:
        logger.error("SSE transport not available")
        return None
    
    transport = SSETransport(host, port)
    transport.start(background=background)
    
    return transport
