#!/bin/bash
# attempt to work around gdal-data deb getting corrupted when we download
# two of them from the two arch builds at the same time.
# This is a likely bug in buildkite agent
# TODO: ticket it
mkdir collated
for dir in build-*; do
    echo "$dir"
    mv "$dir"/*.deb collated/
done

aptly-upload \
    --aptly-url https://apt-repo.kx.gd \
    --retries 3 \
    --repo kx-builds-jammy \
    --series jammy \
    collated/*.deb
