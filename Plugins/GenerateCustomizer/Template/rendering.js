import * as THREE from "three";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";

// SceneKit blends translucent lines and resolves antialiasing in linear light. Do the same before
// converting to the display's color space; blending directly into the canvas makes the grid too dim.
export class ViewportRenderer {
    constructor(renderer) {
        this.renderer = renderer;
        this.target = new THREE.WebGLRenderTarget(1, 1, {
            type: renderer.extensions.has("EXT_color_buffer_float") ? THREE.HalfFloatType : THREE.UnsignedByteType,
            samples: Math.min(4, renderer.capabilities.maxSamples),
        });
        this.output = new OutputPass();
        this.output.renderToScreen = true;
        this.bufferSize = new THREE.Vector2();
    }

    setSize(width, height) {
        this.renderer.setSize(width, height, false);
        this.renderer.getDrawingBufferSize(this.bufferSize);
        this.target.setSize(Math.max(this.bufferSize.x, 1), Math.max(this.bufferSize.y, 1));
    }

    render(scene, camera) {
        this.renderer.setRenderTarget(this.target);
        this.renderer.render(scene, camera);
        this.output.render(this.renderer, null, this.target);
    }

    dispose() {
        this.target.dispose();
        this.output.dispose();
    }
}
