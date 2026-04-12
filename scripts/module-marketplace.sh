#!/usr/bin/env bash
# ai-colab Module Marketplace v1.0
# Discovery and installation CLI for community modules.

set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Registry Configuration
# For now, we use a mock URL or a specific repo for the index
REGISTRY_URL="https://raw.githubusercontent.com/ai-colab/plugin-registry/main/index.json"
CACHE_FILE="/tmp/ai-colab-registry.json"
CACHE_TTL=3600 # 1 hour

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MODULES_DIR="$PROJECT_ROOT/modules"

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         ai-colab Module Marketplace          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
}

fetch_registry() {
    # 1. Check for Local Development Override
    local local_index="$PROJECT_ROOT/registry/index.json"
    if [[ -f "$local_index" ]]; then
        echo -e "${CYAN}Using local development registry...${NC}"
        cp "$local_index" "$CACHE_FILE"
        return 0
    fi

    # 2. Standard Remote Fetch
    local now=$(date +%s)
    local mtime=0
    if [[ -f "$CACHE_FILE" ]]; then
        mtime=$(date -r "$CACHE_FILE" +%s)
    fi

    if (( now - mtime > CACHE_TTL )) || [[ ! -f "$CACHE_FILE" ]]; then
        echo -e "${BLUE}Updating registry index from remote...${NC}"
        # Mocking the registry if it doesn't exist yet
        if ! curl -s -f "$REGISTRY_URL" -o "$CACHE_FILE"; then
            echo -e "${YELLOW}Registry URL not found. Using development mock index.${NC}"
            cat << 'EOF' > "$CACHE_FILE"
{
  "version": "1.0.0",
  "modules": [
    {
      "id": "atari-8bit",
      "name": "Atari 8-Bit Development",
      "description": "6502 assembly and Atari hardware tools",
      "url": "https://github.com/ai-colab/module-atari-8bit",
      "author": "ai-colab"
    }
  ]
}
EOF
        fi
    fi
}

