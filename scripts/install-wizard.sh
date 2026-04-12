#!/usr/bin/env bash
# ai-colab Installation Wizard
# Interactive terminal-based configuration wizard

set -euo pipefail

# Find script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Configuration Manager
CONFIG_MGR="$SCRIPT_DIR/config-manager.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# UI Components
# ============================================

draw_header() {
    clear
    ui_banner "ai-colab Installation Wizard" "${BLUE}"
    echo ""
}

draw_step() {
    local step_num="$1"
    local total_steps="$2"
    local title="$3"
    ui_title "Step $step_num of $total_steps: $title" "${CYAN}"
}

# ============================================
# API Key Detection & Management
# ============================================

# List of all supported API keys
API_KEYS_LIST=(
    "GEMINI_API_KEY"
    "ANTHROPIC_API_KEY"
    "OPENAI_API_KEY"
    "DEEPSEEK_API_KEY"
    "QWEN_API_KEY"
    "NVIDIA_API_KEY"
    "RUNPOD_API_KEY"
)

# Lookup function for API key descriptions (replacing API_KEY_META)
get_api_key_desc() {
    case "$1" in
        "GEMINI_API_KEY") echo "Google Gemini (Architect & Orchestrator)" ;;
        "ANTHROPIC_API_KEY") echo "Anthropic Claude (Generalist & Documentation)" ;;
        "OPENAI_API_KEY") echo "OpenAI (Codex)" ;;
        "DEEPSEEK_API_KEY") echo "DeepSeek (Logic & Optimization)" ;;
        "QWEN_API_KEY") echo "Alibaba Qwen (Assembly & Hardware)" ;;
        "NVIDIA_API_KEY") echo "NVIDIA NIM (nemoclaw Architect)" ;;
        "RUNPOD_API_KEY") echo "RunPod (Cloud GPU Deployment)" ;;
        *) echo "Unknown API Key" ;;
    esac
}

# Lookup function for authentication methods (replacing AUTH_METHODS)
# Values: "api_key", "web_auth", "both"
get_auth_method() {
    case "$1" in
        "GEMINI") echo "both" ;;
        "QWEN") echo "both" ;;
        *) echo "api_key" ;;
    esac
}

# Detect an API key from environment and config files
# Returns the key value if found, empty otherwise
detect_api_key() {
    local key_name="$1"

    # Check environment variable
    local env_value=$(eval echo "\${$key_name:-}")
    if [[ -n "$env_value" ]]; then
        echo "$env_value"
        return 0
    fi

    # Check .env file in project root
    local env_file="$PROJECT_ROOT/.env"
    if [[ -f "$env_file" ]]; then
        local file_value
        file_value=$(grep "^${key_name}=" "$env_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//;s/^'"'"'//;s/'"'"'$//')
        if [[ -n "$file_value" ]]; then
            echo "$file_value"
            return 0
        fi
    fi

    # Check config-manager stored value
    local config_value
    config_value=$(bash "$CONFIG_MGR" get "api_keys.$key_name" "" 2>/dev/null || echo "")
    if [[ -n "$config_value" ]]; then
        echo "$config_value"
        return 0
    fi

    # Check common config locations
    local config_file="$PROJECT_ROOT/config/config.toml"
    if [[ -f "$config_file" ]]; then
        local toml_value
        toml_value=$(grep "${key_name}" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
        if [[ -n "$toml_value" ]]; then
            echo "$toml_value"
            return 0
        fi
    fi

    return 1
}

# Detect if web auth credentials exist for an agent
detect_web_auth() {
    local agent_name="$1"

    case "$agent_name" in
        GEMINI)
            # Check for Google application credentials or OAuth tokens
            if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]] && [[ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
                echo "GOOGLE_APPLICATION_CREDENTIALS"
                return 0
            fi
            # Check default Google auth location
            if [[ -f "$HOME/.config/gcloud/application_default_credentials.json" ]]; then
                echo "gcloud_adc"
                return 0
            fi
            # Check for Gemini CLI auth tokens
            if [[ -d "$HOME/.gemini" ]] || [[ -f "$HOME/.config/gemini/credentials.json" ]]; then
                echo "gemini_cli_auth"
                return 0
            fi
            ;;
        QWEN)
            # Check for DashScope or Alibaba Cloud credentials
            if [[ -n "${DASHSCOPE_API_KEY:-}" ]]; then
                echo "DASHSCOPE_API_KEY"
                return 0
            fi
            # Check for aliyun CLI credentials
            if [[ -f "$HOME/.aliyun/config.json" ]] || [[ -n "${ALIBABACLOUD_ACCESS_KEY_ID:-}" ]]; then
                echo "aliyun_cli"
                return 0
            fi
            # Check for Qwen CLI auth
            if [[ -d "$HOME/.qwen" ]] || [[ -f "$HOME/.config/qwen/credentials.json" ]]; then
                echo "qwen_cli_auth"
                return 0
            fi
            ;;
    esac

    return 1
}

