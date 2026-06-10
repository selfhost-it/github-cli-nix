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
Update github-cli-nix to the latest upstream release that is still compatible
with the Go version shipped by nixos stable.

CONTEXT — Go floor:
  This flake is consumed by NixOS configurations pinned to nixos stable
  (currently 26.05, which ships Go 1.26.3). The Nix sandbox enforces
  GOTOOLCHAIN=local, so a tag whose go.mod requires a Go newer than stable's
  will fail to build on consumers. Verify the actual stable Go version before
  walking back — when a new NixOS release ships a newer Go, the floor moves
  (this is how the old v2.87.3 pin from the 25.11/Go 1.25.8 era was lifted).

1. Determine the candidate tag:
   a. Fetch the latest release tag:
        LATEST=$(curl -s "https://api.github.com/repos/cli/cli/releases/latest" | jq -r '.tag_name')
   b. Read its go.mod (awk may be missing on this host; use grep/cut):
        GOREQ=$(curl -fsSL "https://raw.githubusercontent.com/cli/cli/${LATEST}/go.mod" | grep -m1 '^go ' | cut -d' ' -f2)
   c. If GOREQ is satisfied by stable's Go (currently 1.26.x), the candidate
      is LATEST — proceed with that. Otherwise walk back through recent tags
      (curl "https://api.github.com/repos/cli/cli/releases?per_page=30") and
      pick the most recent tag whose go.mod requirement stable's Go satisfies.
   d. Do NOT use `gh` to query its own repo — it may not be authenticated and
      we are bootstrapping the package itself.

2. Compare the chosen candidate with the current `version` in `package.nix`.
   If already at the candidate, stop and print "GitHub CLI is up to date
   (Go floor in effect: pinned to v<VERSION>)".

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
