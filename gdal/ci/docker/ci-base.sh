#!/bin/bash
set -e

if [ -z "${CCACHE_DIR}" ]; then
    if [ -d "/ccache" ]; then
        export CCACHE_DIR=/ccache
    else
        echo "WARNING: It's highly recommended to mount a ccache directory from the host via '-v /tmp/ccache:/ccache'"
    fi
fi

if [ ! -d "/src" ]; then
    echo "ERROR: Need to mount the source tree to /src via '-v $(pwd):/src'"
    exit 1
fi

exec /bin/bash "$@"
