import * as THREE from "three";

const worldUp = new THREE.Vector3(0, 0, 1);

// The speed of a drag when it's released. A finger that stops before it lifts often sends no more
// moves, which would leave its last speed to fling the view, so the speed fades out over the time
// since the last move: a release within a frame of it keeps it all, and one 40 ms later none.
class VelocityTracker {
    static window = 50; // milliseconds of movement the speed is measured over
    static fade = [16, 40]; // milliseconds since the last move over which the speed fades out

    // A drag starts at rest, where it's begun
    constructor(now = performance.now()) {
        this.samples = [{ delta: new THREE.Vector4(0,0,0,0), time: now }];
        this.velocity = new THREE.Vector4(0,0,0,0);
    }
    record(delta, now = performance.now()) {
        this.samples.push({ delta: delta.clone(), time: now });
        while (this.samples.length > 2 && now - this.samples[1].time > VelocityTracker.window) this.samples.shift();
        // The speed of the movement itself, ending at its last sample. It always reaches back at least
        // one sample, so moves that arrive further apart than the window still have a speed.
        const first = this.samples.find(sample => now - sample.time <= VelocityTracker.window && sample.time < now)
            ?? this.samples.at(-2);
        const seconds = Math.max(now - first.time, 1000 / 240) / 1000;
        this.velocity = delta.clone().sub(first.delta).divideScalar(seconds);
    }
    release(now = performance.now()) {
        const [start, end] = VelocityTracker.fade;
        const since = now - this.samples.at(-1).time;
        return this.velocity.clone().multiplyScalar(THREE.MathUtils.clamp(1 - (since - start) / (end - start), 0, 1));
    }
}

