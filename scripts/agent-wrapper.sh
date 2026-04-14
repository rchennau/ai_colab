#!/usr/bin/env bash
# Generic Agent Wrapper v2.2
# Consolidates hcom registration, heartbeat, and atari_agent MCP
# Now includes automatic restart to maintain persistent presence

set -euo pipefail

# 0. Argument Parsing (must happen early)
TOOL="${1:-}"
shift || true

# Flags
RESTART_COUNT=0
MAX_RESTARTS=20
USE_DOCKER=false
DRY_RUN=false
VALID_ARGS=()
MODEL_SET=false
SYSTEM_PROMPT_SET=false
SYSTEM_PROMPT_CONTENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --docker)
            USE_DOCKER=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --name) 
            export HCOM_NAME="$2"
            shift 2 
            ;;
        -m|--model)
            MODEL_SET=true
            VALID_ARGS+=("--model" "$2")
            shift 2
            ;;
        --system-prompt)
            SYSTEM_PROMPT_SET=true
            SYSTEM_PROMPT_CONTENT="$2"
            shift 2
            ;;
        *)
            VALID_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$TOOL" ]]; then
    echo "Usage: $0 <tool_name> [args...]"
    exit 1
fi

# Find script directory and source utils
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/utils.sh"

# 1. Configuration & Role Determination
case "$TOOL" in
    gemini)
        DEFAULT_MODEL="gemini-3.0"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/gemini.md"
        if has_command gemini; then CMD="gemini";
        elif has_command gemini-cli; then CMD="gemini-cli";
        elif has_command npx; then CMD="npx -p @google/gemini-cli gemini"; fi
        ;;
    qwen)
        DEFAULT_MODEL="qwen3-next-80b-a3b-instruct"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/qwen.md"
        if has_command qwen; then CMD="qwen";
        elif has_command qwen-code; then CMD="qwen-code";
        elif has_command qwen-cli; then CMD="qwen-cli";
        elif has_command npx; then CMD="npx -p @qwen-code/qwen-code qwen"; fi
        ;;
    claude)
        DEFAULT_MODEL="claude-3-5-sonnet-20241022"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/claude.md"
        if has_command claude; then CMD="claude";
        elif has_command claude-code; then CMD="claude-code";
        elif has_command npx; then CMD="npx -p @anthropic-ai/claude-code claude"; fi
        ;;
    deepseek)
        DEFAULT_MODEL="deepseek-v3"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/deepseek.md"
        if has_command deepseek-cli; then CMD="deepseek-cli";
        elif has_command deepseek; then CMD="deepseek";
        elif has_command npx; then CMD="npx -p run-deepseek-cli deepseek"; fi
        ;;
    vllm)
        DEFAULT_MODEL="DeepSeek-Code"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/deepseek.md"
        if has_command elc; then CMD="elc";
        elif has_command npx; then CMD="npx -p easy-llm-cli elc"; fi
        ;;
    nemoclaw|nemo)
        DEFAULT_MODEL="nvidia/llama-3.3-nemotron-super-49b-v1.5"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/nemoclaw.md"
        CMD="python3 \"$SCRIPT_DIR/nemo-cli.py\""
        ;;
    *)
        DEFAULT_MODEL=""
        ROLE_PROMPT=""
        CMD="$TOOL"
        ;;
esac

if [[ "$USE_DOCKER" != "true" ]] && [ -z "$CMD" ] && [[ "$TOOL" != "nemo"* ]]; then
    echo "Error: Tool $TOOL not found. Please run ./install.sh"
    exit 1
fi

# 2. Project Detection
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || dirname "$SCRIPT_DIR")}"

