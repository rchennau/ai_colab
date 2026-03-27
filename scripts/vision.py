"""
ai-colab Vision/Screenshot Support
Enables image/screenshot upload and analysis via LLM CLI tools.
"""

import base64
import logging
import os
import tempfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger('ai_colab.vision')


@dataclass
class ImageInput:
    """Image input for LLM"""
    image_path: str
    image_type: str = "screenshot"  # screenshot, upload, diagram, code
    description: Optional[str] = None
    created_at: str = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now().isoformat()
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'image_path': self.image_path,
            'image_type': self.image_type,
            'description': self.description,
            'created_at': self.created_at
        }


class VisionManager:
    """
    Manages image/screenshot input for LLM tools.
    
    Features:
    - Screenshot capture
    - Image upload handling
    - Base64 encoding for API transmission
    - Image storage and retrieval
    """
    
    def __init__(self, storage_dir: str = None):
        if storage_dir is None:
            storage_dir = Path.home() / '.ai-colab' / 'images'
        
        self.storage_dir = Path(storage_dir)
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        
        logger.info(f"VisionManager initialized: {self.storage_dir}")
    
    def capture_screenshot(self, filename: str = None) -> str:
        """
        Capture a screenshot.
        
        Returns path to saved screenshot.
        """
        try:
            import pyautogui
            
            if filename is None:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"screenshot_{timestamp}.png"
            
            filepath = self.storage_dir / filename
            screenshot = pyautogui.screenshot()
            screenshot.save(str(filepath))
            
            logger.info(f"Screenshot captured: {filepath}")
            return str(filepath)
            
        except ImportError:
            logger.warning("pyautogui not installed. Install with: pip install pyautogui")
            return None
        except Exception as e:
            logger.error(f"Screenshot capture failed: {e}")
            return None
    
    def save_image(self, image_data: bytes, filename: str,
                  image_type: str = "upload") -> str:
        """
        Save uploaded image.
        
        Args:
            image_data: Raw image bytes
            filename: Filename to save as
            image_type: Type of image (screenshot, upload, diagram, code)
        
        Returns:
            Path to saved image
        """
        filepath = self.storage_dir / filename
        
        try:
            with open(filepath, 'wb') as f:
                f.write(image_data)
            
            logger.info(f"Image saved: {filepath} ({image_type})")
            return str(filepath)
            
        except Exception as e:
            logger.error(f"Failed to save image: {e}")
            return None
    
    def image_to_base64(self, image_path: str) -> str:
        """
        Convert image to base64 string for API transmission.
        
        Args:
            image_path: Path to image file
        
        Returns:
            Base64 encoded image string
        """
        try:
            with open(image_path, 'rb') as f:
                image_data = f.read()
            
            base64_string = base64.b64encode(image_data).decode('utf-8')
            
            # Get MIME type from extension
            ext = Path(image_path).suffix.lower()
            mime_types = {
                '.png': 'image/png',
                '.jpg': 'image/jpeg',
                '.jpeg': 'image/jpeg',
                '.gif': 'image/gif',
                '.webp': 'image/webp'
            }
            
            mime_type = mime_types.get(ext, 'image/png')
            
            return f"data:{mime_type};base64,{base64_string}"
            
        except Exception as e:
            logger.error(f"Failed to encode image: {e}")
            return None
    
    def get_image(self, image_id: str) -> Optional[Dict[str, Any]]:
        """
        Get image information.
        
        Args:
            image_id: Image filename or path
        
        Returns:
            Image metadata dict
        """
        # Try as filename first
        filepath = self.storage_dir / image_id
        
        if not filepath.exists():
            # Try as full path
            filepath = Path(image_id)
        
        if not filepath.exists():
            return None
        
        # Get file info
        stat = filepath.stat()
        
        return {
            'image_id': filepath.name,
            'path': str(filepath),
            'size_bytes': stat.st_size,
            'created_at': datetime.fromtimestamp(stat.st_ctime).isoformat(),
            'modified_at': datetime.fromtimestamp(stat.st_mtime).isoformat()
        }
    
    def list_images(self, image_type: str = None,
                   limit: int = 50) -> List[Dict[str, Any]]:
        """
        List stored images.
        
        Args:
            image_type: Filter by image type
            limit: Maximum images to return
        
        Returns:
            List of image metadata
        """
        images = []
        
        for filepath in sorted(self.storage_dir.glob('*.png'),
                              key=lambda p: p.stat().st_mtime,
                              reverse=True)[:limit]:
            
            # Determine image type from filename
            name = filepath.name
            if name.startswith('screenshot_'):
                itype = 'screenshot'
            elif name.startswith('diagram_'):
                itype = 'diagram'
            elif name.startswith('code_'):
                itype = 'code'
            else:
                itype = 'upload'
            
            # Filter by type if specified
            if image_type and itype != image_type:
                continue
            
            stat = filepath.stat()
            images.append({
                'image_id': name,
                'path': str(filepath),
                'type': itype,
                'size_bytes': stat.st_size,
                'created_at': datetime.fromtimestamp(stat.st_ctime).isoformat()
            })
        
        return images
    
    def delete_image(self, image_id: str) -> bool:
        """
        Delete an image.
        
        Args:
            image_id: Image filename or path
        
        Returns:
            True if deleted successfully
        """
        filepath = self.storage_dir / image_id
        
        if not filepath.exists():
            filepath = Path(image_id)
        
        if filepath.exists():
            try:
                filepath.unlink()
                logger.info(f"Image deleted: {image_id}")
                return True
            except Exception as e:
                logger.error(f"Failed to delete image: {e}")
                return False
        
        return False
    
    def cleanup_old_images(self, days: int = 7) -> int:
        """
        Clean up old images.
        
        Args:
            days: Delete images older than this many days
        
        Returns:
            Number of images deleted
        """
        cutoff = datetime.now().timestamp() - (days * 24 * 60 * 60)
        deleted = 0
        
        for filepath in self.storage_dir.glob('*.png'):
            if filepath.stat().st_mtime < cutoff:
                try:
                    filepath.unlink()
                    deleted += 1
                except:
                    pass
        
        if deleted > 0:
            logger.info(f"Cleaned up {deleted} old images")
        
        return deleted


