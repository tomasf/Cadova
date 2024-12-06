import Foundation

// OpenSCAD produces broken binary STL files when exporting to stdout.
// https://github.com/openscad/openscad/issues/5380
// This post-processing code calculates the correct triangle count based on the length of the data.

extension Data {
    func fixBinarySTLIfNeeded() -> Data {
        let triangleCountRange = 80..<84

        guard count >= triangleCountRange.upperBound,
              subdata(in: triangleCountRange) == Data([0, 0, 0, 0])
        else {
            return self
        }

        // Data length, without header, divided by triangle length
        let actualTriangleCount = UInt32((count - triangleCountRange.upperBound) / 50)

        var fixedData = self
        Swift.withUnsafeBytes(of: actualTriangleCount.littleEndian) { bufferPointer in
            fixedData.replaceSubrange(triangleCountRange, with: bufferPointer)
        }
        return fixedData
    }
}