# 2.1 Load Active Modules
# Load all active modules and their environment variables/MCPs
if [ -f "$SCRIPT_DIR/module-manager.sh" ]; then
    # Capture all active modules and load their environment
    while IFS= read -r module_id; do
        if [ -n "$module_id" ]; then
            # Parse and export module environment
            while IFS='=' read -r key value; do
                if [[ -n "$key" ]]; then
                    export "$key=$value"
                fi
            done < <(bash "$SCRIPT_DIR/module-manager.sh" env "$module_id" 2>/dev/null)
        fi
    done < <(bash "$SCRIPT_DIR/module-manager.sh" active 2>/dev/null)
fi

# 2.2 Core Dev MCP Configuration
CORE_DEV_MCP="$PROJECT_ROOT/mcp/core-dev/server.py"
if [ -f "$CORE_DEV_MCP" ]; then
    # Some tools might need explicit flags, for now we just ensure it's findable
    # If the LLM CLI supports direct MCP injection via env vars
    export CORE_DEV_MCP_PATH="$CORE_DEV_MCP"
fi
# 3. vLLM specific config for ELC
if [ "$TOOL" == "vllm" ]; then
    export USE_CUSTOM_LLM=true
    export CUSTOM_LLM_PROVIDER="openai"
    export CUSTOM_LLM_ENDPOINT="${VLLM_BASE_URL:-http://192.168.0.193:8000/v1}"
    export CUSTOM_LLM_API_KEY="${VLLM_API_KEY:-no-key}"
    [ "$MODEL_SET" = true ] && export CUSTOM_LLM_MODEL_NAME="$DEFAULT_MODEL"
fi

# 5. Model & Role Injection
# 5. Register with hcom and start heartbeat
if [[ "$DRY_RUN" != "true" ]]; then
    # This performs initial registration (uses HCOM_NAME if set by --name or environment)
    register_hcom "$TOOL"

    # Start heartbeat to keep agent status fresh in hcom TUI
    # This prevents the "exit:timeout" cycling issue
    start_heartbeat "$TOOL"

    # Start structured protocol status reporter (sends compact status every 60s)
    start_protocol_status "$TOOL"

    # Start conductor monitoring (P25.4) — agents detect conductor absence
    start_conductor_monitor "$TOOL"
fi

CLEANUP_FILES=()
cleanup() {
    # 1. Kill background heartbeat if it exists
    if [ -n "${HEARTBEAT_PID:-}" ]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
    fi

    # 2. Kill conductor monitor process if exists
    if [ -n "${CONDUCTOR_MONITOR_PID:-}" ]; then
        kill "$CONDUCTOR_MONITOR_PID" 2>/dev/null || true
    fi

    # 3. Fix for Bash 3.2 on macOS: handle empty arrays with set -u
    for f in ${CLEANUP_FILES[@]+"${CLEANUP_FILES[@]}"}; do rm -f "$f" 2>/dev/null || true; done

    # 4. Notify hcom of exit if possible
    if [ -n "${HCOM_NAME:-}" ]; then
        hcom stop --name "$HCOM_NAME" > /dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

# Set default model if not specified
if [ "$MODEL_SET" = false ] && [ -n "$DEFAULT_MODEL" ]; then
    VALID_ARGS+=("--model" "$DEFAULT_MODEL")
    [ "$TOOL" == "vllm" ] && export CUSTOM_LLM_MODEL_NAME="$DEFAULT_MODEL"
fi

# Inject Role-Specific System Prompt if not explicitly provided
if [ "$SYSTEM_PROMPT_SET" = false ] && [ -f "$ROLE_PROMPT" ]; then
    SYSTEM_PROMPT_CONTENT="$(cat "$ROLE_PROMPT")"
    SYSTEM_PROMPT_SET=true
fi

# Append Conductor context if provided (from launch.sh)
if [ -n "${QWEN_CONTEXT_FILE:-}" ] && [ -f "$QWEN_CONTEXT_FILE" ]; then
    SYSTEM_PROMPT_CONTENT="$SYSTEM_PROMPT_CONTENT

$(cat "$QWEN_CONTEXT_FILE")"
    SYSTEM_PROMPT_SET=true
elif [ -n "${GEMINI_CONTEXT_FILE:-}" ] && [ -f "$GEMINI_CONTEXT_FILE" ]; then
    SYSTEM_PROMPT_CONTENT="$SYSTEM_PROMPT_CONTENT

$(cat "$GEMINI_CONTEXT_FILE")"
    SYSTEM_PROMPT_SET=true
fi

# 6. Execution
# Apply system prompt via environment variable for tools that support it
if [ "$SYSTEM_PROMPT_SET" = true ]; then
    case "$TOOL" in
        gemini)
            # Use XXXXXX at the end for macOS compatibility
            TMP_SP=$(mktemp /tmp/gemini-sp-XXXXXX)
            mv "$TMP_SP" "$TMP_SP.md"
            TMP_SP="$TMP_SP.md"
            echo "$SYSTEM_PROMPT_CONTENT" > "$TMP_SP"
            export GEMINI_SYSTEM_MD="$TMP_SP"
            CLEANUP_FILES+=("$TMP_SP")
            ;;
        qwen)
            # Use XXXXXX at the end for macOS compatibility
            TMP_SP=$(mktemp /tmp/qwen-sp-XXXXXX)
            mv "$TMP_SP" "$TMP_SP.md"
            TMP_SP="$TMP_SP.md"
            echo "$SYSTEM_PROMPT_CONTENT" > "$TMP_SP"
            export QWEN_SYSTEM_MD="$TMP_SP"
            CLEANUP_FILES+=("$TMP_SP")
            ;;
        nemo|deepseek|claude|vllm)
            # These might support --system-prompt or we pass it through
            VALID_ARGS+=("--system-prompt" "$SYSTEM_PROMPT_CONTENT")
            ;;
        *)
            # Fallback
            VALID_ARGS+=("--system-prompt" "$SYSTEM_PROMPT_CONTENT")
            ;;
    esac
