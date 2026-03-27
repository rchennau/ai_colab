"""
ai-colab Agent Coordination & Federated Learning System
Advanced agent collaboration, team formation, and knowledge sharing.
"""

import json
import logging
import hashlib
import time
import asyncio
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple
from collections import defaultdict

logger = logging.getLogger('ai_colab.agent_coordination')


# ============================================================================
# Data Classes - Agent Coordination
# ============================================================================

class AgentRole(str, Enum):
    """Agent roles in teams"""
    LEADER = "leader"          # Team coordinator
    WORKER = "worker"          # Task executor
    REVIEWER = "reviewer"      # Code/task reviewer
    ARCHITECT = "architect"    # Architecture decisions
    SPECIALIST = "specialist"  # Domain expert


class TaskStatus(str, Enum):
    """Task execution status"""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    BLOCKED = "blocked"
    COMPLETED = "completed"
    FAILED = "failed"


class ConsensusType(str, Enum):
    """Consensus mechanisms"""
    MAJORITY = "majority"           # >50% agreement
    UNANIMOUS = "unanimous"         # 100% agreement
    WEIGHTED = "weighted"           # Weighted by expertise
    LEADER_DECIDES = "leader"       # Leader makes final call


@dataclass
class Agent:
    """Agent information"""
    agent_id: str
    name: str
    role: AgentRole
    capabilities: List[str] = field(default_factory=list)
    expertise_areas: List[str] = field(default_factory=list)
    status: str = "available"  # available, busy, offline
    current_task: Optional[str] = None
    performance_score: float = 0.0
    knowledge_version: int = 0
    last_seen: str = field(default_factory=lambda: datetime.now().isoformat())
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'agent_id': self.agent_id,
            'name': self.name,
            'role': self.role.value,
            'capabilities': self.capabilities,
            'expertise_areas': self.expertise_areas,
            'status': self.status,
            'current_task': self.current_task,
            'performance_score': self.performance_score,
            'knowledge_version': self.knowledge_version,
            'last_seen': self.last_seen
        }


@dataclass
class Task:
    """Task definition"""
    task_id: str
    title: str
    description: str
    assigned_to: List[str] = field(default_factory=list)  # Agent IDs
    status: TaskStatus = TaskStatus.PENDING
    priority: int = 5  # 1-10
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    dependencies: List[str] = field(default_factory=list)  # Task IDs
    requires_consensus: bool = False
    consensus_type: ConsensusType = ConsensusType.MAJORITY
    results: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'task_id': self.task_id,
            'title': self.title,
            'description': self.description,
            'assigned_to': self.assigned_to,
            'status': self.status.value,
            'priority': self.priority,
            'created_at': self.created_at,
            'started_at': self.started_at,
            'completed_at': self.completed_at,
            'dependencies': self.dependencies,
            'requires_consensus': self.requires_consensus,
            'consensus_type': self.consensus_type.value,
            'results': self.results
        }


@dataclass
class Team:
    """Agent team"""
    team_id: str
    name: str
    members: List[str] = field(default_factory=list)  # Agent IDs
    leader: Optional[str] = None  # Agent ID
    tasks: List[str] = field(default_factory=list)  # Task IDs
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    status: str = "active"  # active, completed, disbanded
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'team_id': self.team_id,
            'name': self.name,
            'members': self.members,
            'leader': self.leader,
            'tasks': self.tasks,
            'created_at': self.created_at,
            'status': self.status
        }


@dataclass
class Handoff:
    """Task handoff between agents"""
    handoff_id: str
    from_agent: str
    to_agent: str
    task_id: str
    context: Dict[str, Any] = field(default_factory=dict)
    status: str = "pending"  # pending, accepted, rejected, completed
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    completed_at: Optional[str] = None
    notes: str = ""
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'handoff_id': self.handoff_id,
            'from_agent': self.from_agent,
            'to_agent': self.to_agent,
            'task_id': self.task_id,
            'context': self.context,
            'status': self.status,
            'created_at': self.created_at,
            'completed_at': self.completed_at,
            'notes': self.notes
        }


# ============================================================================
# Data Classes - Federated Learning
# ============================================================================

