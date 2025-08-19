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

yum install -y git gcc wget make

wget https://golang.org/dl/go$GO_VERSION.linux-ppc64le.tar.gz
tar -C /usr/local -xvzf go$GO_VERSION.linux-ppc64le.tar.gz
rm -f go$GO_VERSION.linux-ppc64le.tar.gz
mkdir -p $HOME/go/src $HOME/go/bin $HOME/go/pkg
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# -----------------------------------------------------------------------------
# Image name sanitization + fail-fast docker pull
# -----------------------------------------------------------------------------
if [ -n "$DOCKER_IMAGE" ]; then
  # Replace space with colon (e.g., "ubi9 wildfly" -> "ubi9:wildfly")
  VALIDATED_IMAGE_NAME=$(echo "$DOCKER_IMAGE" | sed 's/ /:/')
  export VALIDATED_IMAGE_NAME

  echo "[INFO] Validated Docker image: $VALIDATED_IMAGE_NAME"

  echo "[CHECK] Pulling Docker image: $VALIDATED_IMAGE_NAME"
  if ! docker pull "$VALIDATED_IMAGE_NAME"; then
    echo "[ERROR] Docker image not found or inaccessible: $VALIDATED_IMAGE_NAME"
    exit 1
  fi
  echo "[OK] Docker image is available: $VALIDATED_IMAGE_NAME"
fi

# -----------------------------------------------------------------------------
echo "Clone wildfly operator package"
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

# e2e tests have dependency on below images which are not available for Power -
# quay.io/operator-framework/scorecard-test:v1.3.1
# quay.io/wildfly-quickstarts/wildfly-operator-quickstart:bootable-21.0
# quay.io/wildfly-quickstarts/clusterbench:latest
#
# Minikube setup is required for E2E tests execution, commenting this as minikube
# doesn’t work within container.
# Steps for Minikube Setup -
# 1. curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-ppc64le
# 2. sudo install minikube-linux-ppc64le /usr/local/bin/minikube
# 3. minikube start --driver=docker
# 4. minikube status
#
# For E2E tests run -
# eval $(minikube -p minikube docker-env) && make test-e2e-minikube
