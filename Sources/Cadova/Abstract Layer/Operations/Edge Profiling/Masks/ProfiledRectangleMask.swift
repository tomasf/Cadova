import Foundation

internal struct ProfiledRectangleMask: Shape2D {
    let size: Vector2D
    let profile: EdgeProfile
    let corners: Rectangle.Corners

    init(size: Vector2D, profile: EdgeProfile, corners: Rectangle.Corners) {
        self.size = size
        self.profile = profile
        self.corners = corners
    }

    var body: any Geometry2D {
        let orderedCorners = corners.sorted()

        profile.profile.measuringBounds { profile, bounds in
            Rectangle(size)
                .aligned(at: .center)
                .subtracting {
                    for corner in orderedCorners {
                        Rectangle(bounds.size)
                            .translated(size / 2 - bounds.size)
                            .flipped(along: corner.flippedAxes)
                    }
                }
                .adding {
                    for corner in orderedCorners {
                        profile
                            .translated(size / 2)
                            .flipped(along: corner.flippedAxes)
                    }
                }
        }
    }
}

fileprivate extension Rectangle.Corner {
    var flippedAxes: Axes2D {
        switch (x, y) {
        case (.negative, .negative): [.x, .y]
        case (.positive, .negative): [.y]
        case (.positive, .positive): []
        case (.negative, .positive): [.x]
        }
    }
}
