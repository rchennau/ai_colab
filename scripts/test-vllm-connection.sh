#!/bin/bash
#
# vLLM Connection Test
# Tests connection to local or remote vLLM server
#
# Usage: ./scripts/test-vllm-connection.sh [host]
#

# Don't exit on error - we want to show all diagnostics
set +e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# vLLM host (default from config or argument)
VLLM_HOST="${1:-$(./scripts/config-manager.sh get llm.vllm.host 2>/dev/null || echo '192.168.0.193')}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_BASE_URL="http://$VLLM_HOST:$VLLM_PORT/v1"

echo ""
echo "============================================================"
echo "  vLLM Connection Test"
echo "  ai-colab System"
echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

# Test 1: Check elc availability
echo -e "${BLUE}Test 1: ELC (easy-llm-cli) Availability${NC}"
echo "────────────────────────────────────────────────"

if command -v elc &> /dev/null; then
    print_success "elc command found: $(which elc)"
    
    # Get elc version
    ELC_VERSION=$(elc --version 2>&1 | head -1 || echo "unknown")
    print_info "Version: $ELC_VERSION"
else
    print_error "elc command not found"
    print_info "Install with: npm install -g easy-llm-cli"
    exit 1
fi

echo ""

# Test 2: Check environment variables
echo -e "${BLUE}Test 2: Environment Variables${NC}"
echo "────────────────────────────────────────────────"

# Source vLLM configuration from launch.sh style
if [[ -f "$PROJECT_ROOT/.ai-colab-prefs" ]]; then
    source "$PROJECT_ROOT/.ai-colab-prefs" 2>/dev/null || true
fi

# Set defaults if not configured
export VLLM_BASE_URL="${VLLM_BASE_URL:-http://192.168.0.193:8000/v1}"
export VLLM_API_KEY="${VLLM_API_KEY:-no-key}"
export CUSTOM_LLM_ENDPOINT="${CUSTOM_LLM_ENDPOINT:-$VLLM_BASE_URL}"
export CUSTOM_LLM_API_KEY="${CUSTOM_LLM_API_KEY:-$VLLM_API_KEY}"

print_info "VLLM_BASE_URL: $VLLM_BASE_URL"
print_info "CUSTOM_LLM_ENDPOINT: $CUSTOM_LLM_ENDPOINT"
print_info "VLLM_API_KEY: ${VLLM_API_KEY:0:3}*** (masked)"

if [[ "$VLLM_API_KEY" == "no-key" ]]; then
    print_warning "Using default API key (ok for local vLLM)"
fi

echo ""

# Test 3: Network connectivity
echo -e "${BLUE}Test 3: Network Connectivity${NC}"
echo "────────────────────────────────────────────────"

# Extract host and port
VLLM_HOST_ONLY=$(echo "$VLLM_BASE_URL" | sed -E 's|https?://||' | cut -d':' -f1)
VLLM_PORT_ONLY=$(echo "$VLLM_BASE_URL" | sed -E 's|https?://[^:]*:||' | cut -d'/' -f1)

print_info "Testing connection to: $VLLM_HOST_ONLY:$VLLM_PORT_ONLY"

# Try to connect using curl
if command -v curl &> /dev/null; then
    print_info "Using curl for connectivity test..."
    
    # Test base endpoint
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$VLLM_BASE_URL/models" 2>&1 || echo "000")
    
    if [[ "$RESPONSE" == "200" ]]; then
        print_success "vLLM server is responding (HTTP $RESPONSE)"
    elif [[ "$RESPONSE" == "000" ]]; then
        print_error "vLLM server is not responding"
        print_info "Make sure vLLM is running: python -m vllm.entrypoints.api_server --host $VLLM_HOST_ONLY --port $VLLM_PORT_ONLY"
    else
        print_warning "vLLM server responded with HTTP $RESPONSE"
    fi
    
    # Test API endpoint
    print_info "Fetching models list..."
    MODELS_RESPONSE=$(curl -s --connect-timeout 5 "$VLLM_BASE_URL/models" 2>&1)
    
    if echo "$MODELS_RESPONSE" | grep -q "object"; then
        print_success "Models endpoint responding"
        print_info "Response: $(echo "$MODELS_RESPONSE" | head -c 200)..."
    else
        print_warning "Models endpoint not returning expected format"
        print_info "Response: $MODELS_RESPONSE"
    fi
else
    print_warning "curl not available, skipping HTTP test"
fi

echo ""

# Test 4: Test with elc
echo -e "${BLUE}Test 4: ELC Connection Test${NC}"
echo "────────────────────────────────────────────────"

print_info "Testing with elc using vLLM configuration..."

# Create temporary test script
TEST_SCRIPT=$(mktemp)
cat > "$TEST_SCRIPT" << 'ELC_TEST'
#!/usr/bin/env node
const { execSync } = require('child_process');

const endpoint = process.env.CUSTOM_LLM_ENDPOINT || process.env.VLLM_BASE_URL || 'http://192.168.0.193:8000/v1';
const apiKey = process.env.CUSTOM_LLM_API_KEY || process.env.VLLM_API_KEY || 'no-key';

