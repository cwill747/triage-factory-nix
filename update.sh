#!/usr/bin/env bash
set -euo pipefail

REPO="sky-ai-eng/triage-factory"
FLAKE="$(cd "$(dirname "$0")" && pwd)/flake.nix"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

extract_hash() {
  awk '/got:/ { print $2; exit }' <<< "$1" || true
}

# Portable in-place sed (macOS needs -i '', GNU needs -i)
sedi() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Get latest release tag, or use the one passed as $1
if [[ ${1:-} ]]; then
  version="${1#v}"
else
  tag=$(gh release list -R "$REPO" --limit 1 --json tagName -q '.[0].tagName')
  version="${tag#v}"
fi

echo "==> Updating to v${version}"

# 1. Source hash
echo "==> Fetching source hash..."
src_hash=$(nix-prefetch-url --unpack --type sha256 \
  "https://github.com/${REPO}/archive/refs/tags/v${version}.tar.gz" 2>/dev/null)
src_sri=$(nix hash convert --hash-algo sha256 --to sri "$src_hash")
echo "    src: ${src_sri}"

# 2. Write version and source hash, then zero out dependency hashes so Nix
# reports the expected values.
sedi "s|version = \".*\";|version = \"${version}\";|" "$FLAKE"
sedi "s|hash = \"sha256-.*\";|hash = \"${src_sri}\";|" "$FLAKE"
sedi "s|pnpmDepsHash = \"sha256-.*\";|pnpmDepsHash = \"${FAKE_HASH}\";|" "$FLAKE"
sedi "s|vendorHash = \"sha256-.*\";|vendorHash = \"${FAKE_HASH}\";|" "$FLAKE"

# 3. pnpm dependency hash. The build reports the expected hash on mismatch.
echo "==> Computing pnpmDepsHash (this fetches the frontend deps)..."
build_out=$(nix build .#frontend 2>&1 || true)
pnpm_hash=$(extract_hash "$build_out")
if [[ -z "$pnpm_hash" ]]; then
  echo "ERROR: couldn't extract pnpmDepsHash from build output:" >&2
  echo "$build_out" >&2
  exit 1
fi
echo "    pnpmDepsHash: ${pnpm_hash}"
sedi "s|pnpmDepsHash = \"${FAKE_HASH}\";|pnpmDepsHash = \"${pnpm_hash}\";|" "$FLAKE"

# 4. Go vendor hash — same trick
echo "==> Computing vendorHash (this fetches Go modules)..."
build_out=$(nix build .#default 2>&1 || true)
vendor_hash=$(extract_hash "$build_out")
if [[ -z "$vendor_hash" ]]; then
  echo "ERROR: couldn't extract vendorHash from build output:" >&2
  echo "$build_out" >&2
  exit 1
fi
echo "    vendorHash: ${vendor_hash}"
sedi "s|vendorHash = \"${FAKE_HASH}\";|vendorHash = \"${vendor_hash}\";|" "$FLAKE"

# 5. Full build to verify
echo "==> Running full build..."
if nix build .#default; then
  echo "==> Success! triagefactory v${version} built."
  ./result/bin/triagefactory --version
else
  echo "ERROR: final build failed — check flake.nix" >&2
  exit 1
fi
