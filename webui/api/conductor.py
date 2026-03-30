"""
Conductor API Blueprint (conductor status and tasks)
"""

import os
from flask import Blueprint, request, jsonify, current_app

conductor_bp = Blueprint('conductor', __name__, url_prefix='/api/conductor')


@conductor_bp.route('/status', methods=['GET'])
def get_conductor_status():
    """Get read-only conductor status"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        status = {
            "available": False,
            "project_root": str(project_root),
            "tracks": [],
            "current_task": None,
            "last_status": None
        }

        # Check if conductor track files exist
        conductor_dir = project_root / "conductor"
        if conductor_dir.exists():
            status["available"] = True

            # Read product.md if exists
            product_file = conductor_dir / "product.md"
            if product_file.exists():
                with open(product_file, 'r') as f:
                    content = f.read()
                    if "# " in content:
                        status["product_name"] = content.split("# ")[1].split("\n")[0].strip()

            # Read tracks registry
            tracks_file = conductor_dir / "tracks.md"
            if tracks_file.exists():
                with open(tracks_file, 'r') as f:
                    content = f.read()
                    # Extract active tracks
                    import re
                    tracks = re.findall(r"- \[(?: |x|/)\] \*\*Track: (.*?)\*\*", content)
                    status["tracks"] = tracks

            # Read live output if available
            log_file = project_root / "logs" / "conductor.log"
            if log_file.exists():
                with open(log_file, 'r') as f:
                    lines = f.readlines()
                    status["conductor_output"] = "".join(lines[-20:])

        return jsonify(status)

    except Exception as e:
        current_app.logger.error(f"Error getting conductor status: {e}")
        return jsonify({"error": str(e)}), 500


@conductor_bp.route('/send', methods=['POST'])
def send_console_command():
    """Send a command to conductor via hcom with webui identity"""
    import subprocess
    try:
        data = request.json or {}
        command = data.get("command", "")
        target = data.get("target", "conductor")

        if not command:
            return jsonify({"error": "No command provided"}), 400

        # First ensure webui identity exists
        subprocess.run(
            ["hcom", "start", "--name", "webui"],
            capture_output=True,
            timeout=5
        )

        # Find conductor agent name
        conductor_name = "conductor"
        try:
            list_result = subprocess.run(
                ["hcom", "list"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if list_result.returncode == 0:
                # Look for conductor in the list
                for line in list_result.stdout.splitlines():
                    if "conductor" in line.lower():
                        conductor_name = line.split()[0]
                        break
        except:
            pass

        # Send command
        # Format: hcom send @conductor -- !status
        hcom_cmd = ["hcom", "send", f"@{conductor_name}", "--", command]
        current_app.logger.info(f"Sending console command: {' '.join(hcom_cmd)}")
        
        result = subprocess.run(
            hcom_cmd,
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode == 0:
            return jsonify({
                "status": "success",
                "output": result.stdout.strip()
            })
        else:
            error_msg = result.stderr.strip() if result.stderr else result.stdout.strip()
            current_app.logger.warning(f"Failed to send command: {error_msg}")
            return jsonify({
                "error": "Failed to send command",
                "details": error_msg
            }), 500

    except subprocess.TimeoutExpired:
        current_app.logger.error("Timeout sending console command")
        return jsonify({"error": "Timeout sending command"}), 500
    except Exception as e:
        current_app.logger.error(f"Error sending console command: {e}")
        return jsonify({"error": str(e)}), 500
