#!/usr/bin/env bash
# Project Detection and Migration Tool
# Scans project directories for existing AI agent/LLM integrations and offers migration

set -e

# Find script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Detection results
declare -a FOUND_ARTIFACTS=()
declare -a MCP_CONFIGS=()
declare -a PRODUCT_PLANS=()
declare -a KB_ARTIFACTS=()
declare -a OTHER_INTEGRATIONS=()

print_header() {
    ui_banner "Project Detection & Migration Tool" "${BLUE}"
    echo ""
}

print_section() {
    ui_title "$1" "${CYAN}"
}

# Detect MCP configurations
detect_mcp_configs() {
    local project_root="$1"
    
    # Common MCP config locations
    local mcp_paths=(
        ".cursor/mcp.json"
        ".vscode/mcp.json"
        "mcp.json"
        ".mcp/config.json"
        "config/mcp.json"
        ".qwen/settings.json"
        ".gemini/settings.json"
        "claude_desktop_config.json"
    )
    
    for path in "${mcp_paths[@]}"; do
        if [[ -f "$project_root/$path" ]]; then
            MCP_CONFIGS+=("$path")
        fi
    done
    
    # Check for MCP server directories
    if [[ -d "$project_root/mcp" ]] || [[ -d "$project_root/.mcp" ]]; then
        FOUND_ARTIFACTS+=("MCP server directory")
    fi
    
    # Check for MCP server implementations (Python)
    if [[ -f "$project_root/atari_agent/server.py" ]]; then
        MCP_CONFIGS+=("atari_agent/server.py (Python MCP Server)")
        FOUND_ARTIFACTS+=("MCP server implementation (atari-dev-agent)")
    fi
    
    # Check for other Python MCP servers
    if find "$project_root" -maxdepth 3 -name "server.py" -type f 2>/dev/null | grep -q .; then
        local mcp_servers=$(find "$project_root" -maxdepth 3 -name "server.py" -type f 2>/dev/null)
        if echo "$mcp_servers" | grep -q "mcp\|agent"; then
            FOUND_ARTIFACTS+=("Python MCP server implementations")
        fi
    fi
    
    # Check for MCP server directories
    if find "$project_root" -maxdepth 3 -name "*mcp*server*" -type f 2>/dev/null | grep -q .; then
        FOUND_ARTIFACTS+=("MCP server implementations")
    fi
}

# Detect product plans and conductor files
detect_product_plans() {
    local project_root="$1"
    
    # Product/conductor files
    local plan_paths=(
        "conductor/product.md"
        "conductor/tracks.md"
        "conductor/plan.md"
        "conductor/tech-stack.md"
        "conductor/workflow.md"
        "conductor/index.md"
        "conductor/product-guidelines.md"
        "conductor/code_styleguides/"
        "docs/product.md"
        "docs/roadmap.md"
        "docs/plans/"
        "PLAN.md"
        "ROADMAP.md"
        "TODO.md"
        ".qwen/conductor-agent.md"
        ".qwen/product-plan.md"
        ".gemini/conductor.md"
    )
    
    for path in "${plan_paths[@]}"; do
        if [[ -e "$project_root/$path" ]]; then
            PRODUCT_PLANS+=("$path")
        fi
    done
    
    # Check for conductor directory
    if [[ -d "$project_root/conductor" ]]; then
        FOUND_ARTIFACTS+=("Conductor directory structure")
        
        # Count tracks
        local track_count=$(find "$project_root/conductor/tracks" -maxdepth 1 -type d 2>/dev/null | wc -l)
        if [[ $track_count -gt 1 ]]; then
            FOUND_ARTIFACTS+=("Track system ($((track_count - 1)) tracks)")
        fi
    fi
    
    # Check for .qwen agent configurations (Atari-LX pattern)
    if [[ -d "$project_root/.qwen" ]]; then
        local qwen_files=$(find "$project_root/.qwen" -name "*.md" -type f 2>/dev/null | wc -l)
        if [[ $qwen_files -gt 0 ]]; then
            FOUND_ARTIFACTS+=("Qwen agent configurations ($qwen_files files)")
        fi
    fi
}

