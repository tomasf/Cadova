import Foundation

public struct Tag: Hashable, Sendable {
    internal let id = UUID()
    internal let label: String?

    public init(_ label: String? = nil) {
        self.label = label
    }

    public var description: String {
        if let label {
            "Tag \"\(label)\" (\(id))"
        } else {
            "Tag \(id)"
        }
    }
}

public extension Geometry3D {
    func tagged(_ tag: Tag) -> any Geometry3D {
        TagGeometry(body: self, tag: tag)
    }
}

extension Tag: Geometry {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        let output = Union {
            environment.buildResults(for: self)
        }.transformed(environment.transform.inverse)

        return try await context.buildResult(for: output, in: environment)
            .modifyingElement(ReferenceState.self) { $0.read(tag: self) }
    }
}

internal struct TagGeometry: Geometry {
    let body: any Geometry3D
    let tag: Tag

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let globalResult = bodyResult.modifyingNode { .transform($0, transform: environment.transform) }

        return bodyResult.modifyingElement(ReferenceState.self) {
            $0.define(tag: tag, as: globalResult)
        }
    }
}
