import Foundation

/// The surface of a shape rounded on both sides at once, as one function to contour: outside rounding with one
/// radius, then inside rounding of that with another, without contouring anything in between.
///
/// Outside rounding is the shape eroded with sharp joins (E), then grown back by the outside radius; E is exact
/// wherever the shape is flat. Its result has no sharp convex edges, so growing it for the inside rounding is the
/// same as growing E by both radii (D), and the inside rounding is D shrunk by the inside radius. The union of the
/// two, min(distance to E − outside, signed distance to D + inside), is that result: convex parts come from the
/// exact E, and concave fillets from D's concave parts, which are exact too. Only D's convex parts come from an
/// earlier contouring, and there D's term must not win, so it's biased by a margin larger than that contouring's
/// error.
///
/// Chamfering works the same way, with square joins in place of round ones: E grown by the outside depth with
/// square joins is the outside chamfer, and growing that with miter joins only moves all its planes outward,
/// cuts included, so it's E grown with square joins by both depths (D). The inside chamfer is D shrunk with square
/// joins. Each term then comes from its pieces (see ``OffsetCorners``) rather than plain distance.
///
/// Both terms change no faster than position, so neither does their minimum, as contouring needs.
internal final class RoundingField: @unchecked Sendable {
    private let eroded: MeshDistanceField
    private let dilated: MeshDistanceField
    private let outside: Double
    private let inside: Double
    /// For chamfering, E grown by the outside depth and D shrunk by the inside depth plus the margin, with square
    /// joins; nil to round
    private let outsideCorners: OffsetCorners?
    private let insideCorners: OffsetCorners?

    /// Rounding: both terms are plain distances
    init(eroded: MeshDistanceField, dilated: MeshDistanceField, outside: Double, inside: Double, margin: Double) {
        self.eroded = eroded
        self.dilated = dilated
        self.outside = outside
        self.inside = inside + margin
        outsideCorners = nil
        insideCorners = nil
    }

    /// Chamfering: both terms are offsets with square joins
    init(chamferingEroded eroded: MeshDistanceField, dilated: MeshDistanceField, outside: Double, inside: Double, margin: Double,
         tolerance: Double) {
        self.eroded = eroded
        self.dilated = dilated
        self.outside = outside
        self.inside = inside + margin
        outsideCorners = OffsetCorners(field: eroded, amount: outside, style: .square, miterLimit: 1, tolerance: tolerance)
        insideCorners = OffsetCorners(field: dilated, amount: -(inside + margin), style: .square, miterLimit: 1, tolerance: tolerance)
    }

    /// The vertices the result lies within: the result is inside D
    var vertices: [Vector3D] { dilated.vertices }

    // Hints pack a face of each mesh (plus one, so zero means none) into one positive number, half its
    // bits each. A face too large for its half, which only happens where Int has 32 bits, is left out:
    // hints only give searches a head start, so that costs time but never changes a result.
    private static let hintFieldWidth = (Int.bitWidth - 1) / 2
    private static let hintFieldMask = (1 << hintFieldWidth) - 1

    private static func unpack(_ hint: Int?) -> (Int?, Int?) {
        guard let hint, hint > 0 else { return (nil, nil) }
        let e = hint & hintFieldMask, d = hint >> hintFieldWidth
        return (e > 0 ? e - 1 : nil, d > 0 ? d - 1 : nil)
    }

    private static func pack(_ e: Int, _ d: Int) -> Int {
        let e = e + 1 <= hintFieldMask ? e + 1 : 0
        let d = d + 1 <= hintFieldMask ? d + 1 : 0
        return e | d << hintFieldWidth
    }

    /// The function (negative inside the result), and a hint for nearby queries
    func value(at p: Vector3D, hint: Int?) -> (value: Double, face: Int) {
        let (e, d) = Self.unpack(hint)
        if let outsideCorners, let insideCorners {
            let outer = outsideCorners.evaluate(at: p, hint: e), inner = insideCorners.evaluate(at: p, hint: d)
            return (min(outer.value, inner.value), Self.pack(outer.face, inner.face))
        }
        let rounded = eroded.signedDistanceAndFace(at: p, hint: e)
        let filleted = dilated.signedDistanceAndFace(at: p, hint: d)
        return (min(rounded.value - outside, filleted.value + inside), Self.pack(rounded.face, filleted.face))
    }

    /// The function, its gradient, and a hint for nearby queries
    func valueAndGradient(at p: Vector3D, hint: Int?) -> (value: Double, gradient: Vector3D, face: Int) {
        let (e, d) = Self.unpack(hint)
        if let outsideCorners, let insideCorners {
            let outer = outsideCorners.evaluate(at: p, hint: e), inner = insideCorners.evaluate(at: p, hint: d)
            let face = Self.pack(outer.face, inner.face)
            return outer.value <= inner.value ? (outer.value, outer.gradient, face) : (inner.value, inner.gradient, face)
        }
        let rounded = eroded.signedDistanceAndGradient(at: p, hint: e)
        let filleted = dilated.signedDistanceAndGradient(at: p, hint: d)
        let face = Self.pack(rounded.face, filleted.face)
        if rounded.value - outside <= filleted.value + inside {
            return (rounded.value - outside, rounded.gradient, face)
        }
        return (filleted.value + inside, filleted.gradient, face)
    }

    /// Whether the surface within radius of p is provably one plane: each term's surface there is one plane, and
    /// where both have one, they're parallel, so their minimum is the outer of the two. For chamfering, no piece may
    /// reach in either.
    func isPlanar(within radius: Double, of p: Vector3D) -> Bool {
        if outsideCorners?.mayAffect(p, radius: radius) == true || insideCorners?.mayAffect(p, radius: radius) == true {
            return false
        }
        let first = eroded.coplanarNormal(within: outside + radius, of: p)
        guard first.coplanar else { return false }
        let second = dilated.coplanarNormal(within: inside + radius, of: p)
        guard second.coplanar else { return false }
        guard let a = first.normal, let b = second.normal else { return true }
        return a ⋅ b > 1 - 1e-9
    }
}
