#!/bin/bash
#
# Checks a published Cadova release the way a new user meets it: declare the package, let SwiftPM
# download the XCFramework from the release URL, verify its checksum, and build and run a model.
#
# Everything else in this repository tests an artifact on disk. Only this exercises the download
# URL and the checksum recorded in the released Package.swift, which is the one path that cannot
# be tried before a release exists and the one whose failure blocks every macOS user at once.
#
# Usage: Scripts/verify-published-release.sh <version> [repository-url]

set -euo pipefail

fail() {
    echo "error: $1" >&2
    exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <version> [repository-url]" >&2
    exit 64
fi

version=$1
repository=${2:-https://github.com/tomasf/Cadova.git}

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "'$version' is not a version of the form 1.2.3"

workdir=$(mktemp -d -t cadova-published-release)
trap 'rm -rf "$workdir"' EXIT

package_dir="$workdir/Consumer"
mkdir -p "$package_dir/Sources/Consumer"

cat > "$package_dir/Package.swift" <<PACKAGE
// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "Consumer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "$repository", exact: "$version"),
    ],
    targets: [
        .executableTarget(
            name: "Consumer",
            dependencies: [.product(name: "Cadova", package: "Cadova")],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
PACKAGE

cat > "$package_dir/Sources/Consumer/main.swift" <<'SOURCE'
import Cadova
import Foundation

await Model(CommandLine.arguments[1]) {
    Box(x: 20, y: 20, z: 5)
        .subtracting {
            Sphere(diameter: 12).translated(x: 10, y: 10, z: 5)
        }
}
SOURCE

echo "==> Resolving Cadova $version from $repository"
swift package --package-path "$package_dir" resolve

# A source build here would mean the manifest declined the binary, which defeats the point of
# publishing one, so check what it actually chose before trusting the run below.
target_kind=$(swift package --package-path "$package_dir" dump-package \
    | python3 -c 'import json,sys; print(next((t["type"] for t in json.load(sys.stdin)["targets"] if t["name"] == "Consumer"), "missing"))')
[[ $target_kind == regular ]] || fail "the consumer target came out as '$target_kind'"

checkout=$(find "$package_dir/.build" -type d -name Cadova -path "*checkouts*" -print -quit)
[[ -n $checkout ]] || fail "Cadova was not checked out"
cadova_kind=$(swift package --package-path "$checkout" dump-package \
    | python3 -c 'import json,sys; print(next(t["type"] for t in json.load(sys.stdin)["targets"] if t["name"] == "Cadova"))')
[[ $cadova_kind == binary ]] || fail "Cadova $version resolved to a '$cadova_kind' target, so the published binary was not used"
echo "    Cadova resolved to a binary target"

echo "==> Building and running a model against the published binary"
swift build --package-path "$package_dir" -c debug
output="$workdir/output"
swift run --package-path "$package_dir" -c debug --skip-build Consumer "$output"

[[ -s "$output.3mf" ]] || fail "no $output.3mf was written"
listing=$(unzip -l "$output.3mf")
grep -q "3D/3dmodel.model" <<<"$listing" || fail "$output.3mf is not a valid 3MF container"
echo "    wrote $(stat -f %z "$output.3mf") bytes of valid 3MF"

echo "==> Cadova $version verified as published"
