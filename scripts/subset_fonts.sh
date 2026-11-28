#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v uv >/dev/null 2>&1; then
  exec uv run --with fonttools python3 scripts/subset_fonts.py
elif python3 -c "import fontTools" >/dev/null 2>&1; then
  exec python3 scripts/subset_fonts.py
else
  echo "Install 'uv' (brew install uv) or 'fonttools' (pip3 install fonttools) to run font subsetting." >&2
  exit 1
fi
