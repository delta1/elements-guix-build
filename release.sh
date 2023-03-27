#!/bin/bash

# cat all the txt files together and remove the duplicate lines with awk
# https://stackoverflow.com/questions/11532157/remove-duplicate-lines-without-sorting

find output/ -type f -name "*.txt" | xargs cat | awk '!x[$0]++' | tee sha256sums.txt

mkdir -p release

# mv the release files

find output/ -type f -iregex ".*.\(gz\|zip\|exe\|dmg\)" -exec mv -t release {} +
cp sha256sums.txt release

# create github release

gh release create "$BUILD_TAG" --title "$BUILD_TAG" --notes-file sha256sums.txt release/*
