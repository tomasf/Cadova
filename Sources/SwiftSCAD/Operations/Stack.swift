import Foundation

public struct Stack3D: Shape3D {
    private let children: [any Geometry3D]
    private let axis: Axis3D
    private let spacing: Double

    public var body: any Geometry3D {
        EnvironmentReader { environment in
            let items = children.map {(
                geometry: $0,
                box: $0.output(in: environment).boundary.boundingBox
            )}

            let otherAxes = Axes3D(axis: axis).inverted
            let maxSize = items.map(\.box.size).reduce(.zero, V.max)

            var offset = 0.0
            for (geometry, box) in items {
                let otherAxesAtOrigin = -box.size.setting(axes: .init(axis: axis), to: 0) / 2.0

                geometry
                    .translated(-box.minimum)
                    //.translated(otherAxesAtOrigin)
                    .translated(Vector3D(axis: axis, value: offset))

                offset += box.size[axis] + spacing
            }
        }
    }

    init(children: [any Geometry3D], axis: Axis3D, spacing: Double) {
        self.children = children
        self.axis = axis
        self.spacing = spacing
    }
}

public func Stack(axis: Axis3D, spacing: Double = 0, @SequenceBuilder3D content: @escaping () -> [any Geometry3D]) -> any Geometry3D {
    Stack3D(children: content(), axis: axis, spacing: spacing)
}
