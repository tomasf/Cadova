import Foundation

internal struct PartAssignment: Geometry {
    let body: any Geometry3D
    let isSeparated: Bool
    let identifier: PartIdentifier

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        let newEnvironment = environment.withOperation(.addition)
        let output = try await context.buildResult(for: body, in: newEnvironment)
        var newOutput = output.modifyingElement(PartCatalog.self) {
            $0.add(part: output, to: identifier)
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
        PartAssignment(body: self, isSeparated: false, identifier: .highlight)
            .colored(.transparent)
    }

    /// Marks this geometry as background context.
    ///
    /// The background part is included in the 3MF output but placed in a separate part. It is typically styled
    /// differently to indicate that it serves as a reference or environment element and is not intended for printing.
    ///
    /// This can be useful for spatial context, such as a device enclosure or mounting plate.
    func inBackground() -> any Geometry3D {
        PartAssignment(body: self, isSeparated: true, identifier: .background)
    }

    /// Marks this geometry as belonging to a named part in the 3MF output.
    ///
    /// This method groups geometry into a named part in the exported 3MF file. All geometry using the same part name
    /// will be merged into a single part, which makes it easier to configure in a slicer or viewer.
    ///
    /// Named parts are useful for:
    /// - Multi-material or multi-color printing.
    /// - Selecting which parts to include or exclude from a print job.
    /// - Applying different slicer settings to different parts (e.g. setting solid infill on a mechanical insert).
    ///
    /// - Parameters:
    ///   - partName: The name of the part in the 3MF file.
    ///   - type: The type of part, such as `.solid` or `.visual`.
    /// - Returns: A geometry wrapped as a named part.
    /// 
    func inPart(named partName: String, type: PartSemantic = .solid) -> any Geometry3D {
        PartAssignment(body: self, isSeparated: true, identifier: .named(partName, type: type))
    }
}
