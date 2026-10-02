#!/usr/bin/env bash
set -euo pipefail
if ! grep -qw 'boot=casper' /proc/cmdline; then
    zenity --error --title='Install Blue OS' --text='The installer is only available in the Live session.'
    exit 1
fi
exec sudo -E /usr/bin/calamares
