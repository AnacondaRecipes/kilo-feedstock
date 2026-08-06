#!/bin/bash
set -euxo pipefail

# Install layout mirrors Homebrew Formula/kilo.rb:
#   libexec holds the binary + assets; bin/kilo is an env wrapper.

LIBEXEC="${PREFIX}/libexec/kilo"
mkdir -p "${LIBEXEC}" "${PREFIX}/bin"

install -m 755 kilo "${LIBEXEC}/kilo"
install -m 644 kilo-sandbox-mutation-worker.js "${LIBEXEC}/kilo-sandbox-mutation-worker.js"
cp -a tree-sitter "${LIBEXEC}/tree-sitter"

# Optional pieces shipped in some platform archives.
if [[ -d console ]]; then
  cp -a console "${LIBEXEC}/console"
fi
if [[ -f kilo-sandbox-network-relay.js ]]; then
  install -m 644 kilo-sandbox-network-relay.js "${LIBEXEC}/kilo-sandbox-network-relay.js"
fi
# Linux-only sandbox helpers + third-party license texts.
if [[ -f bwrap ]]; then
  install -m 755 bwrap "${LIBEXEC}/bwrap"
fi
if [[ -f kilo-sandbox-seccomp ]]; then
  install -m 755 kilo-sandbox-seccomp "${LIBEXEC}/kilo-sandbox-seccomp"
fi
if [[ -d licenses ]]; then
  mkdir -p "${PREFIX}/share/licenses/kilo"
  cp -a licenses/. "${PREFIX}/share/licenses/kilo/"
fi

# Wrapper sets asset paths the way Homebrew's write_env_script does.
cat > "${PREFIX}/bin/kilo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KILO_TREE_SITTER_WASM_DIR="${KILO_TREE_SITTER_WASM_DIR:-${ROOT}/libexec/kilo/tree-sitter}"
if [[ -d "${ROOT}/libexec/kilo/console" ]]; then
  export KILO_CONSOLE_ASSET_DIR="${KILO_CONSOLE_ASSET_DIR:-${ROOT}/libexec/kilo/console}"
fi
exec "${ROOT}/libexec/kilo/kilo" "$@"
EOF
chmod 755 "${PREFIX}/bin/kilo"
