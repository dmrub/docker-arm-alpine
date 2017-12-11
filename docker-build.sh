#!/bin/bash

set -e

export LC_ALL=C
unset CDPATH

THIS_DIR=$( (cd "$(dirname -- "$BASH_SOURCE")" && pwd -P) )

exec "$THIS_DIR/docker-generate.sh" --build "$@"
