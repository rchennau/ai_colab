#!/usr/bin/env python3
import unittest
import json
import tempfile
import shutil
import os
from pathlib import Path
import sys

# Add scripts to path to import workspace-manager
SCRIPT_DIR = Path(__file__).parent.absolute()
sys.path.insert(0, str(SCRIPT_DIR.parent / 'scripts'))
import workspace_manager as workspace_manager

class TestWorkspaceManager(unittest.TestCase):
    def setUp(self):
        self.test_dir = Path(tempfile.mkdtemp())
        self.config_path = self.test_dir / "workspace.json"

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_find_git_repos(self):
        # Create mock git repos
        repo1 = self.test_dir / "repo1"
        repo1.mkdir()
        (repo1 / ".git").mkdir()
        
        repo2 = self.test_dir / "subdir" / "repo2"
        repo2.mkdir(parents=True)
        (repo2 / ".git").mkdir()
        
        non_repo = self.test_dir / "not_a_repo"
        non_repo.mkdir()
        
        repos = workspace_manager.find_git_repos(self.test_dir)
        repo_paths = [r["path"] for r in repos]
        
        self.assertIn(str(repo1.resolve()), repo_paths)
        self.assertIn(str(repo2.resolve()), repo_paths)
        self.assertNotIn(str(non_repo.resolve()), repo_paths)

    def test_register_and_list(self):
        repo_path = str((self.test_dir / "my_project").resolve())
        (self.test_dir / "my_project").mkdir()
        
        # Register
        workspace_manager.register_project(self.config_path, repo_path)
        
        # List
        projects = workspace_manager.list_projects(self.config_path)
        self.assertEqual(len(projects), 1)
        self.assertEqual(projects[0]["path"], repo_path)
        self.assertEqual(projects[0]["name"], "my_project")

    def test_duplicate_registration(self):
        repo_path = str((self.test_dir / "my_project").resolve())
        (self.test_dir / "my_project").mkdir()
        
        workspace_manager.register_project(self.config_path, repo_path)
        workspace_manager.register_project(self.config_path, repo_path)
        
        projects = workspace_manager.list_projects(self.config_path)
        self.assertEqual(len(projects), 1)

if __name__ == "__main__":
    unittest.main()
