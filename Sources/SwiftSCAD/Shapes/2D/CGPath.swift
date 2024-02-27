import Foundation

#if canImport(QuartzCore)
import QuartzCore

extension CGPath {
    func normalizedPolygons(using fillRule: CGPathFillRule) -> (positive: Polygon, negatives: [Polygon]) {
        let polygons = normalized(using: fillRule).polygons()
        let first = polygons.first ?? Polygon([])
        return (first, Array(polygons[1...]))
    }

    func polygons() -> [Polygon] {
        var polygons: [Polygon] = []
        var currentPath: BezierPath2D? = nil

        applyWithBlock { pointer in
            let element = pointer.pointee

            switch element.type {
            case .moveToPoint:
                if let currentPath {
                    polygons.append(Polygon(currentPath))
                }
                currentPath = .init(startPoint: .init(element.points[0]))

            case .addLineToPoint:
                if let path = currentPath {
                    currentPath = path.addingLine(to: .init(element.points[0]))
                }

            case .addCurveToPoint:
                let controlPoint1 = Vector2D(element.points[0])
                let controlPoint2 = Vector2D(element.points[1])
                let endPoint = Vector2D(element.points[2])
                if let path = currentPath {
                    currentPath = path.addingCubicCurve(controlPoint1: controlPoint1, controlPoint2: controlPoint2, end: endPoint)
                }

            case .addQuadCurveToPoint:
                let controlPoint = Vector2D(element.points[0])
                let endPoint = Vector2D(element.points[1])
                if let path = currentPath {
                    currentPath = path.addingQuadraticCurve(controlPoint: controlPoint, end: endPoint)
                }

            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        if let currentPath {
            polygons.append(Polygon(currentPath))
        }
        return polygons
    }
}

extension Vector2D {
    init(_ cgPoint: CGPoint) {
        self.init(cgPoint.x, cgPoint.y)
    }
}

extension CGPath: ContainerGeometry2D {
    func geometry(in environment: Environment) -> any Geometry2D {
        Union(children: componentsSeparated(using: environment.cgPathFillRule).map { component in
            let (positive, negatives) = component.normalizedPolygons(using: environment.cgPathFillRule)
            return positive
                .subtracting {
                    Union(children: negatives)
                }
        })
    }

    static internal var fillRuleEnvironmentKey: Environment.ValueKey = .init(rawValue: "CGPath.FillRule")
}

public extension Environment {
    var cgPathFillRule: CGPathFillRule {
        (self[CGPath.fillRuleEnvironmentKey] as? CGPathFillRule) ?? .evenOdd
    }

    func usingCGPathFillRule(_ fillRule: CGPathFillRule) -> Environment {
        setting(key: CGPath.fillRuleEnvironmentKey, value: fillRule)
    }
}

public extension Geometry2D {
    func usingCGPathFillRule(_ fillRule: CGPathFillRule) -> any Geometry2D {
        withEnvironment { environment in
            environment.usingCGPathFillRule(fillRule)
        }
    }
}

public extension Geometry3D {
    func usingCGPathFillRule(_ fillRule: CGPathFillRule) -> any Geometry3D {
        withEnvironment { environment in
            environment.usingCGPathFillRule(fillRule)
        }
    }
}

#endif
