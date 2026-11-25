#!/usr/bin/env bash
set -euo pipefail

usage='Usage: package-sireum.sh BOOTSTRAP_ZIP CC1_DIRECTORY OUTPUT_ZIP'
bootstrap_zip=$(realpath -- "${1:?$usage}")
rebuilt=$(realpath -- "${2:?$usage}")
output_zip=$(realpath -m -- "${3:?$usage}")
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
test ! -e "$output_zip"

source "$repo/tool/cosmocc/sireum-bootstrap.sh"

work=$(mktemp -d /tmp/sireum-cosmocc.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
bootstrap="$work/bootstrap"
sdk="$work/sdk"
notices="$sdk/share/sireum-cosmopolitan/cc1-rebuild"
mkdir -p "$notices/source"
for arch in x86_64 aarch64; do
  digest=$(<"$rebuilt/$arch.sha256")
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]]
  printf '%s  libexec/gcc/%s-linux-cosmo/14.1.0/cc1\n' "$digest" "$arch"
done > "$notices/SHA256SUMS"
(cd "$rebuilt" && sha256sum --check --strict "$notices/SHA256SUMS")
cp "$repo/tool/cosmocc/cc1-rebuild.md" "$notices/README.md"
cp "$repo/tool/cosmocc/windows-verified-unmap.patch" "$notices/source/"
cp "$repo/tool/cosmocc/LICENSE.gpl3" "$notices/source/GCC-COPYING3"
cp "$repo/LICENSE" "$notices/source/Cosmopolitan-LICENSE"

stage_stock_toolchain "$bootstrap_zip" "$bootstrap" "$sdk"
for arch in x86_64 aarch64; do
  cc1="libexec/gcc/$arch-linux-cosmo/14.1.0/cc1"
  install -m 755 "$rebuilt/$cc1" "$sdk/$cc1"
done

cd "$repo"
MAKEFLAGS="COSMOCC=$bootstrap" tool/cosmocc/package.sh "$sdk"

test -s "$sdk/include/io.h"
test -s "$sdk/include/libc/calls/io.h"
for arch in x86_64 aarch64; do
  cc1="libexec/gcc/$arch-linux-cosmo/14.1.0/cc1"
  cmp "$rebuilt/$cc1" "$sdk/$cc1"
  for mode in '' dbg tiny sysv optlinux tinylinux; do
    lib="$sdk/$arch-linux-cosmo/lib/$mode"
    for product in crt.o crtfastmath.o libcosmo.a libcxx.a; do
      test -s "$lib/$product"
    done
  done
done

"$sdk/bin/cosmocc" --version
printf 'int main(void) { return 0; }\n' > "$work/probe.c"
"$sdk/bin/cosmocc" --coverage -c "$work/probe.c" -o "$work/probe.o"
test -s "$work/probe.gcno"
test -s "$work/.aarch64/probe.o"
test -s "$work/.aarch64/probe.gcno"
"$sdk/bin/cosmocc" "$work/probe.c" -o "$work/probe.com"
"$work/probe.com"

find "$sdk" -type l -print0 >"$work/links"
while IFS= read -r -d '' link; do
  target=$(realpath -e -- "$link")
  if [[ "$target" != "$sdk/"* || ! -f "$target" ]]; then
    printf 'Invalid SDK file alias: %s -> %s\n' "$link" "$target" >&2
    exit 1
  fi
done <"$work/links"

cd "$sdk"
shopt -s dotglob
bsdtar -a -L -cf "$work/cosmocc.zip" -- *
unzip -tq "$work/cosmocc.zip"
mv -T --no-clobber "$work/cosmocc.zip" "$output_zip"
test ! -e "$work/cosmocc.zip"
