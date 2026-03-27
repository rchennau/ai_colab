#!/bin/bash
#
# MCP & RAG Integration Verification
# Verifies that all new enhancements are properly integrated
#
# Usage: ./scripts/verify-integration.sh
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Check if file exists
check_file() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        print_success "$description: $file"
        ((CHECKS_PASSED++))
    else
        print_error "$description missing: $file"
        ((CHECKS_FAILED++))
    fi
}

# Check if directory exists
check_dir() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        print_success "$description: $dir"
        ((CHECKS_PASSED++))
    else
        print_error "$description missing: $dir"
        ((CHECKS_FAILED++))
    fi
}

# Check if command exists
check_command() {
    local cmd="$1"
    local description="$2"
    
    if command -v "$cmd" &> /dev/null; then
        print_success "$description available: $cmd"
        ((CHECKS_PASSED++))
    else
        print_warning "$description not found: $cmd"
        ((CHECKS_WARNING++))
    fi
}

# Check Python import
check_python_import() {
    local module="$1"
    local description="$2"
    
    if python3 -c "import $module" 2>/dev/null; then
        print_success "$description importable: $module"
        ((CHECKS_PASSED++))
    else
        print_warning "$description not importable: $module"
        ((CHECKS_WARNING++))
    fi
}

echo ""
echo "============================================================"
echo "  MCP & RAG Integration Verification"
echo "  Project: ai-colab"
echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

# Section 1: File Structure
echo -e "${BLUE}=== File Structure ===${NC}"
echo ""

# MCP Server files
check_file "$PROJECT_ROOT/mcp/ai_colab_server/__init__.py" "MCP init"
check_file "$PROJECT_ROOT/mcp/ai_colab_server/server.py" "MCP server"
check_file "$PROJECT_ROOT/mcp/ai_colab_server/tools/blackboard.py" "Blackboard tools"
check_file "$PROJECT_ROOT/mcp/ai_colab_server/tools/tracks.py" "Tracks tools"
check_file "$PROJECT_ROOT/mcp/ai_colab_server/tools/knowledge.py" "Knowledge tools"
check_file "$PROJECT_ROOT/mcp/ai_colab_server/tools/agents.py" "Agent tools"
check_file "$PROJECT_ROOT/mcp/ai_colab_server/tools/devops.py" "DevOps tools"
check_file "$PROJECT_ROOT/mcp/ai_colab_server/transports/sse.py" "SSE transport"

# RAG files
check_file "$PROJECT_ROOT/rag/__init__.py" "RAG init"
check_file "$PROJECT_ROOT/rag/client.py" "RAG client"
check_file "$PROJECT_ROOT/rag/indexer/chunker.py" "Document chunker"
check_file "$PROJECT_ROOT/rag/indexer/embedder.py" "Embedder"
check_file "$PROJECT_ROOT/rag/indexer/pipeline.py" "Indexing pipeline"
check_file "$PROJECT_ROOT/rag/search/retriever.py" "Retriever"
check_file "$PROJECT_ROOT/rag/search/cache.py" "Query cache"
check_file "$PROJECT_ROOT/rag/storage/database.py" "Vector store"
check_file "$PROJECT_ROOT/rag/watcher/file_watcher.py" "File watcher"

# Test files
check_file "$PROJECT_ROOT/mcp/tests/test_server.py" "MCP tests"
check_file "$PROJECT_ROOT/rag/tests/test_rag.py" "RAG tests"
check_file "$PROJECT_ROOT/tests/mcp_rag/test_integration.py" "Integration tests"
check_file "$PROJECT_ROOT/tests/mcp_rag/security_audit.py" "Security audit"

# Script files
check_file "$PROJECT_ROOT/scripts/hcom-kb-search.sh" "Enhanced !kb command"
check_file "$PROJECT_ROOT/scripts/setup-mcp-clients.sh" "MCP client setup"
check_file "$PROJECT_ROOT/scripts/run-tests.sh" "Test runner"

