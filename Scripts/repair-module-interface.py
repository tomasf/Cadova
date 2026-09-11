#!/usr/bin/env python3
"""Repairs and verifies the textual Swift module interfaces that go into Cadova.xcframework.

Swift's module interface printer emits a redundant associated type witness for every type that
conforms to a *parameterized* protocol, for example

    public struct Arc : Cadova.Geometry2D {   // Geometry2D == Geometry<D2>, which already binds D
      public typealias D = Cadova.D2          // ... so this second binding is ambiguous
    }

The conformance clause already binds the associated type, so the printed typealias is a second,
competing witness and the interface fails to compile with "multiple matching types named 'D'".
The same declaration written by hand is rejected by the compiler, so this is a printer bug and
not something Cadova's sources can express differently.

This script uses the compiler itself as the oracle: it type-checks each interface, collects the
witnesses the compiler reports as ambiguous, deletes exactly those lines, and type-checks again.
A toolchain without the bug reports nothing, so nothing is deleted. Verification of the final
interface is unconditional, so a repair that does not fully work fails the build rather than
shipping a broken interface.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# "Cadova.swiftinterface:25:18: note: multiple matching types named 'D'" names the requirement
# the compiler could not resolve; the "possibly intended match" notes that follow name each
# competing witness. Only a witness reported under an ambiguity is ever removed.
AMBIGUITY_PATTERN = re.compile(r"^.+:\d+:\d+: note: multiple matching types named ")
MATCH_PATTERN = re.compile(r"^(?P<path>.+):(?P<line>\d+):\d+: note: possibly intended match$")
# Only ever delete a line that is exactly a redundant associated type witness.
WITNESS_PATTERN = re.compile(r"^\s*public typealias [A-Za-z_][A-Za-z0-9_]* = [^{}]+$")

# One pass removes every witness the compiler reports, so a second is only needed if removing
# some unmasks others. Three is generous; the loop stops as soon as an interface type-checks.
MAX_PASSES = 3


class TypeCheckFailed(Exception):
    """The compiler could not be run, or failed without saying why."""


def type_check(interface: Path, module_name: str, sdk: str, search_path: Path) -> str:
    """Type-checks an interface exactly as a client importing it would.

    Returns the diagnostics, or an empty string when the interface is good. A failure the
    compiler did not explain is an error in its own right, never a silent pass.
    """
    result = subprocess.run(
        [
            "xcrun", "swift-frontend",
            "-typecheck-module-from-interface", str(interface),
            "-module-name", module_name,
            "-sdk", sdk,
            "-I", str(search_path),
            "-diagnostic-style", "llvm",
        ],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        return ""
    diagnostics = result.stdout + result.stderr
    if not diagnostics.strip():
        raise TypeCheckFailed(
            f"swift-frontend exited with {result.returncode} and no diagnostics "
            f"while type-checking {interface}"
        )
    return diagnostics


def ambiguous_witness_lines(diagnostics: str, interface: Path) -> set[int]:
    """The lines in `interface` reported as competing witnesses for an ambiguous requirement."""
    lines: set[int] = set()
    under_ambiguity = False
    for diagnostic in diagnostics.splitlines():
        if AMBIGUITY_PATTERN.match(diagnostic):
            under_ambiguity = True
            continue
        match = MATCH_PATTERN.match(diagnostic)
        if not match:
            # Any other diagnostic line ends the run of notes belonging to one ambiguity.
            if diagnostic.endswith(":") or ": note: " in diagnostic or ": error: " in diagnostic:
                under_ambiguity = False
            continue
        if under_ambiguity and Path(match.group("path")).resolve() == interface.resolve():
            lines.add(int(match.group("line")))
    return lines


def repair(interface: Path, module_name: str, sdk: str, search_path: Path) -> None:
    diagnostics = type_check(interface, module_name, sdk, search_path)

    for _ in range(MAX_PASSES):
        if not diagnostics:
            return

        reported = ambiguous_witness_lines(diagnostics, interface)
        source_lines = interface.read_text().splitlines(keepends=True)
        removable = {
            line for line in reported
            if 1 <= line <= len(source_lines)
            and WITNESS_PATTERN.match(source_lines[line - 1].rstrip("\n"))
        }
        if not removable:
            break

        kept = [text for number, text in enumerate(source_lines, start=1) if number not in removable]
        interface.write_text("".join(kept))
        print(f"    removed {len(removable)} redundant associated type witness(es) "
              f"from {interface.name}")
        diagnostics = type_check(interface, module_name, sdk, search_path)

    if diagnostics:
        raise TypeCheckFailed(
            f"{interface} does not type-check as a client would see it:\n{diagnostics}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--headers", required=True, type=Path,
                        help="staging directory holding the <Module>.swiftmodule interface bundles")
    parser.add_argument("--sdk", required=True, help="macOS SDK to type-check against")
    parser.add_argument("--module", action="append", default=[], required=True,
                        help="a module to repair and verify; repeat for each module")
    arguments = parser.parse_args()

    for module_name in arguments.module:
        bundle = arguments.headers / f"{module_name}.swiftmodule"
        interfaces = sorted(bundle.glob("*.swiftinterface"))
        if not interfaces:
            print(f"error: no interface for module {module_name} in {bundle}", file=sys.stderr)
            sys.exit(1)
        for interface in interfaces:
            print(f"==> Verifying {module_name} ({interface.stem})")
            try:
                repair(interface, module_name, arguments.sdk, arguments.headers)
            except TypeCheckFailed as failure:
                print(f"error: {failure}", file=sys.stderr)
                sys.exit(1)


if __name__ == "__main__":
    main()