class KnowledgeType(str, Enum):
    """Types of shared knowledge"""
    SKILL = "skill"              # How to do something
    PATTERN = "pattern"          # Code/design patterns
    BEST_PRACTICE = "best_practice"  # Recommended approaches
    LESSON_LEARNED = "lesson"    # Lessons from mistakes
    OPTIMIZATION = "optimization"  # Performance improvements
    CONFIGURATION = "config"     # Configuration knowledge


class SharingScope(str, Enum):
    """Knowledge sharing scope"""
    TEAM = "team"              # Share within team
    PROJECT = "project"        # Share within project
    GLOBAL = "global"          # Share across all agents


@dataclass
class KnowledgeArtifact:
    """Shared knowledge artifact"""
    artifact_id: str
    title: str
    knowledge_type: KnowledgeType
    content: Dict[str, Any]
    created_by: str  # Agent ID
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    version: int = 1
    scope: SharingScope = SharingScope.PROJECT
    confidence_score: float = 0.0  # 0.0-1.0, how confident we are
    usage_count: int = 0
    endorsements: List[str] = field(default_factory=list)  # Agent IDs who endorse
    tags: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'artifact_id': self.artifact_id,
            'title': self.title,
            'knowledge_type': self.knowledge_type.value,
            'content': self.content,
            'created_by': self.created_by,
            'created_at': self.created_at,
            'version': self.version,
            'scope': self.scope.value,
            'confidence_score': self.confidence_score,
            'usage_count': self.usage_count,
            'endorsements': self.endorsements,
            'tags': self.tags
        }


@dataclass
class LessonLearned:
    """Lesson learned from mistakes"""
    lesson_id: str
    title: str
    task_id: Optional[str]
    agent_id: str
    description: str
    root_cause: str
    solution: str
    prevention: str
    severity: str = "medium"  # low, medium, high, critical
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    applied_count: int = 0  # How many times this prevented issues
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'lesson_id': self.lesson_id,
            'title': self.title,
            'task_id': self.task_id,
            'agent_id': self.agent_id,
            'description': self.description,
            'root_cause': self.root_cause,
            'solution': self.solution,
            'prevention': self.prevention,
            'severity': self.severity,
            'created_at': self.created_at,
            'applied_count': self.applied_count
        }


@dataclass
class PerformanceOptimization:
    """Performance optimization knowledge"""
    opt_id: str
    title: str
    component: str
    before_metrics: Dict[str, float]
    after_metrics: Dict[str, float]
    changes_made: List[str]
    created_by: str
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    validated: bool = False
    adoption_count: int = 0
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'opt_id': self.opt_id,
            'title': self.title,
            'component': self.component,
            'before_metrics': self.before_metrics,
            'after_metrics': self.after_metrics,
            'improvement': self.calculate_improvement(),
            'changes_made': self.changes_made,
            'created_by': self.created_by,
            'validated': self.validated,
            'adoption_count': self.adoption_count
        }
    
    def calculate_improvement(self) -> Dict[str, float]:
        """Calculate improvement percentages"""
        improvement = {}
        for key in self.after_metrics:
            if key in self.before_metrics and self.before_metrics[key] > 0:
                change = (self.after_metrics[key] - self.before_metrics[key]) / self.before_metrics[key]
                improvement[key] = round(change * 100, 2)
        return improvement


# ============================================================================
# Agent Coordination System
# ============================================================================