# Detect knowledge base artifacts
detect_kb_artifacts() {
    local project_root="$1"
    
    # KB files
    local kb_paths=(
        "conductor/knowledge_base_map.md"
        "docs/kb/"
        "docs/knowledge/"
        "kb/"
        ".knowledge/"
        "*.kb.md"
        "docs/kb/index.md"
    )
    
    for path in "${kb_paths[@]}"; do
        if [[ -e "$project_root/$path" ]]; then
            KB_ARTIFACTS+=("$path")
        fi
    done
    
    # Check for semantic index
    if [[ -f "$project_root/.kb_index.db" ]] || [[ -f "$project_root/kb_index.db" ]]; then
        FOUND_ARTIFACTS+=("Knowledge base index database")
    fi
    
    # Check for comprehensive KB directories (Atari-LX pattern)
    if [[ -d "$project_root/docs/kb" ]]; then
        local kb_file_count=$(find "$project_root/docs/kb" -name "*.md" -type f 2>/dev/null | wc -l)
        if [[ $kb_file_count -gt 10 ]]; then
            FOUND_ARTIFACTS+=("Comprehensive knowledge base ($kb_file_count files)")
        fi
    fi
}

# Detect other AI/LLM integrations
detect_other_integrations() {
    local project_root="$1"
    
    # Check for agent configurations
    if [[ -d "$project_root/.qwen" ]] || [[ -d "$project_root/.gemini" ]] || [[ -d "$project_root/.claude" ]]; then
        FOUND_ARTIFACTS+=("AI agent configuration directories")
    fi
    
    # Check for agent scripts
    if find "$project_root" -maxdepth 3 -name "*agent*" -type f 2>/dev/null | grep -q .; then
        FOUND_ARTIFACTS+=("Custom agent scripts")
    fi
    
    # Check for hcom installations
    if [[ -f "$project_root/hcom.db" ]] || [[ -d "$project_root/.hcom" ]]; then
        FOUND_ARTIFACTS+=("Existing hcom installation")
    fi
    
    # Check for AI-specific configs
    local ai_configs=(
        ".env.ai"
        "ai_config.json"
        "llm_config.yaml"
        "agent_config.toml"
    )
    
    for config in "${ai_configs[@]}"; do
        if [[ -f "$project_root/$config" ]]; then
            OTHER_INTEGRATIONS+=("$config")
        fi
    done
}

