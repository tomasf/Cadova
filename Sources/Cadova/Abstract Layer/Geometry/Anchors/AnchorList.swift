import Foundation

internal struct AnchorList: ResultElement {
    var anchors: [Anchor: AffineTransform3D]

    init(_ anchors: [Anchor: AffineTransform3D] = [:]) {
        self.anchors = anchors
    }

    init() {
        self.init([:])
    }

    init(combining elements: [AnchorList]) {
        self.init(elements.reduce(into: [Anchor: AffineTransform3D]()) { result, anchors in
            result.merge(anchors.anchors) { $1 }
        })
    }

    mutating func add(_ anchor: Anchor, at transform: AffineTransform3D) {
        anchors[anchor] = transform
    }
}
