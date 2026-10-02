#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'Use x86_64 Linux.' >&2; exit 1; }
command -v flutter >/dev/null || { echo 'Install Flutter 3.x stable first.' >&2; exit 1; }
flutter config --enable-linux-desktop
for app in blue_store blue_files blue_terminal; do
  cd "$ROOT/apps/$app"
  if [[ ! -f linux/CMakeLists.txt ]]; then
    flutter create --platforms=linux --project-name "$app" --no-pub --empty .
  fi
  flutter pub get
done
