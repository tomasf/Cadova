#!/bin/bash
#
# Checks that Package.swift picks the binary or a source build in the situations that matter.
#
# The choice is made from the environment and from where the package sits on disk, so nothing
# about it shows up in an ordinary build of Cadova. This exercises it directly: it copies the
# manifest into directories shaped like a working copy and a dependency checkout, and asks
# SwiftPM what it decided.
#
# Usage: Scripts/verify-manifest-selection.sh <path/to/Cadova.xcframework>

set -euo pipefail

fail() {
    echo "error: $1" >&2
    exit 1
}

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path/to/Cadova.xcframework>" >&2
    exit 64
fi

[[ -d $1 ]] || fail "$1 is not a directory"
xcframework=$(cd "$1" && pwd)
package_root=$(cd "$(dirname "$0")/.." && pwd)

workdir=$(mktemp -d -t cadova-manifest-selection)
trap 'rm -rf "$workdir"' EXIT

# The kind of the Cadova target is the decision: "binary" means the XCFramework was chosen,
# "regular" means a source build.
cadova_target_kind() {
    local dir=$1
    swift package --package-path "$dir" dump-package \
        | python3 -c 'import json,sys; print(next(t["type"] for t in json.load(sys.stdin)["targets"] if t["name"] == "Cadova"))'
}

expect_kind() {
    local dir=$1 expected=$2 description=$3 actual
    actual=$(cadova_target_kind "$dir")
    [[ $actual == "$expected" ]] || fail "$description: Cadova is a '$actual' target, expected '$expected'"
    echo "    $description -> $actual"
}

# Only the manifest matters, so the sources are not copied.
make_package() {
    local dir=$1
    mkdir -p "$dir/Sources/Cadova"
    cp "$package_root/Package.swift" "$dir/Package.swift"
    touch "$dir/Sources/Cadova/Placeholder.swift"
}

# Switches useLocalXCFramework on in a copied manifest.
use_local_xcframework() {
    local manifest="$1/Package.swift"
    sed -E 's/^let useLocalXCFramework = false$/let useLocalXCFramework = true/' "$manifest" > "$manifest.new"
    mv "$manifest.new" "$manifest"
    grep -q '^let useLocalXCFramework = true$' "$manifest" || fail "could not switch on useLocalXCFramework in $manifest"
}

grep -q '^let useLocalXCFramework = false$' "$package_root/Package.swift" \
    || fail "useLocalXCFramework is switched on in Package.swift; switch it off before committing"

echo "==> Checking the manifest in a working copy"
working_copy="$workdir/Cadova"
make_package "$working_copy"
expect_kind "$working_copy" regular "a working copy builds from source"
CADOVA_BUILD_FROM_SOURCE=1 expect_kind "$working_copy" regular "CADOVA_BUILD_FROM_SOURCE forces source"

local_copy="$workdir/local/Cadova"
make_package "$local_copy"
use_local_xcframework "$local_copy"
expect_kind "$local_copy" binary "useLocalXCFramework selects the binary"
CADOVA_BUILD_FROM_SOURCE=1 expect_kind "$local_copy" regular "CADOVA_BUILD_FROM_SOURCE wins over useLocalXCFramework"

echo "==> Checking the manifest in a dependency checkout"
# SwiftPM and Xcode both place a resolved dependency in a directory named "checkouts", which is
# what the manifest looks for.
checkout="$workdir/some-scratch-path/checkouts/Cadova"
make_package "$checkout"
ditto "$xcframework" "$checkout/Cadova.xcframework"

# Until a release records a real checksum, a dependency checkout has to fall back to source
# rather than resolve a download that does not exist.
if grep -q '^let binaryChecksum = "0*"$' "$checkout/Package.swift"; then
    expect_kind "$checkout" regular "an unpublished checksum falls back to source"
    local_checkout="$workdir/local/some-scratch-path/checkouts/Cadova"
    make_package "$local_checkout"
    use_local_xcframework "$local_checkout"
    expect_kind "$local_checkout" regular "a dependency checkout ignores useLocalXCFramework"
else
    expect_kind "$checkout" binary "a published checksum selects the binary"
fi

# With an XCFramework on disk the choice must not depend on a published release at all.
CADOVA_LOCAL_XCFRAMEWORK=Cadova.xcframework \
    expect_kind "$checkout" binary "CADOVA_LOCAL_XCFRAMEWORK selects the binary"
CADOVA_LOCAL_XCFRAMEWORK=Cadova.xcframework CADOVA_BUILD_FROM_SOURCE=1 \
    expect_kind "$checkout" regular "CADOVA_BUILD_FROM_SOURCE wins over a local XCFramework"

# Setting a flag to zero has to turn it off. Testing only that the variable exists would make
# CADOVA_BUILD_FROM_SOURCE=0 force a source build, which is the opposite of what it says.
echo "==> Checking that a flag set to zero is off"
CADOVA_LOCAL_XCFRAMEWORK=Cadova.xcframework CADOVA_BUILD_FROM_SOURCE=0 \
    expect_kind "$checkout" binary "CADOVA_BUILD_FROM_SOURCE=0 leaves the binary alone"
CADOVA_LOCAL_XCFRAMEWORK=Cadova.xcframework CADOVA_BUILD_FROM_SOURCE= \
    expect_kind "$checkout" binary "an empty CADOVA_BUILD_FROM_SOURCE counts as unset"
CADOVA_USE_BINARY=0 expect_kind "$working_copy" regular "CADOVA_USE_BINARY=0 does not force the binary"

echo "==> Manifest selection verified"
