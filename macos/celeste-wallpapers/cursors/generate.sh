#!/bin/zsh
set -euo pipefail

root=${0:A:h}
/usr/bin/python3 "$root/generate.py"
