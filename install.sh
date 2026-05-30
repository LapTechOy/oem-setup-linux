#!/bin/bash
# Wrapper rootissa, delegoi  install/install.sh tiedostoon varsinaisen logiikan
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/install/install.sh"
