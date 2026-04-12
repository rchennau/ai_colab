"""
Terminal API Blueprint (PTY management)
"""

import os
import pty
import select
import struct
import fcntl
import termios
import logging
import threading
import time
from flask import Blueprint, request, jsonify

terminal_bp = Blueprint('terminal', __name__, url_prefix='/api/terminal')

# Global PTY manager instance (will be initialized by the app)
pty_manager = None

class PTYManager:
    """Manages pseudo-terminal sessions for web terminals"""

    def __init__(self, socketio):
        self.socketio = socketio
        self.terminals = {}  # id -> { 'fd': int, 'pid': int, 'type': str, 'thread': Thread }
        self.logger = logging.getLogger('ai_colab.webui.terminal')

    def spawn(self, terminal_id, terminal_type):
        """Spawn a new PTY session or reconnect to existing one"""
        try:
            # Check if we already have a terminal of this type running
            for existing_id, existing_term in self.terminals.items():
                if existing_term.get('type') == terminal_type and existing_term.get('running', False):
                    # Reuse existing terminal
                    self.logger.info(f"Reusing existing terminal {existing_id} ({terminal_type})")
                    return {'success': True, 'pid': existing_term['pid'], 'reused': True, 'id': existing_id}

            # Determine command based on terminal type
            nvm_setup = 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; export PATH="$HOME/.nvm/versions/node/$(node --version)/bin:$PATH";'

            commands = {
                'conductor': ['bash', '-lic', f'{nvm_setup} cd /home/rchennau/ai_colab && echo "=== ai-colab Conductor Agent ===" && echo "Commands: !status, !test, !build, !kb <query>" && echo "" && hcom start --name conductor_webui 2>/dev/null; exec bash'],
                'qwen': ['bash', '-lic', f'{nvm_setup} echo "=== Qwen Agent ===" && echo "Starting qwen (interactive mode)..." && exec qwen'],
                'gemini': ['bash', '-lic', f'{nvm_setup} echo "=== Gemini Agent ===" && echo "Starting gemini (interactive mode)..." && exec gemini'],
                'claude': ['bash', '-lic', f'{nvm_setup} echo "=== Claude Agent ===" && echo "Starting claude..." && exec claude'],
                'deepseek': ['bash', '-lic', f'{nvm_setup} echo "=== DeepSeek Agent ===" && echo "Starting deepseek-cli (interactive mode)..." && exec deepseek-cli'],
                'vllm': ['bash', '-lic', f'{nvm_setup} echo "=== vLLM Agent ===" && echo "Starting vLLM CLI..." && exec bash -c "source ~/.bashrc 2>/dev/null; exec vllm-hcom.sh"'],
                'user-console': ['bash', '-lic', f'{nvm_setup} cd /home/rchennau/ai_colab && echo "=== User Console ===" && echo "Send commands to conductor via hcom" && echo "Example: hcom send @conductor -- !status" && echo "" && hcom start --name user_console 2>/dev/null; exec bash'],
                'debug': ['bash', '-lic', f'{nvm_setup} echo "=== Debug Shell ===" && echo "KB: /conductor/knowledge_base_map.md" && exec bash']
            }

            cmd = commands.get(terminal_type, ['bash'])

            # Create PTY
            pid, fd = pty.fork()

            if pid == 0:
                # Child process
                os.execvp(cmd[0], cmd)
            else:
                # Parent process
                # Set non-blocking
                flags = fcntl.fcntl(fd, fcntl.F_GETFL)
                fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

                # Store terminal info
                self.terminals[terminal_id] = {
                    'fd': fd,
                    'pid': pid,
                    'type': terminal_type,
                    'running': True,
                    'created_at': time.time()
                }

                # Start read thread
                thread = threading.Thread(
                    target=self._read_loop,
                    args=(terminal_id, fd),
                    daemon=True
                )
                thread.start()
                self.terminals[terminal_id]['thread'] = thread

                self.logger.info(f"Spawned terminal {terminal_id} ({terminal_type}) with PID {pid}")
                return {'success': True, 'pid': pid, 'reused': False, 'id': terminal_id}

        except Exception as e:
            self.logger.error(f"Failed to spawn terminal: {e}")
            return {'success': False, 'error': str(e)}

    def list_terminals(self):
        """List all active terminals"""
        result = []
        for terminal_id, term in self.terminals.items():
            if term.get('running', False):
                result.append({
                    'id': terminal_id,
                    'type': term.get('type'),
                    'pid': term.get('pid'),
                    'running': term.get('running'),
                    'created_at': term.get('created_at')
                })
        return result

    def _read_loop(self, terminal_id, fd):
        """Read from PTY and emit to WebSocket"""
        try:
            while self.terminals.get(terminal_id, {}).get('running', False):
                try:
                    r, _, _ = select.select([fd], [], [], 0.1)
                    if r:
                        output = os.read(fd, 4096)
                        if output:
                            self.socketio.emit('terminal_output', {
                                'id': terminal_id,
                                'data': output.decode('utf-8', errors='replace')
                            })
                        else:
                            break
                except OSError:
                    break
        except Exception as e:
            self.logger.error(f"Read loop error for terminal {terminal_id}: {e}")
        finally:
            self.close(terminal_id)

    def write(self, terminal_id, data):
        """Write to PTY"""
        if terminal_id in self.terminals:
            try:
                fd = self.terminals[terminal_id]['fd']
                os.write(fd, data.encode('utf-8'))
                return True
            except Exception as e:
                self.logger.error(f"Write error: {e}")
                return False
        return False

    def close(self, terminal_id):
        """Close PTY session"""
        if terminal_id in self.terminals:
            try:
                term = self.terminals[terminal_id]
                term['running'] = False

                # Close FD
                if 'fd' in term:
                    try:
                        os.close(term['fd'])
                    except:
                        pass

                # Kill process
                if 'pid' in term:
                    try:
                        os.kill(term['pid'], 9)
                    except:
                        pass

                # Notify client
                self.socketio.emit('terminal_closed', {'id': terminal_id})

                if terminal_id in self.terminals:
                    del self.terminals[terminal_id]
                self.logger.info(f"Closed terminal {terminal_id}")

            except Exception as e:
                self.logger.error(f"Close error: {e}")

    def resize(self, terminal_id, rows, cols):
        """Resize PTY"""
        if terminal_id in self.terminals:
            try:
                fd = self.terminals[terminal_id]['fd']
                winsize = struct.pack('HHHH', rows, cols, 0, 0)
                fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)
                return True
            except Exception as e:
                self.logger.error(f"Resize error: {e}")
                return False
        return False


