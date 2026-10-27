// Reads a 3MF file into three.js meshes with their colors and materials. three.js's own 3MF loader
// drops alpha, ignores metallic display properties for colors, and adds an uncolored copy of a
// whole object when only some of its triangles have a color, so the page reads 3MF itself. This
// covers what Cadova writes: build items (also in separate model files, from the production
// extension), components, color groups, base materials and physically based metallic properties.

import * as THREE from "three";
import { appearanceDefaults as defaults, createMaterial, createPartMeshes } from "./meshes.js";
import { unzipSync, strFromU8 } from "three/addons/libs/fflate.module.js";

const CORE = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02";
const MATERIAL = "http://schemas.microsoft.com/3dmanufacturing/material/2015/02";
const PRODUCTION = "http://schemas.microsoft.com/3dmanufacturing/production/2015/06";
const CADOVA = "https://cadova.org/3mf";
const MODEL_RELATIONSHIP = "http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel";

// Reads a 3MF file. Triangles without a color of their own get the default color. Returns a group
// holding a mesh for each object and material.
export function read3MF(buffer, defaultColor) {
    const files = unzipSync(new Uint8Array(buffer));
    const documents = new Map();
    const materials = new Map();

    const fileText = (path) => {
        const data = files[path.replace(/^\//, "")];
        if (!data) throw new Error(`The 3MF file has no ${path}`);
        return strFromU8(data);
    };

    const model = (path) => {
        if (!documents.has(path)) {
            const document = new DOMParser().parseFromString(fileText(path), "application/xml");
            documents.set(path, { document, resources: readResources(document) });
        }
        return documents.get(path);
    };

    // The model's main file is named by the package's relationships, usually /3D/3dmodel.model
    let rootPath = "/3D/3dmodel.model";
    try {
        const relationships = new DOMParser().parseFromString(fileText("_rels/.rels"), "application/xml");
        for (const relationship of relationships.getElementsByTagName("Relationship")) {
            if (relationship.getAttribute("Type") === MODEL_RELATIONSHIP) rootPath = relationship.getAttribute("Target");
        }
    } catch {
        // No relationships file; use the usual name
    }

    // A group for each build item, which is a part of the model, named like its object as in Cadova
    // Viewer, with the item's part number, if any, and semantic in its user data
    const group = new THREE.Group();
    const root = model(rootPath);
    const build = root.document.getElementsByTagNameNS(CORE, "build")[0];
    for (const [index, item] of [...build?.getElementsByTagNameNS(CORE, "item") ?? []].entries()) {
        const path = item.getAttributeNS(PRODUCTION, "path") || rootPath;
        const semantic = item.getAttributeNS(CADOVA, "semantic") || "solid";
        const objectID = item.getAttribute("objectid");
        const part = new THREE.Group();
        part.name = model(path).resources.objects.get(objectID)?.getAttribute("name") || `Object ${index + 1}`;
        part.userData = { partNumber: item.getAttribute("partnumber"), semantic };
        addObject(part, path, objectID, readTransform(item.getAttribute("transform")), semantic);
        group.add(part);
    }
    // The model's metadata, such as its title and the application that made it, in document order
    group.userData.metadata = [...root.document.getElementsByTagNameNS(CORE, "metadata")]
        .filter((node) => node.parentNode === root.document.documentElement)
        .map((node) => ({ name: node.getAttribute("name"), value: node.textContent }));
    return group;

    function addObject(parent, path, id, transform, semantic) {
        const { resources } = model(path);
        const object = resources.objects.get(id);
        if (!object) throw new Error(`The 3MF file has no object ${id} in ${path}`);

        const mesh = object.getElementsByTagNameNS(CORE, "mesh")[0];
        if (mesh) {
            for (const part of readMesh(mesh, object, resources, path, semantic)) {
                part.applyMatrix4(transform);
                parent.add(part);
            }
        }
        for (const component of object.getElementsByTagNameNS(CORE, "component")) {
            const componentPath = component.getAttributeNS(PRODUCTION, "path") || path;
            const componentTransform = readTransform(component.getAttribute("transform")).premultiply(transform);
            addObject(parent, componentPath, component.getAttribute("objectid"), componentTransform, semantic);
        }
    }

    // A mesh for each material the object's triangles use, sharing the object's vertices
    function readMesh(mesh, object, resources, path, semantic) {
        const vertexNodes = mesh.getElementsByTagNameNS(CORE, "vertex");
        const positions = new Float32Array(vertexNodes.length * 3);
        for (let i = 0; i < vertexNodes.length; i++) {
            positions[i * 3] = Number(vertexNodes[i].getAttribute("x"));
            positions[i * 3 + 1] = Number(vertexNodes[i].getAttribute("y"));
            positions[i * 3 + 2] = Number(vertexNodes[i].getAttribute("z"));
        }

        const objectProperty = object.getAttribute("pid");
        const objectIndex = object.getAttribute("pindex") ?? "0";
        const triangles = mesh.getElementsByTagNameNS(CORE, "triangle");
        const indices = new Uint32Array(triangles.length * 3);
        const faceMaterials = [];
        for (let face = 0; face < triangles.length; face++) {
            const triangle = triangles[face];
            const property = triangle.getAttribute("pid") ?? objectProperty;
            const index = triangle.getAttribute("p1") ?? (triangle.getAttribute("pid") ? "0" : objectIndex);
            const key = property ? `${property}:${index}` : "";
            indices[face * 3] = Number(triangle.getAttribute("v1"));
            indices[face * 3 + 1] = Number(triangle.getAttribute("v2"));
            indices[face * 3 + 2] = Number(triangle.getAttribute("v3"));
            faceMaterials.push(material(path, resources, key));
        }
        return createPartMeshes(positions, indices, faceMaterials, semantic);
    }

    function material(path, resources, key) {
        const cacheKey = `${path}|${key}`;
        if (materials.has(cacheKey)) return materials.get(cacheKey);

        let appearance = { color: new THREE.Color(defaultColor), opacity: 1, ...defaults };
        if (key) {
            const [property, index] = key.split(":");
            appearance = { ...appearance, ...resources.properties.get(property)?.[Number(index)] };
        }
        const result = createMaterial(appearance);
        materials.set(cacheKey, result);
        return result;
    }
}

// The objects and the material properties of one model file. Properties are kept as arrays of
// { color, opacity, roughness, metalness }, indexed the way triangles refer to them.
function readResources(document) {
    const objects = new Map();
    for (const object of document.getElementsByTagNameNS(CORE, "object")) objects.set(object.getAttribute("id"), object);

    const displayProperties = new Map();
    for (const group of document.getElementsByTagNameNS(MATERIAL, "pbmetallicdisplayproperties")) {
        displayProperties.set(group.getAttribute("id"), [...group.getElementsByTagNameNS(MATERIAL, "pbmetallic")].map((node) => ({
            metalness: Number(node.getAttribute("metallicness") ?? defaults.metalness),
            roughness: Number(node.getAttribute("roughness") ?? defaults.roughness),
        })));
    }

    const properties = new Map();
    const addGroup = (group, entries, colorOf) => {
        const display = displayProperties.get(group.getAttribute("displaypropertiesid"));
        properties.set(group.getAttribute("id"), entries.map((entry, index) => ({
            ...readColor(colorOf(entry)),
            ...(display?.[index] ?? display?.[0]),
        })));
    };
    for (const group of document.getElementsByTagNameNS(MATERIAL, "colorgroup")) {
        addGroup(group, [...group.getElementsByTagNameNS(MATERIAL, "color")], (node) => node.getAttribute("color"));
    }
    for (const group of document.getElementsByTagNameNS(CORE, "basematerials")) {
        addGroup(group, [...group.getElementsByTagNameNS(CORE, "base")], (node) => node.getAttribute("displaycolor"));
    }
    return { objects, properties };
}

// A 3MF color: #RRGGBB or #RRGGBBAA, in sRGB
function readColor(text) {
    const hex = (text ?? "").replace("#", "");
    if (!/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(hex)) return {};
    const color = new THREE.Color().setStyle(`#${hex.slice(0, 6)}`);
    const opacity = hex.length === 8 ? parseInt(hex.slice(6, 8), 16) / 255 : 1;
    return { color, opacity };
}

// A 3MF transform lists the first three columns of a 4×4 matrix row by row, for row vectors
function readTransform(text) {
    const matrix = new THREE.Matrix4();
    if (!text) return matrix;
    const m = text.trim().split(/\s+/).map(Number);
    return matrix.set(
        m[0], m[3], m[6], m[9],
        m[1], m[4], m[7], m[10],
        m[2], m[5], m[8], m[11],
        0, 0, 0, 1,
    );
}
