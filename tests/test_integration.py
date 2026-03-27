#!/usr/bin/env python3
"""
ai-colab Integration Test Suite
End-to-end tests for critical workflows.

Run with: python3 tests/test_integration.py
"""

import asyncio
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from typing import Any, Dict

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


# ============================================================================
# Test Utilities
# ============================================================================

class IntegrationTestCase(unittest.TestCase):
    """Base class for integration tests"""
    
    @classmethod
    def setUpClass(cls):
        """Set up test fixtures"""
        cls.test_id = f"test_{int(time.time())}"
        cls.temp_dir = tempfile.mkdtemp(prefix=f"ai_colab_{cls.test_id}_")
    
    @classmethod
    def tearDownClass(cls):
        """Clean up test fixtures"""
        import shutil
        if os.path.exists(cls.temp_dir):
            shutil.rmtree(cls.temp_dir)
    
    def assert_success(self, result: Any, message: str = None):
        """Assert result indicates success"""
        if isinstance(result, dict):
            self.assertTrue(
                result.get('status') == 'success' or 
                result.get('success', True),
                message or f"Expected success, got: {result}"
            )
        else:
            self.assertIsNotNone(result, message or "Expected success, got None")
    
    def assert_failure(self, result: Any, message: str = None):
        """Assert result indicates failure"""
        if isinstance(result, dict):
            self.assertTrue(
                result.get('status') == 'error' or 
                not result.get('success', True),
                message or f"Expected failure, got: {result}"
            )


# ============================================================================
# Test 1: Inference Gateway Integration
# ============================================================================

class TestInferenceGateway(IntegrationTestCase):
    """Test inference gateway end-to-end"""
    
    def test_01_gateway_initialization(self):
        """Test gateway initializes correctly"""
        try:
            from scripts.inference import get_gateway
            
            gateway = get_gateway()
            
            self.assertIsNotNone(gateway)
            self.assertIsNotNone(gateway.validator)
            self.assertIsNotNone(gateway.cache_manager)
            self.assertIsNotNone(gateway.rate_limiter)
            
        except ImportError as e:
            self.skipTest(f"Inference gateway not available: {e}")
    
    def test_02_request_validation(self):
        """Test request validation"""
        from scripts.inference.gateway import RequestValidator
        
        validator = RequestValidator()
        
        # Valid request
        request = validator.validate({
            'prompt': 'Hello, how are you?',
            'max_tokens': 100
        })
        
        self.assertIsNotNone(request)
        self.assertEqual(request.prompt, 'Hello, how are you?')
        self.assertEqual(request.max_tokens, 100)
        
        # Invalid request (empty prompt)
        with self.assertRaises(ValueError):
            validator.validate({'prompt': '', 'max_tokens': 100})
        
        # Invalid request (too long)
        with self.assertRaises(ValueError):
            validator.validate({
                'prompt': 'x' * 200000,
                'max_tokens': 100
            })
    
    def test_03_model_routing(self):
        """Test model routing logic"""
        from scripts.inference.gateway import ModelRouter, ModelConfig, ModelStatus
        
        models = {
            'gemini': ModelConfig(
                id='gemini', name='Gemini', provider='google',
                status=ModelStatus.HEALTHY
            ),
            'qwen': ModelConfig(
                id='qwen', name='Qwen', provider='alibaba',
                status=ModelStatus.HEALTHY
            )
        }
        
        router = ModelRouter(models)
        
        # Test task-based routing
        from scripts.inference.gateway import InferenceRequest, TaskType
        
        # Code task should route to qwen
        request = InferenceRequest(
            request_id='test',
            prompt='Write a function',
            task_type=TaskType.CODE
        )
        
        model = router.select_model(request)
        self.assertIn(model, ['qwen', 'gemini'])
    
    def test_04_cache_operations(self):
        """Test cache operations"""
        from scripts.inference.gateway import CacheManager
        
        cache = CacheManager(ttl_seconds=300)
        
        # Test set/get
        cache.set('test_key', {'value': 'test'})
        result = cache.get('test_key')
        
        self.assertIsNotNone(result)
        self.assertEqual(result['value'], 'test')
        
        # Test cache miss
        result = cache.get('nonexistent')
        self.assertIsNone(result)
        
        # Test delete
        cache.delete('test_key')
        result = cache.get('test_key')
        self.assertIsNone(result)
    
    def test_05_rate_limiting(self):
        """Test rate limiting"""
        from scripts.inference.gateway import RateLimiter
        
        config = {
            'test_model': {
                'requests_per_minute': 5,
                'tokens_per_minute': 1000
            }
        }
        
        limiter = RateLimiter(config)
        
        # Should allow first 5 requests
        for i in range(5):
            result = asyncio.run(limiter.acquire('test_model', 100))
            self.assertTrue(result, f"Request {i+1} should be allowed")
        
        # 6th request should be denied
        result = asyncio.run(limiter.acquire('test_model', 100))
        self.assertFalse(result, "6th request should be denied")


