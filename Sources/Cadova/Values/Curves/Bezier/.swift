//
//  BezierPath+Subcurve.swift
//  Cadova
//
//  Created by Tomas Wincent Franzén on 2025-10-04.
//

public extension BezierPath {
    public struct Subcurve: ParametricCurve {
        let bezierPath: BezierPath
        public let domain: ClosedRange<Double>

        public var isEmpty: Bool { bezierPath.isEmpty }


        public func point(at u: Double) -> V { bezierPath.point(at: u) }

        func points(segmentation: Segmentation) -> [V] {
            <#code#>
        }
        
        var derivativeView: any CurveDerivativeView<V>
        
        func length(in range: ClosedRange<Double>?, segmentation: Segmentation) -> Double {
            <#code#>
        }
        
        func mapPoints<Output>(_ transformer: (V) -> Output) -> any ParametricCurve<Output> where Output : Vector {
            <#code#>
        }
        
        var sampleCountForLengthApproximation: Int
        
        
    }
}
