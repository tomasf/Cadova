//
//  File.swift
//  
//
//  Created by Tomas Wincent Franzén on 2024-09-30.
//

import Foundation

internal protocol TransformedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    var bodyTransform: AffineTransform2D { get }
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
}

extension TransformedGeometry2D {
    private func bodyEnvironment(_ environment: Environment) -> Environment {
        environment.applyingTransform(.init(bodyTransform))
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        .init(
            module: moduleName,
            parameters: moduleParameters,
            body: [body.codeFragment(in: bodyEnvironment(environment))]
        )
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: bodyEnvironment(environment)).transformed(bodyTransform)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: bodyEnvironment(environment))
    }
}

internal protocol TransformedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    var bodyTransform: AffineTransform3D { get }
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
}

extension TransformedGeometry3D {
    private func bodyEnvironment(_ environment: Environment) -> Environment {
        environment.applyingTransform(.init(bodyTransform))
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        .init(
            module: moduleName,
            parameters: moduleParameters,
            body: [body.codeFragment(in: bodyEnvironment(environment))]
        )
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: bodyEnvironment(environment)).transformed(bodyTransform)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: bodyEnvironment(environment))
    }
}
