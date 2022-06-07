#!/bin/bash

TARGET=$1

cd "$(dirname "$0")"

cd web

if [[ -z "$TARGET" ]]; then
    currentlinktarget=`readlink -f index.html`
    if [[ "$currentlinktarget" == *"index_normal.html"* ]]; then
        TARGET="extension"
    else
        # This means if index.html doesn't exist, we'll also default to web.
        TARGET="web"
    fi
fi

if [[ "$TARGET" == "regular" ]]; then
    TARGET="web"
fi

if [[ "$TARGET" =~ ^(web|extension) ]]; then
    echo "Switching to $TARGET"
    rm -f index.html
    rm -f manifest.json
fi

if [[ "$TARGET" == "web" ]]; then
    ln -s index_normal.html index.html
    ln -s manifest_normal.json manifest.json
elif [[ "$TARGET" == "extension" ]]; then
    ln -s index_extension.html index.html
    ln -s manifest_extension.json manifest.json
else
    >&2 echo "ERROR: Invalid target: $TARGET"
    exit 1
fi