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
    func evaluated(in environment: Environment) -> Output {
        .init(
            body: body,
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            transform: bodyTransform,
            environment: environment
        )
    }
}

internal protocol TransformedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    var bodyTransform: AffineTransform3D { get }
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
}

extension TransformedGeometry3D {
    func evaluated(in environment: Environment) -> Output {
        .init(
            body: body,
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            transform: bodyTransform,
            environment: environment
        )
    }
}
