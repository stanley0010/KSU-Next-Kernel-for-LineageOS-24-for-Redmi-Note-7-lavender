#!/usr/bin/env bash
# Compatibility wrapper. Prefer ./ksu/build.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ksu/build.sh" "$@"
