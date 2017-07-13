#!/usr/bin/env bash

# Install swiftlint if necessary
if ! which swiftlint >/dev/null; then
    brew install swiftlint
fi

# Run Swiftlint
swiftlint version
echo "Here comes the output of Swiftlint"
swiftlint