#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc Sources/ClickScheme.swift Sources/MouseClicker.swift Sources/SchemeManager.swift \
    Tests/main.swift -o .build/ClickLoopTests \
    -framework Foundation -framework AppKit -framework CoreGraphics
.build/ClickLoopTests