# Config files
check_file "$PROJECT_ROOT/config/mcp/gemini-cli.toml" "gemini-cli config template"
check_file "$PROJECT_ROOT/config/mcp/qwen-code.toml" "qwen-code config template"

# Documentation
check_file "$PROJECT_ROOT/docs/MCP_CLIENT_SETUP.md" "MCP client setup guide"
check_file "$PROJECT_ROOT/docs/MCP_RAG_USER_GUIDE.md" "User guide"
check_file "$PROJECT_ROOT/docs/PHASE3_SUMMARY.md" "Phase 3 summary"
check_file "$PROJECT_ROOT/docs/PHASE4_SUMMARY.md" "Phase 4 summary"

# Requirements files
check_file "$PROJECT_ROOT/requirements-mcp.txt" "MCP requirements"
check_file "$PROJECT_ROOT/requirements-rag.txt" "RAG requirements"
check_file "$PROJECT_ROOT/requirements-test.txt" "Test requirements"

echo ""

# Section 2: Install.sh Integration
echo -e "${BLUE}=== Install.sh Integration ===${NC}"
echo ""

if [[ -f "$PROJECT_ROOT/install.sh" ]]; then
    # Check for MCP/RAG dependency installation
    if grep -q "requirements-mcp.txt" "$PROJECT_ROOT/install.sh"; then
        print_success "MCP requirements referenced in install.sh"
        ((CHECKS_PASSED++))
    else
        print_error "MCP requirements not referenced in install.sh"
        ((CHECKS_FAILED++))
    fi
    
    if grep -q "requirements-rag.txt" "$PROJECT_ROOT/install.sh"; then
        print_success "RAG requirements referenced in install.sh"
        ((CHECKS_PASSED++))
    else
        print_error "RAG requirements not referenced in install.sh"
        ((CHECKS_FAILED++))
    fi
    
    if grep -q "requirements-webui.txt" "$PROJECT_ROOT/install.sh"; then
        print_success "Web UI requirements referenced in install.sh"
        ((CHECKS_PASSED++))
    else
        print_error "Web UI requirements not referenced in install.sh"
        ((CHECKS_FAILED++))
    fi
else
    print_error "install.sh not found"
    ((CHECKS_FAILED++))
fi

echo ""

# Section 3: Launch.sh Integration
echo -e "${BLUE}=== Launch.sh Integration ===${NC}"
echo ""

if [[ -f "$PROJECT_ROOT/launch.sh" ]]; then
    # Check for --rag-watcher flag
    if grep -q "\-\-rag-watcher" "$PROJECT_ROOT/launch.sh"; then
        print_success "RAG watcher flag (--rag-watcher) in launch.sh"
        ((CHECKS_PASSED++))
    else
        print_error "RAG watcher flag not found in launch.sh"
        ((CHECKS_FAILED++))
    fi
    
    # Check for help option
    if grep -q "\-\-help" "$PROJECT_ROOT/launch.sh"; then
        print_success "Help option (--help) in launch.sh"
        ((CHECKS_PASSED++))
    else
        print_warning "Help option not found in launch.sh"
        ((CHECKS_WARNING++))
    fi
    
    # Check for RAG watcher implementation
    if grep -q "DocumentWatcher" "$PROJECT_ROOT/launch.sh"; then
        print_success "RAG watcher implementation in launch.sh"
        ((CHECKS_PASSED++))
    else
        print_error "RAG watcher implementation not found in launch.sh"
        ((CHECKS_FAILED++))
    fi
else
    print_error "launch.sh not found"
    ((CHECKS_FAILED++))
fi

echo ""

# Section 4: Web UI Integration
echo -e "${BLUE}=== Web UI Integration ===${NC}"
echo ""

check_file "$PROJECT_ROOT/webui/app.py" "Web UI backend"
check_file "$PROJECT_ROOT/webui/index.html" "Web UI frontend"

