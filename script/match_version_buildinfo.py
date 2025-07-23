import json
import os
import re

version = str(os.environ['VERSION'])
match_version = ""

# Load JSON
with open('build_info.json') as f:
    data = json.load(f)

# Search for matching version key
for key, value in data.items():
    subKeys = [subKey.strip() for subKey in key.split(',')]
    for subKey in subKeys:
        if subKey == version:
            match_version = key
            break
        # Convert wildcard to regex pattern
        regex_str = '^' + re.escape(subKey).replace("\\*", ".*") + '$'
        if re.fullmatch(regex_str, version):
            match_version = key
            break
    if match_version:
        break

print(match_version)
