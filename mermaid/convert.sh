#!/usr/bin/env bash
set -euo pipefail

for f in *.mmd; do
  echo "Converting $f..."
  mmdc -i "$f" -o "${f%.mmd}.pdf" -b transparent --configFile config.json --pdfFit
  mmdc -i "$f" -o "${f%.mmd}.png" -b transparent --configFile config.json
done
