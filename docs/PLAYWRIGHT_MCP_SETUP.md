# Playwright MCP Server Setup

This guide explains how to install and configure the Playwright MCP server for browser automation with Claude.

## What is Playwright MCP?

Playwright MCP (Model Context Protocol) allows Claude to directly control a browser for:
- Automated testing
- Web scraping
- UI verification
- Screenshot capture
- Form interaction

## Installation

### Option 1: Quick Install (Recommended)

```bash
# Install Playwright MCP and browsers in one command
npx --yes @playwright/mcp@latest
```

### Option 2: Full Install

```bash
# 1. Install Playwright browsers
npx playwright install chromium

# 2. Install MCP server
npx --yes @playwright/mcp@latest
```

### Option 3: Global Install

```bash
# Install globally
npm install -g @playwright/mcp

# Run
playwright-mcp
```

## Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
**Linux:** `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"],
      "transport": "stdio"
    }
  }
}
```

## Usage with Claude

Once configured, Claude can:

1. **Navigate to pages**
   ```
   Go to http://localhost:8080
   ```

2. **Take screenshots**
   ```
   Take a screenshot of the dashboard
   ```

3. **Click elements**
   ```
   Click the "Search" button
   ```

4. **Fill forms**
   ```
   Enter "project" in the search box
   ```

5. **Extract data**
   ```
   What text is in the health status card?
   ```

## Testing ai-colab WebUI

Example conversation:

```
You: Test the ai-colab WebUI at localhost:8080

Claude (with Playwright MCP):
- Navigates to http://localhost:8080
- Verifies Dashboard loads
- Tests KB Search functionality
- Checks Agent Terminal page
- Validates System page
- Takes screenshots of any issues
```

## Troubleshooting

### "Command not found"
```bash
# Ensure npx is in PATH
which npx

# If missing, install Node.js
conda install -c conda-forge nodejs
```

### Browser installation fails
```bash
# Install browsers manually
npx playwright install chromium --force
```

### MCP connection fails
```bash
# Test MCP server directly
npx --yes @playwright/mcp@latest --help

# Check Claude Desktop logs for errors
```

## Alternative: Use Our E2E Test Suite

If you prefer not to use MCP, we have a standalone E2E test suite:

```bash
# Run automated tests
./scripts/test-webui-e2e.sh

# Run with visible browser
./scripts/test-webui-e2e.sh --headed
```

See `docs/WEBUI_E2E_TESTING.md` for details.

## Resources

- [Playwright MCP GitHub](https://github.com/microsoft/playwright-mcp)
- [Playwright Documentation](https://playwright.dev)
- [MCP Specification](https://modelcontextprotocol.io)