# Mask a key value for display (show first/last 4 chars)
mask_key() {
    local key="$1"
    local len=${#key}

    if [[ $len -le 8 ]]; then
        echo "****"
    else
        echo "${key:0:4}...${key:$((len-4)):4}"
    fi
}

# Detect all API keys and store in individual variables
detect_all_api_keys() {
    local key_name
    for key_name in "${API_KEYS_LIST[@]}"; do
        local detected_value
        detected_value=$(detect_api_key "$key_name" 2>/dev/null || echo "")
        # Use eval to set dynamic variable name
        eval "DETECTED_$key_name=\"$detected_value\""
    done
}

# Prompt user about detected API key
# Returns 0 if user wants to keep existing, 1 if they want to enter new, 2 if skip
prompt_existing_api_key() {
    local key_name="$1"
    local key_description="$2"
    local existing_value="$3"

    echo -e ""
    echo -e "  ${CYAN}Detected existing ${key_description}:${NC}"
    echo -e "    Key: ${key_name}"
    echo -e "    Value: $(mask_key "$existing_value")"
    echo ""

    while true; do
        echo -e "  ${CYAN}Options:${NC}"
        echo -e "    1) Use existing key"
        echo -e "    2) Enter new key"
        echo -e "    3) Skip (leave empty)"
        echo ""
        read -p "  Choice [1-3]: " choice

        case "$choice" in
            1|"")
                # Keep existing
                echo -e "  ${GREEN}✓${NC} Using existing key for ${key_name}"
                return 0
                ;;
            2)
                # Enter new
                echo -e "  ${YELLOW}Enter new key for ${key_name}:${NC}"
                return 1
                ;;
            3)
                # Skip
                echo -e "  ${YELLOW}○${NC} Skipping ${key_name}"
                return 2
                ;;
            *)
                echo -e "  ${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                ;;
        esac
    done
}

# Prompt user for web authentication
# Returns 0 if user wants to use web auth, 1 if they want to skip
prompt_web_auth() {
    local agent_name="$1"
    local auth_type="$2"

    echo -e ""
    echo -e "  ${CYAN}Web Authentication for ${agent_name}${NC}"
    echo -e "  ${BLUE}This agent supports browser-based OAuth.${NC}"

    if [[ "$auth_type" == "existing" ]]; then
        echo -e ""
        echo -e "  ${GREEN}✓${NC} Existing web auth credentials detected."
        echo -e "  ${BLUE}You will be prompted to authenticate in your browser when the agent starts.${NC}"
        return 0
    fi

    echo -e ""
    echo -e "  ${CYAN}Options:${NC}"
    echo -e "    1) Use web authentication (OAuth)"
    echo -e "    2) Use API key instead"
    echo -e "    3) Skip for now"
    echo ""
    read -p "  Choice [1-3]: " choice

    case "$choice" in
        1|"")
            echo -e "  ${GREEN}✓${NC} Web authentication selected for ${agent_name}"
            echo -e "  ${BLUE}You'll be prompted to authenticate in your browser on first use.${NC}"
            return 0
            ;;
        2)
            echo -e "  ${YELLOW}○${NC} Will use API key for ${agent_name}"
            return 1
            ;;
        3)
            echo -e "  ${YELLOW}○${NC} Skipping ${agent_name} for now"
            return 2
            ;;
        *)
            echo -e "  ${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
            ;;
    esac
}

