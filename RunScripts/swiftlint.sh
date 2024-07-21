#!/bin/sh

# PATH in new macOS versions doesn't include path where rdlint is installed.
# Homebrew on Macs with Apple Silicon is installed into a new location which isn't included into PATH
export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin

if which swiftlint > /dev/null; then
    swiftlint --strict
else
    echo "error: SwiftLint is not installed. Follow instructions here: https://readdle-c.atlassian.net/wiki/spaces/DOC/pages/3778871338/How+to+build+the+RD2+project"
    exit 1
fi
