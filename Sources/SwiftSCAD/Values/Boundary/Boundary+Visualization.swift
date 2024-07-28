import Foundation

extension Boundary {
    fileprivate var visualizationPointColor: Color {
        .red
    }

    fileprivate var visualizationStandardPointSize: Double { 0.1 }
}

extension Boundary3D {
    func visualized(scale: Double) -> any Geometry3D {
        points.map {
            Box(visualizationStandardPointSize * scale, center: .all)
                .translated($0)
        }
        .colored(visualizationPointColor)
        .background()
    }
}

extension Boundary2D {
    func visualized(scale: Double) -> any Geometry2D {
        points.map {
            Rectangle(visualizationStandardPointSize * scale)
                .aligned(at: .center)
                .translated($0)
        }
        .colored(visualizationPointColor)
        .background()
    }
}