class AgentCoordination:
    """
    Advanced agent coordination system.
    
    Features:
    - Team formation
    - Collaborative task execution
    - Agent-to-agent handoffs
    - Consensus mechanisms
    - Conflict resolution
    """
    
    def __init__(self, db_path: str = None):
        if db_path is None:
            db_path = Path.home() / '.ai-colab' / 'agent_coordination.db'
        
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        # In-memory stores (would be database in production)
        self.agents: Dict[str, Agent] = {}
        self.teams: Dict[str, Team] = {}
        self.tasks: Dict[str, Task] = {}
        self.handoffs: Dict[str, Handoff] = {}
        
        # Consensus tracking
        self.votes: Dict[str, Dict[str, bool]] = {}  # task_id -> {agent_id: vote}
        
        logger.info(f"AgentCoordination initialized: {self.db_path}")
    
    # ========================================================================
    # Agent Management
    # ========================================================================
    
    def register_agent(self, agent: Agent) -> bool:
        """Register an agent"""
        self.agents[agent.agent_id] = agent
        logger.info(f"Registered agent: {agent.agent_id} ({agent.name})")
        return True
    
    def get_agent(self, agent_id: str) -> Optional[Agent]:
        """Get agent by ID"""
        return self.agents.get(agent_id)
    
    def list_agents(self, status: str = None) -> List[Agent]:
        """List agents"""
        agents = list(self.agents.values())
        if status:
            agents = [a for a in agents if a.status == status]
        return agents
    
    def update_agent_status(self, agent_id: str, status: str,
                           task_id: str = None) -> bool:
        """Update agent status"""
        agent = self.get_agent(agent_id)
        if not agent:
            return False
        
        agent.status = status
        agent.current_task = task_id
        agent.last_seen = datetime.now().isoformat()
        
        logger.info(f"Agent {agent_id} status: {status}, task: {task_id}")
        return True
    
    # ========================================================================
    # Team Formation
    # ========================================================================
    
    def create_team(self, team_id: str, name: str,
                   member_ids: List[str], leader_id: str = None) -> bool:
        """Create a new team"""
        # Validate members exist
        for member_id in member_ids:
            if member_id not in self.agents:
                logger.error(f"Cannot create team: agent {member_id} not found")
                return False
        
        # Auto-select leader if not specified
        if not leader_id and member_ids:
            # Choose agent with highest performance score
            leader_id = max(
                member_ids,
                key=lambda mid: self.agents[mid].performance_score if mid in self.agents else 0
            )
        
        team = Team(
            team_id=team_id,
            name=name,
            members=member_ids,
            leader=leader_id
        )
        
        self.teams[team_id] = team
        logger.info(f"Created team: {team_id} ({name}) with {len(member_ids)} members")
        return True
    
    def get_team(self, team_id: str) -> Optional[Team]:
        """Get team by ID"""
        return self.teams.get(team_id)
    
    def assign_task_to_team(self, team_id: str, task_id: str) -> bool:
        """Assign task to team"""
        team = self.get_team(team_id)
        if not team:
            return False
        
        team.tasks.append(task_id)
        logger.info(f"Assigned task {task_id} to team {team_id}")
        return True
    
    def dissolve_team(self, team_id: str) -> bool:
        """Dissolve a team"""
        team = self.get_team(team_id)
        if not team:
            return False
        
        team.status = "disbanded"
        logger.info(f"Dissolved team: {team_id}")
        return True
    
    # ========================================================================
    # Task Management
    # ========================================================================
    
    def create_task(self, task: Task) -> bool:
        """Create a new task"""
        self.tasks[task.task_id] = task
        logger.info(f"Created task: {task.task_id} ({task.title})")
        return True
    
    def get_task(self, task_id: str) -> Optional[Task]:
        """Get task by ID"""
        return self.tasks.get(task_id)
    
    def assign_agents_to_task(self, task_id: str, agent_ids: List[str]) -> bool:
        """Assign agents to a task"""
        task = self.get_task(task_id)
        if not task:
            return False
        
        task.assigned_to.extend(agent_ids)
        
        # Update agent status
        for agent_id in agent_ids:
            self.update_agent_status(agent_id, "busy", task_id)
        
        logger.info(f"Assigned {len(agent_ids)} agents to task {task_id}")
        return True
    
    def start_task(self, task_id: str) -> bool:
        """Mark task as started"""
        task = self.get_task(task_id)
        if not task:
            return False
        
        task.status = TaskStatus.IN_PROGRESS
        task.started_at = datetime.now().isoformat()
        
        logger.info(f"Task started: {task_id}")
        return True
    
    def complete_task(self, task_id: str, results: Dict[str, Any] = None) -> bool:
        """Mark task as completed"""
        task = self.get_task(task_id)
        if not task:
            return False
        
        task.status = TaskStatus.COMPLETED
        task.completed_at = datetime.now().isoformat()
        if results:
            task.results = results
        
        # Free up assigned agents
        for agent_id in task.assigned_to:
            self.update_agent_status(agent_id, "available", None)
        
        logger.info(f"Task completed: {task_id}")
        return True
    
    # ========================================================================
    # Agent Handoffs
    # ========================================================================
    
    def create_handoff(self, from_agent: str, to_agent: str,
                      task_id: str, context: Dict[str, Any] = None) -> Optional[str]:
        """Create a task handoff between agents"""
        import uuid
        
        # Verify agents exist
        if from_agent not in self.agents or to_agent not in self.agents:
            logger.error("Handoff failed: invalid agent")
            return None
        
        handoff_id = str(uuid.uuid4())
        handoff = Handoff(
            handoff_id=handoff_id,
            from_agent=from_agent,
            to_agent=to_agent,
            task_id=task_id,
            context=context or {}
        )
        
        self.handoffs[handoff_id] = handoff
        logger.info(f"Created handoff: {from_agent} → {to_agent} for task {task_id}")
        return handoff_id
    
    def accept_handoff(self, handoff_id: str) -> bool:
        """Accept a handoff"""
        handoff = self.handoffs.get(handoff_id)
        if not handoff:
            return False
        
        handoff.status = "accepted"
        
        # Update task assignment
        task = self.get_task(handoff.task_id)
        if task:
            if handoff.from_agent in task.assigned_to:
                task.assigned_to.remove(handoff.from_agent)
            task.assigned_to.append(handoff.to_agent)
        
        logger.info(f"Handoff accepted: {handoff_id}")
        return True
    
    def reject_handoff(self, handoff_id: str, reason: str) -> bool:
        """Reject a handoff"""
        handoff = self.handoffs.get(handoff_id)
        if not handoff:
            return False
        
        handoff.status = "rejected"
        handoff.notes = reason
        
        logger.info(f"Handoff rejected: {handoff_id} - {reason}")
        return True
    
    # ========================================================================
    # Consensus Mechanisms
    # ========================================================================
    
    def initiate_consensus(self, task_id: str, consensus_type: ConsensusType,
                          question: str) -> bool:
        """Initiate consensus voting on a task"""
        task = self.get_task(task_id)
        if not task:
            return False
        
        task.requires_consensus = True
        task.consensus_type = consensus_type
        
        # Initialize votes
        self.votes[task_id] = {}
        
        logger.info(f"Consensus initiated for task {task_id}: {question}")
        return True
    
    def cast_vote(self, task_id: str, agent_id: str, vote: bool) -> bool:
        """Cast a vote on a consensus"""
        if task_id not in self.votes:
            return False
        
        self.votes[task_id][agent_id] = vote
        logger.info(f"Vote cast: {agent_id} voted {'YES' if vote else 'NO'} on {task_id}")
        return True
    
    def check_consensus(self, task_id: str) -> Tuple[bool, bool]:
        """
        Check if consensus reached.
        Returns: (consensus_reached, result)
        """
        if task_id not in self.votes:
            return False, False
        
        task = self.get_task(task_id)
        if not task:
            return False, False
        
        votes = self.votes[task_id]
        total_agents = len(task.assigned_to)
        yes_votes = sum(1 for v in votes.values() if v)
        no_votes = len(votes) - yes_votes
        
        if task.consensus_type == ConsensusType.UNANIMOUS:
            # All must agree
            reached = len(votes) == total_agents and no_votes == 0
            return reached, reached
        
        elif task.consensus_type == ConsensusType.MAJORITY:
            # >50% must agree
            if len(votes) < total_agents * 0.5:
                return False, False
            reached = yes_votes > len(votes) * 0.5
            return reached, reached
        
        elif task.consensus_type == ConsensusType.WEIGHTED:
            # Weighted by performance score (simplified)
            total_weight = sum(
                self.agents[aid].performance_score
                for aid in votes.keys()
                if aid in self.agents
            )
            yes_weight = sum(
                self.agents[aid].performance_score
                for aid, vote in votes.items()
                if vote and aid in self.agents
            )
            
            if total_weight == 0:
                return False, False
            
            reached = yes_weight / total_weight > 0.5
            return reached, reached
        
        elif task.consensus_type == ConsensusType.LEADER_DECIDES:
            # Leader's vote decides
            if task.leader and task.leader in votes:
                return True, votes[task.leader]
            return False, False
        
        return False, False
    
    # ========================================================================
    # Conflict Resolution
    # ========================================================================
    
    def resolve_conflict(self, task_id: str, resolution: str) -> bool:
        """Resolve a conflict on a task"""
        task = self.get_task(task_id)
        if not task:
            return False
        
        task.results['conflict_resolution'] = resolution
        logger.info(f"Conflict resolved for task {task_id}: {resolution}")
        return True
    
    def escalate_conflict(self, task_id: str, to_agent_id: str) -> bool:
        """Escalate conflict to a specific agent (e.g., team leader)"""
        task = self.get_task(task_id)
        if not task:
            return False
        
        # Add escalator to task
        if to_agent_id not in task.assigned_to:
            task.assigned_to.append(to_agent_id)
        
        logger.info(f"Conflict escalated to {to_agent_id} for task {task_id}")
        return True


