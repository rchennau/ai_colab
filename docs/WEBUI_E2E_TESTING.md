# ai-colab WebUI E2E Testing

Automated browser testing for the ai-colab WebUI using Playwright.

## Prerequisites

```bash
# Install Playwright (uses existing Python environment)
pip install playwright
playwright install chromium
```

## Running Tests

```bash
# Run all tests
./scripts/test-webui-e2e.sh

# Run specific test
python3 scripts/test-webui-playwright.py --test health

# Run with UI (see browser)
python3 scripts/test-webui-playwright.py --headed
```

## Test Coverage

- ✅ Dashboard loads
- ✅ KB Search functional
- ✅ Agent Terminal page loads
- ✅ System page loads
- ✅ Health check displays
- ✅ Logs display
- ✅ Module management

## Output

Test results saved to: `logs/webui-e2e-<timestamp>.log`

Screenshots on failure: `logs/webui-screenshots/`
