#include "manifold/cross_section.h"
#include <swift/bridging>

namespace cadova {

struct Point {
    double x;
    double y;

    Point() = default;
    Point(double x_, double y_) : x(x_), y(y_) {}
};

class PolygonNode {
public:
    std::vector<Point> polygon;
    std::vector<PolygonNode*> children;

    PolygonNode() = default;
    PolygonNode(std::vector<Point> polygon_) : polygon(std::move(polygon_)) {}

    static const PolygonNode* FromPolygons(const manifold::Polygons inputPolygons);
    static void Destroy(const PolygonNode* node);

    ~PolygonNode() {
        for (auto* child : children) {
            delete child;
        }
    }
} SWIFT_UNSAFE_REFERENCE;

}
