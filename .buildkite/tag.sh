#!/bin/bash
set -eu

if [ -n "${KX_BUILD_DEBUG-}" ]; then
  echo "Enabling script debugging..."
  set -x
fi

DEB_BASE_VERSION="$(buildkite-agent meta-data get deb-base-version)"
if [ -z "${DEB_BASE_VERSION}" ]; then
    echo "Missing deb-base-version: ${DEB_BASE_VERSION}"
    exit 2
elif [ "${BUILDKITE_COMMIT}" = "HEAD" ]; then
    echo "Invalid BUILDKITE_COMMIT: ${BUILDKITE_COMMIT}"
    exit 2
fi

TAG="kx-release-${DEB_BASE_VERSION}+ci${BUILDKITE_BUILD_NUMBER}"
echo "Creating tag: ${TAG} for ${BUILDKITE_COMMIT} ..."

hub release create \
    -t "${BUILDKITE_COMMIT}" \
    -m "CI: ${BUILDKITE_BRANCH}.${BUILDKITE_BUILD_NUMBER}" \
    "${TAG}"

echo -e ":git: Git Tag: \`${TAG}\`" \
    | buildkite-agent annotate --style info --context git-tag
