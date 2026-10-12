import * as THREE from "three";

// Cadova Viewer's directional headlight (800) and small ambient fill (30), expressed in
// Three.js's irradiance units. Its PBR diffuse BRDF divides incoming light by pi.
export function setupLighting(scene, camera, renderer) {
    const ambient = new THREE.AmbientLight(0xffffff, Math.PI * 0.03);
    scene.add(ambient);
    const headlight = new THREE.DirectionalLight(0xffffff, Math.PI * 0.8);
    headlight.name = "Headlight";
    headlight.position.set(0, 0, 1);
    // Both endpoints must follow the camera: targeting the scene origin changes the light's
    // direction when the view is panned. Local +Z to the camera origin shines along local -Z.
    camera.add(headlight, headlight.target);
    scene.add(camera);

    // The same 2:1 gray environment gradient used by SceneLighting in Cadova Viewer.
    // Environment maps use world Y as their pole, independent of the camera's Z-up controls.
    const width = 256, height = 128;
    const pixels = new Uint8Array(width * height * 4);
    for (let y = 0; y < height; y++) {
        const t = (y + 0.5) / height;
        const gray = t <= 0.55 ? THREE.MathUtils.lerp(0.95, 0.55, t / 0.55)
            : THREE.MathUtils.lerp(0.55, 0.12, (t - 0.55) / 0.45);
        const value = Math.round(gray * 255);
        for (let x = 0; x < width; x++) pixels.set([value, value, value, 255], (y * width + x) * 4);
    }
    const texture = new THREE.DataTexture(pixels, width, height);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.mapping = THREE.EquirectangularReflectionMapping;
    texture.flipY = true;
    texture.needsUpdate = true;
    const pmrem = new THREE.PMREMGenerator(renderer);
    const environment = pmrem.fromEquirectangular(texture);
    scene.environment = environment.texture;
    scene.environmentIntensity = 1;
    pmrem.dispose();
    texture.dispose();
    return { headlight, ambient, environment };
}
