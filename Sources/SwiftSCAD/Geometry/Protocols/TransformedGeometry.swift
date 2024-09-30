//
//  File.swift
//  
//
//  Created by Tomas Wincent Franzén on 2024-09-30.
//

import Foundation

protocol TransformedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    var bodyTransform: AffineTransform2D { get }
    var invocationName: String { get }
    var invocationParameters: Invocation.Parameters { get }
}

extension TransformedGeometry2D {
    private func bodyEnvironment(_ environment: Environment) -> Environment {
        environment.applyingTransform(.init(bodyTransform))
    }

    func invocation(in environment: Environment) -> Invocation {
        .init(
            name: invocationName,
            parameters: invocationParameters,
            body: [body.invocation(in: bodyEnvironment(environment))]
        )
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: bodyEnvironment(environment)).transformed(bodyTransform)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body.anchors(in: bodyEnvironment(environment))
            .mapValues { $0.concatenated(with: .init(bodyTransform)) }
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: bodyEnvironment(environment))
    }
}

protocol TransformedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    var bodyTransform: AffineTransform3D { get }
    var invocationName: String { get }
    var invocationParameters: Invocation.Parameters { get }
}

extension TransformedGeometry3D {
    private func bodyEnvironment(_ environment: Environment) -> Environment {
        environment.applyingTransform(.init(bodyTransform))
    }

    func invocation(in environment: Environment) -> Invocation {
        .init(
            name: invocationName,
            parameters: invocationParameters,
            body: [body.invocation(in: bodyEnvironment(environment))]
        )
    }

    func boundary(in environment: Environment) -> Bounds {
        body.boundary(in: bodyEnvironment(environment)).transformed(bodyTransform)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body.anchors(in: bodyEnvironment(environment))
            .mapValues { $0.concatenated(with: bodyTransform) }
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body.elements(in: bodyEnvironment(environment))
    }
}
