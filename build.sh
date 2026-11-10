#!/bin/sh
set -e
cd "$(dirname "$0")"
swiftc -O main.swift -o ikb-cursor
echo "built: $(pwd)/ikb-cursor"
