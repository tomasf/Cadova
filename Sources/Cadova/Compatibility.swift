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

extension Geometry2D {
    @available(*, deprecated, renamed: "revolved(in:)")
    func extruded(angles: Range<Angle> = 0°..<360°) -> any Geometry3D {
        revolved(in: angles)
    }
}

extension Geometry {
    @available(*, deprecated, renamed: "flipped(across:)")
    func flipped(along axes: D.Axes) -> D.Geometry {
        flipped(across: axes)
    }
}

extension Teardrop {
    @available(*, deprecated, renamed: "init(diameter:overhang:style:)")
    public init(diameter: Double, angle: Angle = 45°, style: Style = .pointed) {
        self.init(diameter: diameter, overhang: angle, style: style)
    }
}

extension Teardrop.Style {
    @available(*, deprecated, renamed: "pointed")
    static let full = Self.pointed
    @available(*, deprecated, renamed: "flat")
    static let bridged = Self.flat
}
