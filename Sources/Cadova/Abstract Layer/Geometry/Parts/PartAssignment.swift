import Foundation

internal struct PartAssignment: Geometry {
    let body: any Geometry3D
    let isSeparated: Bool
    let part: Part

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        let newEnvironment = environment.withOperation(.addition)
        let output = try await context.buildResult(for: body, in: newEnvironment)
        var newOutput = output.modifyingElement(PartCatalog.self) {
            $0.add(result: output, to: part)
        }
        if isSeparated {
            newOutput = newOutput.replacing(node: .empty)
        }
        return newOutput
    }
}

public extension Geometry3D {
    /// Marks this geometry as a highlighted reference part.
    ///
    /// The geometry will appear in the 3MF file as a separate part with a transparent color,
    /// making it useful for showing guides or reference shapes in a viewer or slicer without
    /// including them in the printed result.
    ///
    /// Highlighted parts are still included in the output, but styled to visually indicate they are not for printing.
    func highlighted() -> any Geometry3D {
        PartAssignment(body: self, isSeparated: false, part: .highlighted)
            .colored(.transparent)
    }

    /// Marks this geometry as background context.
    ///
    /// The background part is included in the 3MF output but placed in a separate part. It is typically styled
    /// differently to indicate that it serves as a reference or environment element and is not intended for printing.
    ///
    /// This can be useful for spatial context, such as a device enclosure or mounting plate.
    func inBackground() -> any Geometry3D {
        PartAssignment(body: self, isSeparated: true, part: .background)
    }

    /// Marks this geometry as belonging to the specified part in the 3MF output.
    ///
    /// This method groups geometry into a part in the exported 3MF file. All geometry using the same `Part`
    /// instance will be merged into a single part, which makes it easier to configure in a slicer or viewer.
    ///
    /// Parts are useful for:
    /// - Multi-material or multi-color printing.
    /// - Selecting which parts to include or exclude from a print job.
    /// - Applying different slicer settings to different parts (e.g. setting solid infill on a mechanical insert).
    ///
    /// - Parameter part: The part to assign this geometry to.
    /// - Returns: A geometry wrapped as the specified part.
    ///
    func inPart(_ part: Part) -> any Geometry3D {
        PartAssignment(body: self, isSeparated: true, part: part)
    }

}
