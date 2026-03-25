#!/usr/bin/env python3
"""
Web UI File Watcher for Automated Testing
Monitors webui/ directory for changes and automatically runs tests
"""

import os
import sys
import time
import subprocess
import hashlib
from pathlib import Path
from datetime import datetime
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configuration
PROJECT_ROOT = Path(__file__).parent.parent
WEBUI_DIR = PROJECT_ROOT / "webui"
TESTS_DIR = PROJECT_ROOT / "tests"
TEST_SCRIPT = TESTS_DIR / "test_webui.sh"
STATE_FILE = PROJECT_ROOT / ".webui-test-state.json"

# Directories to watch
WATCH_PATHS = [
    str(WEBUI_DIR),
    str(PROJECT_ROOT / "requirements-webui.txt"),
    str(TEST_SCRIPT)
]

# Debounce settings (avoid running tests multiple times for rapid changes)
DEBOUNCE_SECONDS = 2

class Colors:
    """ANSI color codes for terminal output"""
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

class TestRunner:
    """Manages test execution and state"""
    
    def __init__(self):
        self.last_test_hash = self.get_state()
        self.test_running = False
        self.changes_pending = False
    
    def get_state(self):
        """Load last test state from file"""
        if STATE_FILE.exists():
            try:
                import json
                with open(STATE_FILE) as f:
                    state = json.load(f)
                    return state.get('last_test_hash', '')
            except:
                pass
        return ''
    
    def save_state(self, file_hash):
        """Save test state to file"""
        import json
        state = {
            'last_test_hash': file_hash,
            'last_test_time': datetime.now().isoformat(),
            'test_count': self.get_state().get('test_count', 0) + 1 if isinstance(self.get_state(), dict) else 1
        }
        try:
            with open(STATE_FILE, 'w') as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            print(f"{Colors.RED}✗ Failed to save state: {e}{Colors.NC}")
    
    def calculate_hash(self):
        """Calculate hash of all watched files"""
        hasher = hashlib.md5()
        for path in WATCH_PATHS:
            path_obj = Path(path)
            if path_obj.exists():
                if path_obj.is_file():
                    with open(path_obj, 'rb') as f:
                        hasher.update(f.read())
                else:
                    # Directory - hash all files
                    for file_path in path_obj.rglob('*'):
                        if file_path.is_file() and not file_path.name.startswith('.'):
                            with open(file_path, 'rb') as f:
                                hasher.update(f.read())
        return hasher.hexdigest()
    
    def run_tests(self):
        """Execute test script"""
        if self.test_running:
            self.changes_pending = True
            print(f"{Colors.YELLOW}⚠ Test already running, queuing...{Colors.NC}")
            return
        
        self.test_running = True
        print(f"\n{Colors.BLUE}╔══════════════════════════════════════════════════════╗{Colors.NC}")
        print(f"{Colors.BLUE}║  Running Web UI Automated Tests                      ║{Colors.NC}")
        print(f"{Colors.BLUE}╚══════════════════════════════════════════════════════╝{Colors.NC}\n")
        
        try:
            # Run test script
            result = subprocess.run(
                ['bash', str(TEST_SCRIPT)],
                cwd=str(PROJECT_ROOT),
                capture_output=True,
                text=True,
                env={**os.environ, 'CI': 'true'}
            )
            
            # Print output
            print(result.stdout)
            if result.stderr:
                print(result.stderr)
            
            # Print summary
            if result.returncode == 0:
                print(f"\n{Colors.GREEN}╔══════════════════════════════════════════════════════╗{Colors.NC}")
                print(f"{Colors.GREEN}║  ✓ All Tests Passed!                                 ║{Colors.NC}")
                print(f"{Colors.GREEN}╚══════════════════════════════════════════════════════╝{Colors.NC}\n")
            else:
                print(f"\n{Colors.RED}╔══════════════════════════════════════════════════════╗{Colors.NC}")
                print(f"{Colors.RED}║  ✗ Some Tests Failed                                 ║{Colors.NC}")
                print(f"{Colors.RED}╚══════════════════════════════════════════════════════╝{Colors.NC}\n")
            
            # Save state if tests passed
            if result.returncode == 0:
                current_hash = self.calculate_hash()
                self.save_state(current_hash)
            
            return result.returncode == 0
            
        except Exception as e:
            print(f"{Colors.RED}✗ Test execution failed: {e}{Colors.NC}")
            return False
        finally:
            self.test_running = False
            if self.changes_pending:
                print(f"{Colors.CYAN}ℹ Running queued test...{Colors.NC}")
                self.changes_pending = False
                time.sleep(1)
                self.run_tests()

