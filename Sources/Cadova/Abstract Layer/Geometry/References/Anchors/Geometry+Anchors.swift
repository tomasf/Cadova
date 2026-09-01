import Foundation

internal extension Geometry {
    func definingAnchor(_ anchor: Anchor, alignment: GeometryAlignment<D>, transform: D.Transform) -> D.Geometry {
        measuring { _, measurements in
            @Environment var environment

            let alignmentTranslation = (measurements.boundingBox ?? .zero).translation(for: alignment)
            let localTransform = transform.translated(-alignmentTranslation)
            let anchorTransform = localTransform.transform3D * environment.transform

            modifyingResult(ReferenceState.self) {
                $0.define(anchor: anchor, at: anchorTransform)
            }
        }
    }
}
