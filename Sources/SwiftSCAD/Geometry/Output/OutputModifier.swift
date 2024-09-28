import Foundation

internal struct OutputModifier2D: Geometry2D {
    let body: any Geometry2D
    let modifier: (Output) -> Output

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        return modifier(output)
    }
}

public extension Geometry2D {
    func withOutputElement<E: GeometryOutputElement>(_ value: E) -> any Geometry2D {
        OutputModifier2D(body: self) { output in
            output.setting(element: value)
        }
    }

    func modifyingOutputElement<E: GeometryOutputElement>(_ type: E.Type, modification: @escaping (E?) -> E?) -> any Geometry2D {
        OutputModifier2D(body: self) { output in
            output.setting(element: modification(output.elements[E.self]))
        }
    }
}

internal struct OutputModifier3D: Geometry3D {
    let body: any Geometry3D
    let modifier: (Output) -> Output

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        return modifier(output)
    }
}

public extension Geometry3D {
    func withOutputElement<E: GeometryOutputElement>(_ value: E) -> any Geometry3D {
        OutputModifier3D(body: self) { output in
            output.setting(element: value)
        }
    }

    func modifyingOutputElement<E: GeometryOutputElement>(_ type: E.Type, modification: @escaping (E?) -> E?) -> any Geometry3D {
        OutputModifier3D(body: self) { output in
            output.setting(element: modification(output.elements[E.self]))
        }
    }
}
