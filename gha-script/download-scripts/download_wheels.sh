#!/bin/bash -e

validate_build_script=$VALIDATE_BUILD_SCRIPT
cloned_package=$CLONED_PACKAGE
mkdir -p package-cache/wheels
token_request=$(curl -X POST https://iam.cloud.ibm.com/identity/token \
  -H "content-type: application/x-www-form-urlencoded" \
  -H "accept: application/json" \
  -d "grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey&apikey=$GHA_CURRENCY_SERVICE_ID_API_KEY")

if [[ $(echo "$token_request" | jq -r '.errorCode') == "null" ]]; then
    token=$(echo "$token_request" | jq -r '.access_token')
    echo "Fetching wheel list from COS..."
    curl -s -H "Authorization: bearer $token" \
      "https://s3.us.cloud-object-storage.appdomain.cloud/ose-power-artifacts-production?list-type=2&prefix=$PACKAGE_NAME/$VERSION/" \
      | grep -oP '(?<=<Key>)[^<]*\.whl' > wheels_list.txt

    while read wheel; do
      echo "Downloading wheel: $wheel"
      curl -s -H "Authorization: bearer $token" \
        -o "package-cache/wheels/$(basename "$wheel")" \
        "https://s3.us.cloud-object-storage.appdomain.cloud/ose-power-artifacts-production/$wheel"
    done < wheels_list.txt

    echo "All wheels downloaded successfully."
    ls package-cache/wheels
else
    echo "Error: Token request failed. Response: $token_request"
    exit 1
fi
