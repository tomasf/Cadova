import Foundation

internal struct ResultReader<Geometry> {
    let body: Geometry
    let generator: (ResultElementsByType) -> Geometry
}

extension ResultReader<any Geometry2D>: Geometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output2D {
        let bodyOutput = body.evaluated(in: environment)
        return generator(bodyOutput.elements).evaluated(in: environment)
    }
}

extension ResultReader<any Geometry3D>: Geometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let bodyOutput = body.evaluated(in: environment)
        return generator(bodyOutput.elements).evaluated(in: environment)
    }
}

public extension Geometry2D {
    func readingResult<E: ResultElement>(_ type: E.Type, @GeometryBuilder2D generator: @escaping (_ body: any Geometry2D, _ value: E?) -> any Geometry2D) -> any Geometry2D {
        ResultReader(body: self) { elements in
            generator(self, elements[type])
        }
    }
}

public extension Geometry3D {
    func readingResult<E: ResultElement>(_ type: E.Type, @GeometryBuilder3D generator: @escaping (_ body: any Geometry3D, _ value: E?) -> any Geometry3D) -> any Geometry3D {
        ResultReader(body: self) { elements in
            generator(self, elements[type])
        }
    }
}
