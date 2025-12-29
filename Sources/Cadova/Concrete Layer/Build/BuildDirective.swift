import Foundation

public struct BuildDirective: Sendable {
    internal let payload: Payload

    internal enum Payload: Sendable {
        case geometry2D (any Geometry2D)
        case geometry3D (any Geometry3D)
        case model (Model)
        case group (Group)
        case options (ModelOptions)
        case environment (@Sendable (inout EnvironmentValues) -> ())
    }

    var geometry2D: (any Geometry2D)? {
        if case .geometry2D(let geometry2D) = payload { geometry2D } else { nil }
    }

    var geometry3D: (any Geometry3D)? {
        if case .geometry3D(let geometry3D) = payload { geometry3D } else { nil }
    }

    var model: Model? {
        if case .model(let model) = payload { model } else { nil }
    }

    var group: Group? {
        if case .group(let group) = payload { group } else { nil }
    }

    var options: ModelOptions? {
        if case .options(let options) = payload { options } else { nil }
    }

    var environment: ((inout EnvironmentValues) -> ())? {
        if case .environment(let environment) = payload { environment } else { nil }
    }
}

// This is a bit of a hack to allow the use of Environment inside result builders
public extension Environment<@Sendable (inout EnvironmentValues) -> ()> {
    init(_ builder: @Sendable @escaping (inout EnvironmentValues) -> ()) {
        getter = { _ in builder }
    }

    init<Value: Sendable>(
        _ keyPath: WritableKeyPath<EnvironmentValues, Value>,
        _ value: Value
    ){
        getter = { _ in { $0[keyPath: keyPath] = value }}
    }
}
