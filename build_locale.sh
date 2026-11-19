#!/usr/bin/env bash
# Regenera po/*.po -> contents/locale/<locale>/LC_MESSAGES/*.mo
# Fuente única de traducción: el generador del proyecto (gen_i18n).
set -euo pipefail
cd "$(dirname "$0")"
python3 tools/gen_i18n.py
