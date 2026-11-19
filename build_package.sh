#!/usr/bin/env bash
# Genera los dos artefactos de publicación:
#   org.cesar.iaquota.plasmoid        -> instalable con doble clic / kpackagetool6
#   org.cesar.iaquota-store.tar.gz    -> subible a store.kde.org
set -euo pipefail
cd "$(dirname "$0")"

rm -f org.cesar.iaquota.plasmoid org.cesar.iaquota-store.tar.gz

python3 - <<'PY'
import os, zipfile
files = ["metadata.json"]
for dp, dn, fn in os.walk("contents"):
    dn[:] = [d for d in dn if d != "__pycache__"]
    for f in fn:
        if f.endswith((".pyc", ".tmp")):
            continue
        files.append(os.path.join(dp, f))
with zipfile.ZipFile("org.cesar.iaquota.plasmoid", "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(files):
        z.write(f)
print("plasmoid:", len(files), "archivos")
PY

rm -rf build
mkdir -p build/org.cesar.iaquota
cp metadata.json build/org.cesar.iaquota/
rsync -a --exclude __pycache__ --exclude '*.pyc' contents/ build/org.cesar.iaquota/contents/
tar czf org.cesar.iaquota-store.tar.gz -C build org.cesar.iaquota
rm -rf build
echo "store tar.gz: $(tar tzf org.cesar.iaquota-store.tar.gz | wc -l) entradas"
