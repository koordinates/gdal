#!/bin/bash
set -e

if [ -n "${KX_BUILD_DEBUG-}" ]; then
  log "Enabling script debugging..."
  set -x
fi

DEB_BASE_VERSION="$(buildkite-agent metadata get deb-base-version)"
if [ -z "${DEB_BASE_VERSION}" ]; then
    echo "Missing deb-base-version: ${DEB_BASE_VERSION}"
    exit 2
elif [ "${BUILDKITE_COMMIT}" = "HEAD" ]; then
    echo "Invalid BUILDKITE_COMMIT: ${BUILDKITE_COMMIT}"
    exit 2
fi

hub release create \
    -t "${BUILDKITE_COMMIT}" \
    -m "CI: ${BUILDKITE_BRANCH}" \
    "kx-release-${DEB_BASE_VERSION}+ci${BUILDKITE_BUILD_NUMBER}"
