#!/bin/bash
#
# Build GDAL Python wheel against installed libgdal from deb packages.
# Runs inside kx-base-py314-build container via docker plugin.
#
# Expects deb artifacts to be downloaded (via artifacts plugin) into build-*/.
# Installs the debs, runs SWIG to generate Python bindings, then builds a
# wheel that links against the installed libgdal.
#
set -eu

if [ -n "${KX_BUILD_DEBUG-}" ]; then
  set -x
fi

PYTHON=/opt/python/bin/python3
SRCDIR=/src
WORKDIR=$(mktemp -d)

echo "--- Installing GDAL deb packages ..."
apt-get update -qq
dpkg -i ${SRCDIR}/build-*/*.deb 2>/dev/null || apt-get install -f -y -qq

echo "--- Installing build dependencies ..."
apt-get install -y -qq swig

echo "--- Installing Python build dependencies ..."
${PYTHON} -m pip install --quiet --index-url https://pypi.org/simple/ numpy setuptools wheel

echo "--- Generating SWIG wrappers ..."
SWIG_ARGS="-Wall -I${SRCDIR}/swig/include -I${SRCDIR}/swig/include/python -I${SRCDIR}/swig/include/python/docs -threads -relativeimport"

SWIG_VERSION=$(swig -version | grep "SWIG Version" | awk '{print $3}')
if dpkg --compare-versions "${SWIG_VERSION}" lt "4.1"; then
  SWIG_ARGS="${SWIG_ARGS} -py3"
fi

mkdir -p "${WORKDIR}/extensions" "${WORKDIR}/osgeo"

swig ${SWIG_ARGS} -python -outdir "${WORKDIR}/osgeo" \
  -o "${WORKDIR}/extensions/gdalconst_wrap.c" \
  "${SRCDIR}/swig/include/gdalconst.i"

for mod in gdal ogr osr gnm; do
  swig ${SWIG_ARGS} -c++ -python -outdir "${WORKDIR}/osgeo" \
    -o "${WORKDIR}/extensions/${mod}_wrap.cpp" \
    "${SRCDIR}/swig/include/${mod}.i"
done

swig ${SWIG_ARGS} -I${SRCDIR}/gdal -c++ -python -outdir "${WORKDIR}/osgeo" \
  -o "${WORKDIR}/extensions/gdal_array_wrap.cpp" \
  "${SRCDIR}/swig/include/gdal_array.i"

echo "--- Patching SWIG output ..."
for f in "${WORKDIR}/extensions"/*.cpp "${WORKDIR}/extensions"/*.c; do
  cmake -DFILE="$f" -P "${SRCDIR}/swig/python/modify_cpp_files.cmake"
done

echo "--- Setting up wheel build directory ..."
cp "${SRCDIR}/swig/python/osgeo/__init__.py" "${WORKDIR}/osgeo/"
cp "${SRCDIR}/swig/python/osgeo/gdalnumeric.py" "${WORKDIR}/osgeo/"
ln -s "${SRCDIR}/swig/python/gdal-utils" "${WORKDIR}/gdal-utils"
cp "${SRCDIR}/swig/python/README.rst" "${WORKDIR}/"
cp "${SRCDIR}/swig/python/pyproject.toml" "${WORKDIR}/"

GDAL_VERSION=$(cat "${SRCDIR}/VERSION")
sed \
  -e "s|@GDAL_PYTHON_VERSION@|${GDAL_VERSION}|g" \
  -e "s|@PROJECT_BINARY_DIR@|/nonexistent|g" \
  -e "s|@PROJECT_SOURCE_DIR@|${SRCDIR}|g" \
  -e "s|@GDAL_LIB_DIR@||g" \
  -e "s|@GDAL_LIB_OUTPUT_NAME@|gdal|g" \
  -e "s|@GNM_ENABLED@|True|g" \
  -e "s|extras_require={'numpy': \['numpy > 1.0.0'\]}|install_requires=['numpy>=2.0,<3']|g" \
  "${SRCDIR}/swig/python/setup.py.in" > "${WORKDIR}/setup.py"

echo "--- Building wheel ..."
cd "${WORKDIR}"
${PYTHON} setup.py bdist_wheel

echo "--- Copying wheel to output ..."
mkdir -p "${SRCDIR}/dist"
cp "${WORKDIR}/dist"/gdal-*.whl "${SRCDIR}/dist/"

echo "Done. Wheel:"
ls -la "${SRCDIR}/dist"/gdal-*.whl
