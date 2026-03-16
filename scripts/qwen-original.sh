#!/usr/bin/env bash
# Agent Qwen pour le développement Atari 8-bit
set -euo pipefail

# On crée une liste pour les arguments que qwen comprend
VALID_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) 
      # On ignore --name et la valeur qui suit (ex: atari_coder)
      shift 2 
      ;;
    *) 
      # On garde tout le reste pour qwen
      VALID_ARGS+=("$1")
      shift 
      ;;
  esac
done

# On lance qwen uniquement avec les arguments valides
qwen "${VALID_ARGS[@]}"
