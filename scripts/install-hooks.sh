#!/usr/bin/env bash
# Installs the privacy pre-commit hook. Run once per clone.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

mkdir -p .git/hooks
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
exec "$(git rev-parse --show-toplevel)/scripts/check-privacy.sh"
HOOK

chmod +x .git/hooks/pre-commit scripts/check-privacy.sh

echo "Installed .git/hooks/pre-commit -> scripts/check-privacy.sh"