fi

# Run the command with automatic restart and real-time output parsing for progress
run_agent() {
    local agent_cmd=""
    
    # Safely escape all variables for use in eval
    local escaped_name=$(printf "%q" "$HCOM_NAME")
    local escaped_google_key=$(printf "%q" "${GOOGLE_API_KEY:-}")
    local escaped_anthropic_key=$(printf "%q" "${ANTHROPIC_API_KEY:-}")
    local escaped_args=()
    for arg in "${VALID_ARGS[@]}"; do
        escaped_args+=("$(printf "%q" "$arg")")
    done

    if [[ "$USE_DOCKER" == "true" ]]; then
        # Containerized Execution
        local image="aicolab/agent-${TOOL}:latest"
        print_info "Spawning containerized agent: $image"
        
        # Build Docker Run command with safely escaped variables
        agent_cmd="docker run --rm -i \
            -v $(printf "%q" "$PROJECT_ROOT"):/workspace \
            -v $(printf "%q" "$HOME")/.hcom:/root/.hcom \
            -e HCOM_NAME=$escaped_name \
            -e GOOGLE_API_KEY=$escaped_google_key \
            -e ANTHROPIC_API_KEY=$escaped_anthropic_key \
            --name $(printf "%q" "agent_${HCOM_NAME}_$(date +%s)") \
            $image ${escaped_args[*]}"
    else
        # Local Execution
        if [[ "$CMD" == *" "* ]]; then
            # CMD might already contain escaped parts (e.g. python3 "path"), use carefully
            agent_cmd="$CMD ${escaped_args[*]}"
        else
            agent_cmd="$(printf "%q" "$CMD") ${escaped_args[*]}"
        fi
    fi

    # Execute and parse output using process substitution to avoid subshell issues
    local line
    local exit_code=0
    
    while read -r line; do
        echo "$line"
        
        if [[ "$line" =~ PROGRESS:[[:space:]]*([0-9]+)%[[:space:]]*\|[[:space:]]*(.*) ]]; then
            pct="${BASH_REMATCH[1]}"
            step="${BASH_REMATCH[2]}"
            report_progress "$pct" "$step" 2>/dev/null || true
        fi
    done < <(eval "$agent_cmd" 2>&1; echo "EXIT_CODE:$?")

    # Extract exit code from the last line
    if [[ "$line" =~ EXIT_CODE:([0-9]+) ]]; then
        exit_code="${BASH_REMATCH[1]}"
    fi
    
    return $exit_code
}

