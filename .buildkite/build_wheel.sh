#!/bin/bash
#
# Build GDAL Python wheel from source.
# Runs inside kx-base-py314-build container.
#
# Does a minimal cmake build (core library + Python bindings only) to produce
# the wheel. At runtime the wheel's extensions load the full-featured libgdal
# from the deb install.
#
set -eu

if [ -n "${KX_BUILD_DEBUG-}" ]; then
  set -x
fi

PYTHON=/opt/python/bin/python3
NPROC=$(nproc)
SRCDIR=/kx/source

echo "--- Installing build dependencies ..."
apt-get update -qq
apt-get install -y -qq swig libproj-dev

echo "--- Installing Python build dependencies ..."
${PYTHON} -m pip install --quiet numpy setuptools wheel

echo "--- Configuring cmake (minimal, for Python wheel only) ..."
cmake -B "${SRCDIR}/build-wheel" -S "${SRCDIR}" \
  -DPython_ROOT_DIR=/opt/python \
  -DPython_EXECUTABLE=${PYTHON} \
  -DPython_LOOKUP_VERSION=3.14 \
  -DBUILD_PYTHON_BINDINGS=ON \
  -DBUILD_APPS=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_DOCS=OFF \
  -DGDAL_BUILD_OPTIONAL_DRIVERS=OFF \
  -DOGR_BUILD_OPTIONAL_DRIVERS=OFF \
  -DGDAL_USE_CURL=OFF \
  -DGDAL_USE_GEOS=OFF \
  -DGDAL_USE_GEOTIFF=OFF \
  -DGDAL_USE_JPEG=OFF \
  -DGDAL_USE_PNG=OFF \
  -DGDAL_USE_SQLITE3=OFF \
  -DGDAL_USE_TIFF=OFF \
  -DGDAL_USE_LZ4=OFF \
  -DGDAL_USE_ZSTD=OFF \
  -DGDAL_USE_ARROW=OFF \
  -DGDAL_HIDE_INTERNAL_SYMBOLS=OFF \
  -DCMAKE_CXX_STANDARD=20

echo "--- Building Python wheel ..."
cmake --build "${SRCDIR}/build-wheel" --target python_wheel -j${NPROC}

echo "--- Bundling numpy into wheel ..."
WHEEL_DIR="${SRCDIR}/build-wheel/swig/python/dist"
NUMPY_DIR=$(${PYTHON} -c "import numpy, os; print(os.path.dirname(numpy.__file__))")
${PYTHON} "${SRCDIR}/.buildkite/bundle_numpy_in_wheel.py" "${WHEEL_DIR}" "${NUMPY_DIR}"

echo "--- Copying wheel to output ..."
mkdir -p /kx/output
cp "${WHEEL_DIR}"/gdal-*.whl /kx/output/

echo "Done. Wheel:"
ls -la /kx/output/gdal-*.whl
