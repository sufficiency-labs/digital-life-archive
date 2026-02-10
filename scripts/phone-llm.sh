#!/data/data/com.termux/files/usr/bin/bash
# phone-llm.sh — Query local LLM with archive context
# Uses ollama running locally on the phone (or forwarded from server via tunnel).
#
# Modes:
#   phone-llm.sh "summarize recent project notes"  — ask a question with archive context
#   phone-llm.sh search "machine learning"   — search local repos for a term
#   phone-llm.sh chat                        — interactive chat mode
#
# The local model (phi3:mini) is small but useful for:
#   - Searching and summarizing your people/ideas/orgs
#   - Quick lookups when offline
#   - Note-taking assistance
#
# For serious work, SSH into the server and use Claude Code.

set -euo pipefail

ARCHIVE_DIR="$HOME/archive"
MODEL="${PHONE_LLM_MODEL:-phi3:mini}"
OLLAMA_URL="http://localhost:11434"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

check_ollama() {
    if ! curl -s "$OLLAMA_URL/api/tags" &>/dev/null; then
        echo -e "${YELLOW}Starting ollama...${NC}"
        ollama serve &>/dev/null &
        sleep 3
        if ! curl -s "$OLLAMA_URL/api/tags" &>/dev/null; then
            echo "ERROR: ollama is not running and could not be started"
            echo "Try: ollama serve"
            exit 1
        fi
    fi
}

build_context() {
    local context=""

    local claude_md="$ARCHIVE_DIR/CLAUDE.md"
    if [ -f "$claude_md" ]; then
        context+="# Archive Context (from CLAUDE.md)\n"
        context+="$(head -50 "$claude_md")\n\n"
    fi

    local people_idx="$ARCHIVE_DIR/private/relationships/INDEX.md"
    if [ -f "$people_idx" ]; then
        context+="# People Index (first 100 lines)\n"
        context+="$(head -100 "$people_idx")\n\n"
    fi

    local ideas_idx="$ARCHIVE_DIR/private/idea-index/INDEX.md"
    if [ -f "$ideas_idx" ]; then
        context+="# Ideas Index (first 100 lines)\n"
        context+="$(head -100 "$ideas_idx")\n\n"
    fi

    local orgs_idx="$ARCHIVE_DIR/private/organizations/INDEX.md"
    if [ -f "$orgs_idx" ]; then
        context+="# Organizations Index (first 50 lines)\n"
        context+="$(head -50 "$orgs_idx")\n\n"
    fi

    echo -e "$context"
}

search_repos() {
    local query="$1"
    echo -e "${CYAN}Searching local repos for: $query${NC}\n"

    echo -e "${GREEN}=== People ===${NC}"
    grep -ril "$query" "$ARCHIVE_DIR/private/relationships/people/" 2>/dev/null | \
        while read -r f; do
            local slug=$(basename "$(dirname "$f")")
            echo "  $slug"
        done || echo "  (no matches)"

    echo -e "\n${GREEN}=== Ideas ===${NC}"
    grep -ril "$query" "$ARCHIVE_DIR/private/idea-index/ideas/" 2>/dev/null | \
        while read -r f; do
            local slug=$(basename "$(dirname "$f")")
            echo "  $slug"
        done || echo "  (no matches)"

    echo -e "\n${GREEN}=== Organizations ===${NC}"
    grep -ril "$query" "$ARCHIVE_DIR/private/organizations/organizations/" 2>/dev/null | \
        while read -r f; do
            local slug=$(basename "$(dirname "$f")")
            echo "  $slug"
        done || echo "  (no matches)"
}

ask_llm() {
    local question="$1"
    local extra_context="${2:-}"

    check_ollama

    local system_context
    system_context=$(build_context)

    # Try to find matching people READMEs for names in the question
    local names
    names=$(echo "$question" | grep -oE '[A-Z][a-z]+ [A-Z][a-z]+' || true)
    for name in $names; do
        local slug=$(echo "$name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        local readme="$ARCHIVE_DIR/private/relationships/people/$slug/README.md"
        if [ -f "$readme" ]; then
            extra_context+="\n\n# Full details for $slug:\n$(cat "$readme")"
        fi
    done

    echo -e "${CYAN}Asking $MODEL...${NC}\n"

    curl -s "$OLLAMA_URL/api/generate" \
        -d "$(jq -n \
            --arg model "$MODEL" \
            --arg system "You are a helpful assistant with access to a personal knowledge archive. Use the context provided to answer questions accurately. If you don't have enough information, say so.\n\n$system_context\n$extra_context" \
            --arg prompt "$question" \
            '{model: $model, system: $system, prompt: $prompt, stream: false}'
        )" | jq -r '.response'
}

chat_mode() {
    check_ollama
    echo -e "${GREEN}Archive LLM Chat (model: $MODEL)${NC}"
    echo -e "${YELLOW}Type 'quit' to exit, 'search <term>' to search repos${NC}\n"

    while true; do
        echo -ne "${CYAN}> ${NC}"
        read -r input
        [ -z "$input" ] && continue
        [ "$input" = "quit" ] || [ "$input" = "exit" ] && break

        if [[ "$input" == search\ * ]]; then
            search_repos "${input#search }"
        else
            ask_llm "$input"
        fi
        echo ""
    done
}

# --- Main ---
case "${1:-}" in
    "")
        echo "Usage: phone-llm.sh <question>"
        echo "       phone-llm.sh search <term>"
        echo "       phone-llm.sh chat"
        exit 1
        ;;
    "search")
        shift
        search_repos "$*"
        ;;
    "chat")
        chat_mode
        ;;
    *)
        ask_llm "$*"
        ;;
esac
