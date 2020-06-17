#!/bin/bash
RELEASE_NAME=$1
# Branch of buildconf to use for CI
PKGSET_BRANCH=rock-osdeps

if [ "$PKG_PULL_REQUEST_SLUG"  != "" ]; then
    PACKAGE_SET_URL="https://github.com/${PKG_PULL_REQUEST_SLUG}"
    export PACKAGE_SET_URL
else
    PACKAGE_SET_URL="https://github.com/rock-core/rock-osdeps-package_set"
    export PACKAGE_SET_URL
fi

if [ "$PKG_PULL_REQUEST_BRANCH" != "" ]; then
    PACKAGE_SET_BRANCH="${PKG_PULL_REQUEST_BRANCH}"
else
    PACKAGE_SET_BRANCH="${PKG_BRANCH}"
    export PACKAGE_SET_BRANCH
fi

echo "Using package set url: ${PACKAGE_SET_URL}"
echo "Using branch: ${PACKAGE_SET_BRANCH}"

mkdir -p /home/docker/releases/$RELEASE_NAME
cd /home/docker/releases/$RELEASE_NAME
# Use the existing seed configuration
cp /home/docker/seed-config.yml seed-config.yml
echo "debian_release: $RELEASE_NAME" >> seed-config.yml

export AUTOPROJ_BOOTSTRAP_IGNORE_NONEMPTY_DIR=1
ruby /home/docker/autoproj_bootstrap git https://github.com/rock-core/rock-osdeps-buildconf.git branch=$PKGSET_BRANCH --seed-config=seed-config.yml

## Check if this a pull request and change to pull request
## accordingly
sed -i "s#__CI_URL__#${PACKAGE_SET_URL}#" autoproj/manifest
sed -i "s#__CI_BRANCH__#${PACKAGE_SET_BRANCH}#" autoproj/manifest

source env.sh
autoproj update
autoproj envsh
