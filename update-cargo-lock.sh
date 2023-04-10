#!nix-shell
#!nix-shell -i bash -p coreutils gnugrep git cargo

# This updates cargo-lock.patch for the buck2 version listed in flake.nix.

set -eu -o verbose

here=$PWD
checkout=$(mktemp -d)
git clone --depth=1 https://github.com/facebook/buck2 "$checkout"
cd "$checkout"

cargo generate-lockfile
git add -f Cargo.lock
git diff HEAD -- Cargo.lock > "$here"/cargo-lock.patch

cd "$here"
rm -rf "$checkout"
