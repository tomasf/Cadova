import Foundation
import Manifold3D

internal struct Sweep: Shape3D {
    let shape: any Geometry2D
    let path: BezierPath3D
    let reference: Direction2D
    let target: BezierPath3D.FrameTarget

    @Environment var environment

    var body: any Geometry3D {
        CachedNodeTransformer(body: shape, name: "sweep", parameters: path, reference, target, environment.maxTwistRate, environment.segmentation) { node, environment, context in
            let crossSection = try await context.result(for: node).concrete
            let (frames, _) = path.frames(
                environment: environment,
                target: target,
                targetReference: reference,
                perpendicularBounds: .init(crossSection.bounds),
                enableDebugging: false
            )

            let mesh = Mesh(extruding: crossSection.polygonList(), along: frames.map(\.transform))
            return GeometryNode.shape(.mesh(mesh.meshData))
        }
    }
}
