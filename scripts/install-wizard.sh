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
        "Full (All agents + Atari-LX + Web UI)"
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