# Collect all API keys from user
collect_api_keys() {
    local key_name

    # Detect existing keys
    detect_all_api_keys

    # Count detected keys
    local detected_count=0
    for key_name in "${API_KEYS_LIST[@]}"; do
        local det_val=$(eval echo "\$DETECTED_$key_name")
        if [[ -n "$det_val" ]]; then
            ((detected_count++))
        fi
    done

    if [[ $detected_count -gt 0 ]]; then
        draw_header
        draw_step 4 5 "API Key Configuration"
        echo ""
        echo -e "  ${GREEN}Detected $detected_count existing API key(s) in your environment.${NC}"
        echo -e "  ${BLUE}Would you like to review and configure them?${NC}"
        echo ""
    fi

    for key_name in "${API_KEYS_LIST[@]}"; do
        local description=$(get_api_key_desc "$key_name")
        local existing_value=$(eval echo "\$DETECTED_$key_name")

        if [[ -n "$existing_value" ]]; then
            # Key detected — ask user what to do
            prompt_existing_api_key "$key_name" "$description" "$existing_value"
            local user_choice=$?

            if [[ $user_choice -eq 0 ]]; then
                # Keep existing
                eval "COLLECTED_$key_name=\"$existing_value\""
                continue
            elif [[ $user_choice -eq 2 ]]; then
                # Skip
                eval "COLLECTED_$key_name=\"\""
                continue
            fi
            # If choice 1 (enter new), fall through to prompt
        fi

        # Check if this agent supports web authentication
        local agent_base="${key_name%%_API_KEY}"
        local auth_method=$(get_auth_method "$agent_base")

        if [[ "$auth_method" == "both" ]]; then
            # Check for existing web auth
            local web_auth
            web_auth=$(detect_web_auth "$agent_base" 2>/dev/null || echo "")

            if [[ -n "$web_auth" ]]; then
                # Existing web auth detected
                prompt_web_auth "$agent_base" "existing"
                local web_choice=$?

                if [[ $web_choice -eq 0 ]]; then
                    # Use existing web auth
                    eval "COLLECTED_$key_name=\"\""
                    eval "AUTH_STATUS_$agent_base=\"existing\""
                    continue
                fi
            else
                # Offer web auth option
                prompt_web_auth "$agent_base" "new"
                local web_choice=$?

                if [[ $web_choice -eq 0 ]]; then
                    # Use web auth
                    eval "COLLECTED_$key_name=\"\""
                    eval "AUTH_STATUS_$agent_base=\"new\""
                    continue
                fi
            fi
        fi

        # Prompt for new key
        echo ""
        echo -e "  ${CYAN}${description}${NC}"
        echo -e "  Environment variable: ${key_name}"
        echo -e "  ${YELLOW}(Leave empty to skip)${NC}"
        read -p "  Enter ${key_name}: " key_value

        eval "COLLECTED_$key_name=\"${key_value:-}\""

        if [[ -n "$key_value" ]]; then
            echo -e "  ${GREEN}✓${NC} Configured ${key_name}"
        else
            echo -e "  ${YELLOW}○${NC} Skipped ${key_name}"
        fi
    done
}