# ============================================================================
# Test 2: Model Registry Integration
# ============================================================================

class TestModelRegistry(IntegrationTestCase):
    """Test model registry end-to-end"""
    
    def test_01_registry_initialization(self):
        """Test registry initializes correctly"""
        try:
            from scripts.model_registry import get_registry
            
            registry = get_registry()
            
            self.assertIsNotNone(registry)
            
        except ImportError as e:
            self.skipTest(f"Model registry not available: {e}")
    
    def test_02_model_registration(self):
        """Test model registration"""
        from scripts.model_registry import get_registry
        
        registry = get_registry()
        
        # Register test model
        success = registry.register_model(
            model_id=f'test_model_{self.test_id}',
            name='Test Model',
            provider='test',
            description='Integration test model'
        )
        
        self.assertTrue(success)
        
        # Get model
        model = registry.get_model(f'test_model_{self.test_id}')
        self.assertIsNotNone(model)
        self.assertEqual(model['name'], 'Test Model')
    
    def test_03_version_management(self):
        """Test model versioning"""
        from scripts.model_registry import get_registry, ModelVersion, ModelStatus
        
        registry = get_registry()
        
        # Create version
        version = ModelVersion(
            model_id=f'test_model_{self.test_id}',
            version='1.0',
            provider='test',
            endpoint='http://test:8000',
            config={}
        )
        
        success = registry.create_version(version)
        self.assertTrue(success)
        
        # Get version
        retrieved = registry.get_version(f'test_model_{self.test_id}', '1.0')
        self.assertIsNotNone(retrieved)
        self.assertEqual(retrieved.version, '1.0')
    
    def test_04_deployment(self):
        """Test model deployment"""
        from scripts.model_registry import get_registry, ModelVersion
        
        registry = get_registry()
        
        # Create and deploy version
        version = ModelVersion(
            model_id=f'test_model_{self.test_id}',
            version='2.0',
            provider='test',
            endpoint='http://test:8000',
            config={},
            status=ModelStatus.STAGING
        )
        
        registry.create_version(version)
        success = registry.deploy_version(f'test_model_{self.test_id}', '2.0')
        
        self.assertTrue(success)
        
        # Check active version
        active = registry.get_active_version(f'test_model_{self.test_id}')
        self.assertIsNotNone(active)
        self.assertEqual(active.version, '2.0')
    
    def test_05_ab_testing(self):
        """Test A/B testing"""
        from scripts.model_registry import get_registry, ABTest
        
        registry = get_registry()
        
        # Create A/B test
        ab_test = ABTest(
            test_id=f'ab_test_{self.test_id}',
            name='Test A/B',
            model_a=f'test_model_{self.test_id}:1.0',
            model_b=f'test_model_{self.test_id}:2.0',
            traffic_split=0.5
        )
        
        success = registry.create_ab_test(ab_test)
        self.assertTrue(success)
        
        # Get assignment
        assignment = registry.get_ab_test_assignment(
            f'ab_test_{self.test_id}',
            'request_123'
        )
        
        self.assertIn(assignment, [
            f'test_model_{self.test_id}:1.0',
            f'test_model_{self.test_id}:2.0'
        ])


# ============================================================================
# Test 3: Agent Federation Integration
# ============================================================================