# ============================================================================
# Federated Learning System
# ============================================================================

class FederatedLearning:
    """
    Federated learning and knowledge sharing system.
    
    Features:
    - Skill sharing between agents
    - Knowledge synchronization
    - Best practices propagation
    - Learning from mistakes
    - Performance optimization sharing
    """
    
    def __init__(self, db_path: str = None):
        if db_path is None:
            db_path = Path.home() / '.ai-colab' / 'federated_learning.db'
        
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        # In-memory stores
        self.knowledge: Dict[str, KnowledgeArtifact] = {}
        self.lessons: Dict[str, LessonLearned] = {}
        self.optimizations: Dict[str, PerformanceOptimization] = {}
        
        # Agent knowledge versions
        self.agent_versions: Dict[str, int] = {}  # agent_id -> version
        
        logger.info(f"FederatedLearning initialized: {self.db_path}")
    
    # ========================================================================
    # Knowledge Artifacts
    # ========================================================================
    
    def share_knowledge(self, artifact: KnowledgeArtifact) -> str:
        """Share new knowledge artifact"""
        self.knowledge[artifact.artifact_id] = artifact
        
        # Update creator's knowledge version
        if artifact.created_by in self.agent_versions:
            self.agent_versions[artifact.created_by] += 1
        
        logger.info(f"Knowledge shared: {artifact.artifact_id} ({artifact.title})")
        return artifact.artifact_id
    
    def get_knowledge(self, artifact_id: str) -> Optional[KnowledgeArtifact]:
        """Get knowledge artifact"""
        return self.knowledge.get(artifact_id)
    
    def search_knowledge(self, query: str, knowledge_type: KnowledgeType = None,
                        tags: List[str] = None) -> List[KnowledgeArtifact]:
        """Search knowledge artifacts"""
        results = []
        
        for artifact in self.knowledge.values():
            # Filter by type
            if knowledge_type and artifact.knowledge_type != knowledge_type:
                continue
            
            # Filter by tags
            if tags and not any(t in artifact.tags for t in tags):
                continue
            
            # Search in title and content
            query_lower = query.lower()
            if (query_lower in artifact.title.lower() or
                query_lower in str(artifact.content).lower()):
                results.append(artifact)
        
        # Sort by confidence score
        results.sort(key=lambda a: a.confidence_score, reverse=True)
        
        return results
    
    def endorse_knowledge(self, artifact_id: str, agent_id: str) -> bool:
        """Endorse a knowledge artifact"""
        artifact = self.get_knowledge(artifact_id)
        if not artifact:
            return False
        
        if agent_id not in artifact.endorsements:
            artifact.endorsements.append(agent_id)
            # Increase confidence with each endorsement
            artifact.confidence_score = min(1.0, artifact.confidence_score + 0.1)
        
        logger.info(f"Knowledge endorsed: {artifact_id} by {agent_id}")
        return True
    
    def use_knowledge(self, artifact_id: str) -> bool:
        """Record usage of knowledge artifact"""
        artifact = self.get_knowledge(artifact_id)
        if not artifact:
            return False
        
        artifact.usage_count += 1
        logger.info(f"Knowledge used: {artifact_id} (count: {artifact.usage_count})")
        return True
    
    # ========================================================================
    # Lessons Learned
    # ========================================================================
    
    def record_lesson(self, lesson: LessonLearned) -> str:
        """Record a lesson learned"""
        self.lessons[lesson.lesson_id] = lesson
        logger.info(f"Lesson recorded: {lesson.lesson_id} ({lesson.title})")
        return lesson.lesson_id
    
    def get_lessons(self, severity: str = None) -> List[LessonLearned]:
        """Get lessons learned"""
        lessons = list(self.lessons.values())
        if severity:
            lessons = [l for l in lessons if l.severity == severity]
        return lessons
    
    def search_lessons(self, query: str) -> List[LessonLearned]:
        """Search lessons"""
        results = []
        query_lower = query.lower()
        
        for lesson in self.lessons.values():
            if (query_lower in lesson.title.lower() or
                query_lower in lesson.description.lower() or
                query_lower in lesson.root_cause.lower()):
                results.append(lesson)
        
        return results
    
    def apply_lesson(self, lesson_id: str, context: str) -> bool:
        """Apply a lesson to prevent issues"""
        lesson = self.lessons.get(lesson_id)
        if not lesson:
            return False
        
        # Check if lesson's prevention applies to context
        if lesson.prevention.lower() in context.lower():
            lesson.applied_count += 1
            logger.info(f"Lesson applied: {lesson_id} (count: {lesson.applied_count})")
            return True
        
        return False
    
    # ========================================================================
    # Performance Optimizations
    # ========================================================================
    
    def share_optimization(self, opt: PerformanceOptimization) -> str:
        """Share a performance optimization"""
        self.optimizations[opt.opt_id] = opt
        logger.info(f"Optimization shared: {opt.opt_id} ({opt.title})")
        return opt.opt_id
    
    def get_optimizations(self, component: str = None) -> List[PerformanceOptimization]:
        """Get performance optimizations"""
        opts = list(self.optimizations.values())
        if component:
            opts = [o for o in opts if o.component == component]
        return opts
    
    def validate_optimization(self, opt_id: str, validated: bool) -> bool:
        """Validate an optimization"""
        opt = self.optimizations.get(opt_id)
        if not opt:
            return False
        
        opt.validated = validated
        logger.info(f"Optimization {'validated' if validated else 'invalidated'}: {opt_id}")
        return True
    
    def adopt_optimization(self, opt_id: str) -> bool:
        """Record adoption of an optimization"""
        opt = self.optimizations.get(opt_id)
        if not opt:
            return False
        
        opt.adoption_count += 1
        logger.info(f"Optimization adopted: {opt_id} (count: {opt.adoption_count})")
        return True
    
    # ========================================================================
    # Knowledge Synchronization
    # ========================================================================
    
    def sync_knowledge(self, agent_id: str) -> Dict[str, Any]:
        """
        Synchronize knowledge for an agent.
        Returns new/updated knowledge since agent's last sync.
        """
        current_version = self.agent_versions.get(agent_id, 0)
        
        # Get all knowledge artifacts
        all_knowledge = list(self.knowledge.values())
        all_lessons = list(self.lessons.values())
        all_opts = list(self.optimizations.values())
        
        # For now, return all (in production, would filter by version)
        sync_result = {
            'agent_id': agent_id,
            'synced_at': datetime.now().isoformat(),
            'knowledge_version': current_version + 1,
            'new_knowledge': [k.to_dict() for k in all_knowledge],
            'new_lessons': [l.to_dict() for l in all_lessons],
            'new_optimizations': [o.to_dict() for o in all_opts]
        }
        
        # Update agent's version
        self.agent_versions[agent_id] = sync_result['knowledge_version']
        
        logger.info(f"Knowledge synced for agent {agent_id}: {len(all_knowledge)} artifacts")
        return sync_result
    
    def get_best_practices(self, domain: str = None) -> List[KnowledgeArtifact]:
        """Get best practices"""
        practices = [
            k for k in self.knowledge.values()
            if k.knowledge_type == KnowledgeType.BEST_PRACTICE
        ]
        
        if domain:
            practices = [p for p in practices if domain in p.tags]
        
        # Sort by confidence and endorsements
        practices.sort(
            key=lambda p: (p.confidence_score, len(p.endorsements)),
            reverse=True
        )
        
        return practices
    
    def get_skills(self, agent_id: str = None) -> List[KnowledgeArtifact]:
        """Get skills"""
        skills = [
            k for k in self.knowledge.values()
            if k.knowledge_type == KnowledgeType.SKILL
        ]
        
        if agent_id:
            # Get skills created by this agent
            skills = [s for s in skills if s.created_by == agent_id]
        
        return skills