search_modules() {
    local query="${1:-}"
    fetch_registry
    
    echo -e "\n${YELLOW}Search Results:${NC}"
    python3 -c "
import json, sys
query = sys.argv[1].lower()
with open('$CACHE_FILE', 'r') as f:
    data = json.load(f)
    found = False
    for m in data['modules']:
        if query in m['id'].lower() or query in m['name'].lower() or query in m['description'].lower():
            print(f\"  \033[0;32m{m['id']:<15}\033[0m | {m['name']:<25} | {m['author']}\")
            print(f\"                  {m['description']}\")
            found = True
    if not found:
        print('  No modules found matching query.')
" "$query"
}

info_module() {
    local mod_id="$1"
    fetch_registry
    
    python3 -c "
import json, sys
mod_id = sys.argv[1]
with open('$CACHE_FILE', 'r') as f:
    data = json.load(f)
    for m in data['modules']:
        if m['id'] == mod_id:
            print(f\"\n\033[0;34mModule Info: {m['name']}\033[0m\")
            print(f\"ID:          {m['id']}\")
            print(f\"Author:      {m['author']}\")
            print(f\"URL:         {m['url']}\")
            print(f\"Description: {m['description']}\")
            sys.exit(0)
    print(f'Module {mod_id} not found in registry.')
    sys.exit(1)
" "$mod_id"
}

install_module() {
    local mod_id="$1"
    fetch_registry
    
    local url=$(python3 -c "
import json, sys
mod_id = sys.argv[1]
with open('$CACHE_FILE', 'r') as f:
    data = json.load(f)
    for m in data['modules']:
        if m['id'] == mod_id:
            print(m['url'])
            sys.exit(0)
sys.exit(1)
" "$mod_id" 2>/dev/null || echo "")

    if [[ -z "$url" ]]; then
        echo -e "${RED}Error: Module '$mod_id' not found in registry.${NC}"
        return 1
    fi

    if [[ -d "$MODULES_DIR/$mod_id" ]]; then
        echo -e "${YELLOW}Module '$mod_id' is already installed.${NC}"
        read -p "Reinstall? [y/N]: " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then return 0; fi
        rm -rf "$MODULES_DIR/$mod_id"
    fi

    echo -e "${BLUE}Installing $mod_id from $url...${NC}"
    if git clone "$url" "$MODULES_DIR/$mod_id" --depth 1; then
        echo -e "${GREEN}✓ Successfully installed $mod_id${NC}"
        
        # 1. Fetch manifest data
        local manifest_json=$(python3 "$PROJECT_ROOT/scripts/module-manager.py" info "$mod_id")
        
        # 2. Check Permissions (P6.4)
        local perms=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); p=d.get('permissions', {}); print(','.join([k for k,v in p.items() if v]))" "$manifest_json" 2>/dev/null || echo "")
        
        if [[ -n "$perms" ]]; then
            echo -e "\n${YELLOW}⚠️  SECURITY NOTICE: Module '$mod_id' requests the following permissions:${NC}"
            IFS=',' read -ra ADDR <<< "$perms"
            for i in "${ADDR[@]}"; do
                echo -e "  - ${CYAN}${i}${NC}"
            done
            echo ""
            read -p "Do you want to grant these permissions and activate the module? [y/N]: " p_choice
            if [[ ! "$p_choice" =~ ^[Yy]$ ]]; then
                echo -e "${RED}Permissions denied. Removing module.${NC}"
                rm -rf "$MODULES_DIR/$mod_id"
                return 1
            fi
        fi

        # 3. Setup Sandboxed Python Environment (P6.4)
        local py_deps=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); deps=d.get('dependencies', {}).get('python', []); print(','.join(deps))" "$manifest_json" 2>/dev/null || echo "")
        
        if [[ -n "$py_deps" ]]; then
            echo -e "${BLUE}Setting up isolated virtual environment for $mod_id...${NC}"
            if command -v uv >/dev/null 2>&1; then
                (cd "$MODULES_DIR/$mod_id" && uv venv .venv && source .venv/bin/activate && uv pip install ${py_deps//,/ })
                echo -e "  ${GREEN}✓ Virtual environment created with uv${NC}"
            else
                echo -e "${YELLOW}uv not found, using standard venv fallback...${NC}"
                (cd "$MODULES_DIR/$mod_id" && python3 -m venv .venv && source .venv/bin/activate && pip install ${py_deps//,/ })
                echo -e "  ${GREEN}✓ Virtual environment created with venv${NC}"
            fi
        fi

        # 4. Final Validation
        echo -e "${BLUE}Validating manifest...${NC}"
        if python3 "$PROJECT_ROOT/scripts/module-manager.py" validate-all | grep -q "\"$mod_id\": {\"valid\": true"; then
            echo -e "  ${GREEN}✓ Manifest is valid${NC}"
        else
            echo -e "  ${RED}✗ Manifest validation failed!${NC}"
            echo -e "  Please check modules/$mod_id/module.toml"
        fi
    else
        echo -e "${RED}✗ Installation failed.${NC}"
        return 1
    fi
}

main() {
    # If arguments provided, run once and exit (CLI mode)
    if [[ $# -ge 1 ]]; then
        local cmd="$1"
        shift || true
        case "$cmd" in
            search) search_modules "${1:-}" ;;
            info)   info_module "${1:-}" ;;
            install) install_module "${1:-}" ;;
            list-local) python3 "$PROJECT_ROOT/scripts/module-manager.py" list ;;
            *) echo "Unknown command: $cmd"; exit 1 ;;
        esac
        exit 0
    fi

    # Otherwise, enter interactive mode
    while true; do
        clear
        print_header
        echo -e "\n${BLUE}Main Menu:${NC}"
        echo -e "  ${CYAN}1)${NC} Search Marketplace"
        echo -e "  ${CYAN}2)${NC} View Module Info"
        echo -e "  ${CYAN}3)${NC} Install Module"
        echo -e "  ${CYAN}4)${NC} List Locally Installed Modules"
        echo -e "  ${CYAN}q)${NC} Exit to Launcher"
        echo ""
        read -p "  Choice: " choice

        case "$choice" in
            1)
                read -p "  Enter search query (empty for all): " query
                search_modules "$query"
                read -p "  Press Enter to continue..."
                ;;
            2)
                read -p "  Enter module ID: " mod_id
                info_module "$mod_id"
                read -p "  Press Enter to continue..."
                ;;
            3)
                read -p "  Enter module ID to install: " mod_id
                install_module "$mod_id"
                read -p "  Press Enter to continue..."
                ;;
            4)
                echo -e "\n${YELLOW}Locally Installed Modules:${NC}"
                python3 "$PROJECT_ROOT/scripts/module-manager.py" list | python3 -c "import json, sys; d=json.load(sys.stdin); [print(f\"  - {m['name']} ({m['id']}) v{m['version']}\") for m in d]"
                read -p "  Press Enter to continue..."
                ;;
            q|exit|quit)
                break
                ;;
            *)
                echo -e "${RED}Invalid choice.${NC}"
                sleep 1
                ;;
        esac
    done
}

main "$@"
