"""
Document chunking module.
Splits documents into semantic chunks for embedding.
"""

import re
import logging
from typing import List, Dict, Any
from pathlib import Path

logger = logging.getLogger(__name__)


class DocumentChunker:
    """
    Chunks documents into semantic units for embedding.
    
    Supports:
    - Markdown: Split by headers (H1, H2, H3)
    - Python: Split by functions and classes
    - Shell: Split by functions
    - Generic: Fixed-size chunks with overlap
    """
    
    def __init__(self, chunk_size: int = 500, chunk_overlap: int = 50):
        """
        Initialize chunker.
        
        Args:
            chunk_size: Target chunk size in tokens (approximate)
            chunk_overlap: Overlap between chunks in tokens
        """
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
    
    def chunk(self, content: str, source: str, doc_type: str = None) -> List[Dict[str, Any]]:
        """
        Chunk a document into semantic units.
        
        Args:
            content: Document content
            source: Source file path
            doc_type: Document type (md, py, sh, txt). Auto-detected if None.
            
        Returns:
            List of chunks with content, metadata
        """
        if doc_type is None:
            doc_type = self._detect_type(source)
        
        if doc_type == 'md':
            return self._chunk_markdown(content, source)
        elif doc_type == 'py':
            return self._chunk_python(content, source)
        elif doc_type == 'sh':
            return self._chunk_shell(content, source)
        else:
            return self._chunk_generic(content, source)
    
    def _detect_type(self, source: str) -> str:
        """Detect document type from file extension."""
        suffix = Path(source).suffix.lower()
        type_map = {
            '.md': 'md',
            '.markdown': 'md',
            '.py': 'py',
            '.sh': 'sh',
            '.bash': 'sh',
            '.txt': 'txt',
            '.json': 'json',
            '.toml': 'toml',
            '.yaml': 'yaml',
            '.yml': 'yaml'
        }
        return type_map.get(suffix, 'txt')
    
    def _chunk_markdown(self, content: str, source: str) -> List[Dict[str, Any]]:
        """Chunk markdown by headers."""
        chunks = []
        
        # Split by H1/H2 headers
        header_pattern = r'(^#{1,2}\s+.+$)'
        sections = re.split(header_pattern, content, flags=re.MULTILINE)
        
        current_section = ""
        current_header = "Introduction"
        
        for i, section in enumerate(sections):
            if re.match(r'^#{1,2}\s+', section):
                # This is a header
                if current_section.strip():
                    chunks.append(self._create_chunk(
                        current_section, source, current_header, len(chunks)
                    ))
                current_header = section.strip('#').strip()
                current_section = ""
            else:
                current_section += section
        
        # Add final section
        if current_section.strip():
            chunks.append(self._create_chunk(
                current_section, source, current_header, len(chunks)
            ))
        
        # Split large sections into smaller chunks
        final_chunks = []
        for chunk in chunks:
            if len(chunk['content']) > self.chunk_size * 4:  # Rough char estimate
                sub_chunks = self._split_large_chunk(chunk)
                final_chunks.extend(sub_chunks)
            else:
                final_chunks.append(chunk)
        
        logger.info(f"Chunked markdown {source} into {len(final_chunks)} sections")
        return final_chunks
    
    def _chunk_python(self, content: str, source: str) -> List[Dict[str, Any]]:
        """Chunk Python code by functions and classes."""
        chunks = []
        
        # Split by function and class definitions
        pattern = r'(^(?:def|class)\s+\w+'
        sections = re.split(pattern, content, flags=re.MULTILINE)
        
        # Reconstruct with definitions
        matches = re.findall(pattern, content, flags=re.MULTILINE)
        
        current = ""
        for i, section in enumerate(sections):
            if i > 0 and i - 1 < len(matches):
                current += matches[i - 1]
            current += section
            
            if self._is_complete_block(current):
                if current.strip():
                    chunks.append(self._create_chunk(
                        current, source, f"Code block {len(chunks)}", len(chunks)
                    ))
                current = ""
        
        # Add remaining
        if current.strip():
            chunks.append(self._create_chunk(
                current, source, "Code block", len(chunks)
            ))
        
        logger.info(f"Chunked Python {source} into {len(chunks)} blocks")
        return chunks
    
    def _chunk_shell(self, content: str, source: str) -> List[Dict[str, Any]]:
        """Chunk shell scripts by functions."""
        chunks = []
        
        # Split by function definitions
        pattern = r'(^[\w_]+\s*\(\)\s*\{|^function\s+\w+\s*\{)'
        sections = re.split(pattern, content, flags=re.MULTILINE)
        
        current = ""
        for section in sections:
            current += section
            if current.count('{') == current.count('}'):
                if current.strip():
                    # Extract function name
                    match = re.search(r'^(\w+)\s*\(\)', current)
                    func_name = match.group(1) if match else "script"
                    
                    chunks.append(self._create_chunk(
                        current, source, f"Function: {func_name}", len(chunks)
                    ))
                current = ""
        
        # Add remaining (global code)
        if current.strip():
            chunks.append(self._create_chunk(
                current, source, "Global code", len(chunks)
            ))
        
        logger.info(f"Chunked shell {source} into {len(chunks)} blocks")
        return chunks
    
    def _chunk_generic(self, content: str, source: str) -> List[Dict[str, Any]]:
        """Chunk generic text into fixed-size chunks with overlap."""
        chunks = []
        
        # Split into lines first
        lines = content.split('\n')
        current_chunk = ""
        
        for line in lines:
            if len(current_chunk) + len(line) > self.chunk_size * 4:
                # Save current chunk
                chunks.append(self._create_chunk(
                    current_chunk, source, "Text block", len(chunks)
                ))
                # Start new chunk with overlap
                overlap_lines = lines[max(0, len(lines) - self.chunk_overlap):]
                current_chunk = '\n'.join(overlap_lines) + '\n' + line
            else:
                current_chunk += line + '\n'
        
        # Add final chunk
        if current_chunk.strip():
            chunks.append(self._create_chunk(
                current_chunk, source, "Text block", len(chunks)
            ))
        
        logger.info(f"Chunked generic {source} into {len(chunks)} blocks")
        return chunks
    
    def _create_chunk(self, content: str, source: str, section: str, index: int) -> Dict[str, Any]:
        """Create a chunk with metadata."""
        return {
            'content': content.strip(),
            'source': str(source),
            'section': section,
            'chunk_index': index,
            'char_count': len(content),
            'token_estimate': len(content) // 4  # Rough estimate
        }
    
    def _is_complete_block(self, code: str) -> bool:
        """Check if code block is complete (balanced braces)."""
        # Simple heuristic - count braces
        open_braces = code.count('{') - code.count('\\{')
        close_braces = code.count('}') - code.count('\\}')
        return open_braces > 0 and open_braces == close_braces
    
    def _split_large_chunk(self, chunk: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Split a large chunk into smaller pieces."""
        content = chunk['content']
        source = chunk['source']
        section = chunk['section']
        base_index = chunk['chunk_index']
        
        # Split by paragraphs
        paragraphs = re.split(r'\n\n+', content)
        sub_chunks = []
        current = ""
        
        for para in paragraphs:
            if len(current) + len(para) > self.chunk_size * 4:
                if current.strip():
                    sub_chunks.append(self._create_chunk(
                        current, source, f"{section} (part {len(sub_chunks) + 1})", base_index + len(sub_chunks)
                    ))
                current = para
            else:
                current += '\n\n' + para if current else para
        
        if current.strip():
            sub_chunks.append(self._create_chunk(
                current, source, f"{section} (part {len(sub_chunks) + 1})", base_index + len(sub_chunks)
            ))
        
        return sub_chunks


# Convenience function
def chunk_document(content: str, source: str, **kwargs) -> List[Dict[str, Any]]:
    """Quick chunking function."""
    chunker = DocumentChunker(**kwargs)
    return chunker.chunk(content, source)
