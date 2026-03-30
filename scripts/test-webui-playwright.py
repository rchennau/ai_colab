#!/usr/bin/env python3
"""
ai-colab WebUI E2E Tests using Playwright
Automated browser testing for WebUI functionality
"""

import sys
import os
import json
import time
import argparse
from datetime import datetime
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

try:
    from playwright.sync_api import sync_playwright, expect, TimeoutError as PlaywrightTimeout
except ImportError:
    print("❌ Playwright not installed. Install with:")
    print("   pip install playwright")
    print("   playwright install chromium")
    sys.exit(1)

# Test configuration
BASE_URL = os.environ.get('WEBUI_URL', 'http://localhost:8080')
TIMEOUT = 30000  # 30 seconds
SCREENSHOT_DIR = PROJECT_ROOT / 'logs' / 'webui-screenshots'

# Test results
results = {
    'passed': 0,
    'failed': 0,
    'skipped': 0,
    'tests': []
}

def log(message, level='INFO'):
    """Log message with timestamp"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] [{level}] {message}")

def save_screenshot(page, name):
    """Save screenshot on failure"""
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    path = SCREENSHOT_DIR / f"{name}.png"
    page.screenshot(path=str(path))
    log(f"Screenshot saved: {path}", 'WARN')

def test_dashboard_loads(page):
    """Test: Dashboard page loads correctly"""
    test_name = "Dashboard loads"
    try:
        page.goto(f"{BASE_URL}/", timeout=TIMEOUT)
        
        # Wait for page to fully load
        page.wait_for_load_state('networkidle', timeout=10000)
        
        # Check for KB search bar (may need to wait for it to be visible)
        search_input = page.locator('#kbQuery')
        search_input.wait_for(state='visible', timeout=10000)
        
        # Check for agent status card
        expect(page.locator('#agentStatus')).to_be_visible(timeout=5000)
        
        # Check for conductor status card
        expect(page.locator('#conductorStatus')).to_be_visible(timeout=5000)
        
        log(f"✅ PASS: {test_name}")
        results['passed'] += 1
        results['tests'].append({'name': test_name, 'status': 'passed'})
        return True
        
    except Exception as e:
        log(f"❌ FAIL: {test_name} - {str(e)}", 'ERROR')
        save_screenshot(page, 'dashboard_loads_fail')
        results['failed'] += 1
        results['tests'].append({'name': test_name, 'status': 'failed', 'error': str(e)})
        return False

def test_kb_search(page):
    """Test: KB Search returns results"""
    test_name = "KB Search functional"
    try:
        page.goto(f"{BASE_URL}/", timeout=TIMEOUT)
        
        # Enter search query
        search_input = page.locator('#kbQuery')
        search_input.fill('project')
        
        # Click search button
        page.get_by_text('Search').click()
        
        # Wait for results (check for kbResultsContent)
        time.sleep(2)  # Give search time to complete
        
        # Check if results appear
        results_content = page.locator('#kbResultsContent')
        expect(results_content).not_to_contain_text('Enter a query', timeout=10000)
        
        log(f"✅ PASS: {test_name}")
        results['passed'] += 1
        results['tests'].append({'name': test_name, 'status': 'passed'})
        return True
        
    except Exception as e:
        log(f"❌ FAIL: {test_name} - {str(e)}", 'ERROR')
        save_screenshot(page, 'kb_search_fail')
        results['failed'] += 1
        results['tests'].append({'name': test_name, 'status': 'failed', 'error': str(e)})
        return False

def test_agent_terminal_loads(page):
    """Test: Agent Terminal page loads"""
    test_name = "Agent Terminal loads"
    try:
        page.goto(f"{BASE_URL}/", timeout=TIMEOUT)
        
        # Wait for page to load
        page.wait_for_load_state('networkidle', timeout=10000)
        
        # Click AI Command tab
        page.locator('button.nav-btn[data-page="ai-command"]').click()
        
        # Click Agent Terminal submenu
        page.get_by_text('Agent Terminal').first.click()
        
        # Wait for terminal containers to be visible
        time.sleep(2)
        
        # Check for conductor terminal container
        expect(page.locator('#conductorTerminalContainer')).to_be_visible(timeout=5000)
        
        # Check for user console terminal container
        expect(page.locator('#userConsoleTerminalContainer')).to_be_visible(timeout=5000)
        
        # Check for terminal buttons
        expect(page.locator('#terminalButtons')).to_be_visible(timeout=5000)
        
        log(f"✅ PASS: {test_name}")
        results['passed'] += 1
        results['tests'].append({'name': test_name, 'status': 'passed'})
        return True
        
    except Exception as e:
        log(f"❌ FAIL: {test_name} - {str(e)}", 'ERROR')
        save_screenshot(page, 'agent_terminal_fail')
        results['failed'] += 1
        results['tests'].append({'name': test_name, 'status': 'failed', 'error': str(e)})
        return False

def test_system_page_loads(page):
    """Test: System page loads correctly"""
    test_name = "System page loads"
    try:
        page.goto(f"{BASE_URL}/", timeout=TIMEOUT)
        
        # Wait for page to load
        page.wait_for_load_state('networkidle', timeout=10000)
        
        # Click System tab (use button with data-page attribute)
        page.locator('button.nav-btn[data-page="system"]').click()
        
        # Check for system status card
        expect(page.locator('#systemStatus')).to_be_visible(timeout=5000)
        
        # Check for health check card
        expect(page.locator('#healthStatus')).to_be_visible(timeout=5000)
        
        # Check for logs card
        expect(page.locator('#systemLogs')).to_be_visible(timeout=5000)
        
        log(f"✅ PASS: {test_name}")
        results['passed'] += 1
        results['tests'].append({'name': test_name, 'status': 'passed'})
        return True
        
    except Exception as e:
        log(f"❌ FAIL: {test_name} - {str(e)}", 'ERROR')
        save_screenshot(page, 'system_page_fail')
        results['failed'] += 1
        results['tests'].append({'name': test_name, 'status': 'failed', 'error': str(e)})
        return False

def test_health_check_displays(page):
    """Test: Health check displays component status"""
    test_name = "Health check displays"
    try:
        page.goto(f"{BASE_URL}/", timeout=TIMEOUT)
        
        # Wait for page to load
        page.wait_for_load_state('networkidle', timeout=10000)
        
        # Click System tab
        page.locator('button.nav-btn[data-page="system"]').click()
        
        # Check for health status content
        health_status = page.locator('#healthStatus')
        expect(health_status).not_to_be_empty(timeout=10000)
        
        # Should show component status (tmux, hcom, disk, webui)
        page_text = health_status.inner_text(timeout=5000)
        assert any(x in page_text.lower() for x in ['tmux', 'hcom', 'disk', 'webui', 'healthy', 'status'])
        
        log(f"✅ PASS: {test_name}")
        results['passed'] += 1
        results['tests'].append({'name': test_name, 'status': 'passed'})
        return True
        
    except Exception as e:
        log(f"❌ FAIL: {test_name} - {str(e)}", 'ERROR')
        save_screenshot(page, 'health_check_fail')
        results['failed'] += 1
        results['tests'].append({'name': test_name, 'status': 'failed', 'error': str(e)})
        return False

def test_logs_display(page):
    """Test: Logs display in System page"""
    test_name = "Logs display"
    try:
        page.goto(f"{BASE_URL}/", timeout=TIMEOUT)
        
        # Wait for page to load
        page.wait_for_load_state('networkidle', timeout=10000)
        
        # Click System tab
        page.locator('button.nav-btn[data-page="system"]').click()
        
        # Check for logs content
        logs_element = page.locator('#systemLogs')
        expect(logs_element).to_be_visible(timeout=5000)
        
        log(f"✅ PASS: {test_name}")
        results['passed'] += 1
        results['tests'].append({'name': test_name, 'status': 'passed'})
        return True
        
    except Exception as e:
        log(f"❌ FAIL: {test_name} - {str(e)}", 'ERROR')
        save_screenshot(page, 'logs_display_fail')
        results['failed'] += 1
        results['tests'].append({'name': test_name, 'status': 'failed', 'error': str(e)})
        return False

def test_log_management_buttons(page):
    """Test: Log management buttons present"""
    test_name = "Log Management buttons"
    try:
        page.goto(f"{BASE_URL}/", timeout=TIMEOUT)
        
        # Wait for page to load
        page.wait_for_load_state('networkidle', timeout=10000)
        
        # Click System tab
        page.locator('button.nav-btn[data-page="system"]').click()
        
        # Check for log management section (look for heading)
        expect(page.get_by_role('heading', name='Log Management')).to_be_visible(timeout=5000)
        
        # Check for buttons (use text content)
        expect(page.get_by_role('button', name='Rotate Logs')).to_be_visible(timeout=5000)
        expect(page.get_by_role('button', name='Clear Logs')).to_be_visible(timeout=5000)
        expect(page.get_by_role('button', name='Download Logs')).to_be_visible(timeout=5000)
        
        log(f"✅ PASS: {test_name}")
        results['passed'] += 1
        results['tests'].append({'name': test_name, 'status': 'passed'})
        return True
        
    except Exception as e:
        log(f"❌ FAIL: {test_name} - {str(e)}", 'ERROR')
        save_screenshot(page, 'log_management_fail')
        results['failed'] += 1
        results['tests'].append({'name': test_name, 'status': 'failed', 'error': str(e)})
        return False

def run_all_tests(headless=True):
    """Run all E2E tests"""
    log(f"Starting E2E Tests against {BASE_URL}")
    log(f"Headless mode: {headless}")
    
    with sync_playwright() as p:
        # Launch browser
        browser = p.chromium.launch(headless=headless)
        context = browser.new_context(
            viewport={'width': 1920, 'height': 1080}
        )
        page = context.new_page()
        
        # Set default timeout
        page.set_default_timeout(TIMEOUT)
        
        # Run tests
        tests = [
            lambda: test_dashboard_loads(page),
            lambda: test_kb_search(page),
            lambda: test_agent_terminal_loads(page),
            lambda: test_system_page_loads(page),
            lambda: test_health_check_displays(page),
            lambda: test_logs_display(page),
            lambda: test_log_management_buttons(page),
        ]
        
        for test_func in tests:
            try:
                test_func()
            except Exception as e:
                log(f"Test error: {str(e)}", 'ERROR')
        
        # Close browser
        browser.close()
    
    # Print summary
    print_summary()
    
    # Save results
    save_results()
    
    return results['failed'] == 0

def print_summary():
    """Print test summary"""
    total = results['passed'] + results['failed'] + results['skipped']
    
    print("\n" + "="*60)
    print("E2E TEST SUMMARY")
    print("="*60)
    print(f"Total:  {total}")
    print(f"✅ Passed:  {results['passed']}")
    print(f"❌ Failed:  {results['failed']}")
    print(f"⊘ Skipped:  {results['skipped']}")
    print("="*60)
    
    if results['tests']:
        print("\nDetailed Results:")
        for test in results['tests']:
            status_icon = '✅' if test['status'] == 'passed' else '❌'
            print(f"  {status_icon} {test['name']}")
            if test.get('error'):
                print(f"      Error: {test['error'][:100]}")

def save_results():
    """Save test results to file"""
    log_dir = PROJECT_ROOT / 'logs'
    log_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    results_file = log_dir / f"webui-e2e-{timestamp}.json"
    
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    log(f"Results saved to: {results_file}")

def main():
    global BASE_URL
    
    parser = argparse.ArgumentParser(description='WebUI E2E Tests')
    parser.add_argument('--headed', action='store_true', help='Run with browser UI (not headless)')
    parser.add_argument('--url', default=BASE_URL, help=f'WebUI URL (default: {BASE_URL})')
    parser.add_argument('--test', help='Run specific test (default: all)')
    
    args = parser.parse_args()
    
    BASE_URL = args.url
    
    if args.test:
        # Run specific test
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=not args.headed)
            context = browser.new_context(viewport={'width': 1920, 'height': 1080})
            page = context.new_page()
            page.set_default_timeout(TIMEOUT)
            
            test_map = {
                'dashboard': test_dashboard_loads,
                'kb': test_kb_search,
                'terminal': test_agent_terminal_loads,
                'system': test_system_page_loads,
                'health': test_health_check_displays,
                'logs': test_logs_display,
                'logmgmt': test_log_management_buttons,
            }
            
            if args.test in test_map:
                test_map[args.test](page)
            else:
                log(f"Unknown test: {args.test}", 'ERROR')
                log(f"Available tests: {', '.join(test_map.keys())}")
            
            browser.close()
        
        print_summary()
    else:
        # Run all tests
        success = run_all_tests(headless=not args.headed)
        sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
