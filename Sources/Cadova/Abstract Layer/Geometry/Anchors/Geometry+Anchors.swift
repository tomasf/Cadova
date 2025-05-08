import Foundation

internal extension Geometry {
    func definingAnchor(_ anchor: Anchor, alignment: D.Alignment, transform: D.Transform) -> D.Geometry {
        readEnvironment { environment in
            measuring { _, measurements in
                var alignmentTranslation = D.Vector.zero
                if alignment.hasEffect {
                    alignmentTranslation = (measurements.boundingBox ?? .zero).translation(for: alignment)
                }
                let anchorTransform = Transform3D.identity
                    .concatenated(with: environment.transform.inverse)
                    .translated(alignmentTranslation.vector3D)
                    .concatenated(with: transform.inverse.transform3D)

                modifyingResult(AnchorList.self) {
                    $0.add(anchor, at: anchorTransform)
                }
            }
        }
    }
}
