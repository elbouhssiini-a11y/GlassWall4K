#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

HOST="127.0.0.1"
PORT="5180"
URL="http://${HOST}:${PORT}"

if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Wallora Glass Admin: port ${PORT} deja mashghol."
  echo "Ma nftehsh browser. Hawd l-process li kaymlk l-port:"
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN
  exit 1
fi

echo "Wallora Glass Admin: ${URL}"
exec npm run open
