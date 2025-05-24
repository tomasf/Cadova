import Foundation

public extension Geometry3D {
    @available(*, deprecated, message: "Use Model instead.")
    func save(to path: String) async {
        await Model(path, content: { self })
    }
}

public extension Geometry2D {
    @available(*, deprecated, message: "Use Model instead.")
    func save(to path: String) async {
        await Model(path, content: { self })
    }
}

@available(*, deprecated, message: "Use Mesh instead of Polyhedron.")
public typealias Polyhedron = Mesh

public extension Geometry2D {
    @available(*, deprecated, renamed: "revolved(in:)")
    func extruded(angles: Range<Angle> = 0°..<360°) -> any Geometry3D {
        revolved(in: angles)
    }
}

public extension Teardrop {
    @available(*, deprecated, message: "Use the `withOverhangAngle` modifier to specify an angle for Teardrop", renamed: "init(diameter:style:)")
    init(diameter: Double, angle: Angle, style: Style = .pointed) {
        self.init(diameter: diameter, style: style)
    }

    @available(*, deprecated, message: "Use the `withOverhangAngle` modifier to specify an angle for Teardrop", renamed: "init(radius:style:)")
    init(radius: Double, angle: Angle = 45°, style: Style = .pointed) {
        self.init(radius: radius, style: style)
    }
}

public extension Teardrop.Style {
    @available(*, deprecated, renamed: "pointed")
    static let full = Self.pointed
    @available(*, deprecated, renamed: "flat")
    static let bridged = Self.flat
}

@available(*, deprecated, renamed: "Transform2D")
public typealias AffineTransform2D = Transform2D

@available(*, deprecated, renamed: "Transform3D")
public typealias AffineTransform3D = Transform3D

public extension EdgeProfile {
    @available(*, deprecated, renamed: "fillet(depth:height:)")
    func fillet(width: Double, height: Double) -> Self {
        .fillet(depth: width, height: height)
    }

    @available(*, deprecated, renamed: "chamfer(depth:height:)")
    static func chamfer(width: Double, height: Double) -> Self {
        .chamfer(depth: width, height: height)
    }

    @available(*, deprecated, renamed: "chamfer(depth:angle:)")
    static func chamfer(width: Double, angle: Angle) -> Self {
        .chamfer(depth: width, angle: angle)
    }

    @available(*, deprecated, renamed: "chamfer(depth:)")
    static func chamfer(size: Double) -> Self {
        .chamfer(depth: size)
    }

    @available(*, deprecated, renamed: "overhangFillet(radius:)")
    static func chamferedFillet(radius: Double, overhang: Angle = 45°) -> EdgeProfile {
        .overhangFillet(radius: radius)
    }
}

public enum _LegacyProfileMethod {
    case convexHull
    case layered (height: Double)
}

public extension Geometry2D {
    @available(*, deprecated, renamed: "extruded(height:topEdge:bottomEdge:)")
    func extruded(height: Double, topEdge: EdgeProfile?, bottomEdge: EdgeProfile?, method: _LegacyProfileMethod) -> any Geometry3D {
        extruded(height: height, topEdge: topEdge, bottomEdge: bottomEdge)
    }

    @available(*, deprecated, renamed: "extruded(height:topEdge:)")
    func extruded(height: Double, topEdge: EdgeProfile, method: _LegacyProfileMethod) -> any Geometry3D {
        extruded(height: height, topEdge: topEdge)
    }

    @available(*, deprecated, renamed: "extruded(height:bottomEdge:)")
    func extruded(height: Double, bottomEdge: EdgeProfile, method: _LegacyProfileMethod) -> any Geometry3D {
        extruded(height: height, bottomEdge: bottomEdge)
    }
}

public extension Geometry3D {
    @available(*, deprecated, renamed: "applyingEdgeProfile(_:to:)")
    func applyingTopEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: _LegacyProfileMethod, @GeometryBuilder2D shape: () -> any Geometry2D) -> any Geometry3D {
        applyingEdgeProfile(profile, to: .top)
    }

    @available(*, deprecated, renamed: "applyingEdgeProfile(_:to:)")
    func applyingTopEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: _LegacyProfileMethod) -> any Geometry3D {
        applyingEdgeProfile(profile, to: .top)
    }

    @available(*, deprecated, renamed: "applyingEdgeProfile(_:to:)")
    func applyingBottomEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: _LegacyProfileMethod, @GeometryBuilder2D shape: () -> any Geometry2D) -> any Geometry3D {
        applyingEdgeProfile(profile, to: .bottom)
    }

    @available(*, deprecated, renamed: "applyingEdgeProfile(_:to:)")
    func applyingBottomEdgeProfile(_ profile: EdgeProfile, at z: Double? = nil, method: _LegacyProfileMethod) -> any Geometry3D {
        applyingEdgeProfile(profile, to: .bottom)
    }
}

public extension Geometry {
    @available(*, deprecated, message: "Use `await Model(\"...\") {...}` instead")
    func save(to url: URL) {
        save(to: url.path())
    }

    @available(*, deprecated, message: "Use `await Model(\"...\") {...}` instead")
    func save(to path: String) {
        waitForTask {
            await Model(path) {
                self
            }
        }
    }
}

public extension Geometry {
    @available(*, deprecated, renamed: "withSegmentation(minAngle:minSize:)")
    func usingFacets(minAngle: Angle, minSize: Double) -> D.Geometry {
        withSegmentation(minAngle: minAngle, minSize: minSize)
    }

    @available(*, deprecated, renamed: "withSegmentation(count:)")
    func usingFacets(count: Int) -> D.Geometry {
        withSegmentation(count: count)
    }

    @available(*, deprecated, renamed: "withDefaultSegmentation()")
    func usingDefaultFacets() -> D.Geometry {
        withDefaultSegmentation()
    }
}
