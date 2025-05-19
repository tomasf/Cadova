#include "manifold/cross_section.h"
#include "manifold/manifold.h"
//#include <swift/bridging>

// This is from swift/bridging
#define SWIFT_UNSAFE_REFERENCE \
__attribute__((swift_attr("import_reference"))) \
__attribute__((swift_attr("retain:immortal"))) \
__attribute__((swift_attr("release:immortal"))) \
__attribute__((swift_attr("unsafe")))

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

void BulkReadMesh(const manifold::Manifold& man,
                  void(^propertyReader)(const double *const values, size_t vertexCount, size_t propertyCount), // count of values is vertexCount * propertyCount
                  void(^triangleReader)(const uint64_t *const values, size_t count), // count of values is count * 3
                  void(^originalIDReader)(const uint64_t *const runIndex, size_t runIndexCount, const uint32_t *const runOriginalIDs, size_t originalIDCount) // counts are actual
                  );
}
