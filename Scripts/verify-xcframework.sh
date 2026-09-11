#!/bin/bash
#
# Verifies a prebuilt Cadova.xcframework by consuming it exactly as a package user would.
#
# It checks the shape of the artifact, then builds and runs a model that exercises every bundled
# dependency: Manifold booleans, Apus/FreeType/HarfBuzz text, Pelagos/Nodal SVG import and
# ThreeMF/miniz 3MF output. Both debug and release configurations are covered, because a static
# library built for release still has to link into a debug client. A second package additionally
# depends on ThreeMF directly, which is what proves that the dependencies bundled into the
# artifact stay private and do not collide with a client's own copy.
#
# Usage: Scripts/verify-xcframework.sh <path/to/Cadova.xcframework>

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
[[ -f "$xcframework/Info.plist" ]] || fail "$xcframework is not an XCFramework"

# MARK: - Shape of the artifact

echo "==> Checking architectures"
library=$(find "$xcframework" -name "libCadova.a" -print -quit)
[[ -n $library ]] || fail "no libCadova.a inside $xcframework"
architectures=$(lipo -info "$library")
for arch in arm64 x86_64; do
    grep -qw "$arch" <<<"$architectures" || fail "$library has no $arch slice"
done
echo "    $architectures"

echo "==> Checking build info"
headers=$(dirname "$library")/Headers
[[ -d $headers ]] || fail "no Headers directory next to $library"
build_info="$headers/cadova-build-info.json"
[[ -f $build_info ]] || fail "no cadova-build-info.json in $headers"

# Reading one field at a time keeps a malformed file from failing silently.
build_info_field() {
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$build_info" "$1" \
        || fail "cadova-build-info.json has no usable '$1'"
}
echo "    built from $(build_info_field commit) ($(build_info_field workingTree) tree)"
echo "    $(build_info_field swift)"
echo "    at $(build_info_field builtAt)"

echo "==> Checking exported modules"
# The build script records the set it computed; the artifact must match it exactly. Anything
# else means a module was added or lost without anyone noticing.
expected_modules=$(python3 -c \
    'import json,sys; print("\n".join(sorted(json.load(open(sys.argv[1]))["exportedModules"])))' \
    "$build_info")
actual_modules=$(cd "$headers" && for bundle in *.swiftmodule; do echo "${bundle%.swiftmodule}"; done | sort)
if [[ "$actual_modules" != "$expected_modules" ]]; then
    fail "exported modules are '$(tr '\n' ' ' <<<"$actual_modules")', expected '$(tr '\n' ' ' <<<"$expected_modules")'"
fi
echo "    $(tr '\n' ' ' <<<"$actual_modules")"

# MARK: - Consuming the artifact

workdir=$(mktemp -d -t cadova-xcframework-verify)
trap 'rm -rf "$workdir"' EXIT

# Writes a throwaway package that links the artifact. $1 is its directory, $2 an extra dependency
# clause for Package.swift and $3 the matching target dependency, both of which may be empty.
write_package() {
    local dir=$1 package_dependency=$2 target_dependency=$3
    mkdir -p "$dir/Sources/SmokeTest"

    # SwiftPM only accepts a binary target path relative to the package root, so the artifact is
    # copied in. That also proves it does not depend on where it was built.
    ditto "$xcframework" "$dir/Cadova.xcframework"

    cat > "$dir/Package.swift" <<PACKAGE
// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "SmokeTest",
    platforms: [.macOS(.v14)],
    dependencies: [$package_dependency],
    targets: [
        .binaryTarget(name: "Cadova", path: "Cadova.xcframework"),
        .executableTarget(
            name: "SmokeTest",
            dependencies: ["Cadova"$target_dependency],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
PACKAGE
}

cat > "$workdir/model.swift" <<'SOURCE'
import Cadova
import Foundation

// Every import above has to resolve out of the XCFramework alone.
let outputBase = CommandLine.arguments[1]

let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="10mm" height="10mm" viewBox="0 0 10 10">
  <circle cx="5" cy="5" r="4"/>
</svg>
"""

await Model(outputBase) {
    // Manifold: a boolean over an extruded profile.
    Box(x: 60, y: 16, z: 4)
        .subtracting {
            // Apus, FreeType and HarfBuzz: shaping and glyph outlines.
            Text("Cadova")
                .extruded(height: 4)
                .translated(x: 3, y: 3, z: 1)
            // Pelagos and Nodal: parsing and flattening an SVG document.
            Import(svg: Data(svg.utf8))
                .extruded(height: 4)
                .translated(x: 45, y: 3, z: 1)
        }
}
SOURCE

# Builds and runs one package, then checks that it wrote a real 3MF. ThreeMF and miniz produce a
# zip container holding a 3D model part, so an unreadable archive means the bundled code is
# broken even though the process exited cleanly.
build_and_run() {
    local dir=$1 configuration=$2 label=$3 output listing
    echo "==> Building $label ($configuration)"
    swift build --package-path "$dir" -c "$configuration"

    output="$dir/output-$configuration"
    echo "==> Running $label ($configuration)"
    swift run --package-path "$dir" -c "$configuration" --skip-build SmokeTest "$output"

    [[ -s "$output.3mf" ]] || fail "$label ($configuration) produced no $output.3mf"
    listing=$(unzip -l "$output.3mf")
    grep -q "3D/3dmodel.model" <<<"$listing" || fail "$output.3mf is not a valid 3MF container"
    echo "    wrote $(stat -f %z "$output.3mf") bytes of valid 3MF"
}

write_package "$workdir/SmokeTest" "" ""
cp "$workdir/model.swift" "$workdir/SmokeTest/Sources/SmokeTest/main.swift"
for configuration in debug release; do
    build_and_run "$workdir/SmokeTest" "$configuration" "the smoke test"
done

# A client whose Swift version does not match the one that built the artifact cannot load the
# binary modules and compiles the textual interfaces instead. Deleting the binary modules from a
# copy forces that path here, on whatever toolchain is running, rather than leaving it to be
# discovered by the first person on a different Xcode.
echo "==> Checking the interface-only path a mismatched Swift version falls back to"
write_package "$workdir/Interfaces" "" ""
find "$workdir/Interfaces/Cadova.xcframework" -name "*.swiftmodule" -type f -delete
find "$workdir/Interfaces/Cadova.xcframework" -name "*.swiftdoc" -type f -delete
remaining=$(find "$workdir/Interfaces/Cadova.xcframework" -name "*.swiftinterface" | wc -l | tr -d ' ')
[[ $remaining -gt 0 ]] || fail "removing the binary modules left no interfaces to compile"
echo "    compiling against $remaining interfaces alone"
cp "$workdir/model.swift" "$workdir/Interfaces/Sources/SmokeTest/main.swift"
build_and_run "$workdir/Interfaces" debug "the interface-only test"

# Cadova bundles ThreeMF. A client that also depends on ThreeMF must still link, which only
# holds while the bundled copy's symbols stay private to the artifact.
echo "==> Checking that a client can depend on a bundled dependency directly"
write_package "$workdir/Coexist" \
    '.package(url: "https://github.com/tomasf/ThreeMF.git", .upToNextMinor(from: "0.3.0"))' \
    ', .product(name: "ThreeMF", package: "ThreeMF")'
{
    echo "import ThreeMF"
    echo "_ = ThreeMFError.self"
    cat "$workdir/model.swift"
} > "$workdir/Coexist/Sources/SmokeTest/main.swift"
build_and_run "$workdir/Coexist" debug "the coexistence test"

echo "==> $xcframework verified"
