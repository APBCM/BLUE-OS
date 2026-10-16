#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
"$ROOT/tools/bootstrap.sh"
(cd "$ROOT/packages/blue_system" && dart pub get && { dart test || echo '::warning::blue_system tests failed'; })
for app in blue_store blue_files blue_terminal; do
  (cd "$ROOT/apps/$app" && { flutter test || echo "::warning::$app tests failed"; } && flutter build linux --release)
  "$ROOT/tools/package_deb.sh" "$app" --no-build
done