# Check for KB endpoints in app.py
if [[ -f "$PROJECT_ROOT/webui/app.py" ]]; then
    if grep -q "/api/kb/search" "$PROJECT_ROOT/webui/app.py"; then
        print_success "KB search endpoint in app.py"
        ((CHECKS_PASSED++))
    else
        print_error "KB search endpoint not found in app.py"
        ((CHECKS_FAILED++))
    fi
    
    if grep -q "/api/kb/index" "$PROJECT_ROOT/webui/app.py"; then
        print_success "KB index endpoint in app.py"
        ((CHECKS_PASSED++))
    else
        print_error "KB index endpoint not found in app.py"
        ((CHECKS_FAILED++))
    fi
    
    if grep -q "/api/kb/stats" "$PROJECT_ROOT/webui/app.py"; then
        print_success "KB stats endpoint in app.py"
        ((CHECKS_PASSED++))
    else
        print_error "KB stats endpoint not found in app.py"
        ((CHECKS_FAILED++))
    fi
fi

# Check for Knowledge Base page in index.html
if [[ -f "$PROJECT_ROOT/webui/index.html" ]]; then
    if grep -q "Knowledge Base" "$PROJECT_ROOT/webui/index.html"; then
        print_success "Knowledge Base page in index.html"
        ((CHECKS_PASSED++))
    else
        print_error "Knowledge Base page not found in index.html"
        ((CHECKS_FAILED++))
    fi
fi

echo ""

# Section 5: Python Dependencies
echo -e "${BLUE}=== Python Dependencies ===${NC}"
echo ""

check_python_import "flask" "Flask"
check_python_import "rag.client" "RAG client"
check_python_import "mcp.ai_colab_server.server" "MCP server"

echo ""

# Section 6: Track Registry
echo -e "${BLUE}=== Track Registry ===${NC}"
echo ""

if [[ -f "$PROJECT_ROOT/conductor/tracks.md" ]]; then
    if grep -q "MCP Server & RAG Integration" "$PROJECT_ROOT/conductor/tracks.md"; then
        print_success "MCP & RAG track registered in tracks.md"
        ((CHECKS_PASSED++))
    else
        print_error "MCP & RAG track not found in tracks.md"
        ((CHECKS_FAILED++))
    fi
    
    if grep -q "mcp_rag_integration" "$PROJECT_ROOT/conductor/tracks.md"; then
        print_success "Track path registered correctly"
        ((CHECKS_PASSED++))
    else
        print_error "Track path not found in tracks.md"
        ((CHECKS_FAILED++))
    fi
else
    print_error "tracks.md not found"
    ((CHECKS_FAILED++))
fi

# Check track files
check_dir "$PROJECT_ROOT/conductor/tracks/mcp_rag_integration_20260327" "Track directory"
check_file "$PROJECT_ROOT/conductor/tracks/mcp_rag_integration_20260327/index.md" "Track index"
check_file "$PROJECT_ROOT/conductor/tracks/mcp_rag_integration_20260327/spec.md" "Track spec"
check_file "$PROJECT_ROOT/conductor/tracks/mcp_rag_integration_20260327/plan.md" "Track plan"
check_file "$PROJECT_ROOT/conductor/tracks/mcp_rag_integration_20260327/metadata.json" "Track metadata"

echo ""

# Summary
echo "============================================================"
echo "  Verification Summary"
echo "============================================================"
echo ""
echo "  Passed:   $CHECKS_PASSED"
echo "  Failed:   $CHECKS_FAILED"
echo "  Warnings: $CHECKS_WARNING"
echo ""

if [[ $CHECKS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Install dependencies: ./install.sh"
    echo "  2. Run tests: ./scripts/run-tests.sh --all"
    echo "  3. Launch: ./launch.sh --rag-watcher"
    echo ""
    exit 0
else
    echo -e "${RED}✗ $CHECKS_FAILED critical check(s) failed${NC}"
    echo ""
    echo "Please review the failed checks above and ensure all files are properly committed."
    echo ""
    exit 1
fi
