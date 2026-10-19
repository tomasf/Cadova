// Reads a model's preview into three.js meshes. Cadova writes it for the customizer in place of a
// 3MF file: the same parts, colors and materials, as plain arrays the page can view in place rather
// than XML in a zip archive. ThreeMFDataProvider+CustomizerPreview.swift describes the format.

import * as THREE from "three";
import { appearanceDefaults, createMaterial, createPartMeshes } from "./meshes.js";

// Reads a preview. Triangles without a material of their own get the part's default material, or
// else the default color. Returns a group holding a mesh for each part and material.
export function readPreview(buffer, defaultColor) {
    const view = new DataView(buffer);
    let offset = 0;
    const uint32 = () => { const value = view.getUint32(offset, true); offset += 4; return value; };
    const int32 = () => { const value = view.getInt32(offset, true); offset += 4; return value; };
    const float64 = () => { const value = view.getFloat64(offset, true); offset += 8; return value; };
    const string = () => {
        const length = uint32();
        const text = new TextDecoder().decode(new Uint8Array(buffer, offset, length));
        offset += Math.ceil(length / 4) * 4;
        return text;
    };
    const array = (Type, count) => {
        const result = new Type(buffer, offset, count);
        offset += count * Type.BYTES_PER_ELEMENT;
        return result;
    };

    if (new TextDecoder().decode(new Uint8Array(buffer, 0, 4)) !== "CDVP") throw new Error("The model's preview isn't readable");
    offset = 4;
    const version = uint32();
    if (version !== 1) throw new Error(`The model's preview has an unknown version, ${version}`);

    const group = new THREE.Group();
    const partCount = uint32();
    for (let part = 0; part < partCount; part++) {
        string(); // id
        string(); // name
        const semantic = string();
        const positions = array(Float32Array, uint32() * 3);
        const triangleCount = uint32();
        const indices = array(Uint32Array, triangleCount * 3);
        const materialIndices = array(Int32Array, triangleCount);
        const defaultMaterialIndex = int32();

        const materials = Array.from({ length: uint32() }, () => {
            const [red, green, blue, alpha] = array(Uint8Array, 4);
            const metalness = float64(), roughness = float64();
            return createMaterial({
                color: new THREE.Color().setRGB(red / 255, green / 255, blue / 255, THREE.SRGBColorSpace),
                opacity: alpha / 255,
                metalness: Number.isNaN(metalness) ? appearanceDefaults.metalness : metalness,
                roughness: Number.isNaN(roughness) ? appearanceDefaults.roughness : roughness,
            });
        });
        const fallback = materials[defaultMaterialIndex] ?? createMaterial({
            color: new THREE.Color(defaultColor), opacity: 1, ...appearanceDefaults,
        });
        const faceMaterials = Array.from(materialIndices, (index) => materials[index] ?? fallback);

        for (const mesh of createPartMeshes(positions, indices, faceMaterials, semantic)) group.add(mesh);
    }
    return group;
}
