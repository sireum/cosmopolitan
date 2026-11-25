#!/usr/bin/env bash
set -euo pipefail

usage='Usage: rebuild-sireum-cc1.sh TARGET BOOTSTRAP_ZIP OUTPUT_DIRECTORY'
target=${1:?$usage}
case "$target" in
  x86_64|aarch64) ;;
  *) printf 'Unsupported GCC target: %s\n' "$target" >&2; exit 1 ;;
esac
bootstrap_zip=$(realpath -- "${2:?$usage}")
output=$(realpath -m -- "${3:?$usage}")
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$script_dir/sireum-bootstrap.sh"

work=$(mktemp -d /tmp/sireum-gcc.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
checkout() {
  local url=$1 commit=$2 directory=$3
  git init -q "$directory"
  git -C "$directory" fetch --depth=1 --no-tags "$url" "$commit"
  git -C "$directory" checkout --detach FETCH_HEAD
  test "$(git -C "$directory" rev-parse HEAD)" = "$commit"
}

checkout https://github.com/ahgamut/superconfigure.git \
  dd04d27c780832318962efbc6d140743ebff617b "$work/superconfigure"
cd "$work/superconfigure"
checkout https://github.com/jart/cosmopolitan.git \
  1312f602450da58f31a8ca81322257ec61f584b9 cosmopolitan
checkout https://github.com/ahgamut/gcc.git \
  58ccca83f6ce7f33ee3bf1333a1e152a0a2486b7 o/compiler/gcc-14.1-patched/gcc
git -C cosmopolitan apply "$script_dir/windows-verified-unmap.patch"

stage_stock_toolchain "$bootstrap_zip" "$work/bootstrap" "$PWD/cosmopolitan/cosmocc"
MAKEFLAGS="COSMOCC=$work/bootstrap" bash .github/scripts/cosmo
MAXPROC=2 make -j2 "$target-gcc"

cc1="libexec/gcc/$target-linux-cosmo/14.1.0/cc1"
test -s "results/$cc1.com"
install -D -m 755 "results/$cc1.com" "$output/$cc1"
cd "$output"
sha256sum "$cc1" | cut -d ' ' -f1 | tee "$target.sha256"
