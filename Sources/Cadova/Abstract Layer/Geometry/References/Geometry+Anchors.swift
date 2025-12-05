import Foundation

internal extension Geometry3D {
    func definingAnchor(_ anchor: Anchor, alignment: GeometryAlignment3D, transform: Transform3D) -> any Geometry3D {
        readEnvironment { environment in
            measuring { _, measurements in
                let alignmentTranslation = (measurements.boundingBox ?? .zero).translation(for: alignment)
                let localTransform = transform.translated(-alignmentTranslation)
                let anchorTransform = localTransform * environment.transform

                modifyingResult(ReferenceState.self) {
                    $0.define(anchor: anchor, at: anchorTransform)
                }
            }
        }
    }
}
