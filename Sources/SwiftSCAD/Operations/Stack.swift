import Foundation

internal struct Stack2D: Shape2D {
    let items: [any Geometry2D]
    let axis: Axis2D
    let spacing: Double
    let alignment: GeometryAlignment2D

    public var body: any Geometry2D {
        EnvironmentReader { environment in
            var offset = 0.0
            for geometry in items {
                if let box = geometry.output(in: environment).boundary.boundingBox {

                    geometry
                        .translated(-box.minimum) // Reset to origin
                        .translated(
                            (box.size * -alignment.factors)
                                .with(axis, as: offset)
                        )

                    offset += box.size[axis] + spacing
                } else {
                    assertionFailure("Stack item has empty bounds: \(geometry)")
                }
            }
        }
    }
}

public func Stack(
    axis: Axis2D,
    spacing: Double = 0,
    alignment: GeometryAlignment2D...,
    @SequenceBuilder2D content: @escaping () -> [any Geometry2D]
) -> any Geometry2D {
    Stack2D(items: content(), axis: axis, spacing: spacing, alignment: .init(merging: alignment))
}


internal struct Stack3D: Shape3D {
    let items: [any Geometry3D]
    let axis: Axis3D
    let spacing: Double
    let alignment: GeometryAlignment3D

    public var body: any Geometry3D {
        EnvironmentReader { environment in
            var offset = 0.0
            for geometry in items {
                if let box = geometry.output(in: environment).boundary.boundingBox {

                    geometry
                        .translated(-box.minimum) // Reset to origin
                        .translated(
                            (box.size * -alignment.factors)
                                .with(axis, as: offset)
                        )

                    offset += box.size[axis] + spacing
                } else {
                    assertionFailure("Stack item has empty bounds: \(geometry)")
                }
            }
        }
    }
}

public func Stack(
    axis: Axis3D,
    spacing: Double = 0,
    alignment: GeometryAlignment3D...,
    @SequenceBuilder3D content: @escaping () -> [any Geometry3D]
) -> any Geometry3D {
    Stack3D(items: content(), axis: axis, spacing: spacing, alignment: .init(merging: alignment))
}
