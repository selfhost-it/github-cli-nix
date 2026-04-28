#!/usr/bin/env bash
# update.sh — Automatically update GitHub CLI (gh) to the latest upstream release
# using Claude Code in non-interactive mode.
#
# Prerequisites:
#   - claude CLI installed and on PATH
#   - One-time acceptance of --dangerously-skip-permissions
#     (run: claude --dangerously-skip-permissions  and then /exit)
#
# Usage:
#   ./update.sh            # run the update
#   ./update.sh --dry-run  # print the command without executing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROMPT=$(cat <<'EOF'
Update github-cli-nix to the latest upstream release.

1. Check the latest release tag:
   curl -s "https://api.github.com/repos/cli/cli/releases/latest" \
     | jq -r '.tag_name'
   Do NOT use `gh` to query its own repo — it may not be authenticated and we are
   bootstrapping the package itself.

2. Compare with the current `version` in `package.nix` — if already up to date, stop.

3. Update `package.nix`:
   a. Set `version` to the new value (without leading `v`).
   b. Set `hash = "";` -> run `nix build . 2>&1` -> find the line containing `got:` and extract the SRI hash (sha256-...=) -> update `hash`.
   c. Set `vendorHash = "";` -> run `nix build . 2>&1` -> extract the correct hash from `got:` -> update `vendorHash`.

4. Run `nix build .` — this must succeed with no errors.

5. Verify: `./result/bin/gh --version` (the output must include the new version, NOT "DEV").

6. Scan all tracked files (`git ls-files`) for passwords, tokens, API keys, private keys, or sensitive information — abort if found. Content-addressable hashes are NOT secrets.

7. Commit: git add -A && git commit -m "Update GitHub CLI to v<VERSION>"

8. Push: GIT_SSH_COMMAND="ssh -i ~/.ssh/self-host-github" git push origin main
EOF
)

if [[ "${1:-}" == "--dry-run" ]]; then
    echo "Would run:"
    echo "  cd $SCRIPT_DIR"
    echo "  claude -p <prompt> --dangerously-skip-permissions"
    echo ""
    echo "Prompt:"
    echo "$PROMPT"
    exit 0
fi

cd "$SCRIPT_DIR"
exec claude -p "$PROMPT" --dangerously-skip-permissions