def init_terminal_events(socketio):
    """Register Socket.IO events for terminal management"""
    @socketio.on('terminal_input')
    def handle_terminal_input(data):
        terminal_id = data.get('id')
        input_data = data.get('data', '')
        if pty_manager and terminal_id:
            pty_manager.write(terminal_id, input_data)

    @socketio.on('terminal_resize')
    def handle_terminal_resize(data):
        terminal_id = data.get('id')
        rows = data.get('rows', 24)
        cols = data.get('cols', 80)
        if pty_manager and terminal_id:
            pty_manager.resize(terminal_id, rows, cols)

    @socketio.on('connect')
    def handle_connect():
        logging.getLogger('ai_colab.webui.terminal').info('Client connected to Terminal WebSocket')


@terminal_bp.route('/spawn', methods=['POST'])
def spawn_terminal():
    """Spawn a new web terminal"""
    try:
        data = request.json or {}
        terminal_id = data.get('id')
        terminal_type = data.get('type', 'bash')

        if not terminal_id:
            return jsonify({'error': 'Terminal ID required'}), 400

        if not pty_manager:
            return jsonify({'error': 'PTY manager not initialized'}), 500

        result = pty_manager.spawn(terminal_id, terminal_type)

        if result.get('success'):
            return jsonify({
                'status': 'success', 
                'pid': result.get('pid'), 
                'reused': result.get('reused', False), 
                'id': result.get('id')
            })
        else:
            return jsonify({'error': result.get('error', 'Unknown error')}), 500

    except Exception as e:
        logging.error(f"Error spawning terminal: {e}")
        return jsonify({'error': str(e)}), 500


@terminal_bp.route('/list', methods=['GET'])
def list_terminals():
    """List all active terminals"""
    try:
        if not pty_manager:
            return jsonify({'error': 'PTY manager not initialized'}), 500

        terminals = pty_manager.list_terminals()
        return jsonify({'terminals': terminals})

    except Exception as e:
        logging.error(f"Error listing terminals: {e}")
        return jsonify({'error': str(e)}), 500


@terminal_bp.route('/close', methods=['POST'])
def close_terminal():
    """Close a web terminal"""
    try:
        data = request.json or {}
        terminal_id = data.get('id')

        if not terminal_id:
            return jsonify({'error': 'Terminal ID required'}), 400

        if not pty_manager:
            return jsonify({'error': 'PTY manager not initialized'}), 500

        pty_manager.close(terminal_id)
        return jsonify({'status': 'closed'})

    except Exception as e:
        logging.error(f"Error closing terminal: {e}")
        return jsonify({'error': str(e)}), 500
