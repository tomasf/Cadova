import Foundation

internal struct AnchorList: ResultElement {
    var anchors: [Anchor: Transform3D]

    init(_ anchors: [Anchor: Transform3D] = [:]) {
        self.anchors = anchors
    }

    init() {
        self.init([:])
    }

    init(combining elements: [AnchorList]) {
        self.init(elements.reduce(into: [Anchor: Transform3D]()) { result, anchors in
            result.merge(anchors.anchors) { $1 }
        })
    }

    mutating func add(_ anchor: Anchor, at transform: Transform3D) {
        anchors[anchor] = transform
    }
}
