#!/usr/bin/env bash
set -euo pipefail

bootstrap_zip=$(realpath -- "${1:?Usage: package-sireum.sh BOOTSTRAP_ZIP OUTPUT_ZIP}")
output_zip=$(realpath -m -- "${2:?Usage: package-sireum.sh BOOTSTRAP_ZIP OUTPUT_ZIP}")
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
test ! -e "$output_zip"

printf '%s  %s\n' 04043f480ae3c39436f4ed82a3205cab285de8d9750faab6f4c6a3f8fe354f38 "$bootstrap_zip" |
  sha256sum --check --strict

work=$(mktemp -d /tmp/sireum-cosmocc.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
bootstrap="$work/bootstrap"
sdk="$work/sdk"
unzip -q "$bootstrap_zip" -d "$bootstrap"

mkdir -p "$sdk/bin" "$sdk/share/sireum-cosmopolitan"
cp -a "$bootstrap/libexec" "$bootstrap/lib" "$sdk/"
cp -a "$bootstrap/bin/clang-format" "$sdk/bin/"
cp -a "$bootstrap/share/sireum-cosmopolitan/cc1-rebuild" "$sdk/share/sireum-cosmopolitan/"
for arch in x86_64 aarch64; do
  cp -a "$bootstrap/bin/$arch-linux-cosmo-"* "$sdk/bin/"
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
  cmp "$bootstrap/$cc1" "$sdk/$cc1"
  sha256sum "$sdk/$cc1"
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

cd "$sdk"
bsdtar -a -cf "$work/cosmocc.zip" .
unzip -tq "$work/cosmocc.zip"
mv -T --no-clobber "$work/cosmocc.zip" "$output_zip"
test ! -e "$work/cosmocc.zip"
