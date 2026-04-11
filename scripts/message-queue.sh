#!/usr/bin/env bash
# ai-colab Message Queue Layer
# Lightweight SQLite-based message queue with delivery guarantees
# Provides: persistent messages, offline queuing, retry logic, dead-letter queue

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Message queue database (allow override for testing)
MQ_DB_DIR="${MQ_DB_DIR:-$PROJECT_ROOT/.ai-colab/mq}"
MQ_DB="${MQ_DB:-$MQ_DB_DIR/messages.db}"

# Configuration
MQ_DEFAULT_MAX_RETRIES=3
MQ_DEFAULT_TTL=86400  # 24 hours
MQ_RETRY_DELAYS=(10 30 60 120)  # Exponential backoff in seconds

# Colors (optional, for standalone use)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================
# Initialization
# ============================================================

mq_init() {
    mkdir -p "$MQ_DB_DIR"

    sqlite3 "$MQ_DB" << 'SQL'
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    target TEXT NOT NULL,
    sender TEXT NOT NULL,
    content TEXT NOT NULL,
    intent TEXT DEFAULT 'inform',
    thread TEXT DEFAULT 'default',
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP,
    acked_at TIMESTAMP,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    ttl_seconds INTEGER DEFAULT 86400,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_messages_status ON messages(status, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_target ON messages(target, status);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at);

-- Dead letter queue view
CREATE VIEW IF NOT EXISTS dead_letter_queue AS
SELECT * FROM messages
WHERE status = 'failed' AND retry_count >= max_retries;

-- Pending messages view
CREATE VIEW IF NOT EXISTS pending_messages AS
SELECT * FROM messages
WHERE status = 'pending'
  AND (retry_count < max_retries)
  AND (strftime('%s', 'now') - strftime('%s', created_at)) < ttl_seconds;
SQL
}

# ============================================================
# Core Operations
# ============================================================

# Generate a unique message ID
mq_generate_id() {
    echo "msg_$(date +%s%N)_$$_$RANDOM"
}

