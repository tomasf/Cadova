import * as THREE from "three";

// A circular patch of world-aligned grid lines on z = 0. Bounds and the metric spacing ladder
// follow Cadova Viewer's ViewportGrid; the shader fades and antialiases the lines per pixel.
export class ViewportGrid extends THREE.Mesh {
    constructor(color) {
        super(new THREE.PlaneGeometry(2, 2), new THREE.ShaderMaterial({
            uniforms: {
                color: { value: new THREE.Color(color) },
                center: { value: new THREE.Vector2() },
                radius: { value: 1 },
                spacing: { value: 10 },
                fineOpacity: { value: 0 },
            },
            transparent: true,
            depthWrite: false,
            side: THREE.DoubleSide,
            toneMapped: false,
            // Keep coplanar model faces in front of the grid, without moving its reference plane.
            polygonOffset: true,
            polygonOffsetFactor: 1,
            polygonOffsetUnits: 1,
            vertexShader: `
                varying vec2 gridPosition;
                void main() {
                    vec4 world = modelMatrix * vec4(position, 1.0);
                    gridPosition = world.xy;
                    gl_Position = projectionMatrix * viewMatrix * world;
                }
            `,
            fragmentShader: `
                uniform vec3 color;
                uniform vec2 center;
                uniform float radius;
                uniform float spacing;
                uniform float fineOpacity;
                varying vec2 gridPosition;

                float gridAlpha(float cellSize, float opacity) {
                    vec2 coordinates = gridPosition / cellSize;
                    vec2 pixelSize = max(fwidth(coordinates), vec2(0.000001));
                    vec2 distance = abs(fract(coordinates + 0.5) - 0.5) / pixelSize;
                    vec2 lines = (1.0 - smoothstep(vec2(0.0), vec2(1.0), distance)) * opacity;
                    // Suppress subpixel cells near the horizon, where they would alias into a fill.
                    lines *= 1.0 - smoothstep(vec2(0.25), vec2(0.75), pixelSize);
                    return 1.0 - (1.0 - lines.x) * (1.0 - lines.y);
                }

                void main() {
                    float radialDistance = length((gridPosition - center) / radius);
                    if (radialDistance >= 1.0) discard;
                    float fade = 1.0 - smoothstep(0.6, 1.0, radialDistance);
                    float coarse = gridAlpha(spacing, 0.036);
                    float fine = gridAlpha(spacing / 10.0, 0.036 * fineOpacity);
                    gl_FragColor = vec4(color, (1.0 - (1.0 - coarse) * (1.0 - fine)) * fade);
                    #include <colorspace_fragment>
                }
            `,
        }));
        this.name = "Grid";
        this.renderOrder = -1;
        this.visible = false;
        this.modelCenter = new THREE.Vector3();
        this.modelBaseRadius = 0;
        this.gridRadius = 0;
        this.raycaster = new THREE.Raycaster();
        this.screenCenter = new THREE.Vector2();
        this.focus = new THREE.Vector3();
        this.nextCenter = new THREE.Vector3();
        this.cameraPosition = new THREE.Vector3();
        this.cameraDirection = new THREE.Vector3();
        this.projectedCenter = new THREE.Vector3();
        this.projectedNeighbor = new THREE.Vector3();
    }

    updateBounds(box) {
        if (box.isEmpty()) {
            this.visible = false;
            this.modelBaseRadius = 0;
            return;
        }
        const modelRadius = Math.hypot(box.max.x - box.min.x, box.max.y - box.min.y) / 2;
        const radius = Math.max(Math.ceil(modelRadius * 1.5 / 20) * 20, 20);
        this.modelCenter.set((box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2, 0);
        this.modelBaseRadius = radius;
        this.setFootprint(this.modelCenter, radius);
        this.gridRadius = 0; // Recompute the view-following footprint on the next frame.
        this.visible = true;
    }

    setFootprint(center, radius) {
        this.position.copy(center);
        this.scale.set(radius, radius, 1);
        this.material.uniforms.center.value.set(center.x, center.y);
        this.material.uniforms.radius.value = radius;
        this.gridRadius = radius;
    }

    updateScale(camera, width, height) {
        if (this.modelBaseRadius <= 0 || width <= 0 || height <= 0) return;
        camera.getWorldDirection(this.cameraDirection);
        // Native orthographic views looking up from below hide the plane, but keep origin axes.
        this.visible = !camera.isOrthographicCamera || this.cameraDirection.z <= 0;
        if (!this.visible) return;

        this.raycaster.setFromCamera(this.screenCenter, camera);
        const { origin, direction } = this.raycaster.ray;
        const distanceAlongRay = Math.abs(direction.z) > 1e-9 ? -origin.z / direction.z : -1;
        this.focus.copy(this.modelCenter);
        if (distanceAlongRay > 0) this.focus.copy(origin).addScaledVector(direction, distanceAlongRay);
        this.focus.z = 0;
        this.cameraPosition.setFromMatrixPosition(camera.matrixWorld);
        const distance = this.cameraPosition.distanceTo(this.focus);
        const base = this.modelBaseRadius;
        const radius = THREE.MathUtils.clamp(distance, base * 0.1, base * 25) * 2;
        const farBlend = THREE.MathUtils.smoothstep(distance, base * 12, base * 25);
        this.nextCenter.copy(this.focus).lerp(this.modelCenter, farBlend);
        const centerShift = this.nextCenter.distanceTo(this.position);
        const radiusRatio = this.gridRadius > 0 ? radius / this.gridRadius : Infinity;
        if (this.gridRadius === 0 || centerShift > this.gridRadius * 0.1 || radiusRatio > 1.1 || radiusRatio < 0.9) {
            this.setFootprint(this.nextCenter, radius);
        }

        // Sample pixels per millimeter at the screen center's hit on z = 0, along the world diagonal.
        this.projectedCenter.copy(this.focus).project(camera);
        this.projectedNeighbor.copy(this.focus);
        this.projectedNeighbor.x += 1;
        this.projectedNeighbor.y += 1;
        this.projectedNeighbor.project(camera);
        const pixels = Math.hypot(
            (this.projectedNeighbor.x - this.projectedCenter.x) * width / 2,
            (this.projectedNeighbor.y - this.projectedCenter.y) * height / 2,
        ) / Math.SQRT2;
        const scale = THREE.MathUtils.clamp(pixels, 0.00011, 400);
        if (!Number.isFinite(scale)) return;
        const exponent = Math.log10(scale);
        this.material.uniforms.spacing.value = 10 ** (2 - Math.floor(exponent));
        // Fine lines fade in over a decade, then become the coarse lines of the next one.
        this.material.uniforms.fineOpacity.value = THREE.MathUtils.clamp(1 - (Math.ceil(exponent) - exponent), 0, 1);
    }
}
