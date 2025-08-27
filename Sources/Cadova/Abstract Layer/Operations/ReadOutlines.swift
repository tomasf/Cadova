import Foundation

public extension Geometry2D {
    /// Converts this 2D geometry’s **outlines** into closed Bézier paths and passes them to a reader.
    ///
    /// This utility samples the concrete shape of `self`, extracts its polygonal outlines, and wraps each
    /// outline as a `BezierPath2D` made of straight segments. The original geometry and the list of paths
    /// are then provided to the `reader` closure so you can build custom output.
    ///
    /// - Parameters:
    ///   - reader: A closure that receives this geometry and its outline paths and builds new geometry.
    /// - Returns: Whatever the `reader` builds—typically a new geometry assembled from the paths.
    ///
    func readingOutlines<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @escaping @Sendable (_ geometry: any Geometry2D, _ paths: [BezierPath2D]) -> D.Geometry
    ) -> D.Geometry {
        readingConcrete { crossSection, _ in
            reader(self, crossSection.polygonList().polygons.map {
                BezierPath2D(linesBetween: $0.vertices).closed()
            })
        }
    }
}
