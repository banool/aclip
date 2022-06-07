perl -i -pe 's/^(version:\s+\d+\.\d+\.)(\d+)(\+)(\d+)$/$1.($2+1).$3.($4+1)/e' pubspec.yaml

version=`yq .version < pubspec.yaml | sed "s|\+.*||"`

jq .version="\"$version\"" < web/manifest_extension.json > /tmp/new.json

mv /tmp/new.json web/manifest_extension.json
