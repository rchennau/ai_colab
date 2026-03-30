"""
Agent Federation API Blueprint
"""

import sys
from flask import Blueprint, request, jsonify, current_app

federation_bp = Blueprint('federation', __name__, url_prefix='/api')


@federation_bp.route('/agents', methods=['GET'])
def list_agents():
    """List all agents"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation
        federation = get_federation()
        status = request.args.get('status')
        agents = federation.coordination.list_agents(status)
        return jsonify({'agents': [a.to_dict() for a in agents], 'count': len(agents)})
    except Exception as e:
        current_app.logger.error(f"List agents failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/agents', methods=['POST'])
def register_agent():
    """Register a new agent"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation, Agent, AgentRole
        federation = get_federation()
        data = request.json
        agent = Agent(
            agent_id=data['agent_id'],
            name=data['name'],
            role=AgentRole(data.get('role', 'worker')),
            capabilities=data.get('capabilities', []),
            expertise_areas=data.get('expertise_areas', [])
        )
        success = federation.coordination.register_agent(agent)
        return jsonify({'status': 'success', 'message': 'Agent registered'}) if success else \
               jsonify({'status': 'error', 'error': 'Failed to register'}), 500
    except Exception as e:
        current_app.logger.error(f"Register agent failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/teams', methods=['GET'])
def list_teams():
    """List all teams"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation
        federation = get_federation()
        teams = list(federation.coordination.teams.values())
        return jsonify({'teams': [t.to_dict() for t in teams], 'count': len(teams)})
    except Exception as e:
        current_app.logger.error(f"List teams failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/teams', methods=['POST'])
def create_team():
    """Create a new team"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation
        federation = get_federation()
        data = request.json
        success = federation.coordination.create_team(
            team_id=data['team_id'], name=data['name'],
            member_ids=data['members'], leader_id=data.get('leader')
        )
        return jsonify({'status': 'success', 'message': 'Team created'}) if success else \
               jsonify({'status': 'error', 'error': 'Failed to create team'}), 500
    except Exception as e:
        current_app.logger.error(f"Create team failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/tasks', methods=['GET'])
def list_tasks():
    """List all tasks"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation
        federation = get_federation()
        tasks = list(federation.coordination.tasks.values())
        return jsonify({'tasks': [t.to_dict() for t in tasks], 'count': len(tasks)})
    except Exception as e:
        current_app.logger.error(f"List tasks failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/tasks', methods=['POST'])
def create_task():
    """Create a new task"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation, Task, TaskStatus
        federation = get_federation()
        data = request.json
        task = Task(
            task_id=data['task_id'], title=data['title'],
            description=data['description'], status=TaskStatus(data.get('status', 'pending')),
            priority=data.get('priority', 5), dependencies=data.get('dependencies', []),
            requires_consensus=data.get('requires_consensus', False)
        )
        success = federation.coordination.create_task(task)
        return jsonify({'status': 'success', 'message': 'Task created'}) if success else \
               jsonify({'status': 'error', 'error': 'Failed to create task'}), 500
    except Exception as e:
        current_app.logger.error(f"Create task failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/tasks/<task_id>/handoff', methods=['POST'])
def create_handoff(task_id):
    """Create task handoff"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation
        federation = get_federation()
        data = request.json
        handoff_id = federation.coordination.create_handoff(
            from_agent=data['from_agent'], to_agent=data['to_agent'],
            task_id=task_id, context=data.get('context', {})
        )
        return jsonify({'status': 'success', 'handoff_id': handoff_id}) if handoff_id else \
               jsonify({'status': 'error', 'error': 'Failed to create handoff'}), 500
    except Exception as e:
        current_app.logger.error(f"Create handoff failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/knowledge', methods=['GET'])
def list_knowledge():
    """List knowledge artifacts"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation, KnowledgeType
        federation = get_federation()
        query = request.args.get('q', '')
        ktype = request.args.get('type')
        if ktype:
            ktype = KnowledgeType(ktype)
        artifacts = federation.learning.search_knowledge(query, ktype)
        return jsonify({'knowledge': [a.to_dict() for a in artifacts], 'count': len(artifacts)})
    except Exception as e:
        current_app.logger.error(f"List knowledge failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/knowledge', methods=['POST'])
def share_knowledge():
    """Share knowledge"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation, KnowledgeArtifact, KnowledgeType, SharingScope
        federation = get_federation()
        data = request.json
        artifact = KnowledgeArtifact(
            artifact_id=data.get('artifact_id', f"knowledge_{len(federation.learning.knowledge)}"),
            title=data['title'], knowledge_type=KnowledgeType(data.get('knowledge_type', 'skill')),
            content=data['content'], created_by=data.get('created_by', 'system'),
            scope=SharingScope(data.get('scope', 'project')), tags=data.get('tags', [])
        )
        artifact_id = federation.learning.share_knowledge(artifact)
        return jsonify({'status': 'success', 'artifact_id': artifact_id})
    except Exception as e:
        current_app.logger.error(f"Share knowledge failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/lessons', methods=['GET'])
def list_lessons():
    """List lessons learned"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation
        federation = get_federation()
        severity = request.args.get('severity')
        lessons = federation.learning.get_lessons(severity)
        query = request.args.get('q')
        if query:
            lessons = federation.learning.search_lessons(query)
        return jsonify({'lessons': [l.to_dict() for l in lessons], 'count': len(lessons)})
    except Exception as e:
        current_app.logger.error(f"List lessons failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/lessons', methods=['POST'])
def record_lesson():
    """Record lesson"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation, LessonLearned
        federation = get_federation()
        data = request.json
        lesson = LessonLearned(
            lesson_id=data.get('lesson_id', f"lesson_{len(federation.learning.lessons)}"),
            title=data['title'], task_id=data.get('task_id'),
            agent_id=data.get('agent_id', 'system'), description=data['description'],
            root_cause=data['root_cause'], solution=data['solution'],
            prevention=data['prevention'], severity=data.get('severity', 'medium')
        )
        lesson_id = federation.learning.record_lesson(lesson)
        return jsonify({'status': 'success', 'lesson_id': lesson_id})
    except Exception as e:
        current_app.logger.error(f"Record lesson failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/optimizations', methods=['GET'])
def list_optimizations():
    """List optimizations"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation
        federation = get_federation()
        component = request.args.get('component')
        opts = federation.learning.get_optimizations(component)
        return jsonify({'optimizations': [o.to_dict() for o in opts], 'count': len(opts)})
    except Exception as e:
        current_app.logger.error(f"List optimizations failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@federation_bp.route('/federation/sync', methods=['POST'])
def sync_federation():
    """Sync knowledge"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from agent_federation import get_federation
        federation = get_federation()
        data = request.json
        sync_result = federation.learning.sync_knowledge(agent_id=data['agent_id'])
        return jsonify(sync_result)
    except Exception as e:
        current_app.logger.error(f"Federation sync failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500
