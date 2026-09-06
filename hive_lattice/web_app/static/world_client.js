/* Hive-Lattice World Client — v0.7 World in Motion Visual RPG Renderer.
 *
 * Authored 1990s-style illustrated point-and-click adventure room renderer.
 * Strictly presentation + input only: consumes authoritative hive_world_snapshot_v1.
 * Offline-first, dependency-free, zero CDN requirement.
 */

class HiveWorldClient {
  constructor({ canvas, interactButton, hint, requestAction, onTargetSelected }) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.interactButton = interactButton;
    this.hint = hint;
    this.requestAction = requestAction;
    this.onTargetSelected = onTargetSelected;
    this.snapshot = null;
    this.player = { x: 50, y: 78 };
    this.playerFacing = "down"; // down, up, left, right
    this.playerMoving = false;
    this.walkCycle = 0;
    this.destination = null;
    this.path = [];
    this.keys = new Set();
    this.lastFrame = performance.now();
    this.lastSync = 0;
    this.syncInFlight = false;
    this.visible = false;
    this.debugMode = new URLSearchParams(window.location.search).has("debug");
    this.animTime = 0;
    this.viewRect = { ox: 0, oy: 0, rw: 800, rh: 600 };

    // Room background image caching
    this.roomBgImage = new Image();
    this.roomBgLoaded = false;
    this.roomBgImage.onload = () => { this.roomBgLoaded = true; };
    this.roomBgImage.src = "/api/assets/rooms/room.breakroom.illustrated.png";
    this.roomBgImage.onerror = () => {
      // Fallback to central table room art
      this.roomBgImage.src = "/api/assets/rooms/room.breakroom.central_table.png";
    };

    // Target selection & destination markers
    this.hoverTarget = null;
    this.selectedTarget = null;
    this.destinationMarker = null;

