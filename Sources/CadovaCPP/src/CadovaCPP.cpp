#include "CadovaCPP.h"
#include "clipper2/clipper.h"

namespace cadova {

PolygonNode* NodeFromClipperTree(const Clipper2Lib::PolyPathD* node) {
    if (!node) return nullptr;

    std::vector<Point> polygon;
    for (const auto& pt : node->Polygon()) {
        polygon.emplace_back(pt.x, pt.y);
    }

    auto* result = new PolygonNode(std::move(polygon));
    for (const auto& child : *node) {
        result->children.push_back(NodeFromClipperTree(child.get()));
    }

    return result;
}

inline Clipper2Lib::PathsD PathsDFromManifoldPolygon(const manifold::Polygons& polys) {
    Clipper2Lib::PathsD result;
    result.reserve(polys.size());

    for (const auto& poly : polys) {
        Clipper2Lib::PathD path;
        path.reserve(poly.size());

        for (const auto& v : poly) {
            path.emplace_back(v.x, v.y);
        }

        result.push_back(std::move(path));
    }

    return result;
}

const PolygonNode* PolygonNode::FromPolygons(const manifold::Polygons inputPolygons) {
    using namespace Clipper2Lib;
    PathsD paths;
    paths.reserve(inputPolygons.size());

    for (const auto& poly : inputPolygons) {
        PathD path;
        path.reserve(poly.size());
        for (const auto& pt : poly) {
            path.emplace_back(PointD(pt.x, pt.y));
        }
        paths.emplace_back(std::move(path));
    }

    PolyTreeD tree;
    BooleanOp(ClipType::Union, FillRule::Positive, paths, PathsD(), tree, 8);
    return NodeFromClipperTree(&tree);
}

void PolygonNode::Destroy(const PolygonNode* node) {
    delete node;
}

}
