import * as THREE from "three";

// Classify the complete indexed mesh before splitting it by material or smoothing its normals.
// Like Cadova Viewer, outline only edges shared by two faces with a crease greater than 30°.
export function createSharpEdges(positions, indices, faceMaterials) {
    const normals = new Float64Array(indices.length);
    for (let face = 0; face < indices.length / 3; face++) {
        const a = indices[face * 3] * 3, b = indices[face * 3 + 1] * 3, c = indices[face * 3 + 2] * 3;
        const ux = positions[b] - positions[a], uy = positions[b + 1] - positions[a + 1], uz = positions[b + 2] - positions[a + 2];
        const vx = positions[c] - positions[a], vy = positions[c + 1] - positions[a + 1], vz = positions[c + 2] - positions[a + 2];
        const x = uy * vz - uz * vy, y = uz * vx - ux * vz, z = ux * vy - uy * vx;
        const length = Math.hypot(x, y, z);
        normals[face * 3] = x / length;
        normals[face * 3 + 1] = y / length;
        normals[face * 3 + 2] = z / length;
    }

    const vertexCount = positions.length / 3;
    const numericKeys = Number.isSafeInteger(vertexCount * vertexCount);
    const threshold = Math.cos(THREE.MathUtils.degToRad(30));
    const adjacency = new Map();
    const segments = [];
    for (let face = 0; face < indices.length / 3; face++) {
        for (let edge = 0; edge < 3; edge++) {
            const v1 = indices[face * 3 + edge], v2 = indices[face * 3 + (edge + 1) % 3];
            const a = Math.min(v1, v2), b = Math.max(v1, v2);
            const key = numericKeys ? a * vertexCount + b : `${a}:${b}`;
            const previous = adjacency.get(key);
            if (previous === undefined) {
                adjacency.set(key, face + 1);
            } else if (previous > 0) {
                const first = previous - 1;
                const dot = normals[first * 3] * normals[face * 3]
                    + normals[first * 3 + 1] * normals[face * 3 + 1]
                    + normals[first * 3 + 2] * normals[face * 3 + 2];
                if (dot < threshold) {
                    segments.push([a, b, first, face]);
                    adjacency.set(key, -segments.length);
                } else {
                    adjacency.set(key, 0);
                }
            } else {
                // An edge shared by three or more faces is not a manifold crease.
                if (previous < 0) segments[-previous - 1] = null;
                adjacency.set(key, 0);
            }
        }
    }

    const sharp = segments.filter(Boolean);
    if (!sharp.length) return null;
    const vertices = new Float32Array(sharp.length * 6);
    const colors = new Float32Array(sharp.length * 6);
    const light = new THREE.Color("#8c8c8c");
    const isDark = ({ color }) => color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722 < 0.05;
    for (let i = 0; i < sharp.length; i++) {
        const [a, b, first, second] = sharp[i];
        vertices.set(positions.subarray(a * 3, a * 3 + 3), i * 6);
        vertices.set(positions.subarray(b * 3, b * 3 + 3), i * 6 + 3);
        if (isDark(faceMaterials[first]) || isDark(faceMaterials[second])) {
            light.toArray(colors, i * 6);
            light.toArray(colors, i * 6 + 3);
        }
    }

    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(vertices, 3));
    geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    const material = new THREE.LineBasicMaterial({ vertexColors: true, transparent: true, depthWrite: false, toneMapped: false });
    material.onBeforeCompile = (shader) => {
        // Bring lines slightly toward the camera, as the native viewer does, to avoid z-fighting.
        // Keep depth testing so edges behind the model remain hidden.
        shader.vertexShader = shader.vertexShader.replace("#include <project_vertex>", `
            #include <project_vertex>
            mvPosition.z += min(max(-mvPosition.z, 0.0), 1000.0) * 0.001;
            gl_Position = projectionMatrix * mvPosition;
        `);
    };
    const lines = new THREE.LineSegments(geometry, material);
    lines.name = "sharp-edges";
    lines.renderOrder = 1;
    return lines;
}
