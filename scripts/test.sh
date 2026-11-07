#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

exec bats tests/core plugins/devhost/tests tests/integration
