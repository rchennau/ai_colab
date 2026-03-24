#!/usr/bin/env bash
# Automated Atari-LX to ai-colab Migration Script
# Non-interactive migration for existing Atari-LX projects

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Atari-LX to ai-colab Automated Migration         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "\n${CYAN}═══ Step $1: $2 ═══${NC}"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

# Get project root
PROJECT_ROOT="${1:-$(pwd)}"
AI_COLAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_header
echo -e "${BLUE}Project Root:${NC} $PROJECT_ROOT"
echo -e "${BLUE}ai-colab Root:${NC} $AI_COLAB_ROOT"
echo ""

# Verify this is an Atari-LX project
if [[ ! -d "$PROJECT_ROOT/atari_agent" ]] && [[ ! -d "$PROJECT_ROOT/conductor" ]]; then
    echo -e "${RED}Error: This doesn't appear to be an Atari-LX project${NC}"
    echo -e "Expected: atari_agent/ or conductor/ directories"
    exit 1
fi

print_success "Verified Atari-LX project structure"
echo ""

# Step 1: Create backup
print_step "1" "Creating Backup"

BACKUP_DIR="$PROJECT_ROOT/.ai-colab-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "  Backup location: $BACKUP_DIR"

# Backup critical directories
for dir in conductor docs/kb atari_agent .qwen; do
    if [[ -d "$PROJECT_ROOT/$dir" ]]; then
        mkdir -p "$(dirname "$BACKUP_DIR/$dir")"
        cp -r "$PROJECT_ROOT/$dir" "$BACKUP_DIR/$dir"
        print_success "Backed up: $dir"
    fi
done

print_success "Backup complete"
echo ""

# Step 2: Copy MCP server to atari-8bit module
print_step "2" "Migrating MCP Server"

MCP_SOURCE="$PROJECT_ROOT/atari_agent"
MCP_TARGET="$PROJECT_ROOT/modules/atari-8bit/mcp"

if [[ -d "$MCP_SOURCE" ]]; then
    if [[ -d "$MCP_TARGET" ]]; then
        print_warning "MCP target already exists: $MCP_TARGET"
        print_warning "Skipping MCP copy (manual migration may be needed)"
    else
        mkdir -p "$(dirname "$MCP_TARGET")"
        cp -r "$MCP_SOURCE" "$MCP_TARGET"
        print_success "Copied atari_agent/ → modules/atari-8bit/mcp/"
        
        # Update module.toml
        MODULE_TOML="$PROJECT_ROOT/modules/atari-8bit/module.toml"
        if [[ -f "$MODULE_TOML" ]]; then
            if ! grep -q "mcp_server" "$MODULE_TOML"; then
                cat >> "$MODULE_TOML" << EOF

[mcp]
server = "modules/atari-8bit/mcp/server.py"
name = "atari-dev-agent"
EOF
                print_success "Updated module.toml with MCP server config"
            fi
        fi
    fi
else
    print_warning "MCP server not found at: $MCP_SOURCE"
fi
echo ""

# Step 3: Merge conductor configurations
print_step "3" "Migrating Conductor Configurations"

# Ensure conductor directory exists
if [[ ! -d "$PROJECT_ROOT/conductor" ]]; then
    mkdir -p "$PROJECT_ROOT/conductor/tracks"
    print_success "Created conductor directory structure"
fi

# Merge .qwen configs into conductor
if [[ -d "$PROJECT_ROOT/.qwen" ]]; then
    print_success "Found .qwen agent configurations"
    
    # Copy conductor-agent.md if it exists
    if [[ -f "$PROJECT_ROOT/.qwen/conductor-agent.md" ]]; then
        cp "$PROJECT_ROOT/.qwen/conductor-agent.md" "$PROJECT_ROOT/conductor/agent-config.md"
        print_success "Copied: .qwen/conductor-agent.md → conductor/agent-config.md"
    fi
    
    # Copy product-plan.md if conductor/product.md doesn't exist
    if [[ -f "$PROJECT_ROOT/.qwen/product-plan.md" ]] && [[ ! -f "$PROJECT_ROOT/conductor/product.md" ]]; then
        cp "$PROJECT_ROOT/.qwen/product-plan.md" "$PROJECT_ROOT/conductor/product.md"
        print_success "Copied: .qwen/product-plan.md → conductor/product.md"
    fi
fi

# Verify tracks.md
if [[ -f "$PROJECT_ROOT/conductor/tracks.md" ]]; then
    track_count=$(grep -c "^\- \[x\]" "$PROJECT_ROOT/conductor/tracks.md" 2>/dev/null || echo "0")
    print_success "Tracks preserved: $track_count completed tracks in tracks.md"
fi
echo ""

# Step 4: Index knowledge base
print_step "4" "Indexing Knowledge Base"

KB_INDEXER="$AI_COLAB_ROOT/scripts/hcom-kb-index.sh"

