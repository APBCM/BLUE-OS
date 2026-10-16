#!/usr/bin/env bash
set -euo pipefail
if [[ -x /opt/blueos/blue_store/blue_store ]]; then
    exec /opt/blueos/blue_store/blue_store
fi
exec plasma-discover