# ============================================================================
# Unified Coordination & Learning System
# ============================================================================

class AgentFederation:
    """
    Unified agent coordination and federated learning system.
    
    Combines AgentCoordination and FederatedLearning for
    comprehensive agent collaboration.
    """
    
    def __init__(self):
        self.coordination = AgentCoordination()
        self.learning = FederatedLearning()
        
        logger.info("AgentFederation initialized")
    
    def create_collaborative_task(self, task: Task,
                                  required_roles: List[AgentRole] = None) -> bool:
        """Create a task that requires agent collaboration"""
        # Create the task
        self.coordination.create_task(task)
        
        # If roles specified, form appropriate team
        if required_roles:
            available_agents = self.coordination.list_agents(status="available")
            
            # Match agents to roles
            role_assignment = {}
            for role in required_roles:
                for agent in available_agents:
                    if agent.role == role and agent.agent_id not in role_assignment.values():
                        role_assignment[role] = agent.agent_id
                        break
            
            # Assign matched agents to task
            if role_assignment:
                self.coordination.assign_agents_to_task(
                    task.task_id,
                    list(role_assignment.values())
                )
        
        logger.info(f"Created collaborative task: {task.task_id}")
        return True
    
    def handoff_with_context(self, from_agent: str, to_agent: str,
                            task_id: str, context: Dict[str, Any]) -> Optional[str]:
        """Create handoff with full context transfer"""
        handoff_id = self.coordination.create_handoff(
            from_agent, to_agent, task_id, context
        )
        
        if handoff_id:
            # Record knowledge transfer
            artifact = KnowledgeArtifact(
                artifact_id=f"handoff_{handoff_id}",
                title=f"Task handoff: {task_id}",
                knowledge_type=KnowledgeType.SKILL,
                content=context,
                created_by=from_agent,
                scope=SharingScope.TEAM
            )
            self.learning.share_knowledge(artifact)
        
        return handoff_id
    
    def learn_from_task_completion(self, task_id: str,
                                   results: Dict[str, Any]) -> bool:
        """Extract learnings from completed task"""
        task = self.coordination.get_task(task_id)
        if not task:
            return False
        
        # Extract lessons learned
        if 'issues' in results:
            for issue in results['issues']:
                lesson = LessonLearned(
                    lesson_id=f"lesson_{task_id}_{len(self.learning.lessons)}",
                    title=f"Issue in {task.title}",
                    task_id=task_id,
                    agent_id=task.assigned_to[0] if task.assigned_to else "unknown",
                    description=issue.get('description', ''),
                    root_cause=issue.get('root_cause', ''),
                    solution=issue.get('solution', ''),
                    prevention=issue.get('prevention', ''),
                    severity=issue.get('severity', 'medium')
                )
                self.learning.record_lesson(lesson)
        
        # Extract optimizations
        if 'performance' in results:
            perf = results['performance']
            if 'before' in perf and 'after' in perf:
                opt = PerformanceOptimization(
                    opt_id=f"opt_{task_id}",
                    title=f"Optimization from {task.title}",
                    component=task.title,
                    before_metrics=perf['before'],
                    after_metrics=perf['after'],
                    changes_made=perf.get('changes', []),
                    created_by=task.assigned_to[0] if task.assigned_to else "unknown"
                )
                self.learning.share_optimization(opt)
        
        logger.info(f"Learnings extracted from task: {task_id}")
        return True
    
    def get_team_knowledge(self, team_id: str) -> Dict[str, Any]:
        """Get all knowledge relevant to a team"""
        team = self.coordination.get_team(team_id)
        if not team:
            return {}
        
        # Get knowledge from team members
        member_knowledge = []
        for member_id in team.members:
            agent = self.coordination.get_agent(member_id)
            if agent:
                skills = self.learning.get_skills(agent.agent_id)
                member_knowledge.extend([k.to_dict() for k in skills])
        
        return {
            'team_id': team_id,
            'team_name': team.name,
            'members': team.members,
            'knowledge_artifacts': member_knowledge,
            'best_practices': [p.to_dict() for p in self.learning.get_best_practices()]
        }


# Singleton instance
_federation_instance: Optional[AgentFederation] = None


def get_federation() -> AgentFederation:
    """Get or create federation instance"""
    global _federation_instance
    if _federation_instance is None:
        _federation_instance = AgentFederation()
    return _federation_instance
