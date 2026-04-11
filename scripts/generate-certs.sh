#!/usr/bin/env bash
# Generate Self-Signed TLS Certificates for Mosquitto MQTT Broker
# Usage: bash scripts/generate-certs.sh [output_dir]
#
# This script generates:
# - CA certificate and key (ca.crt, ca.key)
# - Server certificate and key (server.crt, server.key)
#
# The CA certificate should be distributed to all MQTT clients.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }

# Output directory
OUTPUT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../docker/mosquitto/certs" && pwd)}"

# Check dependencies
if ! command -v openssl >/dev/null 2>&1; then
    print_error "openssl is not installed. Please install it first."
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

print_info "Generating TLS certificates for Mosquitto MQTT Broker..."
print_info "Output directory: $OUTPUT_DIR"
echo ""

# Check if certificates already exist
if [[ -f "$OUTPUT_DIR/server.crt" && -f "$OUTPUT_DIR/server.key" ]]; then
    print_warning "Certificates already exist in $OUTPUT_DIR"
    read -p "  Overwrite existing certificates? [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Certificate generation cancelled."
        exit 0
    fi
fi

# Generate CA key and certificate
print_info "Generating CA key and certificate..."
openssl genrsa -out "$OUTPUT_DIR/ca.key" 4096 2>/dev/null
openssl req -new -x509 -days 365 \
    -key "$OUTPUT_DIR/ca.key" \
    -out "$OUTPUT_DIR/ca.crt" \
    -subj "/C=US/ST=Local/L=Local/O=ai-colab/OU=Messaging/CN=ai-colab-ca" 2>/dev/null

print_success "CA certificate generated: $OUTPUT_DIR/ca.crt"

# Generate server key
print_info "Generating server key..."
openssl genrsa -out "$OUTPUT_DIR/server.key" 4096 2>/dev/null
print_success "Server key generated: $OUTPUT_DIR/server.key"

# Generate server CSR
print_info "Generating server certificate signing request..."
openssl req -new \
    -key "$OUTPUT_DIR/server.key" \
    -out "$OUTPUT_DIR/server.csr" \
    -subj "/C=US/ST=Local/L=Local/O=ai-colab/OU=Messaging/CN=ai-colab-mqtt" 2>/dev/null

# Sign server cert with CA
print_info "Signing server certificate with CA..."
openssl x509 -req \
    -in "$OUTPUT_DIR/server.csr" \
    -CA "$OUTPUT_DIR/ca.crt" \
    -CAkey "$OUTPUT_DIR/ca.key" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/server.crt" \
    -days 365 \
    -sha256 2>/dev/null

print_success "Server certificate signed: $OUTPUT_DIR/server.crt"

# Clean up CSR and serial
rm -f "$OUTPUT_DIR/server.csr" "$OUTPUT_DIR/ca.srl"

# Set permissions
chmod 644 "$OUTPUT_DIR/ca.crt" "$OUTPUT_DIR/server.crt"
chmod 600 "$OUTPUT_DIR/ca.key" "$OUTPUT_DIR/server.key"

echo ""
print_success "TLS certificates generated successfully!"
echo ""
echo -e "${BLUE}Files created:${NC}"
echo -e "  CA Certificate:      $OUTPUT_DIR/ca.crt (distribute to clients)"
echo -e "  CA Key:              $OUTPUT_DIR/ca.key (keep secret)"
echo -e "  Server Certificate:  $OUTPUT_DIR/server.crt"
echo -e "  Server Key:          $OUTPUT_DIR/server.key (keep secret)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Start MQTT broker: docker compose --profile mqtt up -d"
echo -e "  2. Copy CA cert to clients: scp $OUTPUT_DIR/ca.crt user@client:/etc/mosquitto/ca.crt"
echo -e "  3. Update config.toml with generated credentials"
echo ""
echo -e "${YELLOW}Certificate details:${NC}"
openssl x509 -in "$OUTPUT_DIR/ca.crt" -noout -subject -dates 2>/dev/null || true
echo ""
openssl x509 -in "$OUTPUT_DIR/server.crt" -noout -subject -dates -issuer 2>/dev/null || true