class TestAgentFederation(IntegrationTestCase):
    """Test agent federation end-to-end"""
    
    def test_01_federation_initialization(self):
        """Test federation initializes"""
        try:
            from scripts.agent_federation import get_federation
            
            federation = get_federation()
            
            self.assertIsNotNone(federation)
            self.assertIsNotNone(federation.coordination)
            self.assertIsNotNone(federation.learning)
            
        except ImportError as e:
            self.skipTest(f"Agent federation not available: {e}")
    
    def test_02_agent_registration(self):
        """Test agent registration"""
        from scripts.agent_federation import get_federation, Agent, AgentRole
        
        federation = get_federation()
        
        # Register agent
        agent = Agent(
            agent_id=f'agent_{self.test_id}',
            name='Test Agent',
            role=AgentRole.WORKER,
            capabilities=['code', 'review']
        )
        
        success = federation.coordination.register_agent(agent)
        self.assertTrue(success)
        
        # Get agent
        retrieved = federation.coordination.get_agent(f'agent_{self.test_id}')
        self.assertIsNotNone(retrieved)
        self.assertEqual(retrieved.name, 'Test Agent')
    
    def test_03_team_formation(self):
        """Test team formation"""
        from scripts.agent_federation import get_federation, Agent, AgentRole
        
        federation = get_federation()
        
        # Register agents
        for i in range(3):
            agent = Agent(
                agent_id=f'agent_{self.test_id}_{i}',
                name=f'Agent {i}',
                role=AgentRole.WORKER
            )
            federation.coordination.register_agent(agent)
        
        # Create team
        success = federation.coordination.create_team(
            team_id=f'team_{self.test_id}',
            name='Test Team',
            member_ids=[
                f'agent_{self.test_id}_0',
                f'agent_{self.test_id}_1',
                f'agent_{self.test_id}_2'
            ],
            leader_id=f'agent_{self.test_id}_0'
        )
        
        self.assertTrue(success)
        
        # Get team
        team = federation.coordination.get_team(f'team_{self.test_id}')
        self.assertIsNotNone(team)
        self.assertEqual(len(team.members), 3)
    
    def test_04_task_handoff(self):
        """Test task handoff between agents"""
        from scripts.agent_federation import get_federation, Agent, Task, TaskStatus
        
        federation = get_federation()
        
        # Register agents
        agent1 = Agent(agent_id=f'agent1_{self.test_id}', name='Agent 1')
        agent2 = Agent(agent_id=f'agent2_{self.test_id}', name='Agent 2')
        
        federation.coordination.register_agent(agent1)
        federation.coordination.register_agent(agent2)
        
        # Create task
        task = Task(
            task_id=f'task_{self.test_id}',
            title='Test Task',
            description='Integration test task'
        )
        
        federation.coordination.create_task(task)
        federation.coordination.assign_agents_to_task(
            f'task_{self.test_id}',
            [f'agent1_{self.test_id}']
        )
        
        # Create handoff
        handoff_id = federation.coordination.create_handoff(
            from_agent=f'agent1_{self.test_id}',
            to_agent=f'agent2_{self.test_id}',
            task_id=f'task_{self.test_id}',
            context={'progress': '50%'}
        )
        
        self.assertIsNotNone(handoff_id)
        
        # Accept handoff
        success = federation.coordination.accept_handoff(handoff_id)
        self.assertTrue(success)
    
    def test_05_knowledge_sharing(self):
        """Test knowledge sharing"""
        from scripts.agent_federation import get_federation, KnowledgeArtifact, KnowledgeType
        
        federation = get_federation()
        
        # Share knowledge
        artifact = KnowledgeArtifact(
            artifact_id=f'knowledge_{self.test_id}',
            title='Test Knowledge',
            knowledge_type=KnowledgeType.SKILL,
            content={'skill': 'test'},
            created_by=f'agent_{self.test_id}'
        )
        
        artifact_id = federation.learning.share_knowledge(artifact)
        self.assertIsNotNone(artifact_id)
        
        # Search knowledge
        results = federation.learning.search_knowledge('test')
        self.assertGreater(len(results), 0)
    
    def test_06_lesson_learned(self):
        """Test lesson learned recording"""
        from scripts.agent_federation import get_federation, LessonLearned
        
        federation = get_federation()
        
        # Record lesson
        lesson = LessonLearned(
            lesson_id=f'lesson_{self.test_id}',
            title='Test Lesson',
            task_id=f'task_{self.test_id}',
            agent_id=f'agent_{self.test_id}',
            description='Test description',
            root_cause='Test root cause',
            solution='Test solution',
            prevention='Test prevention'
        )
        
        lesson_id = federation.learning.record_lesson(lesson)
        self.assertIsNotNone(lesson_id)
        
        # Search lessons
        results = federation.learning.search_lessons('test')
        self.assertGreater(len(results), 0)


# ============================================================================
# Test 4: Vision/Screenshot Integration
# ============================================================================

