#!/bin/sh

FILE="$1"
[ -n "$FILE" ] || FILE=checkdupls.found.dup
cat "$FILE" | sort -u | sort -k4 -n
