import Foundation

internal struct AnchorList: ResultElement {
    let anchors: [Anchor: AffineTransform3D]

    init(_ anchors: [Anchor: AffineTransform3D] = [:]) {
        self.anchors = anchors
    }

    func adding(_ anchor: Anchor, at transform: AffineTransform3D) -> AnchorList {
        .init(anchors.setting(anchor, to: transform))
    }

    static func combine(elements: [AnchorList], for operation: GeometryCombination) -> AnchorList? {
        .init(elements.reduce(into: [Anchor: AffineTransform3D]()) { result, anchors in
            result.merge(anchors.anchors) { $1 }
        })
    }
}
