#!/bin/bash
set -euxo pipefail

# Keep bun's install cache and the models.dev cache inside the work dir.
export BUN_INSTALL_CACHE_DIR="${SRC_DIR}/.bun-cache"
export HOME="${SRC_DIR}/.home"
mkdir -p "${HOME}"

# JS dependencies, exactly as pinned (with integrity hashes) by bun.lock.
bun install --frozen-lockfile

# Release build for the native target only (--single), compiled with conda's
# bun. --skip-install: the extra `bun install --os=* --cpu=*` steps only fetch
# other platforms' native packages for cross-compiling.
export KILO_VERSION="${PKG_VERSION}"
export KILO_CHANNEL=latest
export KILO_RELEASE=1
export KILO_SKIP_RELEASE_UPLOAD=1
export KILO_SKIP_PATCHELF=1
# Use conda's bubblewrap (run dependency) instead of building the bundled one,
# which needs Zig.
export KILO_SKIP_BUNDLED_BWRAP=1
(cd packages/opencode && bun run script/build.ts --single --skip-install)

case "${target_platform}" in
  linux-64) dist=linux-x64 ;;
  linux-aarch64) dist=linux-arm64 ;;
  osx-arm64) dist=darwin-arm64 ;;
  *) echo "unsupported target_platform ${target_platform}" >&2; exit 1 ;;
esac
out="packages/opencode/dist/@kilocode/cli-${dist}/bin"

# Install layout mirrors Homebrew: the binary and the assets it finds next to
# its own executable live in libexec; bin/kilo is a thin wrapper.
LIBEXEC="${PREFIX}/libexec/kilo"
mkdir -p "${LIBEXEC}" "${PREFIX}/bin"
cp -a "${out}/." "${LIBEXEC}/"
rm -f "${LIBEXEC}"/*.map

if [[ "${target_platform}" == linux-* ]]; then
  ln -s ../../bin/bwrap "${LIBEXEC}/bwrap"
  cp "${LIBEXEC}/licenses/sandbox-runtime/LICENSE" "${SRC_DIR}/sandbox-runtime-LICENSE"
fi

cat > "${PREFIX}/bin/kilo" <<'EOF'
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${ROOT}/libexec/kilo/kilo" "$@"
EOF
chmod 755 "${PREFIX}/bin/kilo"
