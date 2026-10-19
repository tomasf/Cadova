#!/bin/bash
# Bundles the JavaScript libraries the web customizer's page uses into the generate-customizer
# plugin's template, from npm: three.js and browser_wasi_shim. Only the files the page imports are
# copied, with whatever they import in turn. Each library goes in a directory named after its
# version, so browsers can keep it cached across customizer updates.
#
# Usage: Scripts/update-customizer-libraries.sh THREE_VERSION WASI_SHIM_VERSION
#   e.g. Scripts/update-customizer-libraries.sh 0.170.0 0.4.2
#
# It also points the page's imports at the new versions and updates the libraries' license texts in
# the plugin's Support/licenses. Test the customizer afterwards: three.js changes its API now and then.

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 THREE_VERSION WASI_SHIM_VERSION" >&2
    exit 1
fi
three_version=$1
shim_version=$2

plugin="$(cd "$(dirname "$0")/.." && pwd)/Plugins/GenerateCustomizer"
template="$plugin/Template"
vendor="$template/vendor"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Downloads a package from npm, checks it against the registry's checksum, and unpacks it
fetch() {
    local name=$1 version=$2 directory=$3
    local metadata
    metadata=$(curl -fsSL "https://registry.npmjs.org/${name/\//%2f}/$version")
    local tarball integrity
    tarball=$(jq -r .dist.tarball <<< "$metadata")
    integrity=$(jq -r .dist.integrity <<< "$metadata")
    curl -fsSL -o "$work/package.tgz" "$tarball"
    local actual
    actual="sha512-$(openssl dgst -sha512 -binary "$work/package.tgz" | base64 | tr -d '\n')"
    if [ "$actual" != "$integrity" ]; then
        echo "error: $name $version didn't match its checksum" >&2
        exit 1
    fi
    mkdir -p "$directory"
    tar xzf "$work/package.tgz" -C "$directory"
}

# Copies files from a package, along with every file they import by relative path, keeping their
# paths within the package
copy_with_imports() {
    local package=$1 destination=$2
    shift 2
    local pending=("$@") seen=" "
    while [ ${#pending[@]} -gt 0 ]; do
        local file=${pending[0]}
        pending=("${pending[@]:1}")
        [[ $seen == *" $file "* ]] && continue
        seen+="$file "
        if [ ! -f "$package/$file" ]; then
            echo "error: $file isn't in the package" >&2
            exit 1
        fi
        mkdir -p "$destination/$(dirname "$file")"
        cp "$package/$file" "$destination/$file"
        local import
        while read -r import; do
            [ -z "$import" ] && continue
            local resolved
            resolved="$(cd "$package/$(dirname "$file")/$(dirname "$import")" && pwd)/$(basename "$import")"
            pending+=("${resolved#"$(cd "$package" && pwd)/"}")
        done < <(grep -oE "(from|import)[[:space:]]*\(?[[:space:]]*['\"]\.\.?/[^'\"]+['\"]" "$package/$file" \
            | sed -E "s/.*['\"](\.\.?\/[^'\"]+)['\"].*/\1/" || true)
    done
}

echo "Bundling three.js $three_version"
fetch three "$three_version" "$work/three"
# The addons the page imports, by their path under three/addons/
addons=$(grep -ohE "three/addons/[^\"']+" "$template"/*.js | sed 's#three/addons/#examples/jsm/#' | sort -u)
rm -rf "$vendor"/three-*
# shellcheck disable=SC2086
copy_with_imports "$work/three/package" "$vendor/three-$three_version" build/three.module.min.js $addons
cp "$work/three/package/LICENSE" "$plugin/Support/licenses/three.js.txt"

echo "Bundling browser_wasi_shim $shim_version"
fetch @bjorn3/browser_wasi_shim "$shim_version" "$work/shim"
rm -rf "$vendor"/browser_wasi_shim-*
copy_with_imports "$work/shim/package" "$vendor/browser_wasi_shim-$shim_version" dist/index.js
cp "$work/shim/package/LICENSE-MIT" "$plugin/Support/licenses/browser_wasi_shim.txt"

# Point the page at the new versions
sed -i.bak -E "s#vendor/three-[0-9A-Za-z.-]+/#vendor/three-$three_version/#g" "$template/index.html"
sed -i.bak -E "s#vendor/browser_wasi_shim-[0-9A-Za-z.-]+/#vendor/browser_wasi_shim-$shim_version/#g" "$template/runner.js"
rm -f "$template/index.html.bak" "$template/runner.js.bak"

echo "Bundled $(find "$vendor" -type f | wc -l | tr -d ' ') files, $(du -sh "$vendor" | cut -f1) in all"
