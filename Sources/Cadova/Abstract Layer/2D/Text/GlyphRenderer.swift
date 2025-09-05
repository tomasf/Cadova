import Foundation
import freetype

internal class GlyphRenderer {
    static let scaleFactor = 16.0
    private var paths: [BezierPath2D] = []

    func move(to target: FT_Vector) {
        paths.append(BezierPath2D(startPoint: target.cadovaVector))
    }

    func line(to target: FT_Vector) {
        guard paths.isEmpty == false else { return }
        paths[paths.count - 1] = paths[paths.count - 1].addingLine(to: target.cadovaVector)
    }

    func conic(controlPoint: FT_Vector, end: FT_Vector) {
        guard paths.isEmpty == false else { return }
        paths[paths.count - 1] = paths[paths.count - 1].addingQuadraticCurve(
            controlPoint: controlPoint.cadovaVector,
            end: end.cadovaVector
        )
    }

    func cubic(controlPoint1: FT_Vector, controlPoint2: FT_Vector, end: FT_Vector) {
        guard paths.isEmpty == false else { return }
        paths[paths.count - 1] = paths[paths.count - 1].addingCubicCurve(
            controlPoint1: controlPoint1.cadovaVector,
            controlPoint2: controlPoint2.cadovaVector,
            end: end.cadovaVector
        )
    }

    var callbacks: FT_Outline_Funcs {
        FT_Outline_Funcs(
            move_to: { target, user in
                guard let target, let builder = user?.assumingMemoryBound(to: GlyphRenderer.self).pointee else { return 1 }
                builder.move(to: target.pointee)
                return 0
            },
            line_to: { target, user in
                guard let target, let builder = user?.assumingMemoryBound(to: GlyphRenderer.self).pointee else { return 1 }
                builder.line(to: target.pointee)
                return 0
            },
            conic_to: { controlPoint, end, user in
                guard let controlPoint = controlPoint?.pointee,
                      let end = end?.pointee,
                      let builder = user?.assumingMemoryBound(to: GlyphRenderer.self).pointee
                else { return 1 }

                builder.conic(controlPoint: controlPoint, end: end)
                return 0
            },
            cubic_to: { controlPoint1, controlPoint2, end, user in
                guard let controlPoint1 = controlPoint1?.pointee,
                      let controlPoint2 = controlPoint2?.pointee,
                      let end = end?.pointee,
                      let builder = user?.assumingMemoryBound(to: GlyphRenderer.self).pointee
                else { return 1 }

                builder.cubic(controlPoint1: controlPoint1, controlPoint2: controlPoint2, end: end)
                return 0
            },
            shift: 0,
            delta: 0
        )
    }

    func polygons(for outline: FT_Outline, in environment: EnvironmentValues) -> SimplePolygonList? {
        paths = []

        var funcs = callbacks
        var builder = self
        var mutableOutline = outline
        let composeResult = withUnsafeMutablePointer(to: &builder) { mutablePointer in
            FT_Outline_Decompose(&mutableOutline, &funcs, mutablePointer)
        }
        guard composeResult == 0 else { return nil }
        return SimplePolygonList(paths.map { $0.simplePolygon(in: environment) })
    }
}

internal extension FT_Vector {
    var cadovaVector: Vector2D {
        Vector2D(Double(x) / 64.0 / GlyphRenderer.scaleFactor, Double(y) / 64.0 / GlyphRenderer.scaleFactor)
    }
}
