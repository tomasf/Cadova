import Foundation

@available(*, deprecated, message: "Use readEnvironment instead")
public func EnvironmentReader(@GeometryBuilder2D body: @escaping (EnvironmentValues) -> any Geometry2D) -> any Geometry2D {
    readEnvironment(body)
}

@available(*, deprecated, message: "Use readEnvironment instead")
public func EnvironmentReader(@GeometryBuilder3D body: @escaping (EnvironmentValues) -> any Geometry3D) -> any Geometry3D {
    readEnvironment(body)
}

public typealias UnionBuilder2D = GeometryBuilder2D
public typealias UnionBuilder3D = GeometryBuilder3D

@available(*, deprecated, message: "Use lowercase union instead")
public func Union(@GeometryBuilder2D _ body: () -> any Geometry2D) -> any Geometry2D {
    union(body)
}

@available(*, deprecated, message: "Use lowercase union instead")
public func Union(@GeometryBuilder3D _ body: () -> any Geometry3D) -> any Geometry3D {
    union(body)
}

public extension EnvironmentValues {
    @available(*, deprecated, renamed: "Key") typealias ValueKey = Key
}
