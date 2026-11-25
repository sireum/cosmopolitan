#!/usr/bin/env bash
set -euo pipefail

usage='Usage: package-sireum.sh BOOTSTRAP_ZIP PATCHED_CC1_ZIP OUTPUT_ZIP'
bootstrap_zip=$(realpath -- "${1:?$usage}")
cc1_zip=$(realpath -- "${2:?$usage}")
output_zip=$(realpath -m -- "${3:?$usage}")
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
test ! -e "$output_zip"

printf '%s  %s\n' \
  85b8c37a406d862e656ad4ec14be9f6ce474c1b436b9615e91a55208aced3f44 "$bootstrap_zip" \
  e10490ea2926510c0c0cdeb1ae09109d62d07ddb7c209dc510b53724f71d840c "$cc1_zip" |
  sha256sum --check --strict

work=$(mktemp -d /tmp/sireum-cosmocc.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
bootstrap="$work/bootstrap"
rebuilt="$work/rebuilt"
sdk="$work/sdk"
unzip -q "$bootstrap_zip" -d "$bootstrap"
unzip -q "$cc1_zip" -d "$rebuilt"
(cd "$rebuilt" && sha256sum --check --strict SHA256SUMS)

notices="$sdk/share/sireum-cosmopolitan/cc1-rebuild"
mkdir -p "$sdk/bin" "$notices"
cp -a "$bootstrap/libexec" "$bootstrap/lib" "$sdk/"
cp -a "$bootstrap/bin/clang-format" "$sdk/bin/"
cp -a "$rebuilt/README.md" "$rebuilt/SHA256SUMS" "$rebuilt/source" "$notices/"
for arch in x86_64 aarch64; do
  cp -a "$bootstrap/bin/$arch-linux-cosmo-"* "$sdk/bin/"
  cc1="libexec/gcc/$arch-linux-cosmo/14.1.0/cc1"
  install -m 755 "$rebuilt/$cc1" "$sdk/$cc1"
  lib="$sdk/$arch-linux-cosmo/lib"
  mkdir -p "$lib"
  for archive in "$bootstrap/$arch-linux-cosmo/lib/"*.a; do
    case "${archive##*/}" in
      libcosmo.a|libcxx.a) ;;
      *) cp -a "$archive" "$lib/" ;;
    esac
  done
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
