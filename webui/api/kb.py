"""
Knowledge Base API Blueprint (RAG search)
"""

import os
import subprocess
import logging
import json
from flask import Blueprint, request, jsonify, current_app

kb_bp = Blueprint('kb', __name__, url_prefix='/api/kb')


@kb_bp.route('/search', methods=['GET'])
def kb_search():
    """Search knowledge base using RAG"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        query = request.args.get('query', '')
        top_k = request.args.get('top_k', '5', type=int)
        source = request.args.get('source', None)

        if not query or not query.strip():
            return jsonify({"error": "Query parameter 'query' is required"}), 400

        # Validate query length
        if len(query) > 500:
            return jsonify({"error": "Query too long (max 500 characters)"}), 400

        # Build command for rag search script
        cmd = ["python3", str(project_root / "scripts" / "hcom-kb-search.sh"), query, "--top-k", str(top_k)]
        if source:
            cmd.extend(["--source", source])

        # Actually, let's call the search script directly or use the RAG client if available
        # For now, we'll use the script wrapper approach which is safer for environment isolation
        
        script_path = project_root / "scripts" / "hcom-kb-search.sh"
        if not script_path.exists():
            # Try to use python script directly if bash wrapper not found
            script_path = project_root / "rag" / "search" / "cli.py"
            if script_path.exists():
                search_cmd = ["python3", str(script_path), query, "--top-k", str(top_k)]
            else:
                return jsonify({"error": "Search engine not found"}), 500
        else:
            search_cmd = ["bash", str(script_path), query, "--top-k", str(top_k)]

        result = subprocess.run(
            search_cmd,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(project_root)
        )

        if result.returncode == 0:
            try:
                search_data = json.loads(result.stdout)
                return jsonify(search_data)
            except:
                return jsonify({
                    "query": query,
                    "results": [],
                    "raw_output": result.stdout.strip()
                })
        else:
            return jsonify({"error": "Search failed", "details": result.stderr}), 500

    except Exception as e:
        current_app.logger.error(f"Error searching knowledge base: {e}")
        return jsonify({"error": str(e)}), 500


@kb_bp.route('/index', methods=['POST'])
def trigger_index():
    """Trigger KB re-indexing"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        script_path = project_root / "scripts" / "hcom-kb-index.sh"
        if not script_path.exists():
            return jsonify({"error": "Indexing script not found"}), 500

        # Run in background
        subprocess.Popen(["bash", str(script_path)], cwd=str(project_root))
        
        return jsonify({"status": "started", "message": "Indexing started in background"})
    except Exception as e:
        current_app.logger.error(f"Error triggering index: {e}")
        return jsonify({"error": str(e)}), 500


@kb_bp.route('/stats', methods=['GET'])
def kb_stats():
    """Get KB statistics"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        # Check storage directory for stats
        storage_dir = project_root / "rag" / "storage"
        stats = {
            "indexed_files": 0,
            "total_chunks": 0,
            "last_updated": None
        }
        
        if storage_dir.exists():
            # This is a placeholder for actual stats logic
            # In a real implementation, we'd read the vector DB metadata
            pass
            
        return jsonify(stats)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
