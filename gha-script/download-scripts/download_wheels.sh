#!/bin/bash -e

validate_build_script=$VALIDATE_BUILD_SCRIPT
cloned_package=$CLONED_PACKAGE
mkdir -p package-cache/wheels

# Request IAM token
token_request=$(curl -s -X POST https://iam.cloud.ibm.com/identity/token \
  -H "content-type: application/x-www-form-urlencoded" \
  -H "accept: application/json" \
  -d "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=$GHA_CURRENCY_SERVICE_ID_API_KEY")

if [[ $(echo "$token_request" | jq -r '.errorCode') == "null" ]]; then
    token=$(echo "$token_request" | jq -r '.access_token')
    echo "Fetching wheel list from COS..."

    base_url="https://s3.us.cloud-object-storage.appdomain.cloud/ose-power-artifacts-production"
    RAW_VERSION="$VERSION"
    CLEAN_VERSION="${VERSION#v}"

    # Try with the raw version first
    echo "🔍 Checking prefix: $PACKAGE_NAME/$RAW_VERSION/"
    curl -s -H "Authorization: bearer $token" \
      "${base_url}?list-type=2&prefix=$PACKAGE_NAME/$RAW_VERSION/" \
      | grep -oP '(?<=<Key>)[^<]*\.whl' > wheels_list.txt || true

    # If none found, retry without 'v'
    if [[ ! -s wheels_list.txt ]]; then
        echo "❌ No .whl found for $PACKAGE_NAME/$RAW_VERSION/ — retrying with cleaned version"
        echo "🔍 Checking prefix: $PACKAGE_NAME/$CLEAN_VERSION/"
        curl -s -H "Authorization: bearer $token" \
          "${base_url}?list-type=2&prefix=$PACKAGE_NAME/$CLEAN_VERSION/" \
          | grep -oP '(?<=<Key>)[^<]*\.whl' > wheels_list.txt || true
    fi

    # If still no wheels found, dump all keys under the package
    if [[ ! -s wheels_list.txt ]]; then
        echo "❌ No .whl files found in COS for either prefix:"
        echo "   - $PACKAGE_NAME/$RAW_VERSION/"
        echo "   - $PACKAGE_NAME/$CLEAN_VERSION/"
        echo "Dumping available keys under prefix $PACKAGE_NAME/ for debugging:"
        curl -s -H "Authorization: bearer $token" \
          "${base_url}?list-type=2&prefix=$PACKAGE_NAME/" \
          | grep -oP '(?<=<Key>)[^<]*' || true
        exit 1
    fi

    # Display found wheels
    echo "✅ Found the following wheels:"
    cat wheels_list.txt
    echo "---------------------------------------------------------"

    # Download the wheels
    while read -r wheel; do
      echo "⬇️  Downloading wheel: $wheel"
      curl -s -H "Authorization: bearer $token" \
        -o "package-cache/wheels/$(basename "$wheel")" \
        "${base_url}/$wheel"
    done < wheels_list.txt

    echo "---------------------------------------------------------"
    echo "✅ All wheels downloaded successfully."
    echo "Contents of package-cache/wheels:"
    ls -lh package-cache/wheels || echo "⚠️ No wheel files found!"
    echo "---------------------------------------------------------"
else
    echo "❌ Error: Token request failed. Response: $token_request"
    exit 1
fi