# Save collected API keys to config and environment
save_api_keys() {
    local key_name

    for key_name in "${API_KEYS_LIST[@]}"; do
        local key_value=$(eval echo "\$COLLECTED_$key_name")

        if [[ -n "$key_value" ]]; then
            # Store via config-manager
            bash "$CONFIG_MGR" set "api_keys.$key_name" "$key_value" >/dev/null 2>&1 || true

            # Add to .env file
            local env_file="$PROJECT_ROOT/.env"
            touch "$env_file"
            # Remove existing entry if present
            sed -i.bak "/^${key_name}=/d" "$env_file" 2>/dev/null || true
            rm -f "${env_file}.bak" 2>/dev/null || true
            echo "${key_name}=${key_value}" >> "$env_file"

            # Export for current session
            export "$key_name=$key_value"
        fi
    done

    # Save web auth preferences
    local agents=("GEMINI" "QWEN")
    for agent_name in "${agents[@]}"; do
        local auth_status=$(eval echo "\$AUTH_STATUS_$agent_name")
        if [[ -n "$auth_status" ]]; then
            local agent_lower=$(echo "$agent_name" | tr '[:upper:]' '[:lower:]')
            bash "$CONFIG_MGR" set "auth.$agent_lower" "$auth_status" >/dev/null 2>&1 || true
        fi
    done
}

# ============================================
# Helper Functions
# ============================================

prompt_choice() {
    local prompt="$1"
    local options=("${@:2}")
    local choice=""
    
    echo -e "  ${BOLD}$prompt${NC}"
    for i in "${!options[@]}"; do
        echo -e "    ${CYAN}$((i+1)))${NC} ${options[$i]}"
    done
    echo ""
    
    while true; do
        read -p "  Choice [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            return $((choice - 1))
        fi
        echo -e "  ${RED}Invalid choice. Please try again.${NC}"
    done
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local choice=""
    
    local yn_prompt="[Y/n]"
    [[ "$default" == "n" ]] && yn_prompt="[y/N]"
    
    while true; do
        read -p "$prompt $yn_prompt: " choice
        choice="${choice,,}" # Lowercase
        
        if [[ -z "$choice" ]]; then
            choice="$default"
        fi
        
        if [[ "$choice" == "y" ]]; then
            return 0
        elif [[ "$choice" == "n" ]]; then
            return 1
        fi
        echo -e "${RED}Please enter 'y' or 'n'.${NC}"
    done
}

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local var_name="$3"
    local input=""
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [default: $default]: " input
        input="${input:-$default}"
    else
        read -p "$prompt: " input
    fi
    
    eval "$var_name=\"$input\""
}

# ============================================
# Wizard Steps
# ============================================

step_installation_type() {
    draw_step 1 5 "Installation Type"
    local options=(
        "Minimal (Core only - Gemini & Qwen)"
        "Standard (Recommended - Dashboard + Conductor)"
        "Full (All agents + Active Modules + Web UI)"
    )
    
    prompt_choice "Select installation profile:" "${options[@]}"
    case $? in
        0) PROFILE="minimal" ;;
        1) PROFILE="standard" ;;
        2) PROFILE="full" ;;
    esac
    
    echo -e "\n${GREEN}Selected Profile: $PROFILE${NC}"
    sleep 1
}

step_llm_config() {
    draw_step 2 5 "LLM Configuration"
    echo -e "Enable the LLMs you want to use in the dashboard.\n"
    
    # Defaults based on profile
    local enable_gemini=true
    local enable_qwen=true
    local enable_deepseek=false
    local enable_claude=false
    local enable_vllm=false
    
    if [[ "$PROFILE" == "full" ]]; then
        enable_deepseek=true
        enable_claude=true
    fi
    
    prompt_yes_no "Enable Gemini (gemini-3.0)?" "$([[ $enable_gemini == true ]] && echo y || echo n)" && LLM_GEMINI=true || LLM_GEMINI=false
    prompt_yes_no "Enable Qwen (qwen3-next)?" "$([[ $enable_qwen == true ]] && echo y || echo n)" && LLM_QWEN=true || LLM_QWEN=false
    prompt_yes_no "Enable DeepSeek (deepseek-v3)?" "$([[ $enable_deepseek == true ]] && echo y || echo n)" && LLM_DEEPSEEK=true || LLM_DEEPSEEK=false
    prompt_yes_no "Enable Claude (claude-3-opus)?" "$([[ $enable_claude == true ]] && echo y || echo n)" && LLM_CLAUDE=true || LLM_CLAUDE=false
    prompt_yes_no "Enable vLLM (local/remote server)?" "$([[ $enable_vllm == true ]] && echo y || echo n)" && LLM_VLLM=true || LLM_VLLM=false
    
    if [[ "$LLM_VLLM" == "true" ]]; then
        prompt_input "vLLM Host IP" "192.168.0.193" VLLM_HOST
    fi
}

