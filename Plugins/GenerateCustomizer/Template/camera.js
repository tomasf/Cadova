import * as THREE from "three";

// Cadova Viewer's Isometric preset uses this axis (its elevation is about 26.57 degrees).
const angle = THREE.MathUtils.degToRad(35.264);
const isometricAxis = new THREE.Vector3(-Math.cos(angle), -Math.cos(angle), Math.sin(angle)).normalize();

export function frameIsometric(camera, box, target) {
    if (box.isEmpty()) return;
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const forward = isometricAxis.clone().negate();
    const right = new THREE.Vector3().crossVectors(forward, camera.up).normalize();
    const up = new THREE.Vector3().crossVectors(right, forward).normalize();

    // Project the box onto the camera's right/up vectors, as frameBoundingBox does in ViewerCore.
    // For an axis-aligned box, its span is the sum of the projected lengths of its three edges.
    let width = Math.abs(right.x) * size.x + Math.abs(right.y) * size.y + Math.abs(right.z) * size.z;
    let height = Math.abs(up.x) * size.x + Math.abs(up.y) * size.y + Math.abs(up.z) * size.z;
    if (width <= 0 || height <= 0 || !Number.isFinite(width + height)) {
        width = height = Math.max(size.x, size.y, size.z, 1);
    }
    const aspect = Number.isFinite(camera.aspect) && camera.aspect > 0 ? camera.aspect : 1;
    const halfHeight = Math.max(width / 2 / aspect, height / 2) * 1.5;
    const distance = halfHeight / Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2);
    target.copy(center);
    camera.position.copy(center).addScaledVector(isometricAxis, distance);
    camera.lookAt(center);
    camera.near = Math.max(size.length() / 100, 0.001);
    camera.far = Math.max(size.length() * 100, distance * 2);
    camera.updateProjectionMatrix();
}
