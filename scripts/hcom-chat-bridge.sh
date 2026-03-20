#!/usr/bin/env bash
# hcom to Google Chat Messenger Bridge
# Forwards critical hcom events to a Google Chat space for remote monitoring.

set -euo pipefail

# Configuration
SPACE_NAME="Atari-LX Multi-Agent"
HCOM_NAME="messenger_bridge"

# Register with hcom
hcom start --as "$HCOM_NAME" > /dev/null 2>&1 || true

echo "Starting hcom-chat-bridge..."
echo "Monitoring events and forwarding to Google Chat space: $SPACE_NAME"

# Function to forward message via headless gemini
forward_to_chat() {
    local text="$1"
    # We use a prompt that specifically tells the agent to use the chat skill
    # We use --yolo to avoid confirmation prompts in background
    gemini -y -p "Activate the 'google-chat' skill. Find the space named '$SPACE_NAME'. Send the following update: $text" > /dev/null 2>&1 || true
}

# Initial greeting
forward_to_chat "*Bridge Online*: Remote monitoring enabled for Atari-LX team."

# Event monitoring loop
# We listen for:
# - Intent=inform/request (messages)
# - Life_action=ready/stopped (agent status)
# - Custom threads: plan-sync, visual-debug
LAST_ID=$(hcom events --last 1 | grep -oP '"id":\K\d+' || echo "0")

while true; do
    # Wait for new events
    # We filter for messages or lifecycle events
    EVENT_JSON=$(hcom events --wait 60 --all --sql "id > $LAST_ID AND (type='message' OR type='life')" --last 1)
    
    if [[ -n "$EVENT_JSON" ]]; then
        # Parse event details
        ID=$(echo "$EVENT_JSON" | grep -oP '"id":\K\d+')
        TYPE=$(echo "$EVENT_JSON" | grep -oP '"type":"\K[^"]+')
        INSTANCE=$(echo "$EVENT_JSON" | grep -oP '"instance":"\K[^"]+')
        
        MSG=""
        if [[ "$TYPE" == "message" ]]; then
            FROM=$(echo "$EVENT_JSON" | grep -oP '"msg_from":"\K[^"]+')
            TEXT=$(echo "$EVENT_JSON" | grep -oP '"msg_text":"\K[^"]+')
            THREAD=$(echo "$EVENT_JSON" | grep -oP '"msg_thread":"\K[^"]+')
            MSG="*[$THREAD]* $FROM: $TEXT"
        elif [[ "$TYPE" == "life" ]]; then
            ACTION=$(echo "$EVENT_JSON" | grep -oP '"life_action":"\K[^"]+')
            MSG="*Lifecycle*: $INSTANCE is now $ACTION"
        fi

        if [[ -n "$MSG" ]]; then
            echo "[$(date +%T)] Forwarding: $MSG"
            forward_to_chat "$MSG"
        fi
        
        LAST_ID=$ID
    fi
done
