"""
ai-colab Web UI Backend v2.0 (Enhanced)
Flask-based API and web server for configuration management and monitoring
Improvements: Health checks, pre-flight API, session management, real-time monitoring
"""

import os
import json
import subprocess
import logging
import shutil
import socket
from datetime import datetime
from pathlib import Path
from flask import Flask, request, jsonify, send_from_directory, Response
from flask_cors import CORS
import toml
import jsonschema

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# App configuration
APP_DIR = Path(__file__).parent.parent
CONFIG_DIR = APP_DIR / "config"
CONFIG_FILE = CONFIG_DIR / "config.toml"
CONFIG_SCHEMA = CONFIG_DIR / "config.schema.json"
STATE_FILE = APP_DIR / ".ai-colab-state.json"
SCRIPTS_DIR = APP_DIR / "scripts"
LOGS_DIR = APP_DIR / "logs"

# Configuration constants
MIN_DISK_SPACE_MB = 100
SESSION_LOCK = "/tmp/hcom-dashboard.lock"

# Create Flask app
def create_app():
    app = Flask(__name__,
                static_folder='static',
                static_url_path='')

    # Enable CORS
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    # Register routes
    register_routes(app)

    return app


def register_routes(app):

    @app.route('/')
    def index():
        """Serve the main HTML page"""
        return send_from_directory(APP_DIR / 'webui', 'index.html')

    @app.route('/<path:filename>')
    def static_files(filename):
        """Serve static files"""
        return send_from_directory(APP_DIR / 'webui', filename)

    @app.route('/health')
    def health():
        """Enhanced health check endpoint with system status"""
        try:
            # Check tmux
            tmux_available = shutil.which('tmux') is not None
            tmux_version = None
            if tmux_available:
                try:
                    result = subprocess.run(['tmux', '-V'], capture_output=True, text=True, timeout=2)
                    tmux_version = result.stdout.strip() if result.returncode == 0 else None
                except:
                    pass

            # Check hcom
            hcom_available = shutil.which('hcom') is not None

            # Check disk space
            try:
                stat = shutil.disk_usage(APP_DIR)
                disk_free_mb = stat.free / (1024 * 1024)
            except:
                disk_free_mb = 0

            # Check for stale lock
            lock_exists = os.path.exists(SESSION_LOCK)
            lock_stale = False
            if lock_exists:
                try:
                    lock_age = datetime.now().timestamp() - os.path.getmtime(SESSION_LOCK)
                    lock_stale = lock_age > 3600  # > 1 hour
                except:
                    pass

            # Determine overall health
            critical_issues = []
            if not tmux_available:
                critical_issues.append("tmux not installed")
            if not hcom_available:
                critical_issues.append("hcom not installed")
            if disk_free_mb < MIN_DISK_SPACE_MB:
                critical_issues.append(f"low disk space ({disk_free_mb:.0f}MB)")

            status = "unhealthy" if critical_issues else "healthy"
            status_code = 503 if critical_issues else 200

            return jsonify({
                "status": status,
                "timestamp": datetime.now().isoformat(),
                "version": "2.0.0",
                "checks": {
                    "tmux": {
                        "available": tmux_available,
                        "version": tmux_version
                    },
                    "hcom": {
                        "available": hcom_available
                    },
                    "disk": {
                        "free_mb": round(disk_free_mb, 1),
                        "minimum_mb": MIN_DISK_SPACE_MB,
                        "ok": disk_free_mb >= MIN_DISK_SPACE_MB
                    },
                    "session": {
                        "lock_exists": lock_exists,
                        "lock_stale": lock_stale
                    }
                },
                "issues": critical_issues
            }), status_code
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return jsonify({
                "status": "error",
                "error": str(e)
            }), 500

    @app.route('/api/preflight', methods=['GET'])
    def preflight_checks():
        """Comprehensive pre-flight checks (mirrors dashboard-launch.sh)"""
        results = {
            "passed": True,
            "errors": [],
            "warnings": [],
            "checks": []
        }

        # Check 1: tmux available
        tmux_available = shutil.which('tmux') is not None
        if not tmux_available:
            results["errors"].append({
                "check": "tmux",
                "message": "tmux is not installed",
                "resolution": "Install with: brew install tmux (macOS) or sudo apt-get install tmux (Linux)"
            })
            results["passed"] = False
        else:
            try:
                result = subprocess.run(['tmux', '-V'], capture_output=True, text=True, timeout=2)
                version = result.stdout.strip() if result.returncode == 0 else "unknown"
            except:
                version = "unknown"
            results["checks"].append({
                "name": "tmux",
                "status": "pass",
                "message": f"tmux is available ({version})"
            })

        # Check 2: hcom available
        hcom_available = shutil.which('hcom') is not None
        if not hcom_available:
            results["errors"].append({
                "check": "hcom",
                "message": "hcom is not installed",
                "resolution": "Run ./install.sh to install hcom"
            })
            results["passed"] = False
        else:
            results["checks"].append({
                "name": "hcom",
                "status": "pass",
                "message": "hcom is available"
            })

        # Check 3: Terminal size (via socket - approximate)
        results["checks"].append({
            "name": "terminal",
            "status": "pass",
            "message": "Terminal size check skipped (browser-based)"
        })

        # Check 4: PROJECT_ROOT exists
        if APP_DIR.exists():
            results["checks"].append({
                "name": "project_root",
                "status": "pass",
                "message": f"Project root found ({APP_DIR})"
            })
        else:
            results["warnings"].append({
                "check": "project_root",
                "message": "PROJECT_ROOT not set or doesn't exist"
            })

        # Check 5: Disk space
        try:
            stat = shutil.disk_usage(APP_DIR)
            disk_free_mb = stat.free / (1024 * 1024)
            if disk_free_mb < MIN_DISK_SPACE_MB:
                results["warnings"].append({
                    "check": "disk_space",
                    "message": f"Low disk space (< {MIN_DISK_SPACE_MB}MB free)",
                    "details": f"{disk_free_mb:.0f}MB available"
                })
            else:
                results["checks"].append({
                    "name": "disk_space",
                    "status": "pass",
                    "message": f"Disk space is adequate ({disk_free_mb:.0f}MB free)"
                })
        except Exception as e:
            results["warnings"].append({
                "check": "disk_space",
                "message": "Could not check disk space",
                "details": str(e)
            })

        # Check 6: Stale lock file
        if os.path.exists(SESSION_LOCK):
            try:
                lock_age = datetime.now().timestamp() - os.path.getmtime(SESSION_LOCK)
                if lock_age > 3600:  # > 1 hour
                    results["checks"].append({
                        "name": "lock_file",
                        "status": "pass",
                        "message": "Stale lock file detected and will be cleaned up"
                    })
                else:
                    results["warnings"].append({
                        "check": "lock_file",
                        "message": "Another dashboard instance may be starting"
                    })
            except:
                pass

        return jsonify(results)

    @app.route('/api/session/status', methods=['GET'])
    def session_status():
        """Get tmux session status and agent information"""
        try:
            # Check if session exists
            result = subprocess.run(
                ['tmux', 'has-session', '-t', 'hcom-dashboard'],
                capture_output=True,
                timeout=2
            )
            
            if result.returncode != 0:
                return jsonify({
                    "exists": False,
                    "healthy": False,
                    "message": "Session not running"
                })
            
            # Get pane count
            result = subprocess.run(
                ['tmux', 'list-panes', '-t', 'hcom-dashboard', '-F', '#{pane_id} #{pane_title}'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            panes = []
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        parts = line.split(' ', 1)
                        panes.append({
                            "id": parts[0] if len(parts) > 0 else "",
                            "title": parts[1] if len(parts) > 1 else ""
                        })
            
            # Get window count
            result = subprocess.run(
                ['tmux', 'list-windows', '-t', 'hcom-dashboard', '-F', '#{window_id}'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            windows = len(result.stdout.strip().split('\n')) if result.returncode == 0 else 1
            
            return jsonify({
                "exists": True,
                "healthy": True,
                "panes": panes,
                "pane_count": len(panes),
                "window_count": windows,
                "session": "hcom-dashboard"
            })
            
        except subprocess.TimeoutExpired:
            return jsonify({
                "exists": True,
                "healthy": False,
                "message": "Session check timed out"
            }), 500
        except Exception as e:
            logger.error(f"Session status check failed: {e}")
            return jsonify({
                "exists": False,
                "healthy": False,
                "error": str(e)
            }), 500

    @app.route('/api/session/recover', methods=['POST'])
    def recover_session():
        """Recover from crashed or orphaned session"""
        try:
            # Kill existing session if corrupted
            subprocess.run(
                ['tmux', 'kill-session', '-t', 'hcom-dashboard'],
                capture_output=True,
                timeout=5
            )
            
            # Remove lock file
            if os.path.exists(SESSION_LOCK):
                os.remove(SESSION_LOCK)
            
            # Clean up orphaned agent processes
            subprocess.run(
                ['pkill', '-f', 'agent-wrapper.sh.*hcom'],
                capture_output=True,
                timeout=2
            )
            
            return jsonify({
                "status": "success",
                "message": "Session recovery complete"
            })
            
        except Exception as e:
            logger.error(f"Session recovery failed: {e}")
            return jsonify({
                "status": "error",
                "error": str(e)
            }), 500

    @app.route('/api/agents', methods=['GET'])
    def get_agents():
        """Get list of active agents from hcom"""
        try:
            result = subprocess.run(
                ['hcom', 'list'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            agents = []
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines[1:]:  # Skip header
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 2:
                            agents.append({
                                "name": parts[0],
                                "status": parts[1] if len(parts) > 1 else "unknown",
                                "details": ' '.join(parts[2:]) if len(parts) > 2 else ""
                            })
            
            return jsonify({
                "agents": agents,
                "count": len(agents)
            })
            
        except subprocess.TimeoutExpired:
            return jsonify({
                "agents": [],
                "error": "hcom command timed out"
            }), 500
        except Exception as e:
            logger.error(f"Get agents failed: {e}")
            return jsonify({
                "agents": [],
                "error": str(e)
            }), 500

    @app.route('/api/dashboard/launch', methods=['POST'])
    def launch_dashboard():
        """Launch the dashboard with specified configuration"""
        try:
            config = request.json or {}
            
            # Build command
            cmd = ['bash', str(SCRIPTS_DIR / 'dashboard-launch.sh')]
            
            # Add flags based on config
            if config.get('conductor'):
                cmd.append('--conductor')
            if config.get('vllm'):
                cmd.append('--vllm')
            if config.get('claude'):
                cmd.append('--add-claude')
            if config.get('deepseek'):
                cmd.append('--add-deepseek')
            if config.get('bridge'):
                cmd.append('--bridge')
            
            # Launch in background
            subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(APP_DIR)
            )
            
            return jsonify({
                "status": "started",
                "message": "Dashboard launch initiated"
            })
            
        except Exception as e:
            logger.error(f"Dashboard launch failed: {e}")
            return jsonify({
                "status": "error",
                "error": str(e)
            }), 500
    
    @app.route('/api/config', methods=['GET'])
    def get_config():
        """Get current configuration"""
        try:
            if not CONFIG_FILE.exists():
                return jsonify({"error": "Configuration not found"}), 404
            
            with open(CONFIG_FILE, 'r') as f:
                config = toml.load(f)
            
            return jsonify(config)
        except Exception as e:
            logger.error(f"Error reading config: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/config', methods=['PUT'])
    def update_config():
        """Update configuration"""
        try:
            new_config = request.json
            
            # Validate against schema if available
            if CONFIG_SCHEMA.exists():
                with open(CONFIG_SCHEMA, 'r') as f:
                    schema = json.load(f)
                jsonschema.validate(instance=new_config, schema=schema)
            
            # Convert to TOML and write
            config_content = toml.dumps(new_config)
            
            # Backup existing config
            if CONFIG_FILE.exists():
                backup_dir = CONFIG_DIR / "backups"
                backup_dir.mkdir(exist_ok=True)
                timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
                backup_file = backup_dir / f"config.{timestamp}.toml"
                import shutil
                shutil.copy(CONFIG_FILE, backup_file)
                logger.info(f"Backup created: {backup_file}")
            
            # Write new config
            with open(CONFIG_FILE, 'w') as f:
                f.write(config_content)
            
            # Update state
            update_state("config_changed", datetime.now().isoformat())
            
            logger.info("Configuration updated successfully")
            return jsonify({"status": "success", "message": "Configuration updated"})
            
        except jsonschema.ValidationError as e:
            logger.error(f"Validation error: {e}")
            return jsonify({"error": "Validation failed", "details": str(e)}), 400
        except Exception as e:
            logger.error(f"Error updating config: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/config/validate', methods=['POST'])
    def validate_config():
        """Validate configuration against schema"""
        try:
            config = request.json
            
            if CONFIG_SCHEMA.exists():
                with open(CONFIG_SCHEMA, 'r') as f:
                    schema = json.load(f)
                jsonschema.validate(instance=config, schema=schema)
                return jsonify({"valid": True})
            else:
                return jsonify({"valid": True, "warning": "Schema not found"})
                
        except jsonschema.ValidationError as e:
            return jsonify({"valid": False, "error": str(e)})
    
    @app.route('/api/status', methods=['GET'])
    def get_status():
        """Get system status"""
        try:
            status = {
                "installation": {"status": "unknown", "pathway": "unknown"},
                "agents": [],
                "timestamp": datetime.now().isoformat()
            }
            
            # Read state file
            if STATE_FILE.exists():
                with open(STATE_FILE, 'r') as f:
                    state = json.load(f)
                    status["installation"] = state.get("installation", {})
            
            # Check hcom status if available
            try:
                result = subprocess.run(
                    ["hcom", "list"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    status["hcom"] = "connected"
                    # Parse agent list from output
                    lines = result.stdout.strip().split('\n')
                    for line in lines[1:]:  # Skip header
                        if line.strip():
                            parts = line.split()
                            if len(parts) >= 3:
                                status["agents"].append({
                                    "name": parts[0],
                                    "status": parts[1] if len(parts) > 1 else "unknown"
                                })
                else:
                    status["hcom"] = "disconnected"
            except (FileNotFoundError, subprocess.TimeoutExpired):
                status["hcom"] = "not_installed"
            
            return jsonify(status)
            
        except Exception as e:
            logger.error(f"Error getting status: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/install', methods=['POST'])
    def trigger_install():
        """Trigger installation process"""
        try:
            config = request.json or {}
            pathway = config.get("pathway", "cli")
            
            # Start installation script
            if pathway == "cli":
                install_script = SCRIPTS_DIR / "install-wizard.sh"
            else:
                install_script = SCRIPTS_DIR / "install.sh"
            
            if not install_script.exists():
                return jsonify({"error": "Install script not found"}), 404
            
            # Run installation in background
            subprocess.Popen(
                ["bash", str(install_script), "--auto"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(APP_DIR)
            )
            
            logger.info("Installation triggered")
            return jsonify({
                "status": "started",
                "message": "Installation process started"
            })
            
        except Exception as e:
            logger.error(f"Error triggering install: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/launch', methods=['POST'])
    def trigger_launch():
        """Launch dashboard or agents"""
        try:
            config = request.json or {}
            components = config.get("components", ["dashboard"])
            
            launch_script = APP_DIR / "launch.sh"
            
            if not launch_script.exists():
                return jsonify({"error": "Launch script not found"}), 404
            
            # Build launch command
            cmd = ["bash", str(launch_script)]
            
            # For now, just trigger dashboard
            # In production, this would parse components and add appropriate flags
            
            # Run in background
            subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(APP_DIR)
            )
            
            logger.info("Launch triggered")
            return jsonify({
                "status": "started",
                "message": f"Launching: {', '.join(components)}"
            })
            
        except Exception as e:
            logger.error(f"Error triggering launch: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/logs', methods=['GET'])
    def get_logs():
        """Get recent logs"""
        try:
            lines = request.args.get('lines', '100', type=int)
            log_file = APP_DIR / "logs" / "ai-colab.log"
            
            if not log_file.exists():
                return jsonify({"logs": [], "message": "No logs available"})
            
            # Read last N lines
            with open(log_file, 'r') as f:
                all_lines = f.readlines()
                recent_lines = all_lines[-lines:]
            
            return jsonify({
                "logs": [line.strip() for line in recent_lines]
            })
            
        except Exception as e:
            logger.error(f"Error getting logs: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/profiles', methods=['GET'])
    def get_profiles():
        """Get available configuration profiles"""
        try:
            profiles_dir = CONFIG_DIR / "profiles"
            
            if not profiles_dir.exists():
                return jsonify({"profiles": []})
            
            profiles = []
            for profile_file in profiles_dir.glob("*.toml"):
                profile_name = profile_file.stem
                profiles.append({
                    "name": profile_name,
                    "path": str(profile_file)
                })
            
            return jsonify({"profiles": profiles})
            
        except Exception as e:
            logger.error(f"Error getting profiles: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/profiles/<name>', methods=['GET'])
    def get_profile(name):
        """Get specific profile configuration"""
        try:
            profile_file = CONFIG_DIR / "profiles" / f"{name}.toml"
            
            if not profile_file.exists():
                return jsonify({"error": "Profile not found"}), 404
            
            with open(profile_file, 'r') as f:
                config = toml.load(f)
            
            return jsonify(config)
            
        except Exception as e:
            logger.error(f"Error getting profile: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/profiles/<name>/apply', methods=['POST'])
    def apply_profile(name):
        """Apply a configuration profile"""
        try:
            # Use config-manager.sh to load profile
            config_manager = SCRIPTS_DIR / "config-manager.sh"
            
            if not config_manager.exists():
                return jsonify({"error": "Config manager not found"}), 404
            
            result = subprocess.run(
                ["bash", str(config_manager), "load-profile", name],
                capture_output=True,
                text=True,
                cwd=str(APP_DIR)
            )
            
            if result.returncode != 0:
                return jsonify({"error": result.stderr}), 400
            
            return jsonify({
                "status": "success",
                "message": f"Profile '{name}' applied"
            })
            
        except Exception as e:
            logger.error(f"Error applying profile: {e}")
            return jsonify({"error": str(e)}), 500


def update_state(key, value):
    """Update state file"""
    try:
        if not STATE_FILE.exists():
            state = {"version": "1.0.0", "created": datetime.now().isoformat()}
        else:
            with open(STATE_FILE, 'r') as f:
                state = json.load(f)
        
        # Update key (supports dot notation)
        keys = key.split('.')
        current = state
        for k in keys[:-1]:
            if k not in current:
                current[k] = {}
            current = current[k]
        current[keys[-1]] = value
        
        # Update timestamp
        state["last_modified"] = datetime.now().isoformat()
        
        with open(STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2)
            
    except Exception as e:
        logger.error(f"Error updating state: {e}")


# Create app instance
app = create_app()

if __name__ == '__main__':
    logger.info("Starting ai-colab Web UI server...")
    app.run(host='0.0.0.0', port=8080, debug=False)
