#!/bin/bash
#
# Builds Cadova.xcframework: an optimized, universal (arm64 + x86_64) macOS static library that
# bundles Cadova together with every Swift and C/C++ dependency it needs, plus textual module
# interfaces so it can be imported by any compatible Swift compiler.
#
# Why this works where the obvious approach does not: Swift cannot currently export a C or C++
# target from a binary package, and Cadova depends on several (Manifold, oneTBB, Clipper2,
# pugixml, miniz, FreeType, HarfBuzz). None of them appear in Cadova's public API, though. They
# are imported with `internal import`, so they never reach a module interface; they only need to
# be present as object code, which a static library provides.
#
# Bundling them creates a second problem. A package that depends on both Cadova and, say,
# ThreeMF would link two copies of ThreeMF and fail with hundreds of duplicate symbols. So the
# archive is relinked into a single object with every symbol that does not belong to an exported
# module made private. What a client can see, and therefore collide with, is exactly the set of
# modules the XCFramework exports.
#
# Usage: Scripts/build-xcframework.sh [--output <dir>] [--scratch-path <dir>]
#
# Writes <output>/Cadova.xcframework and <output>/Cadova.xcframework.zip, and prints the
# checksum that a consuming Package.swift needs for the zip.

set -euo pipefail

package_root=$(cd "$(dirname "$0")/.." && pwd)
output_dir="$package_root/.build/xcframework"
scratch_path="$package_root/.build/xcframework-scratch"
triples=(arm64-apple-macosx x86_64-apple-macosx)
deployment_target=14.0

while [[ $# -gt 0 ]]; do
    case $1 in
        --output) output_dir=$2; shift 2 ;;
        --scratch-path) scratch_path=$2; shift 2 ;;
        *) echo "Usage: $0 [--output <dir>] [--scratch-path <dir>]" >&2; exit 64 ;;
    esac
done

mkdir -p "$output_dir" "$scratch_path"
output_dir=$(cd "$output_dir" && pwd)
scratch_path=$(cd "$scratch_path" && pwd)
staging_dir="$scratch_path/staging"
xcframework="$output_dir/Cadova.xcframework"
sdk=$(xcrun --sdk macosx --show-sdk-path)

build_dir() {
    echo "$scratch_path/$1/release"
}

