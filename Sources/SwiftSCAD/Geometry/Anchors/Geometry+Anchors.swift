import Foundation

internal extension Geometry2D {
    func definingAnchor(_ anchor: Anchor, alignment: GeometryAlignment2D, transform: AffineTransform2D) -> any Geometry2D {
        EnvironmentReader { environment in
            measuringBounds { _, bounds in
                let alignmentTranslation = bounds.translation(for: alignment)
                let anchorTransform = AffineTransform3D.identity
                    .concatenated(with: environment.transform.inverse)
                    .translated(.init(alignmentTranslation))
                    .concatenated(with: .init(transform.inverse))

                modifyingResult(AnchorList.self) { anchorList in
                    (anchorList ?? .init()).adding(anchor, at: anchorTransform)
                }
            }
        }
    }
}

internal extension Geometry3D {
    func definingAnchor(_ anchor: Anchor, alignment: GeometryAlignment3D, transform: AffineTransform3D) -> any Geometry3D {
        EnvironmentReader { environment in
            measuringBounds { _, bounds in
                let alignmentTranslation = bounds.translation(for: alignment)
                let anchorTransform = AffineTransform3D.identity
                    .concatenated(with: environment.transform.inverse)
                    .translated(alignmentTranslation)
                    .concatenated(with: transform.inverse)

                modifyingResult(AnchorList.self) { anchorList in
                    (anchorList ?? .init()).adding(anchor, at: anchorTransform)
                }
            }
        }
    }
}
