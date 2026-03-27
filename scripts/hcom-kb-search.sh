#!/bin/bash
#
# Enhanced !kb command with RAG semantic search
# Usage: !kb <query> [options]
#
# Options:
#   --top-k <n>      Number of results (default: 5)
#   --source <pattern>  Filter by source (e.g., "conductor/*")
#   --json           Output as JSON
#   --index          Trigger re-indexing
#   --stats          Show index statistics
#   --help           Show this help
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# RAG index path
INDEX_DIR="$PROJECT_ROOT/.ai-colab/rag"
INDEX_DB="$INDEX_DIR/index.db"

# Default values
TOP_K=5
SOURCE=""
OUTPUT_FORMAT="text"
ACTION="search"
QUERY=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Show help
show_help() {
    cat << EOF
Enhanced Knowledge Base Search (!kb)

Usage: !kb <query> [options]

Search the ai-colab knowledge base using semantic similarity.

Options:
  --top-k <n>          Number of results to return (default: 5)
  --source <pattern>   Filter by source pattern (e.g., "conductor/*")
  --json               Output results as JSON
  --index              Trigger re-indexing of documents
  --force              Force re-indexing (with --index)
  --stats              Show index statistics
  --help               Show this help message

Examples:
  !kb "How does the blackboard work?"
  !kb "agent coordination" --top-k 10
  !kb "MCP server" --source "conductor/*"
  !kb --index
  !kb --stats

EOF
}

# Ensure index directory exists
ensure_index_dir() {
    mkdir -p "$INDEX_DIR"
}

# Check if RAG is available
check_rag_available() {
    if ! python3 -c "import sys; sys.path.insert(0, '$PROJECT_ROOT'); from rag import RAGClient" 2>/dev/null; then
        print_warning "RAG system not fully initialized"
        print_info "Install dependencies: pip install -r $PROJECT_ROOT/requirements-rag.txt"
        return 1
    fi
    return 0
}

# Index documents
do_index() {
    local force_flag=""
    if [[ "$FORCE" == "true" ]]; then
        force_flag=", force=True"
    fi
    
    print_info "Starting document indexing..."
    
    python3 << PYTHON_EOF
import sys
sys.path.insert(0, '$PROJECT_ROOT')

from rag.client import RAGClient

try:
    client = RAGClient()
    result = client.index(force=$force_flag)
    
    print(f"Indexing complete!")
    print(f"  Files processed: {result.get('files_processed', 0)}")
    print(f"  Files indexed: {result.get('files_indexed', 0)}")
    print(f"  Chunks created: {result.get('chunks_created', 0)}")
    
    if result.get('errors'):
        print(f"  Errors: {len(result['errors'])}")
        for err in result['errors'][:5]:
            print(f"    - {err}")
    
except Exception as e:
    print(f"Indexing failed: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
}

# Show statistics
do_stats() {
    python3 << PYTHON_EOF
import sys
sys.path.insert(0, '$PROJECT_ROOT')

from rag.client import RAGClient

try:
    client = RAGClient()
    
    if not client.index_path.exists():
        print("Index not found. Run '!kb --index' to create it.")
        sys.exit(0)
    
    stats = client.get_stats()
    
    print("Knowledge Base Statistics")
    print("=" * 40)
    print(f"Index path: {stats.get('index_path', 'N/A')}")
    print(f"Documents: {stats.get('document_count', 0)}")
    print(f"Chunks: {stats.get('document_count', 0)}")
    print(f"Database size: {stats.get('database_size_mb', 0)} MB")
    
    cache = stats.get('cache', {})
    if cache:
        print(f"\nCache Statistics")
        print("-" * 40)
        print(f"Cache entries: {cache.get('entries', 0)}")
        print(f"Hit rate: {cache.get('hit_rate_percent', 0)}%")
        print(f"Cache size: {cache.get('total_size_kb', 0)} KB")
    
except Exception as e:
    print(f"Error getting stats: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
}

# Search knowledge base
do_search() {
    local query="$1"
    
    if [[ -z "$query" ]]; then
        print_error "Query is required"
        echo "Usage: !kb <query> [options]"
        exit 1
    fi
    
    python3 << PYTHON_EOF
import sys
import json
sys.path.insert(0, '$PROJECT_ROOT')

from rag.client import RAGClient

try:
    client = RAGClient()
    
    # Check if index exists
    if not client.index_path.exists():
        print("Index not found. Running initial indexing...")
        client.index()
    
    # Build search parameters
    search_kwargs = {
        'top_k': $TOP_K
    }
    
    # Add source filter if specified
    source_filter = '$SOURCE'
    if source_filter:
        search_kwargs['filters'] = {'source': source_filter}
    
    # Perform search
    results = client.search('''$query''', **search_kwargs)
    
    # Output results
    output_format = '$OUTPUT_FORMAT'
    
    if output_format == 'json':
        print(json.dumps(results, indent=2))
    else:
        print(f"Search results for: $query")
        print("=" * 60)
        
        if not results:
            print("No results found.")
        else:
            for i, result in enumerate(results, 1):
                score = result.get('score', 0)
                source = result.get('source', 'unknown')
                section = result.get('section', '')
                excerpt = result.get('excerpt', '')[:200]
                
                print(f"\n{i}. [{score:.3f}] {source}")
                if section:
                    print(f"   Section: {section}")
                print(f"   {excerpt}...")
        
        print(f"\nFound {len(results)} results")

except Exception as e:
    print(f"Search failed: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --top-k)
                TOP_K="$2"
                shift 2
                ;;
            --source)
                SOURCE="$2"
                shift 2
                ;;
            --json)
                OUTPUT_FORMAT="json"
                shift
                ;;
            --index)
                ACTION="index"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --stats)
                ACTION="stats"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                QUERY="$QUERY $1"
                shift
                ;;
        esac
    done
    
    # Trim leading space from query
    QUERY="$(echo "$QUERY" | sed 's/^ *//')"
}

# Main
main() {
    parse_args "$@"
    
    ensure_index_dir
    
    case $ACTION in
        index)
            check_rag_available || exit 1
            do_index
            ;;
        stats)
            check_rag_available || exit 1
            do_stats
            ;;
        search)
            check_rag_available
            do_search "$QUERY"
            ;;
    esac
}

main "$@"