# ============================================================================
# Vision-Enhanced LLM Client
# ============================================================================

class VisionLLMClient:
    """
    LLM client with vision/screenshot support.
    
    Extends standard LLM calls with image input capability.
    """
    
    def __init__(self, model: str = "gemini"):
        self.model = model
        self.vision_manager = VisionManager()
        
        # Vision-capable models
        self.vision_models = {
            'gemini': 'gemini-2.0-flash-exp',
            'claude': 'claude-3-5-sonnet-20241022',
            'gpt4v': 'gpt-4-turbo'
        }
    
    async def analyze_image(self, image_path: str,
                           prompt: str = "What's in this image?") -> str:
        """
        Analyze an image using vision-capable LLM.
        
        Args:
            image_path: Path to image file
            prompt: Question/prompt about the image
        
        Returns:
            LLM's analysis of the image
        """
        # Convert image to base64
        base64_image = self.vision_manager.image_to_base64(image_path)
        
        if not base64_image:
            return "Error: Failed to encode image"
        
        # Route to appropriate model
        if self.model == 'gemini':
            return await self._gemini_vision(prompt, base64_image)
        elif self.model == 'claude':
            return await self._claude_vision(prompt, base64_image)
        elif self.model == 'gpt4v':
            return await self._gpt4v_vision(prompt, base64_image)
        else:
            return f"Error: Unknown vision model: {self.model}"
    
    async def _gemini_vision(self, prompt: str,
                            base64_image: str) -> str:
        """Analyze image using Gemini"""
        try:
            # Use gemini-cli with image support
            import subprocess
            import json
            
            # Create temporary file with prompt and image
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
                request = {
                    'contents': [{
                        'parts': [
                            {'text': prompt},
                            {'inline_data': {
                                'mime_type': 'image/png',
                                'data': base64_image.split(',')[1]  # Remove data:image/png;base64, prefix
                            }}
                        ]
                    }]
                }
                json.dump(request, f)
                temp_file = f.name
            
            try:
                # Call gemini with image
                result = subprocess.run(
                    ['gemini', 'shell', '--request', temp_file],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                
                if result.returncode == 0:
                    return result.stdout.strip()
                else:
                    return f"Error: {result.stderr}"
                    
            finally:
                os.unlink(temp_file)
                
        except Exception as e:
            return f"Error analyzing image with Gemini: {e}"
    
    async def _claude_vision(self, prompt: str,
                            base64_image: str) -> str:
        """Analyze image using Claude"""
        try:
            import subprocess
            
            # Create temporary file with request
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
                request = {
                    'model': 'claude-3-5-sonnet-20241022',
                    'max_tokens': 1024,
                    'messages': [{
                        'role': 'user',
                        'content': [
                            {
                                'type': 'image',
                                'source': {
                                    'type': 'base64',
                                    'media_type': 'image/png',
                                    'data': base64_image.split(',')[1]
                                }
                            },
                            {
                                'type': 'text',
                                'text': prompt
                            }
                        ]
                    }]
                }
                json.dump(request, f)
                temp_file = f.name
            
            try:
                result = subprocess.run(
                    ['claude', '--request', temp_file],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                
                if result.returncode == 0:
                    return result.stdout.strip()
                else:
                    return f"Error: {result.stderr}"
                    
            finally:
                os.unlink(temp_file)
                
        except Exception as e:
            return f"Error analyzing image with Claude: {e}"
    
    async def _gpt4v_vision(self, prompt: str,
                           base64_image: str) -> str:
        """Analyze image using GPT-4 Vision"""
        try:
            from openai import OpenAI
            
            client = OpenAI()
            
            response = await client.chat.completions.create(
                model="gpt-4-turbo",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {"url": base64_image}}
                        ]
                    }
                ],
                max_tokens=1024
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            return f"Error analyzing image with GPT-4V: {e}"
    
    async def analyze_screenshot(self, prompt: str = None) -> Dict[str, Any]:
        """
        Capture and analyze a screenshot.
        
        Args:
            prompt: Optional prompt for analysis
        
        Returns:
            Dict with screenshot path and analysis
        """
        if prompt is None:
            prompt = "What is shown in this screenshot? Identify any errors, UI elements, or code."
        
        # Capture screenshot
        screenshot_path = self.vision_manager.capture_screenshot()
        
        if not screenshot_path:
            return {
                'success': False,
                'error': 'Failed to capture screenshot'
            }
        
        # Analyze screenshot
        analysis = await self.analyze_image(screenshot_path, prompt)
        
        return {
            'success': True,
            'screenshot_path': screenshot_path,
            'analysis': analysis,
            'timestamp': datetime.now().isoformat()
        }


# ============================================================================
# Convenience Functions
# ============================================================================

_vision_client: Optional[VisionLLMClient] = None


def get_vision_client(model: str = "gemini") -> VisionLLMClient:
    """Get or create vision client instance"""
    global _vision_client
    if _vision_client is None or _vision_client.model != model:
        _vision_client = VisionLLMClient(model)
    return _vision_client


async def analyze_screenshot(prompt: str = None,
                            model: str = "gemini") -> Dict[str, Any]:
    """
    Quick function to capture and analyze a screenshot.
    
    Args:
        prompt: Optional analysis prompt
        model: LLM model to use
    
    Returns:
        Analysis results dict
    """
    client = get_vision_client(model)
    return await client.analyze_screenshot(prompt)


async def analyze_image(image_path: str, prompt: str = None,
                       model: str = "gemini") -> str:
    """
    Quick function to analyze an image.
    
    Args:
        image_path: Path to image file
        prompt: Analysis prompt
        model: LLM model to use
    
    Returns:
        LLM analysis text
    """
    if prompt is None:
        prompt = "What's in this image?"
    
    client = get_vision_client(model)
    return await client.analyze_image(image_path, prompt)
