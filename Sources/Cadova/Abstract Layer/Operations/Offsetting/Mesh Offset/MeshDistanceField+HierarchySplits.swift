import Foundation

extension MeshDistanceField.Hierarchy {
    /// Where to split the faces in first..<first + count: along the centroids' longest extent
    func splitPoint(first: Int, count: Int) -> Int {
        var low = (Double.infinity, Double.infinity, Double.infinity), high = (-Double.infinity, -Double.infinity, -Double.infinity)
        var i = first
        while i < first + count {
            let f = orderBuffer[i]
            low = (min(low.0, centroids[3 * f]), min(low.1, centroids[3 * f + 1]), min(low.2, centroids[3 * f + 2]))
            high = (max(high.0, centroids[3 * f]), max(high.1, centroids[3 * f + 1]), max(high.2, centroids[3 * f + 2]))
            i += 1
        }
        let extent = (high.0 - low.0, high.1 - low.1, high.2 - low.2)
        let axis = extent.0 >= extent.1 && extent.0 >= extent.2 ? 0 : (extent.1 >= extent.2 ? 1 : 2)
        return splitBySurfaceArea(first: first, count: count, axis: axis,
                                  low: axis == 0 ? low.0 : axis == 1 ? low.1 : low.2,
                                  high: axis == 0 ? high.0 : axis == 1 ? high.1 : high.2)
    }

    /// Splits the faces in first..<first + count where the children's boxes have the least surface area for the faces
    /// they hold (binned along the axis), so queries visit fewer nodes; or at the median where that's degenerate.
    /// Returns where the second child starts.
    func splitBySurfaceArea(first: Int, count: Int, axis: Int, low: Double, high: Double) -> Int {
        let binCount = 16
        guard high > low else {
            select(first + count / 2, from: first, to: first + count, axis: axis)
            return first + count / 2
        }
        let scale = Double(binCount) / (high - low)
        func bin(_ face: Int) -> Int { min(binCount - 1, Int((centroids[3 * face + axis] - low) * scale)) }
        // Each bin's face count and box, as lower then upper corner, and the cost of splitting after it, on the
        // stack: this runs for every node, and arrays allocate
        let best = withUnsafeTemporaryAllocation(of: Int.self, capacity: binCount) { counts in
        withUnsafeTemporaryAllocation(of: Double.self, capacity: 7 * binCount) { storage in
            let boxes = storage.baseAddress!, leftCost = storage.baseAddress! + 6 * binCount
            return bestSplit(first: first, count: count, binCount: binCount, bin: bin, counts: counts.baseAddress!, boxes: boxes, leftCost: leftCost)
        }
        }
        guard best >= 0 else {
            select(first + count / 2, from: first, to: first + count, axis: axis)
            return first + count / 2
        }
        // Partition: faces in bins up to the best one first
        var lower = first, upper = first + count - 1
        while lower <= upper {
            if bin(orderBuffer[lower]) <= best { lower += 1 }
            else {
                let swapped = orderBuffer[lower]; orderBuffer[lower] = orderBuffer[upper]; orderBuffer[upper] = swapped
                upper -= 1
            }
        }
        return lower
    }

    /// The bin after which splitting costs least, or -1 where no split separates anything
    func bestSplit(first: Int, count: Int, binCount: Int, bin: (Int) -> Int, counts: UnsafeMutablePointer<Int>,
                           boxes: UnsafeMutablePointer<Double>, leftCost: UnsafeMutablePointer<Double>) -> Int {
        var b = 0
        while b < binCount { counts[b] = 0; leftCost[b] = 0; b += 1 }
        b = 0
        while b < binCount {
            boxes[6 * b] = .infinity; boxes[6 * b + 1] = .infinity; boxes[6 * b + 2] = .infinity
            boxes[6 * b + 3] = -.infinity; boxes[6 * b + 4] = -.infinity; boxes[6 * b + 5] = -.infinity
            b += 1
        }
        var i = first
        while i < first + count {
            let f = orderBuffer[i]
            let target = bin(f)
            counts[target] += 1
            let face = faces[f]
            var corner = 0
            while corner < 3 {
                let v = corner == 0 ? face.0 : corner == 1 ? face.1 : face.2
                var a = 0
                while a < 3 {
                    boxes[6 * target + a] = min(boxes[6 * target + a], coordinates[3 * v + a])
                    boxes[6 * target + 3 + a] = max(boxes[6 * target + 3 + a], coordinates[3 * v + a])
                    a += 1
                }
                corner += 1
            }
            i += 1
        }
        func area(_ box: (Double, Double, Double, Double, Double, Double)) -> Double {
            let dx = box.3 - box.0, dy = box.4 - box.1, dz = box.5 - box.2
            return dx >= 0 ? dx * dy + dy * dz + dz * dx : 0
        }
        func merged(_ box: (Double, Double, Double, Double, Double, Double), _ b: Int) -> (Double, Double, Double, Double, Double, Double) {
            (min(box.0, boxes[6 * b]), min(box.1, boxes[6 * b + 1]), min(box.2, boxes[6 * b + 2]),
             max(box.3, boxes[6 * b + 3]), max(box.4, boxes[6 * b + 4]), max(box.5, boxes[6 * b + 5]))
        }
        let empty = (Double.infinity, Double.infinity, Double.infinity, -Double.infinity, -Double.infinity, -Double.infinity)
        // Cost of splitting after each bin: the left side's area and count from the left, the right's from the right
        var box = empty, running = 0
        b = 0
        while b < binCount - 1 {
            box = merged(box, b); running += counts[b]
            leftCost[b] = area(box) * Double(running)
            b += 1
        }
        var best = -1, bestCost = Double.infinity
        box = empty; running = 0
        b = binCount - 1
        while b > 0 {
            box = merged(box, b); running += counts[b]
            let left = count - running
            if left > 0 && running > 0 {
                let cost = leftCost[b - 1] + area(box) * Double(running)
                if cost < bestCost { bestCost = cost; best = b - 1 }
            }
            b -= 1
        }
        return best
    }

    /// Reorders the faces in first..<end so the one at `nth` is the one sorting would put there, with no larger
    /// one before it and no smaller one after (Hoare's selection)
    func select(_ nth: Int, from first: Int, to end: Int, axis: Int) {
        var low = first, high = end - 1
        while low < high {
            let pivot = centroids[3 * orderBuffer[(low + high) / 2] + axis]
            var i = low, j = high
            while i <= j {
                while centroids[3 * orderBuffer[i] + axis] < pivot { i += 1 }
                while centroids[3 * orderBuffer[j] + axis] > pivot { j -= 1 }
                if i <= j {
                    let swapped = orderBuffer[i]; orderBuffer[i] = orderBuffer[j]; orderBuffer[j] = swapped
                    i += 1; j -= 1
                }
            }
            if nth <= j { high = j } else if nth >= i { low = i } else { return }
        }
    }
}