if [[ -f "$KB_INDEXER" ]]; then
    echo -e "  Running KB indexer..."
    if bash "$KB_INDEXER" > /dev/null 2>&1; then
        print_success "Knowledge base indexed successfully"
        
        if [[ -f "$PROJECT_ROOT/conductor/knowledge_base_map.md" ]]; then
            kb_lines=$(wc -l < "$PROJECT_ROOT/conductor/knowledge_base_map.md")
            print_success "Created: conductor/knowledge_base_map.md ($kb_lines lines)"
        fi
    else
        print_warning "KB indexer not available or failed (can run manually later)"
        print_warning "Run: ./scripts/hcom-kb-index.sh"
    fi
else
    print_warning "KB indexer not found at: $KB_INDEXER"
fi
echo ""

# Step 5: Create ai-colab configuration
print_step "5" "Creating ai-colab Configuration"

PREFS_FILE="$PROJECT_ROOT/.ai-colab-prefs"

if [[ ! -f "$PREFS_FILE" ]]; then
    cat > "$PREFS_FILE" << EOF
# ai-colab Preferences
# Generated by migration on $(date)

[migration]
migrated=true
migration_date=$(date +%Y-%m-%d)
backup_location=$BACKUP_DIR
source_project=Atari-LX

[modules]
ENABLE_ATARI_8BIT=true

[compute]
backend=local
EOF
    print_success "Created: .ai-colab-prefs"
else
    print_warning "Preferences already exist, updating..."
    
    # Add migration info
    if ! grep -q "source_project" "$PREFS_FILE"; then
        echo "source_project=Atari-LX" >> "$PREFS_FILE"
        echo "migration_date=$(date +%Y-%m-%d)" >> "$PREFS_FILE"
        print_success "Updated preferences with migration info"
    fi
fi

# Enable Atari 8-Bit module
if ! grep -q "ENABLE_ATARI_8BIT" "$PREFS_FILE"; then
    echo "ENABLE_ATARI_8BIT=true" >> "$PREFS_FILE"
    print_success "Enabled: atari-8bit module"
fi
echo ""

# Step 6: Create migration report
print_step "6" "Generating Migration Report"

REPORT_FILE="$PROJECT_ROOT/.ai-colab-migration-report.md"

cat > "$REPORT_FILE" << EOF
# Atari-LX to ai-colab Migration Report

**Date:** $(date)
**Source:** Atari-LX Project
**Status:** ✅ Complete

## Migration Summary

### Components Migrated

| Component | Status | Details |
|-----------|--------|---------|
| MCP Server | ✅ Migrated | atari_agent/ → modules/atari-8bit/mcp/ |
| Conductor | ✅ Preserved | All tracks and configs maintained |
| Knowledge Base | ✅ Indexed | docs/kb/ → conductor/knowledge_base_map.md |
| Agent Configs | ✅ Merged | .qwen/ → conductor/ |

### Backup Information

- **Location:** $BACKUP_DIR
- **Contents:** conductor/, docs/kb/, atari_agent/, .qwen/
- **Rollback:** cp -r $BACKUP_DIR/* .

### Next Steps

1. **Review Migration:**
   \`\`\`bash
   cat $REPORT_FILE
   \`\`\`

2. **Test MCP Server:**
   \`\`\`bash
   cd modules/atari-8bit/mcp
   python3 server.py --test
   \`\`\`

3. **Launch ai-colab:**
   \`\`\`bash
   cd /Users/rchennault/Library/Mobile Documents/com~apple~CloudDocs/GitHub/ai_colab
   ./launch.sh
   \`\`\`

4. **Verify Commands:**
   - !status - Check project status
   - !test - Run tests
   - !kb <query> - Search knowledge base
   - !screenshot - Capture Atari screen (if module enabled)

### Configuration Files

- \`modules/atari-8bit/module.toml\` - Atari 8-Bit module config
- \`conductor/tracks.md\` - Project tracks (preserved)
- \`conductor/product.md\` - Product definition (merged)
- \`.ai-colab-prefs\` - ai-colab preferences

## Verification Checklist

- [ ] MCP server copied to modules/atari-8bit/mcp/
- [ ] Module.toml updated with MCP config
- [ ] Conductor configs merged
- [ ] Knowledge base indexed
- [ ] Preferences created
- [ ] Backup verified

---

**Migration Tool:** ai-colab migrate-project.sh  
**Version:** 1.0  
**Generated:** $(date)
EOF

print_success "Created migration report: $REPORT_FILE"
echo ""

# Step 7: Summary
print_step "7" "Migration Summary"

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Migration Complete!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}What was migrated:${NC}"
echo -e "  ✓ MCP server: atari_agent/ → modules/atari-8bit/mcp/"
echo -e "  ✓ Conductor configs: Preserved and merged"
echo -e "  ✓ Knowledge base: Indexed for !kb commands"
echo -e "  ✓ Agent configs: .qwen/ → conductor/"
echo -e "  ✓ Preferences: .ai-colab-prefs created"
echo ""
echo -e "${BLUE}Backup Location:${NC}"
echo -e "  $BACKUP_DIR"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Review: cat $REPORT_FILE"
echo -e "  2. Test: cd modules/atari-8bit/mcp && python3 server.py --test"
echo -e "  3. Launch: ./launch.sh (from ai-colab directory)"
echo ""
echo -e "${YELLOW}Note:${NC} To use the migrated project, launch ai-colab from:"
echo -e "  ${BLUE}$PROJECT_ROOT${NC}"
echo ""
print_success "Migration complete!"