class TestVisionSupport(IntegrationTestCase):
    """Test vision/screenshot support"""
    
    def test_01_vision_initialization(self):
        """Test vision manager initializes"""
        try:
            from scripts.vision import VisionManager
            
            vision = VisionManager()
            self.assertIsNotNone(vision)
            
        except ImportError as e:
            self.skipTest(f"Vision support not available: {e}")
    
    def test_02_image_storage(self):
        """Test image storage"""
        from scripts.vision import VisionManager
        
        vision = VisionManager(storage_dir=self.temp_dir)
        
        # Create test image
        test_image = self.temp_dir + '/test.png'
        with open(test_image, 'wb') as f:
            # Write minimal PNG
            f.write(b'\x89PNG\r\n\x1a\n')
        
        # Get image info
        info = vision.get_image(test_image)
        
        self.assertIsNotNone(info)
        self.assertEqual(info['path'], test_image)
    
    def test_03_base64_encoding(self):
        """Test base64 encoding"""
        from scripts.vision import VisionManager
        
        vision = VisionManager(storage_dir=self.temp_dir)
        
        # Create test image
        test_image = self.temp_dir + '/test.png'
        with open(test_image, 'wb') as f:
            f.write(b'test image data')
        
        # Encode
        base64_str = vision.image_to_base64(test_image)
        
        self.assertIsNotNone(base64_str)
        self.assertTrue(base64_str.startswith('data:image/png;base64,'))


# ============================================================================
# Test 5: Core Utilities
# ============================================================================

class TestCoreUtils(IntegrationTestCase):
    """Test core utilities"""
    
    def test_01_cache_operations(self):
        """Test unified cache"""
        try:
            from scripts.utils_core import SimpleCache
            
            cache = SimpleCache(max_size=100, default_ttl=300)
            
            # Test set/get
            cache.set('key1', 'value1')
            result = cache.get('key1')
            self.assertEqual(result, 'value1')
            
            # Test namespace
            cache.set('key2', 'value2', namespace='ns1')
            result = cache.get('key2', namespace='ns1')
            self.assertEqual(result, 'value2')
            
            # Test stats
            stats = cache.get_stats()
            self.assertIn('hit_rate', stats)
            self.assertIn('keys_count', stats)
            
        except ImportError as e:
            self.skipTest(f"Core utils not available: {e}")
    
    def test_02_error_handling(self):
        """Test error handling"""
        from scripts.utils_core import (
            AIColabError, ValidationError, handle_exception
        )
        
        # Test custom exception
        error = ValidationError("Test error", "VALIDATION_FAILED")
        error_dict = error.to_dict()
        
        self.assertEqual(error_dict['error'], 'VALIDATION_FAILED')
        self.assertEqual(error_dict['message'], 'Test error')
        
        # Test handle_exception
        result = handle_exception(ValueError("Test"))
        self.assertIn('error', result)
        self.assertIn('message', result)
    
    def test_03_file_utilities(self):
        """Test file utilities"""
        from scripts.utils_core import (
            ensure_dir, secure_write, safe_json_load, safe_json_dump
        )
        
        # Test ensure_dir
        test_dir = self.temp_dir + '/test_dir'
        ensure_dir(test_dir)
        self.assertTrue(os.path.exists(test_dir))
        
        # Test secure_write
        test_file = self.temp_dir + '/test.txt'
        secure_write(test_file, 'test content')
        
        with open(test_file, 'r') as f:
            content = f.read()
        self.assertEqual(content, 'test content')
        
        # Test JSON utilities
        json_file = self.temp_dir + '/test.json'
        safe_json_dump(json_file, {'key': 'value'})
        
        result = safe_json_load(json_file)
        self.assertEqual(result['key'], 'value')


# ============================================================================
# Test Runner
# ============================================================================

def run_tests():
    """Run all integration tests"""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestInferenceGateway))
    suite.addTests(loader.loadTestsFromTestCase(TestModelRegistry))
    suite.addTests(loader.loadTestsFromTestCase(TestAgentFederation))
    suite.addTests(loader.loadTestsFromTestCase(TestVisionSupport))
    suite.addTests(loader.loadTestsFromTestCase(TestCoreUtils))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "="*70)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Skipped: {len(result.skipped)}")
    print("="*70)
    
    return len(result.failures) == 0 and len(result.errors) == 0


if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
