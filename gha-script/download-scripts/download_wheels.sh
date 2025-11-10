#!/bin/bash -e

validate_build_script=$VALIDATE_BUILD_SCRIPT
cloned_package=$CLONED_PACKAGE
mkdir -p package-cache/wheels

echo "Requesting IAM token..."
token_request=$(curl -s -X POST https://iam.cloud.ibm.com/identity/token \
  -H "content-type: application/x-www-form-urlencoded" \
  -H "accept: application/json" \
  -d "grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey&apikey=$GHA_CURRENCY_SERVICE_ID_API_KEY")

error_code=$(echo "$token_request" | jq -r '.errorCode // empty')

if [[ -z "$error_code" ]]; then
    token=$(echo "$token_request" | jq -r '.access_token')
    if [[ -z "$token" || "$token" == "null" ]]; then
        echo "Error: Failed to retrieve access token."
        exit 1
    fi

    bucket_url="https://s3.us.cloud-object-storage.appdomain.cloud/ose-power-artifacts-stag"
    echo "Fetching wheel list from COS for $PACKAGE_NAME/$VERSION/ ..."

    curl -s -H "Authorization: bearer $token" \
      "$bucket_url?list-type=2&prefix=$PACKAGE_NAME/$VERSION/" \
      | grep -oP '(?<=<Key>)[^<]*\.whl' > wheels_list.txt || true

    if [[ ! -s wheels_list.txt ]]; then
        echo "Listing available objects for debugging..."
        curl -s -H "Authorization: bearer $token" \
          "$bucket_url?list-type=2&prefix=$PACKAGE_NAME/" \
          | grep -oP '(?<=<Key>)[^<]*' | head -n 20 || true
        exit 1
    fi

    echo "Found wheels:"
    cat wheels_list.txt

    echo "---------------------------------------------------------"
    while read -r wheel; do
        echo "Downloading wheel: $(basename "$wheel")"
        curl -s -H "Authorization: bearer $token" \
          -o "package-cache/wheels/$(basename "$wheel")" \
          "$bucket_url/$wheel"
    done < wheels_list.txt
    echo "---------------------------------------------------------"

    ls -lh package-cache/wheels
    echo "---------------------------------------------------------"
else
    echo "Message: $(echo "$token_request" | jq -r '.errorMessage // "Unknown error"')"
    exit 1
fi
