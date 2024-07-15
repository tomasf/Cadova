//
//  File.swift
//  
//
//  Created by Tomas Franzén on 2024-07-15.
//

import Foundation

public struct GeometrySnapshot2D: Geometry2D {
    private let output: GeometryOutput2D
    private let source: any Geometry2D

    internal init(source: any Geometry2D, output: GeometryOutput2D) {
        self.output = output
        self.source = source
    }

    internal init(source: any Geometry2D, environment: Environment) {
        self.output = source.output(in: environment)
        self.source = source
    }

    public var dynamic: any Geometry2D { source }

    public func output(in environment: Environment) -> GeometryOutput2D {
        output
    }
}

public struct GeometrySnapshot3D: Geometry3D {
    private let output: GeometryOutput3D
    private let source: any Geometry3D

    internal init(source: any Geometry3D, output: GeometryOutput3D) {
        self.output = output
        self.source = source
    }

    internal init(source: any Geometry3D, environment: Environment) {
        self.output = source.output(in: environment)
        self.source = source
    }

    public var dynamic: any Geometry3D { source }

    public func output(in environment: Environment) -> GeometryOutput3D {
        output
    }
}