# Main loop: restart agent if it exits with exponential backoff and circuit breaker
if [[ "$DRY_RUN" == "true" ]]; then
    agent_cmd=""
    if [[ "$USE_DOCKER" == "true" ]]; then
        image="aicolab/agent-${TOOL}:latest"
        agent_cmd="docker run --rm -i -v \"$PROJECT_ROOT\":/workspace -v \"$HOME/.hcom\":/root/.hcom -e HCOM_NAME=\"$HCOM_NAME\" -e GOOGLE_API_KEY=\"${GOOGLE_API_KEY:-}\" -e ANTHROPIC_API_KEY=\"${ANTHROPIC_API_KEY:-}\" --name \"agent_${HCOM_NAME}_dryrun\" $image $(printf " %q" "${VALID_ARGS[@]}")"
    else
        if [[ "$CMD" == *" "* ]]; then
            agent_cmd="$CMD $(printf " %q" "${VALID_ARGS[@]}")"
        else
            agent_cmd="$CMD $(printf " %q" "${VALID_ARGS[@]}")"
        fi
    fi
    echo "DRY_RUN_CMD: $agent_cmd"
    exit 0
fi

RESTART_COUNT=0
MAX_RESTARTS=20  # Higher limit since backoff increases

while true; do
    echo "[$(date '+%H:%M:%S')] Starting $TOOL agent (attempt $((RESTART_COUNT + 1)))..."
    start_ts=$(get_ms)

    # Run the agent command
    set +e  # Don't exit on error - we want to restart
    run_agent
    EXIT_CODE=$?
    set -e
    
    end_ts=$(get_ms)
    duration=$((end_ts - start_ts))

    echo "[$(date '+%H:%M:%S')] $TOOL agent exited with code $EXIT_CODE"
    
    # Log analytics
    local success="true"
    [[ $EXIT_CODE -ne 0 ]] && success="false"
    log_agent_analytics "session" "$duration" "$success" "Exit code: $EXIT_CODE, Tool: $TOOL"

    # Report exit to Blackboard for Fleet Autonomy
    if [ $EXIT_CODE -ne 0 ]; then
        report_health "crashed" "0" "$EXIT_CODE"

        # Record failure for circuit breaker (only for crashes, not normal exits)
        if [ -n "${HCOM_NAME:-}" ]; then
            agent_record_failure "$HCOM_NAME" 2>/dev/null || true
        fi
    else
        report_health "exited" "0" "0"
    fi

    # Check circuit breaker before retrying
    if [ -n "${HCOM_NAME:-}" ]; then
        if ! agent_should_retry "$HCOM_NAME" 2>/dev/null; then
            echo "[$(date '+%H:%M:%S')] Circuit breaker OPEN for $HCOM_NAME, stopping restarts"
            exit $EXIT_CODE
        fi
    fi

    # Check if we've exceeded max restarts
    if [ $RESTART_COUNT -ge $MAX_RESTARTS ]; then
        echo "[$(date '+%H:%M:%S')] Max restarts ($MAX_RESTARTS) reached, exiting"
        exit $EXIT_CODE
    fi

    # Calculate backoff delay using exponential backoff
    local backoff_delay
    backoff_delay=$(agent_calc_backoff $RESTART_COUNT 2>/dev/null || echo "10")

    # Increment restart counter and wait before restarting
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "[$(date '+%H:%M:%S')] Restarting in ${backoff_delay}s (attempt $RESTART_COUNT/$MAX_RESTARTS)... (Ctrl+C to stop)"
    sleep "$backoff_delay"
done
