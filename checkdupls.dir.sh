#!/bin/sh

ls -1 $1 | xargs -n1 ./checkdupls.sh
