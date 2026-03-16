#!/usr/bin/env bash                                                          
# Qwen CLI Wrapper with hcom Integration                                     
# Launches Qwen CLI with hcom registration                                   
#                                                                            
# Usage: qwen-hcom.sh [qwen arguments]                                       
#                                                                            
                                                                             
set -euo pipefail                                                            
                                                                             
# Register with hcom to enable messaging                                     
AGENT_NAME="qwen-$$"                                                         
hcom start --as "$AGENT_NAME" > /dev/null 2>&1 || true                       
export HCOM_NAME="$AGENT_NAME"                                               

# Ensure relay is running if more than one agent is active
ACTIVE_AGENTS=$(hcom list --names | wc -w)
if [ "$ACTIVE_AGENTS" -gt 1 ]; then
    hcom relay daemon start > /dev/null 2>&1 || true
fi

# Pulse session to transition from "launching" to "listening"
hcom listen --name "$AGENT_NAME" --timeout 1 > /dev/null 2>&1 || true

# Default model (can be overridden)
DEFAULT_MODEL="qwen3-next-80b-a3b-instruct"

# Source the existing qwen.sh script logic - strip --name argument           
VALID_ARGS=()                                                                
MODEL_SET=false

while [[ $# -gt 0 ]]; do                                                     
    case "$1" in                                                             
        --name)                                                              
            # Skip --name and value (hcom handles this)                      
            shift 2                                                          
            ;;                                                               
        -m|--model)
            # Model specified, don't add default
            MODEL_SET=true
            VALID_ARGS+=("$1" "$2")
            shift 2
            ;;
        *)                                                                   
            # Keep all other arguments for qwen                              
            VALID_ARGS+=("$1")                                               
            shift                                                            
            ;;                                                               
    esac                                                                     
done

# Add default model if not specified
if [ "$MODEL_SET" = false ]; then
    VALID_ARGS+=("-m" "$DEFAULT_MODEL")
fi
# Launch qwen with valid arguments                                           
exec qwen "${VALID_ARGS[@]}"
