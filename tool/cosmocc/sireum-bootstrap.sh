stage_stock_toolchain() {
  local archive=$1 bootstrap=$2 sdk=$3 arch archive_path lib
  printf '%s  %s\n' \
    85b8c37a406d862e656ad4ec14be9f6ce474c1b436b9615e91a55208aced3f44 "$archive" |
    sha256sum --check --strict
  unzip -q "$archive" -d "$bootstrap"

  mkdir -p "$sdk/bin"
  cp -a "$bootstrap/libexec" "$bootstrap/lib" "$sdk/"
  cp -a "$bootstrap/bin/clang-format" "$sdk/bin/"
  for arch in x86_64 aarch64; do
    cp -a "$bootstrap/bin/$arch-linux-cosmo-"* "$sdk/bin/"
    lib="$sdk/$arch-linux-cosmo/lib"
    mkdir -p "$lib"
    for archive_path in "$bootstrap/$arch-linux-cosmo/lib/"*.a; do
      case "${archive_path##*/}" in
        libcosmo.a|libcxx.a) ;;
        *) cp -a "$archive_path" "$lib/" ;;
      esac
    done
  done
}
