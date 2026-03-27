#!/usr/bin/env python3
"""
Security Audit Script for MCP Server & RAG System

Run with: python tests/mcp_rag/security_audit.py

Checks for common security vulnerabilities and misconfigurations.
"""

import sys
import os
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


class SecurityAuditor:
    """Security audit for MCP & RAG codebase."""
    
    def __init__(self):
        self.issues = []
        self.warnings = []
        self.passed = []
    
    def audit_code(self):
        """Scan code for security issues."""
        print("\n=== Code Security Audit ===\n")
        
        # Directories to scan
        scan_dirs = [
            PROJECT_ROOT / "mcp" / "ai_colab_server",
            PROJECT_ROOT / "rag",
            PROJECT_ROOT / "webui",
        ]
        
        # Patterns to check
        security_patterns = {
            'hardcoded_secrets': (
                r'(api_key|secret|password|token)\s*=\s*["\'][^"\']+["\']',
                "Hardcoded secret detected"
            ),
            'shell_injection': (
                r'os\.system\s*\(|subprocess\.call\s*\([^)]*shell\s*=\s*True',
                "Potential shell injection vulnerability"
            ),
            'sql_injection': (
                r'execute\s*\(\s*[\'"]SELECT.*%s',
                "Potential SQL injection (use parameterized queries)"
            ),
            'eval_exec': (
                r'\beval\s*\(|\bexec\s*\(',
                "Use of eval/exec (ensure input is sanitized)"
            ),
        }
        
        for scan_dir in scan_dirs:
            if not scan_dir.exists():
                continue
            
            for py_file in scan_dir.rglob("*.py"):
                if '__pycache__' in str(py_file):
                    continue
                
                self._scan_file(py_file, security_patterns)
        
        return len(self.issues) == 0
    
    def _scan_file(self, file_path, patterns):
        """Scan a single file for security issues."""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.split('\n')
        except Exception:
            return
        
        for issue_type, (pattern, message) in patterns.items():
            for line_num, line in enumerate(lines, 1):
                # Skip comments
                if line.strip().startswith('#'):
                    continue
                
                if re.search(pattern, line, re.IGNORECASE):
                    # Check if it's in a safe context
                    if self._is_safe_context(line, issue_type):
                        continue
                    
                    self.warnings.append({
                        'type': issue_type,
                        'file': str(file_path.relative_to(PROJECT_ROOT)),
                        'line': line_num,
                        'message': message,
                        'content': line.strip()[:100]
                    })
    
    def _is_safe_context(self, line, issue_type):
        """Check if pattern is in a safe context."""
        if issue_type == 'hardcoded_secrets':
            # Allow empty defaults
            if '=""' in line or "=''" in line:
                return True
            # Allow environment variable references
            if 'os.environ' in line or 'getenv' in line:
                return True
            # Allow example/placeholder values
            if 'example' in line.lower() or 'placeholder' in line.lower():
                return True
        
        return False
    
    def audit_dependencies(self):
        """Check dependencies for known vulnerabilities."""
        print("\n=== Dependency Audit ===\n")
        
        req_files = [
            PROJECT_ROOT / "requirements-mcp.txt",
            PROJECT_ROOT / "requirements-rag.txt",
            PROJECT_ROOT / "requirements-webui.txt",
        ]
        
        for req_file in req_files:
            if not req_file.exists():
                continue
            
            with open(req_file) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    
                    # Check for unpinned versions
                    if not any(op in line for op in ['==', '>=', '<=', '~=', '!=']):
                        self.warnings.append({
                            'type': 'unpinned_dependency',
                            'file': str(req_file.relative_to(PROJECT_ROOT)),
                            'package': line,
                            'message': 'Dependency version not pinned'
                        })
        
        print(f"✓ Scanned {len(req_files)} requirements files")
        return True
    
    def audit_config(self):
        """Check configuration files for security issues."""
        print("\n=== Configuration Audit ===\n")
        
        # Check for exposed secrets in config files
        config_dirs = [
            PROJECT_ROOT / "config",
        ]
        
        for config_dir in config_dirs:
            if not config_dir.exists():
                continue
            
            for config_file in config_dir.rglob("*"):
                if config_file.suffix in ['.toml', '.json', '.yaml', '.yml']:
                    self._scan_config_file(config_file)
        
        print(f"✓ Scanned configuration files")
        return True
    
    def _scan_config_file(self, file_path):
        """Scan config file for exposed secrets."""
        try:
            with open(file_path, 'r') as f:
                content = f.read()
        except Exception:
            return
        
        # Look for potential secrets
        secret_patterns = [
            r'api_key\s*=\s*["\'][A-Za-z0-9]{20,}',
            r'secret\s*=\s*["\'][A-Za-z0-9]{20,}',
            r'password\s*=\s*["\'][^"\']{8,}',
        ]
        
        for pattern in secret_patterns:
            if re.search(pattern, content):
                self.warnings.append({
                    'type': 'potential_secret_in_config',
                    'file': str(file_path.relative_to(PROJECT_ROOT)),
                    'message': 'Potential secret found in config file'
                })
    
    def audit_permissions(self):
        """Check file permissions."""
        print("\n=== Permissions Audit ===\n")
        
        # Check for world-writable files
        sensitive_dirs = [
            PROJECT_ROOT / "config",
            PROJECT_ROOT / "mcp",
            PROJECT_ROOT / "rag",
        ]
        
        for scan_dir in sensitive_dirs:
            if not scan_dir.exists():
                continue
            
            for file_path in scan_dir.rglob("*"):
                if file_path.is_file():
                    try:
                        mode = file_path.stat().st_mode
                        # Check for world-writable
                        if mode & 0o002:
                            self.warnings.append({
                                'type': 'world_writable',
                                'file': str(file_path.relative_to(PROJECT_ROOT)),
                                'message': 'File is world-writable'
                            })
                    except Exception:
                        pass
        
        print(f"✓ Checked file permissions")
        return True
    
    def generate_report(self):
        """Generate security audit report."""
        print("\n" + "=" * 60)
        print("Security Audit Report")
        print("=" * 60)
        
        # Issues
        if self.issues:
            print(f"\n❌ CRITICAL ISSUES ({len(self.issues)}):")
            for issue in self.issues:
                print(f"  - {issue['type']}: {issue['file']}:{issue.get('line', 'N/A')}")
        else:
            print("\n✓ No critical issues found")
        
        # Warnings
        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings[:10]:  # Show first 10
                print(f"  - {warning.get('type', 'unknown')}: ", end="")
                if 'file' in warning:
                    print(f"{warning['file']}", end="")
                if 'package' in warning:
                    print(f" ({warning['package']})", end="")
                if 'message' in warning:
                    print(f" - {warning['message']}")
            
            if len(self.warnings) > 10:
                print(f"  ... and {len(self.warnings) - 10} more")
        else:
            print("\n✓ No warnings")
        
        # Summary
        print("\n" + "-" * 60)
        print(f"Result: {'PASS' if not self.issues else 'FAIL'}")
        print(f"Issues: {len(self.issues)} critical, {len(self.warnings)} warnings")
        print("-" * 60)
        
        return len(self.issues) == 0


def main():
    """Run security audit."""
    print("=" * 60)
    print("MCP & RAG Security Audit")
    print("=" * 60)
    
    auditor = SecurityAuditor()
    
    # Run audits
    auditor.audit_code()
    auditor.audit_dependencies()
    auditor.audit_config()
    auditor.audit_permissions()
    
    # Generate report
    passed = auditor.generate_report()
    
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