step_compute_backend() {
    draw_step 3 5 "Compute Backend"
    echo -e "Select where high-power agents should run.\n"
    
    local options=(
        "Local (Run everything on this machine)"
        "NVIDIA NIM API (Cloud compute for NeMo/nemoclaw)"
        "RunPod (Cloud GPU instances)"
    )
    
    prompt_choice "Select backend:" "${options[@]}"
    case $? in
        0) BACKEND="local" ;;
        1) BACKEND="nvidia" ;;
        2) BACKEND="runpod" ;;
    esac
    
    echo -e "\n${GREEN}Selected Backend: $BACKEND${NC}"
    sleep 1
}

step_module_selection() {
    draw_step 4 5 "Module Selection"
    echo -e "Select specialized project modules.\n"
    
    prompt_yes_no "Enable Atari-8bit (Atari LX development)?" "y" && MOD_ATARI=true || MOD_ATARI=false
    prompt_yes_no "Enable Google Chat Bridge?" "n" && MOD_CHAT_BRIDGE=true || MOD_CHAT_BRIDGE=false
}

step_review_and_apply() {
    draw_step 5 5 "Review & Apply"
    
    local summary=""
    summary+="Profile: $PROFILE\n"
    summary+="Backend: $BACKEND\n"
    summary+="\nLLMs:\n"
    summary+="  Gemini:    $([[ $LLM_GEMINI == true ]] && echo -e "${GREEN}Enabled${NC}" || echo -e "${RED}Disabled${NC}")\n"
    summary+="  Qwen:      $([[ $LLM_QWEN == true ]] && echo -e "${GREEN}Enabled${NC}" || echo -e "${RED}Disabled${NC}")\n"
    summary+="  DeepSeek:  $([[ $LLM_DEEPSEEK == true ]] && echo -e "${GREEN}Enabled${NC}" || echo -e "${RED}Disabled${NC}")\n"
    summary+="  Claude:    $([[ $LLM_CLAUDE == true ]] && echo -e "${GREEN}Enabled${NC}" || echo -e "${RED}Disabled${NC}")\n"
    summary+="  vLLM:      $([[ $LLM_VLLM == true ]] && echo -e "${GREEN}Enabled (Host: $VLLM_HOST)${NC}" || echo -e "${RED}Disabled${NC}")\n"
    summary+="\nModules:\n"
    summary+="  Atari-8bit: $([[ $MOD_ATARI == true ]] && echo -e "${GREEN}Enabled${NC}" || echo -e "${RED}Disabled${NC}")\n"
    summary+="  Chat Bridge: $([[ $MOD_CHAT_BRIDGE == true ]] && echo -e "${GREEN}Enabled${NC}" || echo -e "${RED}Disabled${NC}")"
    
    ui_box "$summary" "${BLUE}"
    echo ""
    
    if prompt_yes_no "Apply this configuration?" "y"; then
        apply_config
    else
        echo -e "  ${YELLOW}Installation cancelled. No changes were made.${NC}"
        exit 0
    fi
}

# ============================================
# Core Logic
# ============================================

