import * as THREE from "three";
import { LineSegments2 } from "three/addons/lines/LineSegments2.js";
import { LineSegmentsGeometry } from "three/addons/lines/LineSegmentsGeometry.js";
import { LineMaterial } from "three/addons/lines/LineMaterial.js";

// Like the native viewer, mark all three world axes in neutral gray, independently of the
// circular grid. Like SceneKit's line primitives, these stay one physical pixel wide.
export class OriginAxes extends LineSegments2 {
    constructor() {
        const extent = 10000;
        // Split at the origin so near-plane clipping of a long segment cannot distort its depth.
        const geometry = new LineSegmentsGeometry().setPositions([
            -extent, 0, 0, 0, 0, 0, 0, 0, 0, extent, 0, 0,
            0, -extent, 0, 0, 0, 0, 0, 0, 0, 0, extent, 0,
            0, 0, -extent, 0, 0, 0, 0, 0, 0, 0, 0, extent,
        ]);
        super(geometry, new LineMaterial({
            color: 0x575757, linewidth: 1, toneMapped: false,
            transparent: true, depthWrite: false,
        }));
        this.name = "Origin";
        this.visible = false;
    }

    onBeforeRender(renderer) {
        super.onBeforeRender(renderer);
        this.material.linewidth = 1 / renderer.getPixelRatio();
    }
}

// Project unit directions into camera space, without perspective or translation. This matches
// Cadova Viewer's 110-point indicator: 40-point lines and labels at a 50-point radius.
export class AxisIndicator {
    constructor(container) {
        const namespace = "http://www.w3.org/2000/svg";
        this.element = document.createElementNS(namespace, "svg");
        this.element.id = "axis-indicator";
        this.element.setAttribute("viewBox", "0 0 110 110");
        this.element.setAttribute("aria-hidden", "true");
        this.element.style.display = "none";
        this.axes = ["X", "Y", "Z"].map((label, index) => {
            const line = document.createElementNS(namespace, "line");
            line.dataset.axis = label.toLowerCase();
            line.setAttribute("x1", "55");
            line.setAttribute("y1", "55");
            const text = document.createElementNS(namespace, "text");
            text.textContent = label;
            this.element.append(line, text);
            const direction = new THREE.Vector3().setComponent(index, 1);
            return { line, text, direction };
        });
        this.rotation = new THREE.Quaternion();
        this.lastRotation = null;
        this.projected = new THREE.Vector3();
        container.append(this.element);
    }

    update(camera) {
        camera.getWorldQuaternion(this.rotation);
        if (this.lastRotation?.equals(this.rotation)) return;
        this.lastRotation ??= new THREE.Quaternion();
        this.lastRotation.copy(this.rotation);
        this.rotation.invert();
        for (const { line, text, direction } of this.axes) {
            this.projected.copy(direction).applyQuaternion(this.rotation);
            line.setAttribute("x2", 55 + this.projected.x * 40);
            line.setAttribute("y2", 55 - this.projected.y * 40);
            text.setAttribute("x", 55 + this.projected.x * 50);
            text.setAttribute("y", 55 - this.projected.y * 50);
        }
    }

    show() {
        this.element.style.removeProperty("display");
    }
}
