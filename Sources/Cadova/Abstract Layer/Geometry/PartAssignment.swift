import Foundation

internal struct PartAssignment: Geometry {
    let body: any Geometry3D
    let isSeparated: Bool
    let identifier: PartIdentifier

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        let newEnvironment = environment.withOperation(.addition)
        let output = try await body.build(in: newEnvironment, context: context)
        var newOutput = output.modifyingElement(PartCatalog.self) {
            $0.add(part: output, to: identifier)
        }
        if isSeparated {
            newOutput = newOutput.replacing(node: .empty)
        }
        return newOutput
    }
}

internal struct PartDetachment<D: Dimensionality, Input: Dimensionality>: Geometry {
    let body: Input.Geometry
    let partName: String
    let reader: @Sendable (Input.Geometry, (any Geometry3D)?) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let output = try await body.build(in: environment, context: context)

        var part: D3.BuildResult?
        let newOutput = output.modifyingElement(PartCatalog.self) {
            part = $0.detachPart(named: partName)
        }

        let outputGeometry = reader(newOutput, part)
        return try await outputGeometry.build(in: environment, context: context)
    }
}

/// Specifies the semantic role of a part in the 3MF output.
///
/// This is used to indicate how a part should be treated in the resulting model.
///
public enum PartSemantic: String, Hashable, Sendable, Codable {
    /// A regular printable part, typically rendered as opaque and included in the physical output.
    case solid

    /// A background or reference part used for spatial context. These parts are included in the model for visualization,
    /// but are not intended to be printed or interact with the printable geometry.
    case context

    /// A visual-only part used for display, guidance, or context. These are not intended for printing.
    case visual
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
        readEnvironment(\.outputSupportsParts) { supportsParts in
            PartAssignment(body: self, isSeparated: supportsParts == false, identifier: .highlight)
                .colored(.transparent)
        }
    }

    /// Marks this geometry as background context.
    ///
    /// The background part is included in the 3MF output but placed in a separate part. It is typically styled
    /// differently to indicate that it serves as a reference or environment element and is not intended for printing.
    ///
    /// This can be useful for spatial context, such as a device enclosure or mounting plate.
    func background() -> any Geometry3D {
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
    func inPart(named partName: String, type: PartSemantic = .solid) -> any Geometry3D {
        PartAssignment(body: self, isSeparated: true, identifier: .named(partName, type: type))
    }
}

public extension Geometry {
    /// Extracts a named part from the current geometry and allows further manipulation.
    ///
    /// This method detaches a part previously marked with `.inPart(named:)`. The detached part is removed from the input geometry,
    /// and passed to the given closure for further use or combination. If no matching part is found, `part` will be `nil`.
    ///
    /// This is useful when you want to extract, reuse, or reposition specific parts of a model independently, such as rearranging
    /// multi-part assemblies or isolating individual components.
    ///
    /// The detached part is no longer included in the final 3MF output unless it is reattached.
    ///
    /// - Parameters:
    ///   - partName: The name of the part to detach.
    ///   - reader: A closure that receives the original geometry (with the part removed) and the detached part (or `nil`), returning new geometry.
    /// - Returns: A geometry object resulting from the `reader` closure.
    func detachingPart<Output: Dimensionality>(
        named partName: String,
        _ reader: @Sendable @escaping (_ geometry: D.Geometry, _ part: (any Geometry3D)?) -> Output.Geometry
    ) -> Output.Geometry {
        PartDetachment(body: self, partName: partName, reader: reader)
    }
}
