"""
ai-colab Model Registry
Model versioning, deployment, and A/B testing management.
"""

import json
import logging
import os
import sqlite3
import time
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger('ai_colab.model_registry')


# ============================================================================
# Data Classes
# ============================================================================

class ModelStatus(str, Enum):
    """Model deployment status"""
    STAGING = "staging"      # Being tested
    ACTIVE = "active"        # Live in production
    INACTIVE = "inactive"    # Disabled
    DEPRECATED = "deprecated" # Old version, kept for rollback


class ModelType(str, Enum):
    """Model type classification"""
    CHAT = "chat"
    CODE = "code"
    EMBEDDING = "embedding"
    ANALYSIS = "analysis"


@dataclass
class ModelVersion:
    """Model version information"""
    model_id: str
    version: str
    provider: str
    endpoint: str
    config: Dict[str, Any]
    status: ModelStatus = ModelStatus.STAGING
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    deployed_at: Optional[str] = None
    metrics: Dict[str, float] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'model_id': self.model_id,
            'version': self.version,
            'provider': self.provider,
            'endpoint': self.endpoint,
            'config': self.config,
            'status': self.status.value,
            'created_at': self.created_at,
            'deployed_at': self.deployed_at,
            'metrics': self.metrics
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ModelVersion':
        data['status'] = ModelStatus(data['status'])
        return cls(**data)


@dataclass
class ABTest:
    """A/B test configuration"""
    test_id: str
    name: str
    model_a: str  # model_id:version
    model_b: str  # model_id:version
    traffic_split: float = 0.5  # 0.0-1.0, traffic to model_a
    status: str = "running"  # running, completed, stopped
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    completed_at: Optional[str] = None
    results: Dict[str, Any] = field(default_factory=dict)


# ============================================================================
# Model Registry Database
# ============================================================================

