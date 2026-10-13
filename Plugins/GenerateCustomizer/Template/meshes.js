// Turns a model's parts into three.js meshes, whether they come from a preview or a 3MF file

import * as THREE from "three";
import { createSharpEdges } from "./edges.js";

// How a triangle without a material of its own looks, and how parts that aren't printed show
export const appearanceDefaults = { roughness: 0.9, metalness: 0, contextOpacity: 0.3 };

// A material for an appearance, { color, opacity, roughness, metalness }, on a part of the given semantic
export function createMaterial({ color, opacity, roughness, metalness }, semantic) {
    if (semantic === "context") opacity *= appearanceDefaults.contextOpacity;
    return new THREE.MeshStandardMaterial({
        color, roughness, metalness, opacity,
        transparent: opacity < 1,
        depthWrite: opacity >= 1,
    });
}

// A mesh for each material a part's triangles use, sharing the part's vertices. Parts that are
// printed also get outlines along their sharp edges.
export function createPartMeshes(positions, indices, faceMaterials, semantic) {
    const indicesByMaterial = new Map();
    for (let face = 0; face < faceMaterials.length; face++) {
        const material = faceMaterials[face];
        if (!indicesByMaterial.has(material)) indicesByMaterial.set(material, []);
        indicesByMaterial.get(material).push(indices[face * 3], indices[face * 3 + 1], indices[face * 3 + 2]);
    }

    const position = new THREE.BufferAttribute(positions, 3);
    const meshes = [...indicesByMaterial].map(([material, materialIndices]) => {
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute("position", position);
        geometry.setIndex(materialIndices);
        return new THREE.Mesh(geometry, material);
    });
    if (meshes.length && semantic !== "context" && semantic !== "visual") {
        const edges = createSharpEdges(positions, indices, faceMaterials);
        if (edges) meshes[0].add(edges);
    }
    return meshes;
}
