#!/bin/bash
# Fetch model catalog from Cursor Cloud Agents API (GET /v1/models).
set -euo pipefail

API_URL="https://api.cursor.com/v1/models"
API_KEY=""
OUTPUT_PATH=""
RAW=0

err() {
    echo "Error: $1" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Fetch the Cursor Cloud Agents model list (GET /v1/models) and print JSON
to stdout, or write it to a file with -o/--output.

Options:
  -o, --output PATH   Write response body to PATH instead of stdout
  --api-key KEY       API key (overrides CURSOR_API_KEY)
  --raw               Skip jq pretty-print; emit raw response body
  -h, --help          Show this help message

Environment:
  CURSOR_API_KEY      Cursor API key (required unless --api-key is set)

Examples:
  export CURSOR_API_KEY=crsr_...
  $0
  $0 -o models.json
  $0 --api-key "\$KEY" -o /tmp/models.json
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [[ $# -ge 2 ]] || err "--output requires a path argument."
            OUTPUT_PATH="$2"
            shift 2
            ;;
        -o=*|--output=*)
            OUTPUT_PATH="${1#*=}"
            [[ -n "$OUTPUT_PATH" ]] || err "--output requires a path argument."
            shift
            ;;
        --api-key)
            [[ $# -ge 2 ]] || err "--api-key requires a key argument."
            API_KEY="$2"
            shift 2
            ;;
        --api-key=*)
            API_KEY="${1#*=}"
            [[ -n "$API_KEY" ]] || err "--api-key requires a key argument."
            shift
            ;;
        --raw)
            RAW=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            err "Unknown option: $1. Use --help for usage."
            ;;
    esac
done

if [[ -z "$API_KEY" ]]; then
    API_KEY="${CURSOR_API_KEY:-}"
fi
[[ -n "$API_KEY" ]] || err "Set CURSOR_API_KEY or pass --api-key."

command -v curl >/dev/null 2>&1 || err "curl is required but not found on PATH."

BODY="$(curl -fsS \
    --request GET \
    --url "$API_URL" \
    --header "Authorization: Bearer ${API_KEY}")"

if [[ "$RAW" -eq 0 ]] && command -v jq >/dev/null 2>&1; then
    FORMATTED="$(printf '%s\n' "$BODY" | jq .)"
else
    FORMATTED="$BODY"
fi

if [[ -n "$OUTPUT_PATH" ]]; then
    printf '%s\n' "$FORMATTED" >"$OUTPUT_PATH"
    echo "Wrote models to $OUTPUT_PATH" >&2
else
    printf '%s\n' "$FORMATTED"
fi
