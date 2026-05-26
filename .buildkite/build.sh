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

DEB_BASE_VERSION=$(cat VERSION)
DEB_VERSION="${DEB_BASE_VERSION}+kx-ci${BUILDKITE_BUILD_NUMBER}-$(git show -s --date=format:%Y%m%d --format=git%cd.%h)"
echo "Debian Package Version: ${DEB_VERSION}"

if [ -n "${BUILDKITE_AGENT_ACCESS_TOKEN-}" ]; then
  buildkite-agent meta-data set deb-base-version "$DEB_BASE_VERSION"
  buildkite-agent meta-data set deb-version "$DEB_VERSION"

  echo -e ":debian: Package Version: \`${DEB_VERSION}\`" |
    buildkite-agent annotate --style info --context deb-version
fi

time docker run \
  -v "$(pwd):/src" \
  -w "/src" \
  -e DEBEMAIL \
  -e DEBFULLNAME \
  "${ECR}/ci-tools:latest" \
  dch --distribution trixie --newversion "${DEB_VERSION}" "Koordinates CI build of ${BUILDKITE_COMMIT}: branch=${BUILDKITE_BRANCH} tag=${BUILDKITE_TAG-}"

BUILD_CONTAINER="build-${BUILDKITE_JOB_ID}"

# the autotest tests don't work, because there's no pytest in the build environment.
# so we copy the ubuntugis approach of just removing them.
# the gdal fuzzer tests still run (fuzzers/tests)
rm -rf ./autotest

echo "--- Building debian packages ..."
# Uses a docker volume for ccache
time docker run \
  --name "${BUILD_CONTAINER}" \
  -v "$(pwd):/kx/source" \
  -v "ccache:/ccache" \
  -e CCACHE_DIR=/ccache \
  -w "/kx/source" \
  "${ECR}/trixiebuild:master.latest" \
  /kx/buildscripts/build_binary_package.sh -uc -us

echo "--- Signing debian archives ..."
time docker run \
  -v "$(pwd):/src" \
  -e "GPG_KEY=${APT_GPG_KEY}" \
  -w "/src" \
  "${ECR}/ci-tools:latest" \
  sign-debs "/src/build-trixie/*.deb"

mv build-trixie "build-${BUILDKITE_JOB_ID}"