apply_config() {
    echo -e "\n${BLUE}Applying configuration...${NC}"
    
    # Initialize config manager
    bash "$CONFIG_MGR" init
    
    # Set basic info
    bash "$CONFIG_MGR" set version "1.0.0"
    bash "$CONFIG_MGR" set installation.status "complete"
    bash "$CONFIG_MGR" set installation.pathway "cli"
    bash "$CONFIG_MGR" state-set installation.status "complete"
    bash "$CONFIG_MGR" state-set installation.pathway "cli"
    
    # Set profile
    bash "$CONFIG_MGR" set profile "$PROFILE"
    
    # Set LLMs
    # Note: The current config-mgr set command is simple, we might need a better way for arrays
    # For now, we use a flattened structure or simple keys
    bash "$CONFIG_MGR" set llm.gemini.enabled "$LLM_GEMINI"
    bash "$CONFIG_MGR" set llm.qwen.enabled "$LLM_QWEN"
    bash "$CONFIG_MGR" set llm.deepseek.enabled "$LLM_DEEPSEEK"
    bash "$CONFIG_MGR" set llm.claude.enabled "$LLM_CLAUDE"
    bash "$CONFIG_MGR" set llm.vllm.enabled "$LLM_VLLM"
    if [[ "$LLM_VLLM" == "true" ]]; then
        bash "$CONFIG_MGR" set llm.vllm.host "$VLLM_HOST"
    fi
    
    # Set Backend
    bash "$CONFIG_MGR" set compute.backend "$BACKEND"
    
    # Set Modules
    bash "$CONFIG_MGR" set module.atari.enabled "$MOD_ATARI"
    bash "$CONFIG_MGR" set module.chat_bridge.enabled "$MOD_CHAT_BRIDGE"
    
    # Save legacy prefs for backward compatibility
    save_legacy_prefs
    
    echo -e "\n${GREEN}✓ Configuration saved successfully!${NC}"
    echo -e "Next step: Run ${CYAN}./launch.sh${NC} to start your environment."
    echo ""
}

save_legacy_prefs() {
    local prefs_file="$PROJECT_ROOT/.ai-colab-prefs"
    echo "# ai-colab legacy preferences (generated by wizard)" > "$prefs_file"
    echo "PROFILE=$PROFILE" >> "$prefs_file"
    echo "LLM_GEMINI=$LLM_GEMINI" >> "$prefs_file"
    echo "LLM_QWEN=$LLM_QWEN" >> "$prefs_file"
    echo "LLM_DEEPSEEK=$LLM_DEEPSEEK" >> "$prefs_file"
    echo "LLM_CLAUDE=$LLM_CLAUDE" >> "$prefs_file"
    echo "LLM_VLLM=$LLM_VLLM" >> "$prefs_file"
    [[ "$LLM_VLLM" == "true" ]] && echo "VLLM_HOST=$VLLM_HOST" >> "$prefs_file"
    echo "COMPUTE_BACKEND=$BACKEND" >> "$prefs_file"
    echo "ENABLE_ATARI_LX=$MOD_ATARI" >> "$prefs_file"
    echo "ENABLE_CHAT_BRIDGE=$MOD_CHAT_BRIDGE" >> "$prefs_file"
}

# ============================================
# Main
# ============================================

main() {
    local mode="install"
    if [[ "${1:-}" == "--reconfigure" ]]; then
        mode="reconfigure"
    fi
    
    draw_header
    
    if [[ "$mode" == "install" ]]; then
        step_installation_type
        step_llm_config
        step_compute_backend
        step_module_selection
        step_review_and_apply
    else
        echo -e "${BLUE}Reconfiguration Mode${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        while true; do
            echo "Select section to reconfigure:"
            echo "  1) LLMs"
            echo "  2) Compute Backend"
            echo "  3) Modules"
            echo "  4) Review & Apply"
            echo "  5) Exit"
            echo ""
            read -p "Choice [1-5]: " choice
            
            case "$choice" in
                1) step_llm_config ;;
                2) step_compute_backend ;;
                3) step_module_selection ;;
                4) step_review_and_apply; break ;;
                5) exit 0 ;;
                *) echo -e "${RED}Invalid choice${NC}" ;;
            esac
            draw_header
            echo -e "${BLUE}Reconfiguration Mode${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
        done
    fi
}

main "$@"