class ModelRegistry:
    """
    SQLite-based model registry.
    
    Features:
    - Model versioning
    - Deployment management
    - A/B testing
    - Performance tracking
    """
    
    def __init__(self, db_path: str = None):
        if db_path is None:
            db_path = Path.home() / '.ai-colab' / 'model_registry.db'
        
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        self._init_database()
        logger.info(f"ModelRegistry initialized: {self.db_path}")
    
    def _init_database(self):
        """Initialize database schema"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        # Models table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS models (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                provider TEXT NOT NULL,
                model_type TEXT,
                description TEXT,
                created_at TEXT,
                updated_at TEXT
            )
        ''')
        
        # Model versions table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS model_versions (
                id TEXT PRIMARY KEY,
                model_id TEXT,
                version TEXT,
                provider TEXT,
                endpoint TEXT,
                config TEXT,
                status TEXT,
                created_at TEXT,
                deployed_at TEXT,
                metrics TEXT,
                FOREIGN KEY (model_id) REFERENCES models(id)
            )
        ''')
        
        # A/B tests table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS ab_tests (
                test_id TEXT PRIMARY KEY,
                name TEXT,
                model_a TEXT,
                model_b TEXT,
                traffic_split REAL,
                status TEXT,
                created_at TEXT,
                completed_at TEXT,
                results TEXT
            )
        ''')
        
        # Performance metrics table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS performance_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                model_version_id TEXT,
                timestamp TEXT,
                latency_p50 REAL,
                latency_p95 REAL,
                latency_p99 REAL,
                success_rate REAL,
                tokens_per_second REAL,
                cost_per_request REAL
            )
        ''')
        
        # Create indexes
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_versions ON model_versions(model_id, status)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_metrics ON performance_metrics(model_version_id, timestamp)')
        
        conn.commit()
        conn.close()
    
    # ========================================================================
    # Model Management
    # ========================================================================
    
    def register_model(self, model_id: str, name: str, provider: str,
                      model_type: ModelType = ModelType.CHAT,
                      description: str = "") -> bool:
        """Register a new model"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        now = datetime.now().isoformat()
        
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO models 
                (id, name, provider, model_type, description, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (model_id, name, provider, model_type.value, description, now, now))
            
            conn.commit()
            logger.info(f"Registered model: {model_id} ({name})")
            return True
            
        except Exception as e:
            logger.error(f"Failed to register model: {e}")
            return False
        
        finally:
            conn.close()
    
    def get_model(self, model_id: str) -> Optional[Dict[str, Any]]:
        """Get model information"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM models WHERE id = ?', (model_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return {
                'id': row[0],
                'name': row[1],
                'provider': row[2],
                'model_type': row[3],
                'description': row[4],
                'created_at': row[5],
                'updated_at': row[6]
            }
        return None
    
    def list_models(self) -> List[Dict[str, Any]]:
        """List all registered models"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM models ORDER BY name')
        rows = cursor.fetchall()
        conn.close()
        
        return [
            {
                'id': row[0],
                'name': row[1],
                'provider': row[2],
                'model_type': row[3],
                'description': row[4]
            }
            for row in rows
        ]
    
    # ========================================================================
    # Version Management
    # ========================================================================
    
    def create_version(self, version: ModelVersion) -> bool:
        """Create a new model version"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        version_id = f"{version.model_id}:{version.version}"
        
        try:
            cursor.execute('''
                INSERT INTO model_versions 
                (id, model_id, version, provider, endpoint, config, status, 
                 created_at, deployed_at, metrics)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                version_id,
                version.model_id,
                version.version,
                version.provider,
                version.endpoint,
                json.dumps(version.config),
                version.status.value,
                version.created_at,
                version.deployed_at,
                json.dumps(version.metrics)
            ))
            
            conn.commit()
            logger.info(f"Created version: {version_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create version: {e}")
            return False
        
        finally:
            conn.close()
    
    def get_version(self, model_id: str, version: str) -> Optional[ModelVersion]:
        """Get specific model version"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        version_id = f"{model_id}:{version}"
        cursor.execute('SELECT * FROM model_versions WHERE id = ?', (version_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return ModelVersion(
                model_id=row[1],
                version=row[2],
                provider=row[3],
                endpoint=row[4],
                config=json.loads(row[5]),
                status=ModelStatus(row[6]),
                created_at=row[7],
                deployed_at=row[8],
                metrics=json.loads(row[9]) if row[9] else {}
            )
        return None
    
    def get_active_version(self, model_id: str) -> Optional[ModelVersion]:
        """Get currently active version for a model"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT * FROM model_versions 
            WHERE model_id = ? AND status = 'active'
            ORDER BY deployed_at DESC LIMIT 1
        ''', (model_id,))
        
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return ModelVersion(
                model_id=row[1],
                version=row[2],
                provider=row[3],
                endpoint=row[4],
                config=json.loads(row[5]),
                status=ModelStatus(row[6]),
                created_at=row[7],
                deployed_at=row[8],
                metrics=json.loads(row[9]) if row[9] else {}
            )
        return None
    
    def list_versions(self, model_id: str) -> List[ModelVersion]:
        """List all versions of a model"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT * FROM model_versions 
            WHERE model_id = ?
            ORDER BY created_at DESC
        ''', (model_id,))
        
        rows = cursor.fetchall()
        conn.close()
        
        return [
            ModelVersion(
                model_id=row[1],
                version=row[2],
                provider=row[3],
                endpoint=row[4],
                config=json.loads(row[5]),
                status=ModelStatus(row[6]),
                created_at=row[7],
                deployed_at=row[8],
                metrics=json.loads(row[9]) if row[9] else {}
            )
            for row in rows
        ]
    
    # ========================================================================
    # Deployment Management
    # ========================================================================
    
    def deploy_version(self, model_id: str, version: str) -> bool:
        """Deploy a model version (set as active)"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        try:
            # Deactivate current active version
            cursor.execute('''
                UPDATE model_versions 
                SET status = 'inactive'
                WHERE model_id = ? AND status = 'active'
            ''', (model_id,))
            
            # Activate new version
            version_id = f"{model_id}:{version}"
            now = datetime.now().isoformat()
            
            cursor.execute('''
                UPDATE model_versions 
                SET status = 'active', deployed_at = ?
                WHERE id = ?
            ''', (now, version_id))
            
            conn.commit()
            logger.info(f"Deployed version: {model_id}:{version}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to deploy version: {e}")
            return False
        
        finally:
            conn.close()
    
    def rollback_version(self, model_id: str) -> bool:
        """Rollback to previous version"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        try:
            # Get current active version
            cursor.execute('''
                SELECT id FROM model_versions 
                WHERE model_id = ? AND status = 'active'
            ''', (model_id,))
            
            current = cursor.fetchone()
            if not current:
                logger.error(f"No active version for {model_id}")
                return False
            
            # Get previous inactive version
            cursor.execute('''
                SELECT id FROM model_versions 
                WHERE model_id = ? AND status = 'inactive'
                ORDER BY deployed_at DESC LIMIT 1
            ''', (model_id,))
            
            previous = cursor.fetchone()
            if not previous:
                logger.error(f"No previous version to rollback to for {model_id}")
                return False
            
            # Swap versions
            cursor.execute('''
                UPDATE model_versions 
                SET status = 'inactive'
                WHERE id = ?
            ''', (current[0],))
            
            cursor.execute('''
                UPDATE model_versions 
                SET status = 'active', deployed_at = ?
                WHERE id = ?
            ''', (datetime.now().isoformat(), previous[0]))
            
            conn.commit()
            logger.info(f"Rolled back {model_id} to version {previous[0]}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to rollback: {e}")
            return False
        
        finally:
            conn.close()
    
    # ========================================================================
    # A/B Testing
    # ========================================================================
    
    def create_ab_test(self, ab_test: ABTest) -> bool:
        """Create a new A/B test"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO ab_tests 
                (test_id, name, model_a, model_b, traffic_split, status, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                ab_test.test_id,
                ab_test.name,
                ab_test.model_a,
                ab_test.model_b,
                ab_test.traffic_split,
                ab_test.status,
                ab_test.created_at
            ))
            
            conn.commit()
            logger.info(f"Created A/B test: {ab_test.test_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create A/B test: {e}")
            return False
        
        finally:
            conn.close()
    
    def get_ab_test(self, test_id: str) -> Optional[ABTest]:
        """Get A/B test configuration"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM ab_tests WHERE test_id = ?', (test_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return ABTest(
                test_id=row[0],
                name=row[1],
                model_a=row[2],
                model_b=row[3],
                traffic_split=row[4],
                status=row[5],
                created_at=row[6],
                completed_at=row[7],
                results=json.loads(row[8]) if row[8] else {}
            )
        return None
    
    def get_ab_test_assignment(self, test_id: str, request_id: str) -> str:
        """Get model assignment for A/B test (consistent hashing)"""
        ab_test = self.get_ab_test(test_id)
        if not ab_test or ab_test.status != "running":
            return None
        
        # Consistent hashing based on request_id
        hash_value = hash(request_id) % 100
        threshold = int(ab_test.traffic_split * 100)
        
        return ab_test.model_a if hash_value < threshold else ab_test.model_b
    
    def complete_ab_test(self, test_id: str, results: Dict[str, Any]) -> bool:
        """Complete an A/B test with results"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                UPDATE ab_tests 
                SET status = 'completed', completed_at = ?, results = ?
                WHERE test_id = ?
            ''', (datetime.now().isoformat(), json.dumps(results), test_id))
            
            conn.commit()
            logger.info(f"Completed A/B test: {test_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to complete A/B test: {e}")
            return False
        
        finally:
            conn.close()
    
    def list_ab_tests(self, status: str = None) -> List[ABTest]:
        """List A/B tests"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        if status:
            cursor.execute('SELECT * FROM ab_tests WHERE status = ? ORDER BY created_at DESC', (status,))
        else:
            cursor.execute('SELECT * FROM ab_tests ORDER BY created_at DESC')
        
        rows = cursor.fetchall()
        conn.close()
        
        return [
            ABTest(
                test_id=row[0],
                name=row[1],
                model_a=row[2],
                model_b=row[3],
                traffic_split=row[4],
                status=row[5],
                created_at=row[6],
                completed_at=row[7],
                results=json.loads(row[8]) if row[8] else {}
            )
            for row in rows
        ]
    
    # ========================================================================
    # Performance Metrics
    # ========================================================================
    
    def record_metrics(self, model_version_id: str, metrics: Dict[str, float]) -> bool:
        """Record performance metrics for a model version"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO performance_metrics 
                (model_version_id, timestamp, latency_p50, latency_p95, latency_p99,
                 success_rate, tokens_per_second, cost_per_request)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                model_version_id,
                datetime.now().isoformat(),
                metrics.get('latency_p50', 0),
                metrics.get('latency_p95', 0),
                metrics.get('latency_p99', 0),
                metrics.get('success_rate', 0),
                metrics.get('tokens_per_second', 0),
                metrics.get('cost_per_request', 0)
            ))
            
            conn.commit()
            return True
            
        except Exception as e:
            logger.error(f"Failed to record metrics: {e}")
            return False
        
        finally:
            conn.close()
    
    def get_model_metrics(self, model_version_id: str, days: int = 7) -> Dict[str, Any]:
        """Get aggregated metrics for a model version"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        cutoff = (datetime.now().timestamp() - (days * 24 * 60 * 60))
        
        cursor.execute('''
            SELECT 
                AVG(latency_p50), AVG(latency_p95), AVG(latency_p99),
                AVG(success_rate), AVG(tokens_per_second), AVG(cost_per_request),
                COUNT(*)
            FROM performance_metrics
            WHERE model_version_id = ? AND timestamp > ?
        ''', (model_version_id, datetime.fromtimestamp(cutoff).isoformat()))
        
        row = cursor.fetchone()
        conn.close()
        
        if row and row[6] > 0:
            return {
                'avg_latency_p50': row[0] or 0,
                'avg_latency_p95': row[1] or 0,
                'avg_latency_p99': row[2] or 0,
                'avg_success_rate': row[3] or 0,
                'avg_tokens_per_second': row[4] or 0,
                'avg_cost_per_request': row[5] or 0,
                'sample_count': row[6]
            }
        return {}


# Singleton instance
_registry_instance: Optional[ModelRegistry] = None


def get_registry() -> ModelRegistry:
    """Get or create registry instance"""
    global _registry_instance
    if _registry_instance is None:
        _registry_instance = ModelRegistry()
    return _registry_instance
