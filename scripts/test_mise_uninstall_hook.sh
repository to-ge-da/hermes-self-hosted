#!/bin/bash
# One check: leftover activate hook evals the stub, prompt stays clean, stub gone.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mise.sh
source "${SCRIPT_DIR}/mise.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DEST="${TMP}/mise"

plant_hook_stub "$DEST"
is_uninstall_stub "$DEST" || { echo "FAIL: stub not detected"; exit 1; }

# Missing path: silent
silent="$(remove_path "${TMP}/no-such-mise" 2>&1 || true)"
[[ -z "$silent" ]] || { echo "FAIL: missing path printed: ${silent}"; exit 1; }

STUB_EVAL="$("$DEST" hook-env -s bash)"
export STUB_EVAL DEST
bash --noprofile --norc <<'INNER'
set -euo pipefail
_mise_hook() { echo hook_still_here; }
PROMPT_COMMAND="_mise_hook"
eval "$STUB_EVAL"
if type _mise_hook >/dev/null 2>&1; then
    echo "FAIL: _mise_hook still defined"
    exit 1
fi
if [[ "${PROMPT_COMMAND}" == *_mise_hook* ]]; then
    echo "FAIL: PROMPT_COMMAND still has hook: ${PROMPT_COMMAND}"
    exit 1
fi
if [[ -e "$DEST" ]]; then
    echo "FAIL: stub not deleted"
    exit 1
fi
INNER

plant_hook_stub "$DEST"
set +e
"$DEST" --version >/dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 127 ]] || { echo "FAIL: non-hook exit ${status}"; exit 1; }
[[ ! -e "$DEST" ]] || { echo "FAIL: stub not deleted on non-hook"; exit 1; }

echo OK
