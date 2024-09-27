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
    func settingOutputElement(_ key: GeometryOutputElementKey, value: any GeometryOutputElement) -> any Geometry2D {
        OutputModifier2D(body: self) { output in
            output.setting(element: key, to: value)
        }
    }

    func modifyingOutputElement(_ key: GeometryOutputElementKey, modification: @escaping ((any GeometryOutputElement)?) -> (any GeometryOutputElement)?) -> any Geometry2D {
        OutputModifier2D(body: self) { output in
            output.setting(element: key, to: modification(output.elements[key]))
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
    func settingOutputElement(_ key: GeometryOutputElementKey, value: any GeometryOutputElement) -> any Geometry3D {
        OutputModifier3D(body: self) { output in
            output.setting(element: key, to: value)
        }
    }

    func modifyingOutputElement(_ key: GeometryOutputElementKey, modification: @escaping ((any GeometryOutputElement)?) -> (any GeometryOutputElement)?) -> any Geometry3D {
        OutputModifier3D(body: self) { output in
            output.setting(element: key, to: modification(output.elements[key]))
        }
    }
}
