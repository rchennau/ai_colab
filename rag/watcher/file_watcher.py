"""
File watcher for automatic document re-indexing.
"""

import logging
import time
import threading
from pathlib import Path
from typing import List, Optional, Callable, Set
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileModifiedEvent, FileCreatedEvent, FileDeletedEvent, DirDeletedEvent

logger = logging.getLogger(__name__)


class DocumentEventHandler(FileSystemEventHandler):
    """
    Handles file system events for document indexing.
    """
    
    def __init__(self, watcher: 'DocumentWatcher'):
        self.watcher = watcher
        self._debounce_timers = {}
    
    def _schedule_reindex(self, path: str, event_type: str):
        """Schedule re-indexing with debouncing."""
        if path in self._debounce_timers:
            self._debounce_timers[path].cancel()
        
        timer = threading.Timer(
            self.watcher.debounce_seconds,
            self.watcher._reindex_file,
            args=[path, event_type]
        )
        timer.start()
        self._debounce_timers[path] = timer
    
    def on_modified(self, event):
        """Handle file modification events."""
        if event.is_directory:
            return
        
        path = str(event.src_path)
        if self.watcher._should_index(path):
            logger.info(f"File modified: {path}")
            self._schedule_reindex(path, 'modified')
    
    def on_created(self, event):
        """Handle file creation events."""
        if event.is_directory:
            return
        
        path = str(event.src_path)
        if self.watcher._should_index(path):
            logger.info(f"File created: {path}")
            self._schedule_reindex(path, 'created')
    
    def on_deleted(self, event):
        """Handle file deletion events."""
        path = str(event.src_path if hasattr(event, 'src_path') else event.dest_path)
        if self.watcher._should_index(path):
            logger.info(f"File deleted: {path}")
            self.watcher._remove_from_index(path)


class DocumentWatcher:
    """
    Watches document directories for changes and triggers re-indexing.
    
    Features:
    - Debounced file change detection
    - Automatic re-indexing
    - Configurable source patterns
    """
    
    def __init__(self, 
                 index_path: str,
                 sources: Optional[List[str]] = None,
                 debounce_seconds: float = 2.0):
        """
        Initialize document watcher.
        
        Args:
            index_path: Path to SQLite index database
            sources: List of source patterns to watch
            debounce_seconds: Seconds to wait before re-indexing
        """
        from ..indexer.pipeline import IndexingPipeline
        
        self.index_path = Path(index_path)
        self.sources = sources or [
            "conductor/*.md",
            "conductor/tracks/**/*.md",
            "system-prompts/*.md",
            "docs/*.md",
            "scripts/*.sh",
            "webui/*.py",
            "mcp/**/*.py",
            "rag/**/*.py"
        ]
        self.debounce_seconds = debounce_seconds
        
        # Project root
        self.project_root = Path(__file__).parent.parent.parent
        
        # Watch directories (unique parent dirs of source patterns)
        self.watch_dirs = self._get_watch_directories()
        
        # Indexing pipeline for re-indexing
        self.pipeline = IndexingPipeline(str(index_path), sources=sources)
        
        # Observer and handler
        self.observer = None
        self.handler = DocumentEventHandler(self)
        
        # Running state
        self._running = False
        self._indexed_files: Set[str] = set()
        
        logger.info(f"DocumentWatcher initialized for {len(self.watch_dirs)} directories")
    
    def _get_watch_directories(self) -> Set[Path]:
        """Get unique directories to watch from source patterns."""
        watch_dirs = set()
        
        for pattern in self.sources:
            # Get the base directory from pattern
            parts = pattern.split('/')
            base = self.project_root
            
            for part in parts:
                if '*' in part:
                    break
                base = base / part
            
            if base.exists():
                watch_dirs.add(base)
            else:
                # Try parent if base doesn't exist
                if self.project_root.exists():
                    watch_dirs.add(self.project_root)
        
        return watch_dirs
    
    def _should_index(self, file_path: str) -> bool:
        """Check if file should be indexed based on patterns."""
        from pathlib import Path
        import fnmatch
        
        file_path_obj = Path(file_path)
        
        # Check if file matches any source pattern
        for pattern in self.sources:
            full_pattern = str(self.project_root / pattern)
            if fnmatch.fnmatch(str(file_path_obj), full_pattern):
                # Check exclusion patterns
                exclude_patterns = [
                    "**/node_modules/**",
                    "**/.git/**",
                    "**/*.pyc",
                    "**/__pycache__/**"
                ]
                
                for exclude in exclude_patterns:
                    if exclude.replace('**/', '') in str(file_path_obj):
                        return False
                
                return True
        
        return False
    
    def _reindex_file(self, file_path: str, event_type: str):
        """Re-index a single file."""
        try:
            logger.info(f"Re-indexing file: {file_path} ({event_type})")
            
            if event_type == 'deleted':
                self._remove_from_index(file_path)
            else:
                # Run pipeline for single file
                result = self.pipeline._index_file(Path(file_path))
                logger.info(f"Re-indexing complete: {result}")
            
            self.pipeline._mark_file_indexed(Path(file_path))
            
        except Exception as e:
            logger.error(f"Re-indexing failed for {file_path}: {e}")
    
    def _remove_from_index(self, file_path: str):
        """Remove file from index."""
        try:
            # Get all doc IDs for this source
            cursor = self.pipeline.vector_store.conn.cursor()
            cursor.execute(
                'SELECT id FROM documents WHERE source = ?',
                (str(file_path),)
            )
            doc_ids = [row[0] for row in cursor.fetchall()]
            
            # Delete documents and embeddings
            for doc_id in doc_ids:
                self.pipeline.vector_store.delete(doc_id)
            
            logger.info(f"Removed {len(doc_ids)} chunks for {file_path}")
            
        except Exception as e:
            logger.error(f"Failed to remove {file_path} from index: {e}")
    
    def start(self):
        """Start watching for file changes."""
        if self._running:
            logger.warning("Watcher already running")
            return
        
        logger.info(f"Starting file watcher on {len(self.watch_dirs)} directories")
        
        self.observer = Observer()
        
        for watch_dir in self.watch_dirs:
            if watch_dir.exists():
                self.observer.schedule(
                    self.handler,
                    str(watch_dir),
                    recursive=True
                )
                logger.info(f"Watching: {watch_dir}")
        
        self.observer.start()
        self._running = True
        
        logger.info("File watcher started")
    
    def stop(self):
        """Stop watching for file changes."""
        if not self._running:
            return
        
        logger.info("Stopping file watcher")
        
        self.observer.stop()
        self.observer.join()
        self._running = False
        
        logger.info("File watcher stopped")
    
    def run_forever(self):
        """Start watcher and run until interrupted."""
        self.start()
        
        try:
            while self._running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Interrupted, stopping watcher")
        finally:
            self.stop()
    
    def __enter__(self):
        """Context manager entry."""
        self.start()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.stop()
    
    def close(self):
        """Clean up resources."""
        self.stop()
        self.pipeline.close()


# Convenience function
def start_watcher(index_path: Optional[str] = None, **kwargs):
    """
    Start file watcher in background.
    
    Returns:
        DocumentWatcher instance
    """
    if index_path is None:
        project_root = Path(__file__).parent.parent.parent
        index_path = str(project_root / ".ai-colab" / "rag" / "index.db")
    
    watcher = DocumentWatcher(index_path, **kwargs)
    watcher.start()
    
    return watcher
