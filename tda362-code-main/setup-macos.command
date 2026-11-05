#!/bin/bash
# Finder launcher: keep Terminal open so students can read errors and instructions.
cd "$(dirname "$0")" || exit 1
/bin/bash ./setup-macos.sh "$@"
setup_status=$?
printf '\n'
if [[ "$setup_status" != 0 ]]; then
    echo "Setup did not finish. Read the message above; run this file again after fixing the problem."
fi
if [[ -t 0 ]]; then read -r -p "Press Return to close this setup session. " answer; fi
exit "$setup_status"
