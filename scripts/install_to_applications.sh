#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
"$DIR/scripts/package_app.sh" --install "$@"
