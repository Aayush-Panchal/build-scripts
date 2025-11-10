#!/bin/bash -e

FILE_NAME=$1

if [[ -z "$FILE_NAME" ]]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

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

    echo "Downloading $FILE_NAME from COS..."
    curl -s -X GET -H "Authorization: bearer $token" \
      -o "$FILE_NAME" \
      "https://s3.us.cloud-object-storage.appdomain.cloud/ose-power-toolci-bucket-stag/$PACKAGE_NAME/$VERSION/$FILE_NAME"

else
    echo "Message: $(echo "$token_request" | jq -r '.errorMessage // "Unknown error"')"
    exit 1
fi