console.log(`Testing endpoint: ${endpoint}`);
console.log(`API Key: ${apiKey.substring(0, 3)}***`);

try {
    // Test models endpoint
    console.log('\nFetching models...');
    const modelsCmd = `curl -s "${endpoint}/models"`;
    const models = execSync(modelsCmd, { encoding: 'utf8' });
    console.log('Models response:', models.substring(0, 200));
    
    // Test completion endpoint
    console.log('\nTesting completion...');
    const testPrompt = "Hello, are you there?";
    const completionCmd = `curl -s "${endpoint}/completions" \\
        -H "Content-Type: application/json" \\
        -H "Authorization: Bearer ${apiKey}" \\
        -d '{
            "model": "test",
            "prompt": "${testPrompt}",
            "max_tokens": 10,
            "temperature": 0
        }'`;
    
    const completion = execSync(completionCmd, { encoding: 'utf8', timeout: 10000 });
    console.log('Completion response:', completion.substring(0, 300));
    
    console.log('\n✓ All tests passed!');
    process.exit(0);
} catch (error) {
    console.error('\n✗ Test failed:', error.message);
    if (error.status) {
        console.error(`HTTP Status: ${error.status}`);
    }
    process.exit(1);
}
ELC_TEST

# Run test
if command -v node &> /dev/null; then
    if node "$TEST_SCRIPT" 2>&1; then
        print_success "ELC connection test passed"
    else
        print_error "ELC connection test failed"
        print_info "Make sure vLLM server is running and accessible"
    fi
    rm -f "$TEST_SCRIPT"
else
    print_warning "Node.js not available, skipping ELC test"
fi

echo ""

# Test 5: Agent wrapper test
echo -e "${BLUE}Test 5: Agent Wrapper Configuration${NC}"
echo "────────────────────────────────────────────────"

WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/agent-wrapper.sh"

if [[ -f "$WRAPPER_SCRIPT" ]]; then
    print_success "agent-wrapper.sh found"
    
    # Check vLLM configuration
    if grep -q 'VLLM_BASE_URL' "$WRAPPER_SCRIPT"; then
        print_success "agent-wrapper.sh has VLLM_BASE_URL configuration"
    else
        print_warning "agent-wrapper.sh missing VLLM_BASE_URL"
    fi
    
    # Check default endpoint
    DEFAULT_ENDPOINT=$(grep 'VLLM_BASE_URL:-' "$WRAPPER_SCRIPT" | head -1 | sed 's/.*VLLM_BASE_URL:-\([^}]*\).*/\1/')
    if [[ -n "$DEFAULT_ENDPOINT" ]]; then
        print_info "Default vLLM endpoint: $DEFAULT_ENDPOINT"
    fi
else
    print_error "agent-wrapper.sh not found"
fi

echo ""

# Test 6: Configuration summary
echo -e "${BLUE}Test 6: Configuration Summary${NC}"
echo "────────────────────────────────────────────────"

echo ""
echo -e "${CYAN}vLLM Configuration:${NC}"
echo "  Host:        $VLLM_HOST"
echo "  Port:        $VLLM_PORT"
echo "  Base URL:    $VLLM_BASE_URL"
echo "  API Key:     ${VLLM_API_KEY:0:3}***"
echo "  Endpoint:    $CUSTOM_LLM_ENDPOINT"
echo ""

# Check if running in ai-colab project
if [[ -f "$PROJECT_ROOT/conductor/tracks.md" ]]; then
    print_success "Running in ai-colab project context"
else
    print_warning "Not running in ai-colab project directory"
fi

echo ""

# Final summary
echo "============================================================"
echo "  Connection Test Summary"
echo "============================================================"
echo ""

# Determine overall status
if curl -s --connect-timeout 5 "$VLLM_BASE_URL/models" &> /dev/null; then
    echo -e "${GREEN}✓ vLLM Connection: SUCCESSFUL${NC}"
    echo ""
    echo "vLLM server is running and accessible at:"
    echo "  $VLLM_BASE_URL"
    echo ""
    echo "You can now:"
    echo "  1. Launch dashboard with vLLM: ./launch.sh --vllm"
    echo "  2. Use elc directly: elc --base-url $VLLM_BASE_URL"
    echo "  3. Configure in ai-colab: ./scripts/config-manager.sh set llm.vllm.enabled true"
    echo ""
    exit 0
else
    echo -e "${RED}✗ vLLM Connection: FAILED${NC}"
    echo ""
    echo "vLLM server is NOT responding at:"
    echo "  $VLLM_BASE_URL"
    echo ""
    echo "To start a local vLLM server:"
    echo ""
    echo "  # Install vLLM"
    echo "  pip install vllm"
    echo ""
    echo "  # Start server"
    echo "  python -m vllm.entrypoints.api_server \\"
    echo "    --host $VLLM_HOST \\"
    echo "    --port $VLLM_PORT \\"
    echo "    --model <your-model-name>"
    echo ""
    echo "Or update configuration to point to existing vLLM server:"
    echo "  ./scripts/config-manager.sh set llm.vllm.host <host>"
    echo ""
    exit 1
fi
