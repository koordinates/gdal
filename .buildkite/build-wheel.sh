#!/usr/bin/bash
set -eu

echo "--- Building wheel for GDAL ${GDAL_PY_VERSION}"

apt-get update
apt-get install -qy build-focal/libgdal*.deb
pushd gdal/swig/python
perl -pi -e "s/^version = .*/version = '${GDAL_PY_VERSION}'"
python setup.py bdist_wheel
popd