    this._bindInput();
    this._resize();
    if (window.ResizeObserver) {
      new ResizeObserver(() => this._resize()).observe(canvas);
    }
    requestAnimationFrame((t) => this._tick(t));
  }

  setSnapshot(snapshot) {
    this.snapshot = snapshot;
    const p = snapshot && snapshot.player ? snapshot.player : null;
    if (p && Number.isFinite(p.x) && Number.isFinite(p.y)) {
      // If server position is significantly different, smoothly update
      const dist = Math.hypot(this.player.x - p.x, this.player.y - p.y);
      if (dist > 12) {
        this.player = { x: p.x, y: p.y };
      }
    }
    this.visible = Boolean(snapshot && snapshot.world && snapshot.world.enabled);
    this.canvas.classList.toggle("hidden", !this.visible);
    if (this.interactButton) this.interactButton.classList.toggle("hidden", !this.visible);
    if (this.hint) this.hint.classList.toggle("hidden", !this.visible);
    this._draw();
  }

  toggleDebug() {
    this.debugMode = !this.debugMode;
    return this.debugMode;
  }

  _bindInput() {
    window.addEventListener("keydown", (event) => {
      // Toggle debug mode with Ctrl+Shift+D
      if (event.ctrlKey && event.shiftKey && event.key.toLowerCase() === "d") {
        this.toggleDebug();
        return;
      }
      const key = event.key.toLowerCase();
      if (["w", "a", "s", "d", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(key)) {
        this.keys.add(key);
      }
      if ((key === "e" || key === "enter") && this.visible) {
        const target = this._nearestTarget();
        if (target) this._interact(target);
      }
    });
    window.addEventListener("keyup", (event) => this.keys.delete(event.key.toLowerCase()));

    const handlePointer = (event) => {
      if (!this.visible || !this.snapshot) return;
      const worldPos = this._screenToWorld(event.clientX, event.clientY);
      const clickedTarget = this._targetAt(worldPos.x, worldPos.y);

      if (clickedTarget) {
        this.selectedTarget = clickedTarget;
        if (this.onTargetSelected) this.onTargetSelected(clickedTarget);
        const approach = clickedTarget.approach_point || clickedTarget.position;
        const dist = Math.hypot(this.player.x - clickedTarget.position.x, this.player.y - clickedTarget.position.y);
        const radius = clickedTarget.interaction_radius || 18;

        if (dist <= radius) {
          this.path = [];
          this.destination = null;
          this.playerMoving = false;
          this.destinationMarker = { x: clickedTarget.position.x, y: clickedTarget.position.y, time: this.animTime };
          this._updateInteractionPrompt();
        } else {
          // Walk toward approach point routing around obstacles
          this.path = this._buildPath(this.player, approach);
          this.destination = this.path.shift() || null;
          this.destinationMarker = { x: clickedTarget.position.x, y: clickedTarget.position.y, time: this.animTime };
        }
        return;
      }

      // Empty floor tapped: clear selection, resolve valid walkable floor, pathfind there
      this.selectedTarget = null;
      if (this.onTargetSelected) this.onTargetSelected(null);
      const floorPos = this._resolveValidFloorPoint(worldPos.x, worldPos.y);
      this.path = this._buildPath(this.player, floorPos);
      this.destination = this.path.shift() || null;
      this.destinationMarker = { x: floorPos.x, y: floorPos.y, time: this.animTime };
    };

    this.canvas.addEventListener("pointerdown", handlePointer);

    // Mouse hover detection for cursor & affordances
    this.canvas.addEventListener("pointermove", (event) => {
      if (!this.visible || !this.snapshot) return;
      const worldPos = this._screenToWorld(event.clientX, event.clientY);
      this.hoverTarget = this._targetAt(worldPos.x, worldPos.y);
      this.canvas.style.cursor = this.hoverTarget ? "pointer" : "default";
    });

    if (this.interactButton) {
      this.interactButton.addEventListener("click", () => {
        const target = this.selectedTarget || this._nearestTarget();
        if (target) this._interact(target);
      });
    }
  }

  _targetAt(x, y) {
    for (const target of this._targets()) {
      const p = target.position;
      if (!p) continue;
      const r = (target.interaction_radius || 14) * 0.95;
      if (Math.hypot(x - p.x, y - p.y) <= r) {
        return target;
      }
    }
    return null;
  }

  _updateViewRect() {
    const w = this.canvas.width;
    const h = this.canvas.height;
    const targetAspect = 4 / 3;
    let rw = w;
    let rh = w / targetAspect;
    let ox = 0;
    let oy = (h - rh) / 2;
    if (rh > h) {
      rh = h;
      rw = h * targetAspect;
      ox = (w - rw) / 2;
      oy = 0;
    }
    this.viewRect = { ox, oy, rw, rh };
  }

  _resize() {
    const rect = this.canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const width = Math.max(1, Math.floor(rect.width * dpr));
    const height = Math.max(1, Math.floor(rect.height * dpr));
    if (this.canvas.width !== width || this.canvas.height !== height) {
      this.canvas.width = width;
      this.canvas.height = height;
    }
    this._updateViewRect();
    this._draw();
  }

  _xy(point) {
    const { ox, oy, rw, rh } = this.viewRect;
    return {
      x: ox + (point.x / 100) * rw,
      y: oy + (point.y / 100) * rh,
    };
  }

  _screenToWorld(clientX, clientY) {
    const rect = this.canvas.getBoundingClientRect();
    const dpr = this.canvas.width / rect.width;
    const cx = (clientX - rect.left) * dpr;
    const cy = (clientY - rect.top) * dpr;
    const { ox, oy, rw, rh } = this.viewRect;
    const wx = Math.max(0, Math.min(100, ((cx - ox) / rw) * 100));
    const wy = Math.max(0, Math.min(100, ((cy - oy) / rh) * 100));
    return { x: wx, y: wy };
  }

  _tick(now) {
    const dt = Math.min(0.05, (now - this.lastFrame) / 1000);
    this.lastFrame = now;
    this.animTime += dt;

    if (this.visible && this.snapshot) {
      this._move(dt);
      this._updateInteractionPrompt();
      this._draw();
      if (now - this.lastSync > 160) this._syncPosition(now);
    }
    requestAnimationFrame((t) => this._tick(t));
  }

  _bounds() {
    return (this.snapshot && this.snapshot.world && this.snapshot.world.bounds) || { min_x: 6, max_x: 94, min_y: 20, max_y: 92 };
  }

  _blockedRegions() {
    const custom = (this.snapshot && this.snapshot.world && this.snapshot.world.blocked_regions) || [];
    if (custom.length > 0) return custom;
    return [
      { id: "col.central_table", min_x: 35, max_x: 65, min_y: 50, max_y: 68 },
      { id: "col.coffee_counter", min_x: 24, max_x: 76, min_y: 0, max_y: 32 },
      { id: "col.vending_machine", min_x: 0, max_x: 18, min_y: 18, max_y: 58 },
      { id: "col.utility_corner", min_x: 78, max_x: 100, min_y: 38, max_y: 68 },
      { id: "col.back_wall", min_x: 0, max_x: 100, min_y: 0, max_y: 18 }
    ];
  }

  _isBlocked(x, y, margin = 1.0) {
    const b = this._bounds();
    if (x < b.min_x || x > b.max_x || y < b.min_y || y > b.max_y) return true;
    for (const r of this._blockedRegions()) {
      if (x >= (r.min_x - margin) && x <= (r.max_x + margin) &&
          y >= (r.min_y - margin) && y <= (r.max_y + margin)) {
        return true;
      }
    }
    return false;
  }

  _resolveValidFloorPoint(x, y) {
    const b = this._bounds();
    x = Math.max(b.min_x, Math.min(b.max_x, x));
    y = Math.max(b.min_y, Math.min(b.max_y, y));
    for (const r of this._blockedRegions()) {
      if (x >= r.min_x && x <= r.max_x && y >= r.min_y && y <= r.max_y) {
        const dl = Math.abs(x - r.min_x);
        const dr = Math.abs(x - r.max_x);
        const dt = Math.abs(y - r.min_y);
        const db = Math.abs(y - r.max_y);
        const m = Math.min(dl, dr, dt, db);
        if (m === dl) x = Math.max(b.min_x, r.min_x - 2);
        else if (m === dr) x = Math.min(b.max_x, r.max_x + 2);
        else if (m === dt) y = Math.max(b.min_y, r.min_y - 2);
        else y = Math.min(b.max_y, r.max_y + 2);
      }
    }
    return { x, y };
  }

  _waypoints() {
    const wp = (this.snapshot && this.snapshot.world && this.snapshot.world.waypoints) || [];
    if (wp.length > 0) return wp;
    return [
      { id: "wp.table_left", x: 26, y: 60 },
      { id: "wp.table_right", x: 74, y: 60 },
      { id: "wp.table_bottom", x: 50, y: 80 },
      { id: "wp.table_top", x: 50, y: 40 },
      { id: "wp.keith_approach", x: 76, y: 76 },
      { id: "wp.darla_approach", x: 50, y: 38 },
      { id: "wp.wetberry_approach", x: 50, y: 74 },
      { id: "wp.vending_approach", x: 24, y: 48 }
    ];
  }

  _lineBlocked(p1, p2) {
    for (const r of this._blockedRegions()) {
      if (this._segmentIntersectsRect(p1, p2, r)) return true;
    }
    return false;
  }

  _segmentIntersectsRect(p1, p2, r) {
    if ((p1.x > r.min_x && p1.x < r.max_x && p1.y > r.min_y && p1.y < r.max_y) ||
        (p2.x > r.min_x && p2.x < r.max_x && p2.y > r.min_y && p2.y < r.max_y)) {
      return true;
    }
    const tl = { x: r.min_x, y: r.min_y };
    const tr = { x: r.max_x, y: r.min_y };
    const bl = { x: r.min_x, y: r.max_y };
    const br = { x: r.max_x, y: r.max_y };
    return this._linesCross(p1, p2, tl, tr) ||
           this._linesCross(p1, p2, tr, br) ||
           this._linesCross(p1, p2, br, bl) ||
           this._linesCross(p1, p2, bl, tl);
  }

  _linesCross(a, b, c, d) {
    const det = (b.x - a.x) * (d.y - c.y) - (b.y - a.y) * (d.x - c.x);
    if (det === 0) return false;
    const lambda = ((d.y - c.y) * (d.x - a.x) + (c.x - d.x) * (d.y - a.y)) / det;
    const gamma = ((a.y - b.y) * (d.x - a.x) + (b.x - a.x) * (d.y - a.y)) / det;
    return (0 <= lambda && lambda <= 1) && (0 <= gamma && gamma <= 1);
  }

  _buildPath(start, goal) {
    if (!this._lineBlocked(start, goal)) {
      return [goal];
    }
    const waypoints = this._waypoints();
    const nodes = [start, ...waypoints, goal];
    const n = nodes.length;
    const dist = new Array(n).fill(Infinity);
    const prev = new Array(n).fill(-1);
    const visited = new Array(n).fill(false);

    dist[0] = 0;
    for (let step = 0; step < n; step++) {
      let u = -1;
      let best = Infinity;
      for (let i = 0; i < n; i++) {
        if (!visited[i] && dist[i] < best) {
          best = dist[i];
          u = i;
        }
      }
      if (u === -1 || u === n - 1) break;
      visited[u] = true;

      for (let v = 0; v < n; v++) {
        if (u === v || visited[v]) continue;
        if (!this._lineBlocked(nodes[u], nodes[v])) {
          const d = Math.hypot(nodes[u].x - nodes[v].x, nodes[u].y - nodes[v].y);
          if (dist[u] + d < dist[v]) {
            dist[v] = dist[u] + d;
            prev[v] = u;
          }
        }
      }
    }

    if (prev[n - 1] === -1) {
      return [goal];
    }

    const path = [];
    let curr = n - 1;
    while (curr !== 0 && curr !== -1) {
      path.unshift(nodes[curr]);
      curr = prev[curr];
    }
    return path.length > 0 ? path : [goal];
  }

  _move(dt) {
    const speed = (this.snapshot.player && this.snapshot.player.speed) || 24;
    let dx = 0;
    let dy = 0;
    if (this.keys.has("a") || this.keys.has("arrowleft")) dx -= 1;
    if (this.keys.has("d") || this.keys.has("arrowright")) dx += 1;
    if (this.keys.has("w") || this.keys.has("arrowup")) dy -= 1;
    if (this.keys.has("s") || this.keys.has("arrowdown")) dy += 1;

    if (dx || dy) {
      this.destination = null;
      this.path = [];
      const mag = Math.hypot(dx, dy) || 1;
      dx /= mag;
      dy /= mag;
      const targetX = this.player.x + dx * speed * dt;
      const targetY = this.player.y + dy * speed * dt;
      if (!this._isBlocked(targetX, targetY)) {
        this.player.x = targetX;
        this.player.y = targetY;
      } else if (!this._isBlocked(targetX, this.player.y)) {
        this.player.x = targetX; // slide horizontally
      } else if (!this._isBlocked(this.player.x, targetY)) {
        this.player.y = targetY; // slide vertically
      }
      this.playerMoving = true;
      this.walkCycle += dt * 9;
      if (Math.abs(dx) > Math.abs(dy)) {
        this.playerFacing = dx > 0 ? "right" : "left";
      } else {
        this.playerFacing = dy > 0 ? "down" : "up";
      }
    } else if (this.destination) {
      const vx = this.destination.x - this.player.x;
      const vy = this.destination.y - this.player.y;
      const dist = Math.hypot(vx, vy);
      if (dist < 1.4) {
        if (this.path && this.path.length > 0) {
          this.destination = this.path.shift();
        } else {
          this.destination = null;
          this.playerMoving = false;
        }
      } else {
        const step = Math.min(dist, speed * dt);
        const nx = this.player.x + (vx / dist) * step;
        const ny = this.player.y + (vy / dist) * step;
        if (!this._isBlocked(nx, ny)) {
          this.player.x = nx;
          this.player.y = ny;
        } else {
          // Obstacle encountered: shift to next waypoint
          this.destination = this.path.shift() || null;
        }
        this.playerMoving = true;
        this.walkCycle += dt * 9;
        if (Math.abs(vx) > Math.abs(vy)) {
          this.playerFacing = vx > 0 ? "right" : "left";
        } else {
          this.playerFacing = vy > 0 ? "down" : "up";
        }
      }
    } else {
      this.playerMoving = false;
    }

    const b = this._bounds();
    this.player.x = Math.max(b.min_x, Math.min(b.max_x, this.player.x));
    this.player.y = Math.max(b.min_y, Math.min(b.max_y, this.player.y));
  }

  async _syncPosition(now = performance.now(), force = false) {
    if (this.syncInFlight || !this.visible || !this.requestAction) return;
    if (!force && now - this.lastSync < 160) return;
    this.lastSync = now;
    this.syncInFlight = true;
    try {
      const data = await this.requestAction({ kind: "move", x: this.player.x, y: this.player.y }, { quiet: true });
      if (data && data.world && data.world.player) {
        this.player = { x: data.world.player.x, y: data.world.player.y };
      }
    } finally {
      this.syncInFlight = false;
    }
  }

  _targets() {
    if (!this.snapshot) return [];
    return [...(this.snapshot.entities || []), ...(this.snapshot.hotspots || [])];
  }

  _nearestTarget() {
    let best = null;
    let bestDistance = Infinity;
    for (const target of this._targets()) {
      const p = target.position;
      if (!p) continue;
      const distance = Math.hypot(this.player.x - p.x, this.player.y - p.y);
      const radius = target.interaction_radius || 18;
      if (distance <= radius && distance < bestDistance) {
        best = target;
        bestDistance = distance;
      }
    }
    return best;
  }

  _updateInteractionPrompt() {
    if (!this.interactButton) return;
    const target = this.selectedTarget || this._nearestTarget();
    if (!target) {
      this.interactButton.classList.add("hidden");
      return;
    }
    const label = target.interaction_label || `Interact: ${target.name || target.id}`;
    this.interactButton.innerHTML = `<span class="interact-icon">&#x1F4AC;</span> <strong>${label}</strong>`;
    this.interactButton.dataset.targetId = target.id;
    this.interactButton.classList.remove("hidden");
  }

  async _interact(target) {
    await this._syncPosition(performance.now(), true);
    if (!this.requestAction) return;
    await this.requestAction({ kind: "interact", target_id: target.id });
  }

  _draw() {
    const ctx = this.ctx;
    if (!ctx || !this.canvas.width || !this.canvas.height) return;
    const w = this.canvas.width;
    const h = this.canvas.height;
    ctx.clearRect(0, 0, w, h);
    if (!this.visible || !this.snapshot) return;

    // 1. Draw Illustrated Room Environment
    this._drawRoom(ctx, w, h);

    // 2. Draw Destination Marker (Tap-to-walk ripple)
    if (this.destinationMarker) {
      this._drawDestinationMarker(ctx);
    }

    // 3. Collect and Y-Sort all renderable scene actors/objects for depth ordering
    const renderList = [];

    // Table Surface Layer: Table top/chairs occlude actors whose feet/base are behind y: 62
    renderList.push({
      type: "table_surface",
      y: 62,
      data: null,
    });

    // Hotspots (Wetberry, etc.)
    for (const hotspot of this.snapshot.hotspots || []) {
      if (hotspot.position) {
        renderList.push({
          type: "hotspot",
          y: hotspot.position.y,
          data: hotspot,
        });
      }
    }

    // Entities (Keith, Darla, Tammy)
    for (const entity of this.snapshot.entities || []) {
      if (entity.position) {
        renderList.push({
          type: "entity",
          y: entity.position.y,
          data: entity,
        });
      }
    }

    // Player
    renderList.push({
      type: "player",
      y: this.player.y,
      data: this.player,
    });

    // Sort by Y position (lower on screen renders in front)
    renderList.sort((a, b) => a.y - b.y);

    // Render sorted entities
    for (const item of renderList) {
      if (item.type === "hotspot") {
        this._drawHotspot(ctx, item.data);
      } else if (item.type === "entity") {
        this._drawActor(ctx, item.data);
      } else if (item.type === "player") {
        this._drawPlayer(ctx);
      } else if (item.type === "table_surface") {
        this._drawTableSurface(ctx);
      }
    }

    // Selection reticle on selected target
    if (this.selectedTarget) {
      this._drawSelectionReticle(ctx, this.selectedTarget);
    }

    // 4. Foreground Lighting & Ambient Fluorescent Overlay
    this._drawLightingAndAtmosphere(ctx, w, h);

    // 5. Debug Mode Overlay (Only rendered if debugMode is true)
    if (this.debugMode) {
      this._drawDebugOverlay(ctx, w, h);
    }
  }

  _drawRoom(ctx, w, h) {
    const vr = this.viewRect || { ox: 0, oy: 0, rw: w, rh: h };
    // Clear letterbox borders with deep cosmic void
    ctx.fillStyle = "#070a10";
    ctx.fillRect(0, 0, w, h);

    if (this.roomBgLoaded && this.roomBgImage.naturalWidth > 0) {
      ctx.drawImage(this.roomBgImage, vr.ox, vr.oy, vr.rw, vr.rh);
    } else {
      // Procedural painterly fallback mapped inside viewRect
      const style = (this.snapshot.world && this.snapshot.world.style) || {};
      ctx.fillStyle = style.floor || "#111722";
      ctx.fillRect(vr.ox, vr.oy, vr.rw, vr.rh);

      // Back wall
      ctx.fillStyle = "#161c24";
      ctx.fillRect(vr.ox, vr.oy, vr.rw, vr.rh * 0.52);

      // Coffee counter
      ctx.fillStyle = style.counter || "#4c3c35";
      ctx.fillRect(vr.ox + vr.rw * 0.28, vr.oy + vr.rh * 0.26, vr.rw * 0.44, vr.rh * 0.16);

      // Vending machine
      ctx.fillStyle = style.fridge || "#2a3648";
      ctx.fillRect(vr.ox + vr.rw * 0.04, vr.oy + vr.rh * 0.22, vr.rw * 0.16, vr.rh * 0.38);

      // Utility corner
      ctx.fillStyle = style.utility || "#1a2836";
      ctx.fillRect(vr.ox + vr.rw * 0.74, vr.oy + vr.rh * 0.35, vr.rw * 0.22, vr.rh * 0.35);

      // Central table base
      ctx.fillStyle = style.table || "#384452";
      ctx.beginPath();
      ctx.ellipse(vr.ox + vr.rw * 0.50, vr.oy + vr.rh * 0.64, vr.rw * 0.18, vr.rh * 0.11, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#64768a";
      ctx.lineWidth = Math.max(2, vr.rw / 260);
      ctx.stroke();
    }
  }

  _drawTableSurface(ctx) {
    // Renders the foreground lip/rim of the central table so characters walking behind y:62 are occluded
    const vr = this.viewRect || { ox: 0, oy: 0, rw: this.canvas.width, rh: this.canvas.height };
    const centerX = vr.ox + vr.rw * 0.50;
    const centerY = vr.oy + vr.rh * 0.64;
    const rx = vr.rw * 0.18;
    const ry = vr.rh * 0.11;

    ctx.save();
    // Soft under-table shadow
    ctx.fillStyle = "rgba(4, 7, 12, 0.4)";
    ctx.beginPath();
    ctx.ellipse(centerX, centerY + ry * 0.25, rx * 1.05, ry * 0.7, 0, 0, Math.PI * 2);
    ctx.fill();

    // Table rim & surface edge
    const grad = ctx.createLinearGradient(centerX, centerY - ry, centerX, centerY + ry);
    grad.addColorStop(0, "rgba(35, 48, 64, 0.65)");
    grad.addColorStop(0.5, "rgba(22, 32, 45, 0.85)");
    grad.addColorStop(1, "rgba(12, 18, 26, 0.95)");
    ctx.fillStyle = grad;
    ctx.strokeStyle = "rgba(0, 243, 255, 0.35)";
    ctx.lineWidth = Math.max(1.5, vr.rw / 340);

    ctx.beginPath();
    ctx.ellipse(centerX, centerY, rx, ry, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // Fluorescent highlight along top edge
    ctx.strokeStyle = "rgba(255, 255, 255, 0.25)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(centerX, centerY - ry * 0.3, rx * 0.75, ry * 0.4, 0, 0, Math.PI);
    ctx.stroke();

    ctx.restore();
  }

  _drawSelectionReticle(ctx, target) {
    if (!target || !target.position) return;
    const p = this._xy(target.position);
    const scale = Math.max(0.85, Math.min(this.canvas.width, this.canvas.height) / 460);
    const radius = ((target.interaction_radius || 16) * scale);
    const time = this.animTime;

    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.strokeStyle = "#ffb020";
    ctx.lineWidth = 2 * scale;

    // Corner brackets
    const bracketLen = 7 * scale;
    const offset = radius * 0.75 + Math.sin(time * 6) * 2 * scale;

    // Top-Left
    ctx.beginPath();
    ctx.moveTo(-offset, -offset + bracketLen);
    ctx.lineTo(-offset, -offset);
    ctx.lineTo(-offset + bracketLen, -offset);
    ctx.stroke();

    // Top-Right
    ctx.beginPath();
    ctx.moveTo(offset - bracketLen, -offset);
    ctx.lineTo(offset, -offset);
    ctx.lineTo(offset, -offset + bracketLen);
    ctx.stroke();

    // Bottom-Left
    ctx.beginPath();
    ctx.moveTo(-offset, offset - bracketLen);
    ctx.lineTo(-offset, offset);
    ctx.lineTo(-offset + bracketLen, offset);
    ctx.stroke();

    // Bottom-Right
    ctx.beginPath();
    ctx.moveTo(offset - bracketLen, offset);
    ctx.lineTo(offset, offset);
    ctx.lineTo(offset, offset - bracketLen);
    ctx.stroke();

    ctx.restore();
  }

  _drawDestinationMarker(ctx) {
    if (!this.destinationMarker) return;
    const p = this._xy(this.destinationMarker);
    const age = this.animTime - this.destinationMarker.time;
    if (age > 1.2 && !this.destination) {
      this.destinationMarker = null;
      return;
    }
    const radius = 8 + (Math.sin(this.animTime * 8) + 1) * 3;
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.strokeStyle = "rgba(0, 243, 255, 0.75)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(0, 0, radius, radius * 0.5, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = "rgba(0, 243, 255, 0.9)";
    ctx.beginPath();
    ctx.arc(0, 0, 3, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  _drawHotspot(ctx, hotspot) {
    const p = this._xy(hotspot.position);
    const isNearby = this._nearestTarget() === hotspot;
    const isHover = this.hoverTarget === hotspot;
    const scale = Math.max(0.85, Math.min(this.canvas.width, this.canvas.height) / 460);

    ctx.save();
    ctx.translate(p.x, p.y);

    if (hotspot.id === "hotspot.wetberry") {
      // Pulsing strawberry moisture aura
      const pulse = Math.sin(this.animTime * 4);
      const glowR = (20 + pulse * 4) * scale;
      const grad = ctx.createRadialGradient(0, -4 * scale, 2, 0, -4 * scale, glowR);
      grad.addColorStop(0, "rgba(255, 62, 138, 0.65)");
      grad.addColorStop(0.6, "rgba(255, 62, 138, 0.25)");
      grad.addColorStop(1, "rgba(255, 62, 138, 0)");
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.ellipse(0, 0, glowR * 1.3, glowR * 0.8, 0, 0, Math.PI * 2);
      ctx.fill();

      // Proximity highlight ring
      if (isNearby || isHover) {
        ctx.strokeStyle = "#00f3ff";
        ctx.lineWidth = 2 * scale;
        ctx.setLineDash([4 * scale, 3 * scale]);
        ctx.beginPath();
        ctx.ellipse(0, 6 * scale, 22 * scale, 11 * scale, 0, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // Berry body (strawberry shaped pixel art)
      const bw = 14 * scale;
      const bh = 18 * scale;
      ctx.fillStyle = "#ff3e8a";
      ctx.strokeStyle = "#ffa6cb";
      ctx.lineWidth = 2 * scale;
      ctx.beginPath();
      ctx.moveTo(0, -bh);
      ctx.bezierCurveTo(bw, -bh * 0.8, bw * 0.8, bh * 0.4, 0, bh * 0.8);
      ctx.bezierCurveTo(-bw * 0.8, bh * 0.4, -bw, -bh * 0.8, 0, -bh);
      ctx.fill();
      ctx.stroke();

      // Green Leaf Crown
      ctx.fillStyle = "#7dff91";
      ctx.strokeStyle = "#38b855";
      ctx.lineWidth = 1.5 * scale;
      ctx.beginPath();
      ctx.moveTo(0, -bh - 4 * scale);
      ctx.lineTo(6 * scale, -bh);
      ctx.lineTo(0, -bh + 2 * scale);
      ctx.lineTo(-6 * scale, -bh);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();

      // Glistening moisture dots
      ctx.fillStyle = "#fff";
      ctx.beginPath();
      ctx.arc(-3 * scale, -bh * 0.3, 1.5 * scale, 0, Math.PI * 2);
      ctx.arc(2 * scale, bh * 0.1, 1.5 * scale, 0, Math.PI * 2);
      ctx.fill();

      // Floating label when nearby
      if (isNearby || isHover) {
        this._drawTargetBadge(ctx, "WETBERRY", 0, -bh - 14 * scale, scale);
      }
    } else {
      ctx.fillStyle = "#ff0055";
      ctx.beginPath();
      ctx.arc(0, 0, 8 * scale, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  _drawActor(ctx, entity) {
    const p = this._xy(entity.position);
    const identity = entity.identity || {};
    const palette = identity.palette || {};
    const behavior = entity.dynamics && entity.dynamics.behavior ? entity.dynamics.behavior : "steady";
    const scale = Math.max(0.85, Math.min(this.canvas.width, this.canvas.height) / 440);
    const isNearby = this._nearestTarget() === entity;
    const isHover = this.hoverTarget === entity;

    ctx.save();
    ctx.translate(p.x, p.y);

    // Floor shadow
    ctx.fillStyle = "rgba(6, 10, 16, 0.65)";
    ctx.beginPath();
    ctx.ellipse(0, 8 * scale, 18 * scale, 8 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // Proximity target ring
    if (isNearby || isHover) {
      ctx.strokeStyle = isNearby ? "#00f3ff" : "rgba(0, 243, 255, 0.5)";
      ctx.lineWidth = 2 * scale;
      ctx.setLineDash([4 * scale, 3 * scale]);
      ctx.beginPath();
      ctx.ellipse(0, 8 * scale, 24 * scale, 12 * scale, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    if (entity.id === "npc.keith_janitor") {
      this._drawKeithSprite(ctx, palette, behavior, scale);
      if (isNearby || isHover) {
        this._drawTargetBadge(ctx, "KEITH", 0, -52 * scale, scale);
      }
    } else if (entity.id === "npc.darla_microwave") {
      this._drawDarlaSprite(ctx, palette, behavior, scale);
      if (isNearby || isHover) {
        this._drawTargetBadge(ctx, "DARLA", 0, -48 * scale, scale);
      }
    } else if (entity.id === "npc.tammy_hr") {
      this._drawTammySprite(ctx, palette, behavior, scale);
      if (isNearby || isHover) {
        this._drawTargetBadge(ctx, "TAMMY (HR)", 0, -50 * scale, scale);
      }
    } else {
      ctx.fillStyle = palette.primary || "#8aa0b2";
      ctx.beginPath();
      ctx.arc(0, -10 * scale, 14 * scale, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  _drawKeithSprite(ctx, palette, behavior, scale) {
    const primary = palette.primary || "#2f6678";
    const secondary = palette.secondary || "#173746";
    const skin = palette.skin || "#d8a87c";
    const accent = palette.accent || "#f1c44f";

    // Idle breathing offset
    const breathe = Math.sin(this.animTime * 2.5) * 1.5 * scale;
    const isAgitated = behavior === "agitated" || behavior === "strained";
    const lean = isAgitated ? -3 * scale : 0;

    // 1. Mop of Minor Exorcism (Silhouette anchor)
    ctx.strokeStyle = "#a4b2be";
    ctx.lineWidth = 3.5 * scale;
    ctx.beginPath();
    ctx.moveTo((18 + lean) * scale, -32 * scale + breathe);
    ctx.lineTo((26 + lean) * scale, 12 * scale);
    ctx.stroke();
    // Mop strings head at bottom
    ctx.fillStyle = "#cfdadf";
    ctx.beginPath();
    ctx.ellipse((26 + lean) * scale, 14 * scale, 7 * scale, 4 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // 2. Legs / maintenance trousers
    ctx.fillStyle = secondary;
    ctx.fillRect((-9 + lean) * scale, 4 * scale, 7 * scale, 14 * scale);
    ctx.fillRect((2 + lean) * scale, 4 * scale, 7 * scale, 14 * scale);
    // Work boots
    ctx.fillStyle = "#0e1820";
    ctx.fillRect((-11 + lean) * scale, 14 * scale, 10 * scale, 5 * scale);
    ctx.fillRect((2 + lean) * scale, 14 * scale, 10 * scale, 5 * scale);

    // 3. Torso / Workshirt
    ctx.fillStyle = primary;
    ctx.fillRect((-12 + lean) * scale, -16 * scale + breathe, 24 * scale, 22 * scale);
    ctx.strokeStyle = secondary;
    ctx.lineWidth = 1.5 * scale;
    ctx.strokeRect((-12 + lean) * scale, -16 * scale + breathe, 24 * scale, 22 * scale);

    // 4. Evidence Bag of Not My Business (Clutched on left hip)
    ctx.fillStyle = "rgba(235, 242, 220, 0.95)";
    ctx.strokeStyle = accent;
    ctx.lineWidth = 2 * scale;
    const bagX = (-24 + lean) * scale;
    const bagY = (-4 + breathe) * scale;
    ctx.fillRect(bagX, bagY, 14 * scale, 16 * scale);
    ctx.strokeRect(bagX, bagY, 14 * scale, 16 * scale);
    ctx.fillStyle = "#18222b";
    ctx.font = `bold ${6 * scale}px monospace`;
    ctx.fillText("EV", bagX + 2 * scale, bagY + 10 * scale);

    // 5. Head & Face
    const headY = (-28 + breathe) * scale;
    ctx.fillStyle = skin;
    ctx.beginPath();
    ctx.ellipse(lean * scale, headY, 10 * scale, 12 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // Maintenance Cap
    ctx.fillStyle = secondary;
    ctx.fillRect((-10 + lean) * scale, headY - 14 * scale, 20 * scale, 6 * scale);
    ctx.fillRect((4 + lean) * scale, headY - 10 * scale, 10 * scale, 3 * scale); // bill

    // Tired heavy eyes & flat mouth
    ctx.strokeStyle = "#1a2530";
    ctx.lineWidth = 1.5 * scale;
    ctx.beginPath();
    ctx.moveTo((-6 + lean) * scale, headY - 2 * scale);
    ctx.lineTo((-1 + lean) * scale, headY - 2 * scale);
    ctx.moveTo((2 + lean) * scale, headY - 2 * scale);
    ctx.lineTo((7 + lean) * scale, headY - 2 * scale);
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo((-4 + lean) * scale, headY + 5 * scale);
    ctx.lineTo((4 + lean) * scale, headY + 5 * scale);
    ctx.stroke();
  }

  _drawDarlaSprite(ctx, palette, behavior, scale) {
    const primary = palette.primary || "#7f4b86";
    const secondary = palette.secondary || "#3c2644";
    const skin = palette.skin || "#c98f67";
    const accent = palette.accent || "#ef8f4d";

    const sip = Math.sin(this.animTime * 2) * 1.2 * scale;

    // 1. Skirt / legs
    ctx.fillStyle = secondary;
    ctx.fillRect(-8 * scale, 2 * scale, 16 * scale, 12 * scale);
    ctx.fillStyle = "#1c1420";
    ctx.fillRect(-8 * scale, 14 * scale, 6 * scale, 4 * scale);
    ctx.fillRect((2) * scale, 14 * scale, 6 * scale, 4 * scale);

    // 2. Cardigan / Body
    ctx.fillStyle = primary;
    ctx.beginPath();
    ctx.ellipse(0, -8 * scale + sip, 14 * scale, 16 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // 3. Head & Hair
    const headY = (-25 + sip) * scale;
    ctx.fillStyle = "#2c1c18";
    ctx.beginPath();
    ctx.ellipse(0, headY - 2 * scale, 13 * scale, 13 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = skin;
    ctx.beginPath();
    ctx.ellipse(0, headY, 9 * scale, 10 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // Knowing Side-Eye
    ctx.fillStyle = "#1a1520";
    ctx.beginPath();
    ctx.arc(-3 * scale, headY - scale, 1.5 * scale, 0, Math.PI * 2);
    ctx.arc(4 * scale, headY - scale, 1.5 * scale, 0, Math.PI * 2);
    ctx.fill();

    // Smirk
    ctx.strokeStyle = "#8f2845";
    ctx.lineWidth = 1.5 * scale;
    ctx.beginPath();
    ctx.arc(scale, headY + 3 * scale, 4 * scale, 0.2, Math.PI * 0.8);
    ctx.stroke();

    // 4. Coffee Mug held in hand
    ctx.fillStyle = accent;
    ctx.fillRect(8 * scale, (-10 + sip) * scale, 8 * scale, 10 * scale);
    ctx.strokeStyle = "#904515";
    ctx.lineWidth = 1 * scale;
    ctx.strokeRect(8 * scale, (-10 + sip) * scale, 8 * scale, 10 * scale);
  }

  _drawTammySprite(ctx, palette, behavior, scale) {
    const primary = palette.primary || "#8e365d";
    const skin = palette.skin || "#e0ad86";
    const accent = palette.accent || "#e8e0ce";

    // 1. Blazer / Body
    ctx.fillStyle = primary;
    ctx.fillRect(-11 * scale, -14 * scale, 22 * scale, 24 * scale);

    // 2. Head
    const headY = -26 * scale;
    ctx.fillStyle = skin;
    ctx.beginPath();
    ctx.ellipse(0, headY, 9 * scale, 11 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // Glasses & stare
    ctx.strokeStyle = "#a02040";
    ctx.lineWidth = 1.5 * scale;
    ctx.strokeRect(-7 * scale, headY - 3 * scale, 6 * scale, 5 * scale);
    ctx.strokeRect(1 * scale, headY - 3 * scale, 6 * scale, 5 * scale);

    // 3. Clipboard in hand
    ctx.fillStyle = accent;
    ctx.fillRect(10 * scale, -6 * scale, 11 * scale, 18 * scale);
    ctx.strokeStyle = "#403020";
    ctx.lineWidth = 1.5 * scale;
    ctx.strokeRect(10 * scale, -6 * scale, 11 * scale, 18 * scale);
  }

  _drawPlayer(ctx) {
    const p = this._xy(this.player);
    const scale = Math.max(0.85, Math.min(this.canvas.width, this.canvas.height) / 440);
    const legOffset = this.playerMoving ? Math.sin(this.walkCycle) * 4 * scale : 0;
    const bodyBob = this.playerMoving ? Math.abs(Math.sin(this.walkCycle)) * 2 * scale : 0;

    ctx.save();
    ctx.translate(p.x, p.y);

    // Floor shadow
    ctx.fillStyle = "rgba(4, 8, 14, 0.70)";
    ctx.beginPath();
    ctx.ellipse(0, 6 * scale, 16 * scale, 7 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // Directional orientation
    // Legs / Boots
    ctx.fillStyle = "#141c24";
    if (this.playerFacing === "left" || this.playerFacing === "right") {
      ctx.fillRect(-4 * scale + legOffset, 2 * scale, 8 * scale, 10 * scale);
    } else {
      ctx.fillRect(-8 * scale, 2 * scale + legOffset, 6 * scale, 10 * scale);
      ctx.fillRect((2) * scale, 2 * scale - legOffset, 6 * scale, 10 * scale);
    }

    // Survivor Coat / Body (Cyan neon-accented office explorer)
    ctx.fillStyle = "#1e3a4c";
    ctx.fillRect(-11 * scale, -16 * scale + bodyBob, 22 * scale, 20 * scale);
    ctx.strokeStyle = "#00f3ff";
    ctx.lineWidth = 1.5 * scale;
    ctx.strokeRect(-11 * scale, -16 * scale + bodyBob, 22 * scale, 20 * scale);

    // Head
    const headY = (-26 + bodyBob) * scale;
    ctx.fillStyle = "#d8a87c";
    ctx.beginPath();
    ctx.ellipse(0, headY, 9 * scale, 10 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // Hair / Explorer Beanie
    ctx.fillStyle = "#0c2838";
    ctx.beginPath();
    ctx.ellipse(0, headY - 4 * scale, 10 * scale, 7 * scale, 0, 0, Math.PI * 2);
    ctx.fill();

    // Eyes based on facing direction
    ctx.fillStyle = "#071018";
    if (this.playerFacing === "down") {
      ctx.beginPath();
      ctx.arc(-3 * scale, headY, 1.5 * scale, 0, Math.PI * 2);
      ctx.arc(3 * scale, headY, 1.5 * scale, 0, Math.PI * 2);
      ctx.fill();
    } else if (this.playerFacing === "left") {
      ctx.beginPath();
      ctx.arc(-5 * scale, headY, 1.5 * scale, 0, Math.PI * 2);
      ctx.fill();
    } else if (this.playerFacing === "right") {
      ctx.beginPath();
      ctx.arc(5 * scale, headY, 1.5 * scale, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  _drawTargetBadge(ctx, text, x, y, scale) {
    ctx.save();
    ctx.font = `bold ${9 * scale}px monospace`;
    const textW = ctx.measureText(text).width;
    ctx.fillStyle = "rgba(7, 10, 16, 0.88)";
    ctx.strokeStyle = "#00f3ff";
    ctx.lineWidth = 1.5 * scale;
    ctx.fillRect(x - textW / 2 - 6 * scale, y - 8 * scale, textW + 12 * scale, 16 * scale);
    ctx.strokeRect(x - textW / 2 - 6 * scale, y - 8 * scale, textW + 12 * scale, 16 * scale);
    ctx.fillStyle = "#00f3ff";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(text, x, y);
    ctx.restore();
  }

  _drawLightingAndAtmosphere(ctx, w, h) {
    // Subtle fluorescent flicker
    const flicker = (Math.sin(this.animTime * 12) + Math.sin(this.animTime * 37)) * 0.02;
    ctx.fillStyle = `rgba(10, 30, 25, ${0.05 + Math.max(0, flicker)})`;
    ctx.fillRect(0, 0, w, h);

    // Vignette
    const vig = ctx.createRadialGradient(w / 2, h / 2, h * 0.4, w / 2, h / 2, w * 0.7);
    vig.addColorStop(0, "rgba(0,0,0,0)");
    vig.addColorStop(1, "rgba(4, 7, 12, 0.45)");
    ctx.fillStyle = vig;
    ctx.fillRect(0, 0, w, h);
  }

  _drawDebugOverlay(ctx, w, h) {
    ctx.save();
    ctx.strokeStyle = "rgba(255, 0, 85, 0.25)";
    ctx.lineWidth = 1;
    for (let x = 0; x < 100; x += 10) {
      const px = (x / 100) * w;
      ctx.beginPath(); ctx.moveTo(px, 0); ctx.lineTo(px, h); ctx.stroke();
    }
    for (let y = 0; y < 100; y += 10) {
      const py = (y / 100) * h;
      ctx.beginPath(); ctx.moveTo(0, py); ctx.lineTo(w, py); ctx.stroke();
    }

    // Player coordinates
    ctx.fillStyle = "#00f3ff";
    ctx.font = "11px monospace";
    ctx.fillText(`[DEBUG] P: (${this.player.x.toFixed(1)}, ${this.player.y.toFixed(1)}) Facing: ${this.playerFacing}`, 10, 20);

    // Interaction radii
    for (const target of this._targets()) {
      if (!target.position) continue;
      const tp = this._xy(target.position);
      const rad = ((target.interaction_radius || 12) / 100) * (this.viewRect ? this.viewRect.rw : w);
      ctx.strokeStyle = "rgba(0, 243, 255, 0.4)";
      ctx.beginPath();
      ctx.arc(tp.x, tp.y, rad, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillText(`${target.id}`, tp.x + 10, tp.y);
    }

    // Blocked regions
    for (const b of this._blockedRegions()) {
      const tl = this._xy({ x: b.min_x, y: b.min_y });
      const br = this._xy({ x: b.max_x, y: b.max_y });
      ctx.fillStyle = "rgba(255, 0, 50, 0.25)";
      ctx.strokeStyle = "rgba(255, 0, 50, 0.75)";
      ctx.lineWidth = 1;
      ctx.fillRect(tl.x, tl.y, br.x - tl.x, br.y - tl.y);
      ctx.strokeRect(tl.x, tl.y, br.x - tl.x, br.y - tl.y);
      ctx.fillStyle = "#ff0055";
      ctx.fillText(b.name || "blocked", tl.x + 4, tl.y + 12);
    }

    // Waypoints
    const wps = (this.snapshot.world && this.snapshot.world.waypoints) || [];
    for (const wp of wps) {
      const p = this._xy(wp);
      ctx.fillStyle = "rgba(0, 255, 120, 0.8)";
      ctx.beginPath();
      ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
}

window.HiveWorldClient = HiveWorldClient;
