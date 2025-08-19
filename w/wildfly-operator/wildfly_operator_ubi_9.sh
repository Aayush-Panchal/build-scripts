#!/bin/bash -e
# -----------------------------------------------------------------------------
#
# Package       : wildfly-operator
# Version       : 1.1.3
# Source repo   : https://github.com/wildfly/wildfly-operator/
# Tested on     : UBI 9
# Language      : GO
# Travis-Check  : True
# Script License: Apache License, Version 2 or later
# Maintainer    : Mohit Sharma <Mohit.Sharma46@ibm.com>
#
# Disclaimer: This script has been tested in root mode on given
# ==========  platform using the mentioned version of the package.
#             It may not work as expected with newer versions of the
#             package and/or distribution. In such case, please
#             contact "Maintainer" of this script.
#
# ----------------------------------------------------------------------------
PACKAGE_NAME=wildfly-operator
PACKAGE_VERSION=${1:-1.1.3}
PACKAGE_URL=https://github.com/wildfly/wildfly-operator.git
export GO_VERSION=${GO_VERSION:-1.21.0}

### FIX START: Docker image name sanitization
# If script is invoked with an image name argument (e.g., "ubi9 wildfly"),
# ensure it is converted to proper format "ubi9:wildfly"
if [ -n "$3" ]; then
  RAW_IMAGE_NAME="$3"
  if [[ "$RAW_IMAGE_NAME" == *" "* ]]; then
    IMAGE_PART1=$(echo "$RAW_IMAGE_NAME" | awk '{print $1}')
    IMAGE_PART2=$(echo "$RAW_IMAGE_NAME" | awk '{print $2}')
    FIXED_IMAGE_NAME="${IMAGE_PART1}:${IMAGE_PART2}"
    echo "[FIX] Corrected Docker image name from '$RAW_IMAGE_NAME' to '$FIXED_IMAGE_NAME'"
    export VALIDATED_IMAGE_NAME="$FIXED_IMAGE_NAME"
  else
    export VALIDATED_IMAGE_NAME="$RAW_IMAGE_NAME"
  fi
  # Hard check for valid repo:tag format
  if [[ "$VALIDATED_IMAGE_NAME" != *":"* ]]; then
    echo "[ERROR] Invalid Docker image reference: $VALIDATED_IMAGE_NAME"
    echo "Expected format 'repository:tag'"
    exit 1
  fi
fi
### FIX END

yum install -y git gcc wget make

wget https://golang.org/dl/go$GO_VERSION.linux-ppc64le.tar.gz
tar -C /usr/local -xvzf go$GO_VERSION.linux-ppc64le.tar.gz
rm -f go$GO_VERSION.linux-ppc64le.tar.gz
mkdir -p $HOME/go
mkdir -p $HOME/go/src
mkdir -p $HOME/go/bin
mkdir -p $HOME/go/pkg
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

echo "clone wildfly operator package"
git clone $PACKAGE_URL $PACKAGE_NAME
cd $PACKAGE_NAME
git checkout $PACKAGE_VERSION

if ! make build; then
    echo "------------------$PACKAGE_NAME:build_fails---------------------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    exit 1
fi

# If build passes, run the unit tests
if ! make unit-test; then
    echo "------------------$PACKAGE_NAME:unit_test_fails-----------------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    exit 1
else
    echo "------------------$PACKAGE_NAME:unit_test_pass-----------------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME  | $PACKAGE_VERSION | $OS_NAME | GitHub  | Pass |  Install_and_Test_Success"
    exit 0
fi

# e2e tests have dependencies not available on Power, skipped.
