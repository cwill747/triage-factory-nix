#!/usr/bin/env bash
set -euo pipefail

REPO="sky-ai-eng/triage-factory"
FLAKE="$(cd "$(dirname "$0")" && pwd)/flake.nix"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

extract_hash() {
  grep "got:" <<< "$1" | head -1 | awk '{print $2}'
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

# 2. Write version + source hash, zero out dep hashes so nix tells us the real ones
sed -i '' "s|version = \".*\";|version = \"${version}\";|" "$FLAKE"
sed -i '' "s|hash = \"sha256-.*\";|hash = \"${src_sri}\";|" "$FLAKE"
sed -i '' "s|npmDepsHash = \"sha256-.*\";|npmDepsHash = \"${FAKE_HASH}\";|" "$FLAKE"
sed -i '' "s|vendorHash = \"sha256-.*\";|vendorHash = \"${FAKE_HASH}\";|" "$FLAKE"

# 3. npm deps hash — build will fail with hash mismatch, we extract the correct one
echo "==> Computing npmDepsHash (this builds the frontend deps)..."
build_out=$(nix build .#default 2>&1 || true)
npm_hash=$(extract_hash "$build_out")
if [[ -z "$npm_hash" ]]; then
  echo "ERROR: couldn't extract npmDepsHash from build output:" >&2
  echo "$build_out" >&2
  exit 1
fi
echo "    npmDepsHash: ${npm_hash}"
sed -i '' "s|npmDepsHash = \"${FAKE_HASH}\";|npmDepsHash = \"${npm_hash}\";|" "$FLAKE"

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
sed -i '' "s|vendorHash = \"${FAKE_HASH}\";|vendorHash = \"${vendor_hash}\";|" "$FLAKE"

# 5. Full build to verify
echo "==> Running full build..."
if nix build .#default; then
  echo "==> Success! triagefactory v${version} built."
  ./result/bin/triagefactory --version
else
  echo "ERROR: final build failed — check flake.nix" >&2
  exit 1
fi