// Cadova Viewer's turntable and rigid drag-start transforms, in CSS pixels (y down).
// Orbit has no pole clamp, and keeps the view upright. Picking runs once per grab/zoom burst.
export class CameraNavigator {
    constructor(camera, element) {
        this.camera = camera;
        this.element = element;
        this.sphere = new THREE.Sphere(new THREE.Vector3(), 0);
        this.meshes = [];
        this.raycaster = new THREE.Raycaster();
        this.inertia = null;
        this.zoomAnimation = null;
        this.zoomPivot = null;
    }
    setModel(object, box) {
        this.stopMotion();
        this.resetZoomPivot();
        box.getBoundingSphere(this.sphere);
        this.meshes = [];
        object.traverse(child => { if (child.isMesh && !child.isLineSegments2) this.meshes.push(child); });
    }
    stopMotion() { this.inertia = this.zoomAnimation = null; }
    resetZoomPivot() { this.zoomPivot = null; }
    pivot(point) {
        const rect = this.element.getBoundingClientRect();
        this.camera.updateMatrixWorld();
        this.raycaster.setFromCamera(new THREE.Vector2(
            (point.x - rect.left) / Math.max(rect.width, 1) * 2 - 1,
            1 - (point.y - rect.top) / Math.max(rect.height, 1) * 2,
        ), this.camera);
        const hit = this.raycaster.intersectObjects(this.meshes, false)[0];
        if (hit) return hit.point.clone();
        const grid = this.raycaster.ray.intersectPlane(new THREE.Plane(worldUp, 0), new THREE.Vector3());
        if (grid && grid.distanceTo(this.sphere.center) < Math.max(this.sphere.radius, 1) * 50) return grid;
        return this.sphere.center.clone();
    }
    worldPerPixel(depth) {
        const height = Math.max(this.element.clientHeight, 1);
        return this.camera.isOrthographicCamera ? (this.camera.top - this.camera.bottom) / this.camera.zoom / height
            : 2 * depth * Math.tan(THREE.MathUtils.degToRad(this.camera.fov) / 2) / height;
    }
    begin(point, pivot = this.pivot(point)) {
        this.stopMotion();
        const position = this.camera.position.clone(), quaternion = this.camera.quaternion.clone();
        const right = new THREE.Vector3(1, 0, 0).applyQuaternion(quaternion);
        const up = new THREE.Vector3(0, 1, 0).applyQuaternion(quaternion);
        const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(quaternion);
        const depth = Math.abs(pivot.clone().sub(position).dot(forward));
        return { position, quaternion, right, up, forward, pivot, wpp: this.worldPerPixel(depth),
            dimension: Math.max(this.element.clientWidth, this.element.clientHeight, 1), zoom: this.camera.zoom };
    }
    apply(state, delta, motion) {
        const camera = this.camera;
        const rotation = new THREE.Quaternion();
        if (motion === "orbit") {
            const speed = 2 * Math.PI / state.dimension;
            const yaw = new THREE.Quaternion().setFromAxisAngle(worldUp, -delta.x * speed);
            const pitch = new THREE.Quaternion().setFromAxisAngle(state.right.clone().applyQuaternion(yaw), -delta.y * speed);
            rotation.copy(pitch).multiply(yaw);
        }
        camera.quaternion.copy(rotation).multiply(state.quaternion);
        camera.position.copy(state.position).sub(state.pivot).applyQuaternion(rotation).add(state.pivot);
        let scale = 1;
        if (motion === "zoom" || motion === "touch") {
            const radius = this.sphere.radius;
            const limits = radius > 1e-4 ? [radius * 0.05, radius * 40] : [0.001, Infinity];
            const factor = Math.exp(THREE.MathUtils.clamp(delta.z, -50, 50));
            if (camera.isOrthographicCamera) {
                const halfHeight = (camera.top - camera.bottom) / 2 / state.zoom;
                const newHeight = THREE.MathUtils.clamp(halfHeight / factor, ...limits);
                scale = newHeight / halfHeight;
                camera.zoom = state.zoom / scale;
                const offset = state.pivot.clone().sub(state.position);
                camera.position.addScaledVector(state.right, offset.dot(state.right) * (1 - scale));
                camera.position.addScaledVector(state.up, offset.dot(state.up) * (1 - scale));
                camera.updateProjectionMatrix();
            } else {
                const offset = camera.position.clone().sub(state.pivot);
                const distance = offset.length();
                if (distance > 1e-5) {
                    scale = THREE.MathUtils.clamp(distance / factor, ...limits) / distance;
                    camera.position.copy(state.pivot).addScaledVector(offset, scale);
                }
            }
        }
        if (motion === "pan" || motion === "touch") {
            const right = state.right.clone().applyQuaternion(rotation), up = state.up.clone().applyQuaternion(rotation);
            camera.position.addScaledVector(right, -delta.x * state.wpp * scale).addScaledVector(up, delta.y * state.wpp * scale);
        }
        camera.updateMatrixWorld();
    }
    zoom(logZoom, point) {
        if (!this.zoomPivot || this.zoomPivot.point.distanceTo(point) >= 0.5) {
            this.zoomPivot = { point: point.clone(), world: this.pivot(point) };
        }
        this.apply(this.begin(point, this.zoomPivot.world), new THREE.Vector4(0, 0, logZoom, 0), "zoom");
    }
    scrollPan(dx, dy) {
        this.stopMotion();
        this.resetZoomPivot();
        const q = this.camera.quaternion;
        const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(q);
        const depth = Math.abs(this.sphere.center.clone().sub(this.camera.position).dot(forward));
        const wpp = this.worldPerPixel(depth);
        this.camera.position.addScaledVector(new THREE.Vector3(1, 0, 0).applyQuaternion(q), dx * wpp)
            .addScaledVector(new THREE.Vector3(0, 1, 0).applyQuaternion(q), -dy * wpp);
        this.camera.updateMatrixWorld();
    }
    // Zooms smoothly toward a point, as the zoom buttons do. Zooming again before it's done adds on to
    // what's left of the zoom in progress.
    animateZoom(logZoom, point) {
        const previous = this.zoomAnimation;
        const remaining = previous ? previous.logZoom * (1 - previous.progress) : 0;
        const state = this.begin(point);
        this.zoomAnimation = { state, logZoom: logZoom + remaining, start: null, progress: 0 };
    }
    startInertia(state, delta, velocity, motion) {
        this.stopMotion();
        const speed = new THREE.Vector4(0,0,0,0);
        if (motion === "orbit" || motion === "pan" || motion === "touch") {
            if (Math.hypot(velocity.x, velocity.y) >= 12) { speed.x = velocity.x; speed.y = velocity.y; }
        }
        if ((motion === "zoom" || motion === "touch") && Math.abs(velocity.z) >= 0.5) speed.z = velocity.z;
        if (speed.length()) this.inertia = { state, delta: delta.clone(), velocity: speed, motion, time: null };
    }
    update(time = performance.now()) {
        const animation = this.zoomAnimation;
        if (animation) {
            animation.start ??= time;
            const t = THREE.MathUtils.clamp((time - animation.start) / 200, 0, 1);
            animation.progress = 1 - Math.pow(1 - t, 3);
            this.apply(animation.state, new THREE.Vector4(0, 0, animation.logZoom * animation.progress, 0), "zoom");
            if (t >= 1) this.zoomAnimation = null;
        }
        const glide = this.inertia;
        if (!glide) return;
        const dt = glide.time === null ? 0 : THREE.MathUtils.clamp((time - glide.time) / 1000, 0, 0.1);
        glide.time = time;
        glide.delta.addScaledVector(glide.velocity, dt);
        glide.velocity.multiplyScalar(Math.pow(0.95, dt * 60));
        if (Math.hypot(glide.velocity.x, glide.velocity.y) < 4) glide.velocity.x = glide.velocity.y = 0;
        if (Math.abs(glide.velocity.z) < 0.05) glide.velocity.z = 0;
        this.apply(glide.state, glide.delta, glide.motion);
        if (!glide.velocity.length()) this.inertia = null;
    }
}

