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
/// Both terms change no faster than position, so neither does their minimum, as contouring needs.
internal final class RoundingField: @unchecked Sendable {
    private let eroded: MeshDistanceField
    private let dilated: MeshDistanceField
    private let outside: Double
    private let inside: Double

    init(eroded: MeshDistanceField, dilated: MeshDistanceField, outside: Double, inside: Double, margin: Double) {
        self.eroded = eroded
        self.dilated = dilated
        self.outside = outside
        self.inside = inside + margin
    }

    /// The vertices the result lies within: the result is inside D
    var vertices: [Vector3D] { dilated.vertices }

    // Hints pack a face of each mesh (plus one, so zero means none) into one number
    private static func unpack(_ hint: Int?) -> (Int?, Int?) {
        guard let hint, hint > 0 else { return (nil, nil) }
        let e = hint & 0xffff_ffff, d = hint >> 32
        return (e > 0 ? e - 1 : nil, d > 0 ? d - 1 : nil)
    }

    private static func pack(_ e: Int, _ d: Int) -> Int {
        (e + 1) | (d + 1) << 32
    }

    /// The function (negative inside the result), and a hint for nearby queries
    func value(at p: Vector3D, hint: Int?) -> (value: Double, face: Int) {
        let (e, d) = Self.unpack(hint)
        let rounded = eroded.signedDistanceAndFace(at: p, hint: e)
        let filleted = dilated.signedDistanceAndFace(at: p, hint: d)
        return (min(rounded.value - outside, filleted.value + inside), Self.pack(rounded.face, filleted.face))
    }

    /// The function, its gradient, and a hint for nearby queries
    func valueAndGradient(at p: Vector3D, hint: Int?) -> (value: Double, gradient: Vector3D, face: Int) {
        let (e, d) = Self.unpack(hint)
        let rounded = eroded.signedDistanceAndGradient(at: p, hint: e)
        let filleted = dilated.signedDistanceAndGradient(at: p, hint: d)
        let face = Self.pack(rounded.face, filleted.face)
        if rounded.value - outside <= filleted.value + inside {
            return (rounded.value - outside, rounded.gradient, face)
        }
        return (filleted.value + inside, filleted.gradient, face)
    }

    /// Whether the surface within radius of p is provably one plane: each term's surface there is one plane, and
    /// where both have one, they're parallel, so their minimum is the outer of the two
    func isPlanar(within radius: Double, of p: Vector3D) -> Bool {
        let first = eroded.coplanarNormal(within: outside + radius, of: p)
        guard first.coplanar else { return false }
        let second = dilated.coplanarNormal(within: inside + radius, of: p)
        guard second.coplanar else { return false }
        guard let a = first.normal, let b = second.normal else { return true }
        return a ⋅ b > 1 - 1e-9
    }
}
