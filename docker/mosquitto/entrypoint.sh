#!/bin/sh
# Mosquitto Entrypoint Script
# Generates certificates and password file on first run

set -e

CERTS_DIR="/mosquitto/certs"
DATA_DIR="/mosquitto/data"
CONFIG_DIR="/mosquitto/config"
PASSWD_FILE="$CONFIG_DIR/passwd"

# Ensure directories exist
mkdir -p "$CERTS_DIR" "$DATA_DIR" "$CONFIG_DIR"

# Generate self-signed certificates if they don't exist
if [ ! -f "$CERTS_DIR/server.crt" ] || [ ! -f "$CERTS_DIR/server.key" ]; then
    echo "Generating self-signed TLS certificates..."

    # Generate CA key and certificate
    openssl genrsa -out "$CERTS_DIR/ca.key" 4096 2>/dev/null
    openssl req -new -x509 -days 365 \
        -key "$CERTS_DIR/ca.key" \
        -out "$CERTS_DIR/ca.crt" \
        -subj "/C=US/ST=Local/L=Local/O=ai-colab/OU=Messaging/CN=ai-colab-ca" 2>/dev/null

    # Generate server key
    openssl genrsa -out "$CERTS_DIR/server.key" 4096 2>/dev/null

    # Generate server CSR
    openssl req -new \
        -key "$CERTS_DIR/server.key" \
        -out "$CERTS_DIR/server.csr" \
        -subj "/C=US/ST=Local/L=Local/O=ai-colab/OU=Messaging/CN=ai-colab-mqtt" 2>/dev/null

    # Sign server cert with CA
    openssl x509 -req \
        -in "$CERTS_DIR/server.csr" \
        -CA "$CERTS_DIR/ca.crt" \
        -CAkey "$CERTS_DIR/ca.key" \
        -CAcreateserial \
        -out "$CERTS_DIR/server.crt" \
        -days 365 \
        -sha256 2>/dev/null

    # Clean up CSR
    rm -f "$CERTS_DIR/server.csr"

    # Set permissions
    chmod 644 "$CERTS_DIR/ca.crt" "$CERTS_DIR/server.crt"
    chmod 600 "$CERTS_DIR/ca.key" "$CERTS_DIR/server.key"

    echo "TLS certificates generated successfully."
fi

# Generate password file if it doesn't exist
if [ ! -f "$PASSWD_FILE" ]; then
    echo "Generating MQTT credentials..."

    # Generate random admin credentials
    MQTT_USERNAME="ai-colab-admin"
    MQTT_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/')

    # Create password file
    mosquitto_passwd -b "$PASSWD_FILE" "$MQTT_USERNAME" "$MQTT_PASSWORD"

    # Set permissions
    chmod 600 "$PASSWD_FILE"
    chown mosquitto:mosquitto "$PASSWD_FILE" 2>/dev/null || true

    # Output credentials to stdout for retrieval
    echo "============================================"
    echo "  MQTT Broker Credentials (First Run)"
    echo "============================================"
    echo "  Username: $MQTT_USERNAME"
    echo "  Password: $MQTT_PASSWORD"
    echo "============================================"
    echo ""
    echo "  Save these credentials securely!"
    echo "  Update config.toml with these values."
    echo "============================================"
fi

echo "Starting Mosquitto MQTT Broker..."
exec mosquitto -c /mosquitto/config/mosquitto.conf
