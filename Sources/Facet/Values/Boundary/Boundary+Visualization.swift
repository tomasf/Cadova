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
            Box(visualizationStandardPointSize * scale)
                .aligned(at: .center)
                .translated($0)
        }
        .colored(visualizationPointColor)
        .background()
    }
}
