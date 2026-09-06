/* Hive-Lattice World Client — dependency-free v0.7 vertical-slice renderer.
 *
 * This is intentionally renderer-agnostic. It proves the Action/Event/Snapshot
 * contract without adding an external network dependency. The same snapshot
 * can later be consumed by Phaser without changing the Python game rules.
 */

class HiveWorldClient {
  constructor({ canvas, interactButton, hint, requestAction }) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.interactButton = interactButton;
    this.hint = hint;
    this.requestAction = requestAction;
    this.snapshot = null;
    this.player = { x: 50, y: 70 };
    this.destination = null;
    this.keys = new Set();
    this.lastFrame = performance.now();
    this.lastSync = 0;
    this.syncInFlight = false;
    this.visible = false;

    this._bindInput();
    this._resize();
    new ResizeObserver(() => this._resize()).observe(canvas);
    requestAnimationFrame((t) => this._tick(t));
  }

  setSnapshot(snapshot) {
    this.snapshot = snapshot;
    const p = snapshot && snapshot.player ? snapshot.player : null;
    if (p && Number.isFinite(p.x) && Number.isFinite(p.y)) {
      this.player = { x: p.x, y: p.y };
    }
    this.visible = Boolean(snapshot && snapshot.world && snapshot.world.enabled);
    this.canvas.classList.toggle("hidden", !this.visible);
    if (this.interactButton) this.interactButton.classList.add("hidden");
    if (this.hint) this.hint.classList.toggle("hidden", !this.visible);
    this._draw();
  }

  _bindInput() {
    window.addEventListener("keydown", (event) => {
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

    this.canvas.addEventListener("pointerdown", (event) => {
      if (!this.visible || !this.snapshot) return;
      const rect = this.canvas.getBoundingClientRect();
      const x = ((event.clientX - rect.left) / rect.width) * 100;
      const y = ((event.clientY - rect.top) / rect.height) * 100;
      this.destination = { x, y };
    });

    if (this.interactButton) {
      this.interactButton.addEventListener("click", () => {
        const target = this._nearestTarget();
        if (target) this._interact(target);
      });
    }
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
    this._draw();
  }

  _tick(now) {
    const dt = Math.min(0.05, (now - this.lastFrame) / 1000);
    this.lastFrame = now;
    if (this.visible && this.snapshot) {
      this._move(dt);
      this._updateInteractionPrompt();
      this._draw();
      if (now - this.lastSync > 160) this._syncPosition(now);
    }
    requestAnimationFrame((t) => this._tick(t));
  }

  _bounds() {
    return (this.snapshot && this.snapshot.world && this.snapshot.world.bounds) || { min_x: 0, max_x: 100, min_y: 0, max_y: 100 };
  }

  _move(dt) {
    const speed = (this.snapshot.player && this.snapshot.player.speed) || 22;
    let dx = 0;
    let dy = 0;
    if (this.keys.has("a") || this.keys.has("arrowleft")) dx -= 1;
    if (this.keys.has("d") || this.keys.has("arrowright")) dx += 1;
    if (this.keys.has("w") || this.keys.has("arrowup")) dy -= 1;
    if (this.keys.has("s") || this.keys.has("arrowdown")) dy += 1;

    if (dx || dy) {
      this.destination = null;
      const mag = Math.hypot(dx, dy) || 1;
      dx /= mag;
      dy /= mag;
      this.player.x += dx * speed * dt;
      this.player.y += dy * speed * dt;
    } else if (this.destination) {
      const vx = this.destination.x - this.player.x;
      const vy = this.destination.y - this.player.y;
      const dist = Math.hypot(vx, vy);
      if (dist < 0.9) {
        this.destination = null;
      } else {
        const step = Math.min(dist, speed * dt);
        this.player.x += (vx / dist) * step;
        this.player.y += (vy / dist) * step;
      }
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
      const radius = target.interaction_radius || 11;
      if (distance <= radius && distance < bestDistance) {
        best = target;
        bestDistance = distance;
      }
    }
    return best;
  }

  _updateInteractionPrompt() {
    if (!this.interactButton) return;
    const target = this._nearestTarget();
    if (!target) {
      this.interactButton.classList.add("hidden");
      return;
    }
    this.interactButton.textContent = target.interaction_label || `Interact: ${target.name || target.id}`;
    this.interactButton.dataset.targetId = target.id;
    this.interactButton.classList.remove("hidden");
  }

  async _interact(target) {
    await this._syncPosition(performance.now(), true);
    if (!this.requestAction) return;
    await this.requestAction({ kind: "interact", target_id: target.id });
  }

  _xy(point) {
    return {
      x: (point.x / 100) * this.canvas.width,
      y: (point.y / 100) * this.canvas.height,
    };
  }

  _draw() {
    const ctx = this.ctx;
    if (!ctx || !this.canvas.width || !this.canvas.height) return;
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    if (!this.visible || !this.snapshot) return;

    this._drawRoom(ctx);
    for (const hotspot of this.snapshot.hotspots || []) this._drawHotspot(ctx, hotspot);
    for (const entity of this.snapshot.entities || []) this._drawActor(ctx, entity);
    this._drawPlayer(ctx);
  }

  _drawRoom(ctx) {
    const w = this.canvas.width;
    const h = this.canvas.height;
    const style = (this.snapshot.world && this.snapshot.world.style) || {};
    ctx.fillStyle = style.floor || "#111722";
    ctx.fillRect(0, 0, w, h);

    ctx.strokeStyle = style.grid || "#1d2a39";
    ctx.lineWidth = Math.max(1, w / 500);
    for (let x = 0; x < 100; x += 5) {
      const px = (x / 100) * w;
      ctx.beginPath(); ctx.moveTo(px, 0); ctx.lineTo(px, h); ctx.stroke();
    }
    for (let y = 0; y < 100; y += 5) {
      const py = (y / 100) * h;
      ctx.beginPath(); ctx.moveTo(0, py); ctx.lineTo(w, py); ctx.stroke();
    }

    // Coffee counter
    ctx.fillStyle = style.counter || "#4c3c35";
    ctx.fillRect(w * 0.28, h * 0.04, w * 0.44, h * 0.12);
    // Fridge block
    ctx.fillStyle = style.fridge || "#8896a3";
    ctx.fillRect(w * 0.06, h * 0.26, w * 0.18, h * 0.34);
    // Utility corner
    ctx.fillStyle = style.utility || "#24364a";
    ctx.fillRect(w * 0.69, h * 0.63, w * 0.25, h * 0.25);
    // Central table
    ctx.fillStyle = style.table || "#3c4654";
    ctx.beginPath(); ctx.ellipse(w * 0.50, h * 0.52, w * 0.16, h * 0.11, 0, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = "#707b89"; ctx.lineWidth = Math.max(2, w / 260); ctx.stroke();
  }

  _drawHotspot(ctx, hotspot) {
    const p = this._xy(hotspot.position);
    if (hotspot.id === "hotspot.wetberry") {
      const size = Math.max(12, this.canvas.width * 0.027);
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.fillStyle = "#ff3e8a";
      ctx.strokeStyle = "#ffb3d3";
      ctx.lineWidth = 2;
      ctx.fillRect(-size * 0.45, -size * 0.8, size * 0.9, size * 1.35);
      ctx.strokeRect(-size * 0.45, -size * 0.8, size * 0.9, size * 1.35);
      ctx.fillStyle = "#7dff91";
      ctx.beginPath(); ctx.arc(0, -size * 0.72, size * 0.18, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    } else {
      ctx.fillStyle = "#ff0055";
      ctx.beginPath(); ctx.arc(p.x, p.y, 7, 0, Math.PI * 2); ctx.fill();
    }
  }

  _drawActor(ctx, entity) {
    const p = this._xy(entity.position);
    const identity = entity.identity || {};
    const palette = identity.palette || {};
    const behavior = entity.dynamics && entity.dynamics.behavior ? entity.dynamics.behavior : "steady";
    const scale = Math.max(0.75, Math.min(this.canvas.width, this.canvas.height) / 430);

    ctx.save();
    ctx.translate(p.x, p.y);

    if (entity.id === "npc.keith_janitor") {
      this._drawKeith(ctx, palette, behavior, scale);
    } else if (entity.id === "npc.darla_microwave") {
      this._drawDarla(ctx, palette, scale);
    } else if (entity.id === "npc.tammy_hr") {
      this._drawTammy(ctx, palette, scale);
    } else {
      ctx.fillStyle = palette.primary || "#8aa0b2";
      ctx.beginPath(); ctx.arc(0, 0, 11 * scale, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();
  }

  _drawKeith(ctx, palette, behavior, scale) {
    const primary = palette.primary || "#2f6678";
    const secondary = palette.secondary || "#173746";
    const skin = palette.skin || "#d8a87c";
    const accent = palette.accent || "#f1c44f";
    const lean = behavior === "agitated" || behavior === "strained" ? -3 * scale : 0;

    // Mop handle — silhouette anchor.
    ctx.strokeStyle = "#b9c2c9"; ctx.lineWidth = 3 * scale;
    ctx.beginPath(); ctx.moveTo(20 * scale, -25 * scale); ctx.lineTo(28 * scale, 28 * scale); ctx.stroke();
    // lanky body / work shirt
    ctx.fillStyle = primary;
    ctx.fillRect((-13 + lean) * scale, -5 * scale, 26 * scale, 35 * scale);
    ctx.fillStyle = secondary;
    ctx.fillRect((-11 + lean) * scale, 24 * scale, 9 * scale, 22 * scale);
    ctx.fillRect((3 + lean) * scale, 24 * scale, 9 * scale, 22 * scale);
    // head
    ctx.fillStyle = skin;
    ctx.beginPath(); ctx.ellipse(lean, -22 * scale, 11 * scale, 13 * scale, 0, 0, Math.PI * 2); ctx.fill();
    // maintenance cap
    ctx.fillStyle = secondary;
    ctx.fillRect((-11 + lean) * scale, -35 * scale, 22 * scale, 5 * scale);
    ctx.fillRect((5 + lean) * scale, -31 * scale, 12 * scale, 3 * scale);
    // tired eyes
    ctx.strokeStyle = "#18222b"; ctx.lineWidth = 2 * scale;
    ctx.beginPath(); ctx.moveTo((-7 + lean) * scale, -23 * scale); ctx.lineTo((-2 + lean) * scale, -24 * scale); ctx.stroke();
    ctx.beginPath(); ctx.moveTo((3 + lean) * scale, -24 * scale); ctx.lineTo((8 + lean) * scale, -23 * scale); ctx.stroke();
    // flat mouth
    ctx.beginPath(); ctx.moveTo((-4 + lean) * scale, -15 * scale); ctx.lineTo((5 + lean) * scale, -15 * scale); ctx.stroke();
    // evidence bag
    ctx.fillStyle = "rgba(236,241,218,0.90)"; ctx.strokeStyle = accent; ctx.lineWidth = 2 * scale;
    ctx.fillRect((-27 + lean) * scale, 7 * scale, 15 * scale, 19 * scale); ctx.strokeRect((-27 + lean) * scale, 7 * scale, 15 * scale, 19 * scale);
    ctx.fillStyle = "#18222b"; ctx.font = `${7 * scale}px monospace`; ctx.fillText("EVID", (-26 + lean) * scale, 18 * scale);
  }

  _drawDarla(ctx, palette, scale) {
    ctx.fillStyle = palette.primary || "#7f4b86";
    ctx.beginPath(); ctx.ellipse(0, 6 * scale, 16 * scale, 25 * scale, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = palette.skin || "#c98f67";
    ctx.beginPath(); ctx.arc(0, -17 * scale, 11 * scale, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = palette.accent || "#ef8f4d";
    ctx.fillRect(12 * scale, 2 * scale, 10 * scale, 12 * scale);
  }

  _drawTammy(ctx, palette, scale) {
    ctx.fillStyle = palette.primary || "#8e365d";
    ctx.fillRect(-13 * scale, -4 * scale, 26 * scale, 36 * scale);
    ctx.fillStyle = palette.skin || "#e0ad86";
    ctx.beginPath(); ctx.arc(0, -20 * scale, 11 * scale, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = palette.accent || "#e8e0ce";
    ctx.fillRect(14 * scale, 2 * scale, 13 * scale, 22 * scale);
    ctx.strokeStyle = "#222"; ctx.lineWidth = 1.5 * scale; ctx.strokeRect(14 * scale, 2 * scale, 13 * scale, 22 * scale);
  }

  _drawPlayer(ctx) {
    const p = this._xy(this.player);
    const r = Math.max(8, this.canvas.width * 0.018);
    ctx.save(); ctx.translate(p.x, p.y);
    ctx.fillStyle = "#00f3ff";
    ctx.strokeStyle = "#ffffff";
    ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#071018";
    ctx.beginPath(); ctx.arc(-r * 0.32, -r * 0.15, 1.6, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.arc(r * 0.32, -r * 0.15, 1.6, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
  }
}

window.HiveWorldClient = HiveWorldClient;