// Pointer Events cover mice, pens and touch screens. Trackpads arrive as precise wheel events,
// Ctrl+wheel pinches, or Safari's scale gestures. OS scroll momentum already supplies pan
// inertia, so it must not get a second glide here.
// With `lockPointer`, a mouse drag locks the pointer once it moves, so it can go on past the edge of
// the screen, as in Cadova Viewer. Browsers announce every lock with a banner, so the customizer
// leaves it off; embedders without one, such as VS Code's webviews, can turn it on.
export class ViewportControls extends CameraNavigator {
    constructor(camera, element, { lockPointer = false } = {}) {
        super(camera, element);
        this.lockPointer = lockPointer;
        this.locked = false;
        this.pointers = new Map();
        this.drag = null;
        this.pendingTouch = null;
        this.gesture = null;
        this.pinch = null;
        this.scroll = null;
        this.cursor = null;
        this.safariEnded = -Infinity;
        this.listeners = [];
        const svg = "http://www.w3.org/2000/svg";
        this.marker = document.createElementNS(svg, "svg");
        this.marker.classList.add("viewport-pivot");
        this.marker.setAttribute("viewBox", "0 0 10 10");
        this.marker.setAttribute("aria-hidden", "true");
        this.marker.style.cssText = "position:absolute;left:50%;top:50%;width:10px;height:10px;pointer-events:none;opacity:0;transform:translate(-50%,-50%)";
        const dot = document.createElementNS(svg, "circle");
        for (const [key, value] of Object.entries({ cx: 5, cy: 5, r: 4, fill: "red", stroke: "rgba(0,0,0,0.5)" })) dot.setAttribute(key, value);
        this.marker.append(dot);
        element.parentElement?.append(this.marker);
        this.pivotVisual = null;
        const listen = (target, type, callback, options) => {
            target.addEventListener(type, callback, options);
            this.listeners.push(() => target.removeEventListener(type, callback, options));
        };
        listen(element, "pointerdown", event => this.pointerDown(event));
        listen(element, "pointermove", event => this.pointerMove(event));
        listen(element, "pointerup", event => this.pointerUp(event));
        listen(element, "pointerenter", event => { this.cursor = this.point(event); this.resetZoomPivot(); });
        listen(element, "pointerleave", event => { if (!this.pointers.has(event.pointerId)) { this.cursor = null; this.resetZoomPivot(); } });
        listen(element, "pointercancel", () => this.reset());
        // Some embedded browsers, such as VS Code's webviews, release the capture before sending the
        // pointerup, and lose it when a fast drag leaves the page, as a flick often does. Either way
        // the page hears no more of the drag, so it ends there, gliding on as it was moving rather
        // than stopping dead.
        listen(element, "lostpointercapture", event => {
            // Chrome releases pointer capture when pointer lock engages. A locked pointer still
            // delivers its events here, so only a capture lost for another reason ends the drag.
            if (!this.pointers.has(event.pointerId) || this.drag?.lockPending || document.pointerLockElement === element) return;
            this.pointerUp(event);
        });
        listen(element, "wheel", event => this.wheel(event), { passive: false });
        listen(element, "contextmenu", event => event.preventDefault());
        for (const type of ["gesturestart", "gesturechange", "gestureend"]) {
            listen(document, type, event => this.safariGesture(event), { passive: false });
        }
        if (lockPointer) {
            listen(document, "pointerlockchange", () => {
                const locked = document.pointerLockElement === element;
                if (this.drag) this.drag.lockPending = false;
                // Losing the lock mid-drag (Escape, or the browser revoking it) ends the drag. Exiting it
                // after the button is released must not, or that drag's inertia would stop at once.
                if (this.locked && !locked && this.drag) this.reset();
                this.locked = locked;
                if (locked && !this.drag) document.exitPointerLock();
            });
            listen(document, "pointerlockerror", () => this.pointerLockFailed());
        }
        listen(window, "blur", () => this.reset());
        listen(window, "keydown", event => { if (event.key === "Escape") this.reset(); });
        listen(document, "visibilitychange", () => { if (document.hidden) this.reset(); });
        element.style.touchAction = "none";
    }
    point(event) { return new THREE.Vector2(event.clientX, event.clientY); }
    setModel(object, box) { this.reset(); super.setModel(object, box); }
    reset() {
        this.stopMotion(); this.resetZoomPivot();
        clearTimeout(this.pinchTimer);
        this.drag = this.pendingTouch = this.gesture = this.pinch = this.scroll = null;
        const pointers = [...this.pointers.keys()];
        this.pointers.clear();
        for (const id of pointers) if (this.element.hasPointerCapture(id)) this.element.releasePointerCapture(id);
        if (document.pointerLockElement === this.element) document.exitPointerLock();
        this.element.style.cursor = "";
        this.hidePivot(true);
    }
    pointerLockFailed() {
        if (!this.drag?.lockPending) return;
        this.drag.lockPending = false;
        this.element.style.cursor = "grabbing";
        // A refused lock normally leaves capture in place. If it was released anyway, take it back
        // so the drag still ends with its pointerup, or end the drag if the pointer is already up.
        for (const id of this.pointers.keys()) {
            if (this.element.hasPointerCapture(id)) continue;
            try { this.element.setPointerCapture(id); } catch { this.reset(); return; }
        }
    }
    dispose() { this.reset(); this.listeners.forEach(remove => remove()); this.marker.remove(); }
    update(time = performance.now()) {
        // Touch contacts arrive separately. Sample the complete pair once per presented frame,
        // rather than turning its intermediate centroid offsets into a spurious pan fling.
        this.sampleTouchVelocity();
        super.update(time);
        this.updatePivot();
    }
    showPivot(point) {
        if (!this.pivotVisual || this.pivotVisual.hiddenAt !== null) {
            this.pivotVisual = { point: point.clone(), shownAt: performance.now(), hiddenAt: null };
        }
    }
    hidePivot(immediate = false) {
        if (immediate) { this.pivotVisual = null; this.marker.style.opacity = "0"; }
        else if (this.pivotVisual && this.pivotVisual.hiddenAt === null) this.pivotVisual.hiddenAt = performance.now();
    }
    updatePivot() {
        const visual = this.pivotVisual;
        if (!visual) return;
        const now = performance.now();
        let opacity = THREE.MathUtils.clamp((now - visual.shownAt) / 100, 0, 1);
        if (visual.hiddenAt !== null) opacity *= THREE.MathUtils.clamp(1 - (now - visual.hiddenAt - 300) / 300, 0, 1);
        if (visual.hiddenAt !== null && now >= visual.hiddenAt + 600) { this.hidePivot(true); return; }
        const point = visual.point.clone().project(this.camera);
        this.marker.style.display = Math.abs(point.x) <= 1 && Math.abs(point.y) <= 1 && Math.abs(point.z) <= 1 ? "" : "none";
        this.marker.style.left = `${this.element.offsetLeft + (point.x + 1) * this.element.clientWidth / 2}px`;
        this.marker.style.top = `${this.element.offsetTop + (1 - point.y) * this.element.clientHeight / 2}px`;
        this.marker.style.opacity = String(opacity);
    }
    sampleTouchVelocity() {
        if (this.drag?.multi && this.drag.dirty) {
            this.drag.tracker.record(this.drag.delta, this.drag.sampleTime);
            this.drag.dirty = false;
        }
    }
    pointerDown(event) {
        if (event.pointerType !== "touch" && ![0, 1, 2].includes(event.button)) return;
        if (this.pointers.size && (event.pointerType !== "touch" || [...this.pointers.values()][0].type !== "touch")) return;
        event.preventDefault();
        this.finishPinch(false);
        this.gesture = null;
        this.pendingTouch = null;
        this.hidePivot(true);
        this.resetZoomPivot();
        this.stopMotion();
        this.pointers.set(event.pointerId, { point: this.point(event), type: event.pointerType });
        this.element.setPointerCapture(event.pointerId);
        this.startPointers(event);
    }
    startPointers(event) {
        const points = [...this.pointers.values()].map(pointer => pointer.point);
        if (!points.length) { this.drag = null; return; }
        const multi = points.length >= 2;
        const center = multi ? points[0].clone().add(points[1]).multiplyScalar(0.5) : points[0].clone();
        const touch = [...this.pointers.values()][0].type === "touch";
        const pan = !touch && (event.button === 1 || event.button === 2 || event.altKey);
        this.drag = { state: this.begin(center), start: center, delta: new THREE.Vector4(0,0,0,0), tracker: new VelocityTracker(event.timeStamp),
            motion: multi ? "touch" : pan ? "pan" : "orbit", touch, multi,
            lockAxis: !touch && !pan && event.shiftKey, axis: null,
            distance: multi ? Math.max(points[0].distanceTo(points[1]), 1) : 0, zooming: false,
            lockCursor: this.lockPointer && !touch && (!pan || event.button === 2), lockRequested: false, lockPending: false };
    }
    pointerMove(event) {
        const point = this.point(event);
        if (!this.cursor || this.cursor.distanceTo(point) >= 0.5) this.resetZoomPivot();
        this.cursor = point;
        const pointer = this.pointers.get(event.pointerId), drag = this.drag;
        if (!pointer || !drag) return;
        event.preventDefault();
        this.pendingTouch = null;
        if (document.pointerLockElement === this.element) pointer.point.add(new THREE.Vector2(event.movementX, event.movementY));
        else pointer.point.copy(point);
        const points = [...this.pointers.values()].map(pointer => pointer.point);
        const center = drag.multi ? points[0].clone().add(points[1]).multiplyScalar(0.5) : points[0];
        drag.delta.x = center.x - drag.start.x;
        drag.delta.y = center.y - drag.start.y;
        if (drag.lockAxis && !drag.axis && Math.hypot(drag.delta.x, drag.delta.y) > 0) {
            drag.axis = Math.abs(drag.delta.x) >= Math.abs(drag.delta.y) ? "x" : "y";
        }
        if (drag.axis === "x") drag.delta.y = 0;
        if (drag.axis === "y") drag.delta.x = 0;
        if (drag.multi) {
            this.setGestureZoom(drag, Math.log(Math.max(points[0].distanceTo(points[1]), 1) / drag.distance));
        }
        // Locked only once the drag has gone further than a click can wander, since a locked pointer
        // stays where it was and is released there
        if (drag.lockCursor && !drag.lockRequested && Math.hypot(drag.delta.x, drag.delta.y) > 6) {
            drag.lockRequested = true;
            // Trusted mouse input can use native-style unlimited drags. Capture remains the fallback
            // when pointer lock isn't available or the browser declines it.
            if (event.isTrusted && this.element.requestPointerLock) {
                drag.lockPending = true;
                try {
                    const request = this.element.requestPointerLock();
                    request?.catch(() => this.pointerLockFailed());
                } catch { this.pointerLockFailed(); }
            }
        }
        // A drag that locks the pointer hides it, so showing the grabbing hand first would only flicker
        if (!drag.touch && !drag.lockCursor) this.element.style.cursor = "grabbing";
        if (drag.motion === "orbit" && Math.hypot(drag.delta.x, drag.delta.y) > 0) this.showPivot(drag.state.pivot);
        this.apply(drag.state, drag.delta, drag.motion);
        // Timed by when the movement happened rather than when it's handled: moves arrive a frame at
        // a time, so a slow frame would otherwise look like a pause before letting go, and no glide
        if (drag.multi) { drag.dirty = true; drag.sampleTime = event.timeStamp; }
        else drag.tracker.record(drag.delta, event.timeStamp);
    }
    // A pinch zooms once it has spread or closed enough to mean it, so that a two-finger pan doesn't
    // zoom as well. Twisting does nothing: rolling the view was too easy to do by accident.
    setGestureZoom(gesture, logZoom) {
        if (Math.abs(logZoom) >= 0.02) gesture.zooming = true;
        gesture.delta.z = gesture.zooming ? logZoom : 0;
    }
    pointerUp(event) {
        if (!this.pointers.has(event.pointerId)) return;
        event.preventDefault();
        const drag = this.drag;
        this.hidePivot();
        this.sampleTouchVelocity();
        this.pointers.delete(event.pointerId);
        if (this.element.hasPointerCapture(event.pointerId)) this.element.releasePointerCapture(event.pointerId);
        if (this.pointers.size >= 2) {
            this.startPointers(event);
        } else if (this.pointers.size) {
            // Fingers rarely lift at the same moment, so a finger left over from a pinch doesn't move
            // the view: its own movement as it lifts would orbit, and fling, the model. The pinch
            // glides on as it was moving when its first finger lifted, once the last one does.
            if (drag?.multi) this.pendingTouch = { drag, velocity: drag.tracker.release(event.timeStamp) };
            this.drag = null;
        } else {
            const pending = this.pendingTouch;
            if (pending) this.startInertia(pending.drag.state, pending.drag.delta, pending.velocity, pending.drag.motion);
            else if (drag) this.startInertia(drag.state, drag.delta, drag.tracker.release(event.timeStamp), drag.motion);
            this.drag = this.pendingTouch = null;
            this.element.style.cursor = "";
            if (document.pointerLockElement === this.element) document.exitPointerLock();
        }
    }
    wheel(event) {
        event.preventDefault();
        const now = performance.now(), point = this.point(event);
        if (this.pointers.size || this.gesture || (event.ctrlKey && now - this.safariEnded < 150)) return;
        if (event.ctrlKey) {
            this.scroll = null;
            // Chromium/Firefox represent a trackpad pinch as Ctrl+wheel, with 100*log(scale) deltas.
            if (!this.pinch || this.pinch.point.distanceTo(point) >= 0.5) {
                this.finishPinch(false);
                this.pinch = { state: this.begin(point), point, delta: new THREE.Vector4(0,0,0,0), tracker: new VelocityTracker(event.timeStamp) };
            }
            this.pinch.delta.z -= event.deltaY * (event.deltaMode === 1 ? 16 : 1) * 0.01;
            this.apply(this.pinch.state, this.pinch.delta, "zoom");
            this.pinch.tracker.record(this.pinch.delta, event.timeStamp);
            clearTimeout(this.pinchTimer);
            // Wheel events have no gesture-ended phase. A short quiet interval detects lift-off.
            this.pinchTimer = setTimeout(() => this.finishPinch(true), 70);
            return;
        }
        this.finishPinch(false);
        if (!this.scroll || now - this.scroll.time > 200) {
            // The DOM doesn't expose AppKit's precise-scroll flag, so the device is inferred. Firefox
            // reports a wheel in lines or pages. In Chrome and Safari, a trackpad's legacy wheelDelta
            // is exactly -3 times its delta and a wheel's isn't, as measured on macOS with both; a
            // wheel's accelerated pixel deltas can't be told from a trackpad's by their size. Without
            // wheelDelta, familiar detent sizes identify a wheel.
            const hasLegacy = Number.isFinite(event.wheelDeltaX) && Number.isFinite(event.wheelDeltaY);
            const dominant = Math.abs(event.deltaY) >= Math.abs(event.deltaX) ? event.deltaY : event.deltaX;
            const detent = event.deltaMode !== 0 || (hasLegacy
                ? !(event.wheelDeltaX === -3 * event.deltaX && event.wheelDeltaY === -3 * event.deltaY)
                : (!event.deltaX || (event.shiftKey && !event.deltaY)) && Number.isInteger(dominant)
                    && [40, 50, 100, 120].some(step => dominant !== 0 && Math.abs(dominant) % step === 0));
            this.scroll = { zoom: detent || event.shiftKey || event.altKey, detent, time: now };
        }
        this.scroll.time = now;
        if (this.scroll.zoom) {
            const delta = Math.abs(event.deltaY) >= Math.abs(event.deltaX) ? event.deltaY : event.deltaX;
            const sensitivity = this.scroll.detent ? (event.deltaMode === 1 ? 0.1 / 3 : event.deltaMode === 2 ? 0.1 : 0.001) : 0.01;
            const legacy = Math.abs(event.deltaY) >= Math.abs(event.deltaX) ? event.wheelDeltaY : event.wheelDeltaX;
            // A wheel's pixel deltas differ between browsers and grow with the system's scroll
            // acceleration. Its legacy wheelDelta counts 120 per detent, which gives the native
            // 10%-per-detent step, and grows with acceleration as the native viewer's zoom does.
            const logZoom = this.scroll.detent && event.deltaMode === 0 && Number.isFinite(legacy) && legacy !== 0
                ? legacy / 120 * 0.1 : -delta * sensitivity;
            this.zoom(logZoom, point);
        } else this.scrollPan(event.deltaX, event.deltaY);
    }
    finishPinch(coast) {
        clearTimeout(this.pinchTimer);
        if (!this.pinch) return;
        if (coast) {
            // Account for the quiet interval when estimating speed; OS pan momentum is handled above.
            const speed = this.pinch.tracker.velocity.clone().multiplyScalar(Math.pow(0.95, 70 / 1000 * 60));
            this.startInertia(this.pinch.state, this.pinch.delta, speed, "zoom");
        }
        this.pinch = null;
    }
    safariGesture(event) {
        // Safari may deliver trackpad gestures to the document. Scope them to the hovered viewport,
        // while keeping an active gesture captured if the pointer leaves it.
        const rect = this.element.getBoundingClientRect();
        const hovered = this.cursor && this.cursor.x >= rect.left && this.cursor.x <= rect.right
            && this.cursor.y >= rect.top && this.cursor.y <= rect.bottom;
        if (!this.gesture && event.target !== this.element && !hovered) return;
        event.preventDefault();
        if ([...this.pointers.values()].some(pointer => pointer.type === "touch")) return;
        const now = performance.now();
        if (event.type === "gesturestart") {
            this.finishPinch(false);
            this.scroll = null;
            const point = this.cursor?.clone() ?? new THREE.Vector2(rect.left + rect.width / 2, rect.top + rect.height / 2);
            this.gesture = { state: this.begin(point), delta: new THREE.Vector4(0,0,0,0), tracker: new VelocityTracker(),
                scale: event.scale || 1, zooming: false };
        } else if (event.type === "gesturechange" && this.gesture) {
            const gesture = this.gesture;
            this.setGestureZoom(gesture, Math.log(Math.max(event.scale, 0.01) / gesture.scale));
            this.apply(gesture.state, gesture.delta, "zoom");
            gesture.tracker.record(gesture.delta, now);
        } else if (event.type === "gestureend") {
            if (this.gesture) {
                const gesture = this.gesture;
                this.startInertia(gesture.state, gesture.delta, gesture.tracker.release(now), "zoom");
            }
            this.gesture = null;
            this.safariEnded = now;
        }
    }
}