# Send a message (queues if agent offline, delivers if online)
mq_send() {
    local target="$1"
    local content="$2"
    local sender="${3:-conductor}"
    local intent="${4:-inform}"
    local thread="${5:-default}"
    local max_retries="${6:-$MQ_DEFAULT_MAX_RETRIES}"
    local ttl="${7:-$MQ_DEFAULT_TTL}"

    mq_init

    local msg_id
    msg_id=$(mq_generate_id)

    # Insert message into queue
    sqlite3 "$MQ_DB" << SQL
INSERT INTO messages (id, target, sender, content, intent, thread, max_retries, ttl_seconds)
VALUES ('$msg_id', '$target', '$sender', '$(echo "$content" | sed "s/'/''/g")', '$intent', '$thread', $max_retries, $ttl);
SQL

    # Attempt immediate delivery
    if mq_is_agent_online "$target"; then
        mq_deliver_message "$msg_id"
    else
        # Agent offline, message stays in pending state
        echo "$msg_id"
    fi
}

# Check if an agent is online (registered with hcom)
mq_is_agent_online() {
    local agent_name="$1"

    if ! command -v hcom >/dev/null 2>&1; then
        return 1
    fi

    # Check if agent appears in hcom list
    if hcom list 2>/dev/null | grep -qi "$agent_name"; then
        return 0
    fi

    return 1
}

# Deliver a specific message to the target agent
mq_deliver_message() {
    local msg_id="$1"

    # Get message details
    local msg_data
    msg_data=$(sqlite3 -separator '|' "$MQ_DB" << SQL
SELECT target, content, sender, intent, thread FROM messages WHERE id = '$msg_id' AND status = 'pending';
SQL
)

    if [[ -z "$msg_data" ]]; then
        return 1
    fi

    local target content sender intent thread
    IFS='|' read -r target content sender intent thread <<< "$msg_data"

    # Send via hcom
    if hcom send "@$target" --name "$sender" --intent "$intent" --thread "$thread" -- "$content" 2>/dev/null; then
        # Mark as delivered
        sqlite3 "$MQ_DB" << SQL
UPDATE messages SET status = 'delivered', delivered_at = CURRENT_TIMESTAMP WHERE id = '$msg_id';
SQL
        return 0
    else
        # Delivery failed, increment retry counter
        local retry_count
        retry_count=$(sqlite3 "$MQ_DB" "SELECT retry_count FROM messages WHERE id = '$msg_id';")
        retry_count=$((retry_count + 1))

        local max_retries
        max_retries=$(sqlite3 "$MQ_DB" "SELECT max_retries FROM messages WHERE id = '$msg_id';")

        if [[ $retry_count -ge $max_retries ]]; then
            # Move to dead letter queue
            sqlite3 "$MQ_DB" << SQL
UPDATE messages SET status = 'failed', retry_count = $retry_count, error_message = 'Max retries exceeded' WHERE id = '$msg_id';
SQL
        else
            # Schedule retry
            sqlite3 "$MQ_DB" << SQL
UPDATE messages SET retry_count = $retry_count, status = 'pending' WHERE id = '$msg_id';
SQL
        fi
        return 1
    fi
}

# Acknowledge message receipt
mq_ack() {
    local msg_id="$1"

    sqlite3 "$MQ_DB" << SQL
UPDATE messages SET status = 'acked', acked_at = CURRENT_TIMESTAMP WHERE id = '$msg_id' AND status IN ('delivered', 'pending');
SQL
}

# Check pending messages for an agent
mq_pending() {
    local agent_name="$1"

    sqlite3 "$MQ_DB" << SQL
SELECT COUNT(*) FROM messages
WHERE target = '$agent_name' AND status = 'pending'
  AND retry_count < max_retries
  AND (strftime('%s', 'now') - strftime('%s', created_at)) < ttl_seconds;
SQL
}

# Get pending messages for an agent
mq_get_pending() {
    local agent_name="$1"

    sqlite3 -separator '|' "$MQ_DB" << SQL
SELECT id, content, sender, intent, thread FROM messages
WHERE target = '$agent_name' AND status = 'pending'
  AND retry_count < max_retries
  AND (strftime('%s', 'now') - strftime('%s', created_at)) < ttl_seconds
ORDER BY created_at ASC;
SQL
}

# ============================================================
# Retry Logic
# ============================================================

# Process pending deliveries (called by conductor main loop)
mq_process_pending() {
    mq_init

    # Get all pending messages that are ready for retry
    local messages
    messages=$(sqlite3 -separator '|' "$MQ_DB" << 'SQL'
SELECT id FROM pending_messages ORDER BY created_at ASC LIMIT 50;
SQL
)

    if [[ -z "$messages" ]]; then
        return 0
    fi

    local delivered=0
    local failed=0

    while IFS= read -r msg_id; do
        if [[ -n "$msg_id" ]]; then
            if mq_deliver_message "$msg_id"; then
                ((delivered++))
            else
                ((failed++))
            fi
        fi
    done <<< "$messages"

    echo "$delivered delivered, $failed failed"
}

# Retry a specific message with exponential backoff
mq_retry() {
    local msg_id="$1"

    # Get retry count
    local retry_count
    retry_count=$(sqlite3 "$MQ_DB" "SELECT retry_count FROM messages WHERE id = '$msg_id';")

    # Check if enough time has passed since last attempt
    local last_attempt
    last_attempt=$(sqlite3 "$MQ_DB" "SELECT strftime('%s', delivered_at) FROM messages WHERE id = '$msg_id' AND delivered_at IS NOT NULL;")

    if [[ -n "$last_attempt" ]]; then
        local now
        now=$(date +%s)
        local elapsed=$((now - last_attempt))
        local wait_time=${MQ_RETRY_DELAYS[$retry_count]:-120}

        if [[ $elapsed -lt $wait_time ]]; then
            return 0  # Too soon, skip retry
        fi
    fi

    mq_deliver_message "$msg_id"
}

# ============================================================
# Dead Letter Queue
# ============================================================

# Get dead letter queue contents
mq_dead_letter() {
    sqlite3 -header -column "$MQ_DB" << 'SQL'
SELECT id, target, content, retry_count, error_message, created_at
FROM dead_letter_queue
ORDER BY created_at DESC;
SQL
}

# Retry a dead-lettered message
mq_retry_dead_letter() {
    local msg_id="$1"

    sqlite3 "$MQ_DB" << SQL
UPDATE messages SET status = 'pending', retry_count = 0, error_message = NULL, delivered_at = NULL WHERE id = '$msg_id';
SQL
}

# Clear dead letter queue
mq_clear_dead_letter() {
    sqlite3 "$MQ_DB" "DELETE FROM messages WHERE status = 'failed';"
}

# ============================================================
# Status & Monitoring
# ============================================================

# Get message queue status
mq_status() {
    local pending delivered acked failed total

    pending=$(sqlite3 "$MQ_DB" "SELECT COUNT(*) FROM messages WHERE status = 'pending';")
    delivered=$(sqlite3 "$MQ_DB" "SELECT COUNT(*) FROM messages WHERE status = 'delivered';")
    acked=$(sqlite3 "$MQ_DB" "SELECT COUNT(*) FROM messages WHERE status = 'acked';")
    failed=$(sqlite3 "$MQ_DB" "SELECT COUNT(*) FROM messages WHERE status = 'failed';")
    total=$((pending + delivered + acked + failed))

    echo "Message Queue Status:"
    echo "  Total: $total"
    echo "  Pending: $pending"
    echo "  Delivered: $delivered"
    echo "  Acknowledged: $acked"
    echo "  Failed: $failed"
    echo "  Dead Letter: $(sqlite3 "$MQ_DB" "SELECT COUNT(*) FROM dead_letter_queue;")"
}

# Get queue depth for a specific agent
mq_queue_depth() {
    local agent_name="$1"
    sqlite3 "$MQ_DB" "SELECT COUNT(*) FROM messages WHERE target = '$agent_name' AND status = 'pending';"
}

# Clean up expired messages
mq_cleanup() {
    sqlite3 "$MQ_DB" << 'SQL'
DELETE FROM messages
WHERE status = 'pending'
  AND (strftime('%s', 'now') - strftime('%s', created_at)) > ttl_seconds;
SQL
}

# Purge old acknowledged messages (older than 7 days)
mq_purge_old() {
    sqlite3 "$MQ_DB" << 'SQL'
DELETE FROM messages
WHERE status = 'acked'
  AND acked_at < datetime('now', '-7 days');
SQL
}

# ============================================================
# CLI Interface (for testing and manual use)
# ============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        send)
            target="${2:-}"
            content="${3:-}"
            sender="${4:-conductor}"
            intent="${5:-inform}"
            thread="${6:-default}"
            max_retries="${7:-$MQ_DEFAULT_MAX_RETRIES}"
            ttl="${8:-$MQ_DEFAULT_TTL}"
            mq_send "$target" "$content" "$sender" "$intent" "$thread" "$max_retries" "$ttl"
            ;;
        ack)
            mq_ack "${2:-}"
            ;;
        pending)
            mq_pending "${2:-}"
            ;;
        status)
            mq_status
            ;;
        dead-letter)
            mq_dead_letter
            ;;
        process)
            mq_process_pending
            ;;
        cleanup)
            mq_cleanup
            mq_purge_old
            echo "Cleanup complete"
            ;;
        init)
            mq_init
            echo "Message queue initialized"
            ;;
        queue-depth)
            mq_queue_depth "${2:-}"
            ;;
        get-pending)
            mq_get_pending "${2:-}"
            ;;
        *)
            echo "Usage: $0 {send|ack|pending|status|dead-letter|process|cleanup|init|queue-depth|get-pending} [args...]"
            echo ""
            echo "Commands:"
            echo "  send <target> <content> [sender] [intent] [thread] [max_retries] [ttl]"
            echo "  ack <message_id>"
            echo "  pending <agent_name>"
            echo "  status"
            echo "  dead-letter"
            echo "  process"
            echo "  cleanup"
            echo "  init"
            echo "  queue-depth <agent_name>"
            echo "  get-pending <agent_name>"
            exit 1
            ;;
    esac
fi
