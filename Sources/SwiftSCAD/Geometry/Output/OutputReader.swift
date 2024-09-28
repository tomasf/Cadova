import Foundation

internal struct OutputReader2D: Geometry2D {
    let body: any Geometry2D
    let generator: (GeometryOutput2D) -> any Geometry2D

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        return generator(output).output(in: environment)
    }
}

public extension Geometry2D {
    func readingOutputElement<E: GeometryOutputElement>(_ type: E.Type, @UnionBuilder2D generator: @escaping (_ body: any Geometry2D, _ value: E?) -> any Geometry2D) -> any Geometry2D {
        OutputReader2D(body: self) { output in
            generator(self, output.elements[type])
        }
    }
}

internal struct OutputReader3D: Geometry3D {
    let body: any Geometry3D
    let generator: (GeometryOutput3D) -> any Geometry3D

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        return generator(output).output(in: environment)
    }
}

public extension Geometry3D {
    func readingOutputElement<E: GeometryOutputElement>(_ type: E.Type, @UnionBuilder3D generator: @escaping (_ body: any Geometry3D, _ value: E?) -> any Geometry3D) -> any Geometry3D {
        OutputReader3D(body: self) { output in
            generator(self, output.elements[type])
        }
    }
}