# Cadova and every package module reachable through the imports of its interface. Those are the
# modules a client needs to see; everything else is an implementation detail that stays inside
# the static library, with its symbols hidden.
exposed_modules() {
    local dir=$1
    local queue="Cadova" result="" module dependency

    while [[ -n $queue ]]; do
        module=${queue%% *}
        queue=${queue#"$module"}
        queue=${queue# }
        case " $result " in *" $module "*) continue ;; esac
        result="$result $module"

        for dependency in $(sed -n -E 's/^([a-z_]+ )?import ([A-Za-z0-9_]+).*$/\2/p' \
                "$dir/$module.build/$module.swiftinterface"); do
            if [[ -f "$dir/Modules/$dependency.swiftmodule" ]]; then
                queue="$queue $dependency"
            fi
        done
    done
    echo "${result# }"
}

# Copies one file per exported module and architecture into the staging tree.
stage_module_files() {
    local source_subdirectory=$1 extension=$2 triple dir arch module bundle
    for triple in "${triples[@]}"; do
        dir=$(build_dir "$triple")
        arch=${triple%%-*}
        for module in $modules; do
            bundle="$staging_dir/Headers/$module.swiftmodule"
            mkdir -p "$bundle"
            cp "$dir/${source_subdirectory//MODULE/$module}/$module.$extension" \
               "$bundle/$arch-apple-macos.$extension"
        done
    done
}

# Library evolution is what makes a module interface possible, and SwiftPM applies -Xswiftc to
# every target, so the internal modules are built resilient as well even though nothing reads
# their interfaces. Resilience costs a little speed at module boundaries, so this was measured on
# a boolean-heavy model: 0.220 s median without it against 0.224 s with it, over five runs each,
# with the two ranges overlapping. Cadova's hot path is Manifold's C++, which resilience does not
# touch, so the difference is not worth a more complicated build.
for triple in "${triples[@]}"; do
    echo "==> Building Cadova for $triple"
    # Cadova's own manifest must not pull in the binary it is about to produce.
    CADOVA_BUILD_FROM_SOURCE=1 swift build \
        --package-path "$package_root" \
        --scratch-path "$scratch_path" \
        --configuration release \
        --product CadovaStatic \
        --triple "$triple" \
        -Xswiftc -enable-library-evolution \
        -Xswiftc -emit-module-interface \
        -Xswiftc -no-verify-emitted-module-interface
done

rm -rf "$staging_dir" "$xcframework" "$xcframework.zip"
mkdir -p "$staging_dir/Headers"

modules=$(exposed_modules "$(build_dir "${triples[0]}")")
echo "==> Exporting modules: $modules"

# Record what this artifact is and where it came from. A binary that cannot say which source it
# was built from is hard to support, because a bug report names a Cadova version but the version
# alone does not identify the build. verify-xcframework.sh also reads the module list from here
# rather than restating it.
echo "==> Recording build info"
CADOVA_MODULES="$modules" \
CADOVA_ARCHITECTURES="${triples[*]%%-*}" \
CADOVA_DEPLOYMENT_TARGET="$deployment_target" \
CADOVA_COMMIT="$(git -C "$package_root" rev-parse HEAD 2>/dev/null || echo unknown)" \
CADOVA_TREE="$(test -z "$(git -C "$package_root" status --porcelain 2>/dev/null)" && echo clean || echo dirty)" \
CADOVA_SWIFT="$(swift --version 2>&1 | head -1)" \
python3 -c '
import json, os, datetime
info = {
    "exportedModules": os.environ["CADOVA_MODULES"].split(),
    "architectures": os.environ["CADOVA_ARCHITECTURES"].split(),
    "deploymentTarget": os.environ["CADOVA_DEPLOYMENT_TARGET"],
    "commit": os.environ["CADOVA_COMMIT"],
    "workingTree": os.environ["CADOVA_TREE"],
    "swift": os.environ["CADOVA_SWIFT"],
    "builtAt": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
}
print(json.dumps(info, indent=2))
' > "$staging_dir/Headers/cadova-build-info.json"
python3 -c '
import json, sys
info = json.load(open(sys.argv[1]))
print("    commit %s (%s tree)" % (info["commit"], info["workingTree"]))
' "$staging_dir/Headers/cadova-build-info.json"

stage_module_files "MODULE.build" swiftinterface

# Repairs a Swift interface printer bug and, either way, proves that every exported interface
# type-checks the way a client importing it would. See the script for details. This runs before
# the binary modules are staged, so it exercises the interface-only path that a client on a
# different Swift version falls back to.
module_arguments=()
for module in $modules; do
    module_arguments+=(--module "$module")
done
"$package_root/Scripts/repair-module-interface.py" \
    --headers "$staging_dir/Headers" \
    --sdk "$sdk" \
    "${module_arguments[@]}"

# A client on this exact Swift version loads these instead of parsing the interfaces.
stage_module_files Modules swiftmodule
stage_module_files Modules swiftdoc

# Relinks one architecture's archive into a single object, keeping only the symbols the exported
# modules define. Everything else becomes private to the object, so a client that also depends
# on ThreeMF, Nodal, Zip, Apus or Pelagos links its own copy without colliding with ours.
hide_internal_symbols() {
    local triple=$1
    local dir; dir=$(build_dir "$triple")
    local arch=${triple%%-*}
    local work="$scratch_path/hidden/$arch"
    local module objects=()

    rm -rf "$work"
    mkdir -p "$work"

    for module in $modules; do
        while IFS= read -r object; do objects+=("$object"); done \
            < <(find "$dir/$module.build" -name "*.o")
    done
    nm -gjU "${objects[@]}" | sort -u > "$work/exported.syms"
    nm -gjU "$dir/libCadovaStatic.a" | sort -u > "$work/all.syms"
    comm -23 "$work/all.syms" "$work/exported.syms" > "$work/hidden.syms"
    echo "    $arch: hiding $(wc -l < "$work/hidden.syms" | tr -d ' ') internal symbols"

    ld -r -all_load "$dir/libCadovaStatic.a" \
        -unexported_symbols_list "$work/hidden.syms" \
        -arch "$arch" \
        -platform_version macos "$deployment_target" "$deployment_target" \
        -o "$work/Cadova.o"

    # Most of the merged object is a symbol table naming the internals that were just made
    # private, which no client can refer to. Dropping it, and the debug symbols with it, halves
    # what people download. Swift metadata and Objective-C class registration live in their own
    # sections and are untouched.
    strip -S -x "$work/Cadova.o"

    libtool -static -o "$work/libCadova.a" "$work/Cadova.o"
}

echo "==> Hiding internal symbols"
libraries=()
for triple in "${triples[@]}"; do
    hide_internal_symbols "$triple"
    libraries+=("$scratch_path/hidden/${triple%%-*}/libCadova.a")
done

echo "==> Creating universal static library"
lipo -create "${libraries[@]}" -output "$staging_dir/libCadova.a"

echo "==> Creating $xcframework"
xcodebuild -create-xcframework \
    -library "$staging_dir/libCadova.a" \
    -headers "$staging_dir/Headers" \
    -output "$xcframework"

echo "==> Creating $xcframework.zip"
ditto -c -k --keepParent "$xcframework" "$xcframework.zip"

checksum=$(swift package --package-path "$package_root" compute-checksum "$xcframework.zip")
echo "==> Done"
echo "xcframework: $xcframework"
echo "zip:         $xcframework.zip"
echo "checksum:    $checksum"
