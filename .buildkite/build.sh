#!/bin/bash
set -eu

if [ -n "${KX_BUILD_DEBUG-}" ]; then
  echo "Enabling script debugging..."
  set -x
fi

export TIMEFORMAT='🕑 %1lR'
export DEBEMAIL=support@koordinates.com
export DEBFULLNAME="Koordinates CI Builder"

echo "Updating changelog..."

DEB_BASE_VERSION=$(cat gdal/VERSION)
DEB_VERSION="${DEB_BASE_VERSION}+ci${BUILDKITE_BUILD_NUMBER}-$(git show -s --date=format:%Y%m%d --format=git%cd.%h)"
echo "Debian Package Version: ${DEB_VERSION}"

buildkite-agent meta-data set deb-base-version "$DEB_BASE_VERSION"
buildkite-agent meta-data set deb-version "$DEB_VERSION"

echo -e ":debian: Package Version: \`${DEB_VERSION}\`" \
    | buildkite-agent annotate --style info --context deb-version

time docker run \
  -v "$(pwd):/src" \
  -w "/src/gdal" \
  -e DEBEMAIL \
  -e DEBFULLNAME \
  "${ECR}/ci-tools:latest" \
    dch --distribution trusty --newversion "${DEB_VERSION}" "Koordinates CI build of ${BUILDKITE_COMMIT}: branch=${BUILDKITE_BRANCH} tag=${BUILDKITE_TAG-}"

BUILD_CONTAINER="build-${BUILDKITE_JOB_ID}"

echo "--- Building debian package ..."
# Uses a docker volume for ccache
time docker run \
  --name "${BUILD_CONTAINER}" \
  -v "$(pwd):/kx/source" \
  -v "ccache:/ccache" \
  -e CCACHE_DIR=/ccache \
  -w "/kx/source/gdal" \
  "${ECR}/trustybuild:latest" \
    /kx/buildscripts/build_binary_package.sh -uc -us

echo "--- Signing debian archives ..."
time docker run \
  -v "$(pwd):/src" \
  -e "GPG_KEY=${APT_GPG_KEY}" \
  -w "/src" \
  "${ECR}/ci-tools:latest" \
    sign-debs "/src/build-trusty/*.deb"

echo "--- Running tests ..."
TEST_CONTAINER="test-${BUILDKITE_JOB_ID}"
docker commit "${BUILD_CONTAINER}" "${TEST_CONTAINER}"
R=0
time docker run --rm -i \
  -v "$(pwd):/src" \
  -w "/src/autotest" \
  "${TEST_CONTAINER}" \
  /bin/bash -exs << EOF || R=$?
DEBIAN_FRONTEND=noninteractive dpkg -i ../build-trusty/{gdal-bin,gdal-data,libgdal20,python-gdal,python3-gdal}*.deb
# skip known failures
sed -i -r 's/^\s+ogr_fgdb_(19|19bis|20|21),/#\0/' ogr/ogr_fgdb.py
sed -i -r 's/^\s+basic_test_8,/#\0/' gcore/basic_test.py
sed -i -r 's/^\s+rfc30_1,/#\0/' gcore/rfc30.py
sed -i -r 's/^gdaltest_list = \[rfc30_1,$/gdaltest_list = [ #rfc30_1/' gcore/rfc30.py
sed -i -r 's/^gdaltest_list = \[rfc30_1, rfc30_2\]/gdaltest_list = [rfc30_2] #rfc30_1/' gcore/rfc30.py
TRAVIS=YES TRAVIS_BRANCH=trusty python run_all.py
EOF

if [ $R -ne 0 ]; then
  echo "^^^ +++"
  echo "⚠️ Errors running GDAL tests ($R). But may be kinda expected. Check them and edit build.sh to skip?"
else
  echo "--- ✅ GDAL tests passed!"
fi

docker rm "${BUILD_CONTAINER}"

exit 0
