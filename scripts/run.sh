#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

# Build if needed
if [ ! -d "$DIR/WeatherBar.app" ]; then
    ./scripts/build_app.sh
fi

echo "Launching WeatherBar..."
open "$DIR/WeatherBar.app"
echo "WeatherBar is running in your menu bar next to the clock!"