class WebUIFileHandler(FileSystemEventHandler):
    """Handle file system events"""
    
    def __init__(self, test_runner):
        super().__init__()
        self.test_runner = test_runner
        self.last_change = time.time()
        self.debounce_timer = None
    
    def on_modified(self, event):
        """Handle file modification events"""
        if event.is_directory:
            return
        
        # Check if it's a relevant file
        if not self.is_relevant_file(event.src_path):
            return
        
        current_time = time.time()
        
        # Debounce
        if current_time - self.last_change < DEBOUNCE_SECONDS:
            return
        
        self.last_change = current_time
        
        print(f"\n{Colors.CYAN}▶ Change detected: {event.src_path}{Colors.NC}")
        
        # Run tests after debounce
        self.test_runner.run_tests()
    
    def on_created(self, event):
        """Handle file creation events"""
        if event.is_directory:
            return
        
        if not self.is_relevant_file(event.src_path):
            return
        
        print(f"\n{Colors.CYAN}▶ New file created: {event.src_path}{Colors.NC}")
        self.test_runner.run_tests()
    
    def on_deleted(self, event):
        """Handle file deletion events"""
        if not self.is_relevant_file(event.src_path):
            return
        
        print(f"\n{Colors.YELLOW}⚠ File deleted: {event.src_path}{Colors.NC}")
        self.test_runner.run_tests()
    
    def is_relevant_file(self, path):
        """Check if file is relevant for testing"""
        path_obj = Path(path)
        
        # Skip hidden files and directories
        if any(part.startswith('.') for part in path_obj.parts):
            return False
        
        # Skip Python cache files
        if path_obj.suffix in ['.pyc', '.pyo', '.pyc']:
            return False
        if '__pycache__' in str(path_obj):
            return False
        
        # Check if in watched paths
        for watch_path in WATCH_PATHS:
            if str(path_obj).startswith(str(watch_path)):
                return True
        
        return False

def print_banner():
    """Print startup banner"""
    print(f"\n{Colors.BLUE}╔══════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.BLUE}║  Web UI Automated Test Watcher                        ║{Colors.NC}")
    print(f"{Colors.BLUE}╚══════════════════════════════════════════════════════╝{Colors.NC}\n")
    
    print(f"{Colors.CYAN}Watching for changes in:{Colors.NC}")
    for path in WATCH_PATHS:
        print(f"  • {path}")
    
    print(f"\n{Colors.CYAN}Debounce:{Colors.NC} {DEBOUNCE_SECONDS} seconds")
    print(f"{Colors.CYAN}Test script:{Colors.NC} {TEST_SCRIPT}")
    print(f"\n{Colors.GREEN}Ready! Press Ctrl+C to stop{Colors.NC}\n")

def main():
    """Main entry point"""
    print_banner()
    
    # Check if test script exists
    if not TEST_SCRIPT.exists():
        print(f"{Colors.RED}✗ Test script not found: {TEST_SCRIPT}{Colors.NC}")
        print("Please ensure tests/test_webui.sh exists")
        sys.exit(1)
    
    # Check if watchdog is installed
    try:
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler
    except ImportError:
        print(f"{Colors.RED}✗ watchdog library not installed{Colors.NC}")
        print("Install with: pip install watchdog")
        sys.exit(1)
    
    # Initialize test runner
    test_runner = TestRunner()
    
    # Set up file watcher
    event_handler = WebUIFileHandler(test_runner)
    observer = Observer()
    
    # Watch webui directory
    if WEBUI_DIR.exists():
        observer.schedule(event_handler, str(WEBUI_DIR), recursive=True)
        print(f"{Colors.GREEN}✓ Watching: {WEBUI_DIR}{Colors.NC}")
    
    # Watch test script directory
    if TESTS_DIR.exists():
        observer.schedule(event_handler, str(TESTS_DIR), recursive=False)
        print(f"{Colors.GREEN}✓ Watching: {TESTS_DIR}{Colors.NC}")
    
    # Start observer
    observer.start()
    print(f"\n{Colors.GREEN}▶ File watcher started{Colors.NC}\n")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}⚠ Stopping file watcher...{Colors.NC}")
        observer.stop()
    
    observer.join()
    print(f"{Colors.GREEN}✓ File watcher stopped{Colors.NC}")

if __name__ == '__main__':
    main()
