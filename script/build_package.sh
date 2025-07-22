#!/bin/bash -e

# Update system and install required packages
sudo apt update -y && sudo apt-get install file -y

# Install required Python packages
pip3 install --force-reinstall -v "requests==2.31.0"
pip3 install --upgrade docker

echo "Running build script execution in background for ${PKG_DIR_PATH}${BUILD_SCRIPT} ${VERSION}"
echo "*************************************************************************************"

docker_image=""

# Default TESTED_ON to UBI 9.3 if not provided
if [[ -z "$TESTED_ON" ]]; then
  TESTED_ON="UBI:9.3"
fi

# Extract UBI version from TESTED_ON
ubi_version=$(echo "$TESTED_ON" | grep -oE '[0-9]+\.[0-9]+' || echo "9.3")

# Function to build a non-root Docker image
docker_build_non_root() {
  echo "Building Docker image for non-root user build"
  docker build --build-arg BASE_IMAGE="$1" -t docker_non_root_image -f script/dockerfile_non_root .
  docker_image="docker_non_root_image"
}

# Determine which base image to use
if [[ "$TESTED_ON" == UBI:9* || "$TESTED_ON" == UBI9* ]]; then
    docker_image="registry.access.redhat.com/ubi9/ubi:$ubi_version"
else
    echo "WARNING: Unsupported or missing TESTED_ON value '$TESTED_ON'. Defaulting to UBI 9.3."
    docker_image="registry.access.redhat.com/ubi9/ubi:9.3"
    ubi_version="9.3"
fi

# Pull the Docker image
docker pull "$docker_image"

# Build non-root Docker image if required
if [[ "$NON_ROOT_BUILD" == "true" ]]; then
    docker_build_non_root "$docker_image"
fi

# Run the validation script
python3 script/validate_builds_currency.py "${PKG_DIR_PATH}${BUILD_SCRIPT}" "$VERSION" "$docker_image" > build_log &

SCRIPT_PID=$!
while ps -p $SCRIPT_PID > /dev/null
do 
  echo "$SCRIPT_PID is running"
  sleep 100
done

wait $SCRIPT_PID
my_pid_status=$?
build_size=$(stat -c %s build_log)

if [ $my_pid_status != 0 ]; then
    echo "Script execution failed for ${PKG_DIR_PATH}${BUILD_SCRIPT} ${VERSION}"
    echo "*************************************************************************************"
    if [ $build_size -lt 1800000 ]; then
       cat build_log
    else
       tail -100 build_log
    fi
    exit 1
else
    echo "Script execution completed successfully for ${PKG_DIR_PATH}${BUILD_SCRIPT} ${VERSION}"
    echo "*************************************************************************************"
    if [ $build_size -lt 1800000 ]; then
       cat build_log
    else
       tail -100 build_log
    fi    
fi

exit 0
