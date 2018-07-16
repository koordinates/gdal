#!/bin/bash
set -e

cd /src
CMD=$1
if [ "${CMD}" = "build" ]; then
    # install.sh weirdness makes one-time run assumptions
    echo "=> Building..."
    rm -f /usr/bin/clang /usr/bin/clang++
    time /src/gdal/ci/travis/trusty_clang/install.sh "$@"

elif [ "${CMD}" = "test" ]; then
    echo "=> Testing..."
    time /src/gdal/ci/travis/trusty_clang/script.sh "$@"

elif [ "${CMD}" = "all" ]; then
    # install.sh weirdness makes one-time run assumptions
    echo "=> Building..."
    rm -f /usr/bin/clang /usr/bin/clang++
    time /src/gdal/ci/travis/trusty_clang/install.sh

    echo "=> Testing..."
    time /src/gdal/ci/travis/trusty_clang/script.sh

else
    echo "=> run with 'build'; 'test'; 'all'"
    exit 2

fi
