#!/bin/bash
#
# Checks that Package.swift picks the binary or a source build in the situations that matter.
#
# The choice is made from the environment and from where the package sits on disk, so nothing
# about it shows up in an ordinary build of Cadova. This exercises it directly: it copies the
# manifest into a directory shaped like a dependency checkout and asks SwiftPM what it decided.
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

echo "==> Checking the manifest in Cadova's own checkout"
expect_kind "$package_root" regular "a working copy builds from source"
CADOVA_BUILD_FROM_SOURCE=1 expect_kind "$package_root" regular "CADOVA_BUILD_FROM_SOURCE forces source"

echo "==> Checking the manifest in a dependency checkout"
# SwiftPM and Xcode both place a resolved dependency in a directory named "checkouts", which is
# what the manifest looks for. Only the manifest matters here, so the sources are not copied.
checkout="$workdir/some-scratch-path/checkouts/Cadova"
mkdir -p "$checkout/Sources/Cadova"
cp "$package_root/Package.swift" "$checkout/Package.swift"
touch "$checkout/Sources/Cadova/Placeholder.swift"
ditto "$xcframework" "$checkout/Cadova.xcframework"

# Until a release records a real checksum, a dependency checkout has to fall back to source
# rather than resolve a download that does not exist.
if grep -q '^let binaryChecksum = "0*"$' "$checkout/Package.swift"; then
    expect_kind "$checkout" regular "an unpublished checksum falls back to source"
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
CADOVA_USE_BINARY=0 expect_kind "$package_root" regular "CADOVA_USE_BINARY=0 does not force the binary"

echo "==> Manifest selection verified"