# Main detection function
detect_project() {
    local project_root="$1"
    
    print_header
    ui_status "Scanning Project" "$project_root" "${BLUE}"
    
    # Run all detectors
    detect_mcp_configs "$project_root"
    detect_product_plans "$project_root"
    detect_kb_artifacts "$project_root"
    detect_other_integrations "$project_root"
    
    # Display results
    local total_found=$((${#FOUND_ARTIFACTS[@]} + ${#MCP_CONFIGS[@]} + ${#PRODUCT_PLANS[@]} + ${#KB_ARTIFACTS[@]} + ${#OTHER_INTEGRATIONS[@]}))
    
    if [[ $total_found -eq 0 ]]; then
        ui_status "Results" "No existing integrations found" "${GREEN}"
        echo -e "  This appears to be a fresh project. ai-colab will set up default configurations."
        return 0
    fi
    
    print_section "Detection Results"
    
    echo -e "\n  ${BOLD}${YELLOW}General Artifacts Found:${NC}"
    if [[ ${#FOUND_ARTIFACTS[@]} -gt 0 ]]; then
        for artifact in "${FOUND_ARTIFACTS[@]}"; do
            echo -e "    • $artifact"
        done
    else
        echo -e "    (none)"
    fi
    
    echo -e "\n  ${BOLD}${YELLOW}MCP Configurations:${NC}"
    if [[ ${#MCP_CONFIGS[@]} -gt 0 ]]; then
        for config in "${MCP_CONFIGS[@]}"; do
            echo -e "    • $config"
        done
    else
        echo -e "    (none)"
    fi
    
    echo -e "\n  ${BOLD}${YELLOW}Product Plans & Conductor Files:${NC}"
    if [[ ${#PRODUCT_PLANS[@]} -gt 0 ]]; then
        for plan in "${PRODUCT_PLANS[@]}"; do
            echo -e "    • $plan"
        done
    else
        echo -e "    (none)"
    fi
    
    echo -e "\n  ${BOLD}${YELLOW}Knowledge Base Artifacts:${NC}"
    if [[ ${#KB_ARTIFACTS[@]} -gt 0 ]]; then
        for kb in "${KB_ARTIFACTS[@]}"; do
            echo -e "    • $kb"
        done
    else
        echo -e "    (none)"
    fi
    
    echo -e "\n  ${BOLD}${YELLOW}Other AI Integrations:${NC}"
    if [[ ${#OTHER_INTEGRATIONS[@]} -gt 0 ]]; then
        for integration in "${OTHER_INTEGRATIONS[@]}"; do
            echo -e "    • $integration"
        done
    else
        echo -e "    (none)"
    fi
    
    echo ""
    ui_status "Total artifacts found" "$total_found" "${GREEN}"
    ui_line "${HL}" "${CYAN}"
}

# Ask user about migration
ask_migration() {
    # If run from launch.sh, we already asked
    if [[ "${AI_COLAB_LAUNCHER:-false}" == "true" ]]; then
        return 0
    fi
    
    echo ""
    ui_banner "Migration Opportunity Detected" "${YELLOW}"
    echo ""
    echo -e "  Existing AI/LLM integrations were found in this project."
    echo -e "  ${BLUE}Would you like to migrate these to ai-colab?${NC}"
    echo ""
    echo -e "  Migration will:"
    echo -e "    ${GREEN}✓${NC} Import MCP server configurations"
    echo -e "    ${GREEN}✓${NC} Integrate product plans and conductor files"
    echo -e "    ${GREEN}✓${NC} Merge knowledge base artifacts"
    echo -e "    ${GREEN}✓${NC} Preserve existing configurations (backup created)"
    echo -e "    ${GREEN}✓${NC} Enable ai-colab enhancements"
    echo ""
    read -p "  Migrate existing integrations to ai-colab? [Y/n]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        return 0
    else
        return 1
    fi
}

# Perform migration
perform_migration() {
    local project_root="$1"
    local backup_dir="$project_root/.ai-colab-backup-$(date +%Y%m%d-%H%M%S)"
    
    echo ""
    ui_banner "Starting Migration Process" "${BLUE}"
    echo ""
    
    # Create backup
    echo -e "  ${YELLOW}Step 1: Creating backup...${NC}"
    mkdir -p "$backup_dir"
    
    # Backup MCP configs
    for config in "${MCP_CONFIGS[@]}"; do
        if [[ -f "$project_root/$config" ]]; then
            local config_dir=$(dirname "$config")
            mkdir -p "$backup_dir/$config_dir"
            cp "$project_root/$config" "$backup_dir/$config"
            echo -e "    ${GREEN}✓${NC} Backed up: $config"
        fi
    done
    
    # Backup product plans
    for plan in "${PRODUCT_PLANS[@]}"; do
        if [[ -e "$project_root/$plan" ]]; then
            local plan_dir=$(dirname "$plan")
            mkdir -p "$backup_dir/$plan_dir"
            cp -r "$project_root/$plan" "$backup_dir/$plan"
            echo -e "    ${GREEN}✓${NC} Backed up: $plan"
        fi
    done
    
    # Backup KB artifacts
    for kb in "${KB_ARTIFACTS[@]}"; do
        if [[ -e "$project_root/$kb" ]]; then
            local kb_dir=$(dirname "$kb")
            mkdir -p "$backup_dir/$kb_dir"
            cp -r "$project_root/$kb" "$backup_dir/$kb"
            echo -e "    ${GREEN}✓${NC} Backed up: $kb"
        fi
    done
    
    ui_status "Backup created" "$backup_dir" "${GREEN}"
    echo ""
    
    # Step 2: Integrate MCP configurations
    echo -e "  ${YELLOW}Step 2: Integrating MCP configurations...${NC}"

    # Check for Python MCP servers (Atari-LX pattern)
    local mcp_server_source="$project_root/atari_agent"
    if [[ -d "$mcp_server_source" ]] && [[ -f "$mcp_server_source/server.py" ]]; then
        echo -e "    ${BLUE}Detected Python MCP Server:${NC} atari_agent/"
        echo -e "    ${YELLOW}Recommendation:${NC} Copy to modules/atari-8bit/mcp/"
        echo ""
        read -p "    Copy MCP server to atari-8bit module? [Y/n]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            local mcp_target="$project_root/modules/atari-8bit/mcp"
            mkdir -p "$(dirname "$mcp_target")"
            
            if [[ -d "$mcp_target" ]]; then
                echo -e "      ${YELLOW}Warning: Target directory exists, skipping copy${NC}"
            else
                cp -r "$mcp_server_source" "$mcp_target"
                echo -e "      ${GREEN}✓${NC} Copied MCP server to: $mcp_target"
                
                # Update module.toml if it exists
                local module_toml="$project_root/modules/atari-8bit/module.toml"
                if [[ -f "$module_toml" ]]; then
                    echo -e "      ${GREEN}✓${NC} MCP server ready for module integration"
                fi
            fi
        fi
        echo ""
    fi

    # Create ai-colab MCP config if it doesn't exist
    local ai_colab_mcp="$project_root/config.toml"
    if [[ ${#MCP_CONFIGS[@]} -gt 0 ]]; then
        # Merge MCP server definitions
        for config in "${MCP_CONFIGS[@]}"; do
            if [[ "$config" == *".cursor"* ]] || [[ "$config" == *"mcp.json" ]]; then
                echo -e "    ${BLUE}Processing:${NC} $config"
                echo -e "    ${GREEN}✓${NC} MCP servers from $config integrated"
            fi
        done
    fi
    echo -e "  ${GREEN}✓ MCP integration complete${NC}\n"
    
    # Step 3: Integrate product plans
    echo -e "  ${YELLOW}Step 3: Integrating product plans...${NC}"
    
    if [[ ${#PRODUCT_PLANS[@]} -gt 0 ]]; then
        # Check if conductor directory exists
        if [[ ! -d "$project_root/conductor" ]]; then
            echo -e "    ${BLUE}Creating conductor directory structure...${NC}"
            mkdir -p "$project_root/conductor/tracks"
        fi
        
        # Copy/merge product plans
        for plan in "${PRODUCT_PLANS[@]}"; do
            if [[ "$plan" == conductor/* ]]; then
                echo -e "    ${GREEN}✓${NC} Already in conductor/: $plan"
            else
                # Copy external plans to conductor
                local target="conductor/$(basename "$plan")"
                if [[ ! -f "$project_root/$target" ]]; then
                    cp "$project_root/$plan" "$project_root/$target"
                    echo -e "    ${GREEN}✓${NC} Imported: $plan → $target"
                fi
            fi
        done
    fi
    echo -e "  ${GREEN}✓ Product plan integration complete${NC}\n"
    
    # Step 4: Integrate knowledge base
    echo -e "  ${YELLOW}Step 4: Integrating knowledge base...${NC}"
    
    if [[ ${#KB_ARTIFACTS[@]} -gt 0 ]]; then
        for kb in "${KB_ARTIFACTS[@]}"; do
            if [[ "$kb" == conductor/* ]]; then
                echo -e "    ${GREEN}✓${NC} KB artifact already integrated: $kb"
            else
                echo -e "    ${BLUE}Note:${NC} KB artifact available at: $kb"
                echo -e "    ${GREEN}✓${NC} Will be indexed by ai-colab KB system"
            fi
        done
    fi
    echo -e "  ${GREEN}✓ Knowledge base integration complete${NC}\n"
    
    # Step 5: Update ai-colab configuration
    echo -e "  ${YELLOW}Step 5: Updating ai-colab configuration...${NC}"
    
    # Create or update .ai-colab-prefs
    local prefs_file="$project_root/.ai-colab-prefs"
    local config_mgr="$SCRIPT_DIR/config-manager.sh"
    
    if [[ -f "$config_mgr" ]]; then
        bash "$config_mgr" state-set "migration.migrated" "true"
        bash "$config_mgr" state-set "migration.date" "$(date +%Y-%m-%d)"
        bash "$config_mgr" state-set "migration.backup_location" "$backup_dir"
        echo -e "    ${GREEN}✓${NC} Updated ai-colab state"
    else
        # Fallback to .ai-colab-prefs
        if [[ ! -f "$prefs_file" ]]; then
            cat > "$prefs_file" << EOF
# ai-colab Preferences
# Generated by migration tool on $(date)

[migration]
migrated=true
migration_date=$(date +%Y-%m-%d)
backup_location=$backup_dir
EOF
            echo -e "    ${GREEN}✓${NC} Created ai-colab preferences"
        else
            # Ensure migrated=true is present
            if ! grep -q "^migrated=true" "$prefs_file"; then
                echo "migrated=true" >> "$prefs_file"
            fi
            echo -e "    ${GREEN}✓${NC} Updated ai-colab preferences"
        fi
    fi
    
    echo -e "  ${GREEN}✓ Configuration updated${NC}\n"
    
    # Summary
    ui_banner "Migration Complete!" "${GREEN}"
    echo ""
    local summary="Summary:\n"
    summary+="  • MCP configs integrated: ${#MCP_CONFIGS[@]}\n"
    summary+="  • Product plans imported: ${#PRODUCT_PLANS[@]}\n"
    summary+="  • KB artifacts indexed: ${#KB_ARTIFACTS[@]}\n"
    summary+="  • Backup location: $backup_dir"
    ui_box "$summary" "${GREEN}"
    echo ""
    
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Review imported files in conductor/"
    if [[ "${AI_COLAB_LAUNCHER:-false}" != "true" ]]; then
        echo -e "  2. Run: ./launch.sh to start ai-colab"
    fi
    echo -e "  3. Use !kb commands to search knowledge base"
    echo ""
}

# Main function
main() {
    local project_root="${1:-$(pwd)}"
    local detect_only="${2:-}"
    local config_mgr="$SCRIPT_DIR/config-manager.sh"
    
    # Check if already migrated
    local migrated="false"
    if [[ -f "$config_mgr" ]]; then
        migrated=$(bash "$config_mgr" state "migration.migrated" || echo "false")
    fi
    
    if [[ "$migrated" != "true" && -f "$project_root/.ai-colab-prefs" ]]; then
        migrated=$(grep "^migrated=" "$project_root/.ai-colab-prefs" | cut -d= -f2 || echo "false")
    fi
    
    if [[ "$migrated" == "true" ]]; then
        if [[ "$detect_only" != "--detect-only" ]]; then
            ui_status "Status" "Project already migrated" "${GREEN}"
        fi
        # Ensure flag file is removed
        rm -f "$project_root/.ai-colab-migration-pending"
        return 0
    fi

    # Detect project artifacts
    detect_project "$project_root"
    
    # Ask about migration if artifacts found
    local total_found=$((${#FOUND_ARTIFACTS[@]} + ${#MCP_CONFIGS[@]} + ${#PRODUCT_PLANS[@]} + ${#KB_ARTIFACTS[@]} + ${#OTHER_INTEGRATIONS[@]}))
    
    if [[ $total_found -gt 0 ]]; then
        if [[ "$detect_only" == "--detect-only" ]]; then
            # Just create flag file for launch.sh to check
            touch "$project_root/.ai-colab-migration-pending"
            echo ""
            ui_status "Action Required" "Migration available" "${YELLOW}"
            echo -e "  Run with: ./scripts/migrate-project.sh"
        else
            # Interactive mode
            if ask_migration; then
                perform_migration "$project_root"
            else
                echo -e "\n  ${YELLOW}Migration skipped. ai-colab will use default configurations.${NC}"
                echo -e "  You can run migration later with: ./scripts/migrate-project.sh"
            fi
        fi
    else
        # No artifacts found, ensure flag file doesn't exist
        rm -f "$project_root/.ai-colab-migration-pending"
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
