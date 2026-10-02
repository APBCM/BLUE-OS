#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP="${1:-}"
case "$APP" in blue_store|blue_files|blue_terminal) ;; *) echo 'Usage: tools/package_deb.sh blue_store|blue_files|blue_terminal [--no-build]' >&2; exit 2 ;; esac
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'Use x86_64 Linux.' >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo 'Install dpkg-dev.' >&2; exit 1; }
if [[ "${2:-}" != --no-build ]]; then
  "$ROOT/tools/bootstrap.sh"
  (cd "$ROOT/apps/$APP" && flutter build linux --release)
fi
SOURCE="$ROOT/apps/$APP/build/linux/x64/release/bundle"
[[ -x "$SOURCE/$APP" ]] || { echo "Missing release bundle: $SOURCE" >&2; exit 1; }
STAGE="$(mktemp -d "$ROOT/.blue-deb.XXXXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
mkdir -p "$STAGE/DEBIAN" "$STAGE/opt/blueos/$APP" "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/icons/hicolor/scalable/apps" "$ROOT/dist"
cp -a "$SOURCE/." "$STAGE/opt/blueos/$APP/"
case "$APP" in
  blue_store) LABEL='Blue Store'; EXTRA=', apt, pkexec'; CATEGORIES='System;PackageManager;' ;;
  blue_files) LABEL='Blue Files'; EXTRA=', libglib2.0-bin, xdg-utils'; CATEGORIES='System;FileManager;' ;;
  blue_terminal) LABEL='Blue Terminal'; EXTRA=', apt, pkexec, lsb-release'; CATEGORIES='System;TerminalEmulator;' ;;
esac
PACKAGE="blue-os-${APP#blue_}"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PACKAGE
Version: 0.1.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Blue OS Project <maintainers@example.invalid>
Depends: libgtk-3-0t64, libstdc++6, libglib2.0-0t64, libblkid1, liblzma5$EXTRA
Description: $LABEL desktop application for Blue OS
 Offline-capable Flutter desktop application.
EOF
cat > "$STAGE/usr/share/applications/$PACKAGE.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$LABEL
Exec=/opt/blueos/$APP/$APP
Icon=$PACKAGE
Terminal=false
Categories=$CATEGORIES
EOF
cp "$ROOT/apps/blue_store/assets/icons/placeholder.svg" "$STAGE/usr/share/icons/hicolor/scalable/apps/$PACKAGE.svg"
dpkg-deb --root-owner-group --build "$STAGE" "$ROOT/dist/${PACKAGE}_0.1.0_amd64.deb"
echo "Built dist/${PACKAGE}_0.1.0_amd64.deb"
