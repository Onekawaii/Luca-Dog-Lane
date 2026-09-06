/* Strawberry Omen — frontend logic (v0.7.0 Visual RPG Slice) */

let currentState = null;
let toastTimer = null;
let activeMobileTab = "adventure";
let worldClient = null;
let selectedInventoryItem = null;

/* ── API layer ────────────────────────────────────────────────────────── */

async function api(path, opts) {
    try {
        const res = await fetch(path, opts);
        if (!res.ok && res.status === 503) {
            showToast("Server unavailable", true);
            document.getElementById("offline-banner").classList.remove("hidden");
            return null;
        }
        document.getElementById("offline-banner").classList.add("hidden");
        return await res.json();
    } catch (e) {
        showToast("Server unavailable", true);
        document.getElementById("offline-banner").classList.remove("hidden");
        return null;
    }
}

/* ── Toast notifications ──────────────────────────────────────────────── */

function showToast(text, isError) {
    const el = document.getElementById("toast");
    if (!el) return;
    el.textContent = text;
    el.className = "";
    el.style.borderColor = isError ? "var(--accent)" : "var(--accent-cyan)";
    /* Force reflow for transition */
    void el.offsetWidth;
    el.classList.add("visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { el.className = "hidden"; }, 2500);
}

/* ── State refresh ────────────────────────────────────────────────────── */

async function refresh() {
    const data = await api("/api/state");
    if (!data) return;
    currentState = data;
    render(data);
    showToast("HUD State Reloaded");
}

/* ── Mobile Tab Navigation ────────────────────────────────────────────── */

function switchMobileTab(tab) {
    activeMobileTab = tab;
    
    // Update button states
    document.querySelectorAll(".tab-btn").forEach(btn => btn.classList.remove("active"));
    const activeBtn = document.getElementById(`tab-${tab}-btn`);
    if (activeBtn) activeBtn.classList.add("active");

    // Hide/show sidebars and main columns
    const hudLeft = document.getElementById("hud-left");
    const hudCenter = document.getElementById("hud-center");
    const hudRight = document.getElementById("hud-right");

    if (tab === "adventure") {
        hudLeft.classList.add("mobile-hidden");
        hudCenter.classList.remove("mobile-hidden");
        hudRight.classList.add("mobile-hidden");
    } else if (tab === "status") {
        hudLeft.classList.remove("mobile-hidden");
        hudCenter.classList.add("mobile-hidden");
        hudRight.classList.add("mobile-hidden");
    } else if (tab === "gear") {
        hudLeft.classList.add("mobile-hidden");
        hudCenter.classList.add("mobile-hidden");
        hudRight.classList.remove("mobile-hidden");
    }
}

/* ── Render HUD ───────────────────────────────────────────────────────── */

function render(data) {
    if (!data) return;

    // Header Title and Info
    document.getElementById("title").textContent = data.scene.title || "Strawberry Omen";
    document.getElementById("location-bar").textContent = "Location: " + (data.location.name || data.location.id);

    /* Act progression indicator — server-derived single source of truth. */
    const actBar = document.getElementById("act-bar");
    const progression = data.progression || {};
    actBar.textContent = progression.current_label || "Act I";

    // Narration terminal & Dialogue frame
    document.getElementById("scene-text").textContent = data.scene.read_aloud || "";

    // Render Character Dialogue Portrait
    renderDialoguePortrait(data);

    // Render Choice buttons
    const panel = document.getElementById("choices-panel");
    panel.innerHTML = "";
    for (const choice of data.choices) {
        const btn = document.createElement("button");
        btn.className = "choice-btn" + (choice.available === false ? " locked-choice" : "");
        btn.disabled = choice.available === false;
        btn.textContent = choice.available === false
            ? `${choice.label} — ${choice.locked_reason || "LOCKED"}`
            : choice.label;
        if (choice.kind && choice.kind !== "choice") btn.dataset.kind = choice.kind;
        if (choice.available !== false) btn.onclick = () => makeChoice(choice.id);
        panel.appendChild(btn);
    }

    // Result banner
    const resultBanner = document.getElementById("result-banner");
    if (data.result) {
        resultBanner.textContent = data.result;
        resultBanner.classList.remove("hidden");
    } else {
        resultBanner.classList.add("hidden");
    }

    // Visual Images and Sprite Staging
    renderVisualStage(data);

    // Sidebar Content updates
    renderSidebarStats(data);
    renderSidebarQuests(data);
    renderSidebarInventory(data);
    renderSidebarLore(data);
    renderSidebarLogs(data);
}

/* ── Dialogue Portrait Rendering ───────────────────────────────────────── */

function renderDialoguePortrait(data) {
    const portraitBox = document.getElementById("dialogue-portrait-box");
    const portraitImg = document.getElementById("dialogue-portrait-img");
    const speakerName = document.getElementById("dialogue-speaker-name");

    if (!portraitBox || !portraitImg) return;

    if (data.scene && data.scene.speaker_portrait) {
        portraitImg.src = data.scene.speaker_portrait;
        if (speakerName) speakerName.textContent = data.scene.speaker_name || "";
        portraitBox.classList.remove("hidden");
        portraitImg.onerror = () => { portraitBox.classList.add("hidden"); };
    } else {
        portraitBox.classList.add("hidden");
        portraitImg.removeAttribute("src");
    }
}

/* ── Adventure Verbs System ────────────────────────────────────────────── */

function updateVerbAffordances(target) {
    const buttons = document.querySelectorAll(".verb-btn");
    if (!target) {
        // No target selected: reset to default
        buttons.forEach(btn => {
            btn.classList.remove("suggested", "dimmed");
        });
        return;
    }

    // Determine suggested verbs based on target type
    const targetId = target.id || "";
    const isKeith = targetId.includes("keith");
    const isDarla = targetId.includes("darla");
    const isWetberry = targetId.includes("wetberry");
    const isHotspot = target.kind === "hotspot" || targetId.startsWith("hotspot.");

    let suggested = [];
    if (isKeith || isDarla) {
        suggested = ["LOOK", "TALK", "USE"];
    } else if (isWetberry) {
        suggested = ["LOOK", "TAKE", "USE"];
    } else if (isHotspot) {
        suggested = ["LOOK", "USE", "OPEN"];
    } else {
        suggested = ["LOOK", "USE"];
    }

    buttons.forEach(btn => {
        const verb = btn.dataset.verb;
        if (suggested.includes(verb)) {
            btn.classList.add("suggested");
            btn.classList.remove("dimmed");
        } else {
            btn.classList.remove("suggested");
            btn.classList.add("dimmed");
        }
    });
}

async function executeVerb(verb) {
    if (!currentState) return;
    const client = ensureWorldClient();
    const target = (client && client.selectedTarget) || (client ? client._nearestTarget() : null);

    if (verb === "GO") {
        showToast("Tap floor to walk or use WASD keys.");
        return;
    }

    if (!target) {
        if (verb === "LOOK") {
            showToast(`Looking around ${currentState.location?.name || "the room"}...`);
            await refresh();
        } else if (verb === "TALK") {
            showToast("Nobody selected to talk to. Tap a character first.", true);
        } else if (verb === "TAKE") {
            showToast("Nothing selected to take. Tap an object first.", true);
        } else if (verb === "USE") {
            if (selectedInventoryItem) {
                showToast(`Select a target in the room to use ${selectedInventoryItem.name} on.`);
            } else {
                showToast("Select an item in Gear & Archives tab first, or tap an object in the room.");
                switchMobileTab("gear");
            }
        } else if (verb === "OPEN") {
            showToast("Nothing selected to open. Tap a container or door first.", true);
        }
        return;
    }

    // Special object-on-object shortcut: Evidence Bag on Wetberry
    if ((verb === "TAKE" || verb === "USE") && target.id.includes("wetberry")) {
        const details = currentState.inventory_details || [];
        let bagAction = null;
        for (const item of details) {
            for (const act of (item.actions || [])) {
                if (act.id && act.id.includes("evidence_bag.wetberry") && act.available !== false) {
                    bagAction = act.id;
                }
            }
        }
        if (bagAction) {
            showToast("Containing Wetberry with Evidence Bag...");
            await useItemAction(bagAction);
            return;
        }
    }

    // Send kind: "verb" to authoritative engine
    const payload = {
        verb: verb,
        item_id: selectedInventoryItem ? selectedInventoryItem.id : null
    };

    const targetLabel = target.name || target.id;
    showToast(`${verb} ${targetLabel}...`);
    await makeWorldAction({
        kind: "verb",
        target_id: target.id,
        payload: payload
    });
}

/* ── Debug Mode ────────────────────────────────────────────────────────── */

function toggleDebugMode() {
    const client = ensureWorldClient();
    if (!client) return;
    const active = client.toggleDebug();
    const indicator = document.getElementById("debug-indicator");
    if (indicator) indicator.classList.toggle("hidden", !active);

    const minimap = document.getElementById("minimap-panel");
    if (minimap) minimap.classList.toggle("debug-active", active);

    showToast(`Developer Diagnostics: ${active ? "ENABLED" : "DISABLED"}`);
}

/* ── World in Motion action bridge ─────────────────────────────────────── */

async function makeWorldAction(action, opts = {}) {
    const data = await api("/api/action", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(action)
    });
    if (!data || data.error) {
        if (data && !opts.quiet) showToast("Error: " + data.error, true);
        return data;
    }
    currentState = data;
    if (opts.quiet) {
        if (worldClient && data.world) worldClient.setSnapshot(data.world);
    } else {
        render(data);
        if (data.result) showToast(data.result);
    }
    return data;
}

function ensureWorldClient() {
    if (worldClient || !window.HiveWorldClient) return worldClient;
    worldClient = new window.HiveWorldClient({
        canvas: document.getElementById("world-canvas"),
        interactButton: document.getElementById("world-interact-btn"),
        hint: document.getElementById("world-hint"),
        requestAction: makeWorldAction
    });
    worldClient.onTargetSelected = (target) => {
        updateVerbAffordances(target);
    };
    return worldClient;
}

/* ── Visual Stage and 2D Layered Sprites ───────────────────────────────── */

function renderVisualStage(data) {
    const roomImg = document.getElementById("room-img");
    const roomFallback = document.getElementById("room-fallback");
    const arenaImg = document.getElementById("arena-img");
    const arenaLoading = document.getElementById("arena-loading");
    const npcSpriteImg = document.getElementById("npc-sprite-img");
    const mapImg = document.getElementById("map-img");
    const mapBox = document.getElementById("map-box");
    const worldCanvas = document.getElementById("world-canvas");
    const worldHint = document.getElementById("world-hint");
    const worldInteract = document.getElementById("world-interact-btn");

    /* Reset every mutually-exclusive stage layer before selecting one. */
    roomImg.classList.add("hidden");
    roomFallback.classList.add("hidden");
    arenaImg.classList.add("hidden");
    arenaLoading.classList.add("hidden");
    npcSpriteImg.className = "npc-sprite hidden";
    npcSpriteImg.removeAttribute("src");
    worldCanvas.classList.add("hidden");
    worldHint.classList.add("hidden");
    worldInteract.classList.add("hidden");

    const roomUrl = data.images && data.images.room ? data.images.room : null;
    const showRoomFallback = () => {
        roomImg.classList.add("hidden");
        roomFallback.classList.remove("hidden");
    };
    const showRoom = () => {
        if (!roomUrl) {
            showRoomFallback();
            return;
        }
        roomImg.src = roomUrl;
        roomImg.classList.remove("hidden");
        roomFallback.classList.add("hidden");
    };

    roomImg.onerror = showRoomFallback;

    /* Hearing arena (Act V): fall back to room art if renderer is unavailable. */
    if (data.arena && data.arena.active && data.arena.render_url) {
        arenaLoading.classList.remove("hidden");
        const requestedScene = data.scene.id;
        fetch(data.arena.render_url)
            .then((res) => {
                if (!res.ok) throw new Error("arena render unavailable");
                return res.blob();
            })
            .then((blob) => {
                if (!currentState || currentState.scene.id !== requestedScene) return;
                arenaImg.src = URL.createObjectURL(blob);
                arenaImg.classList.remove("hidden");
                arenaLoading.classList.add("hidden");
            })
            .catch(() => {
                if (!currentState || currentState.scene.id !== requestedScene) return;
                arenaImg.classList.add("hidden");
                arenaLoading.classList.add("hidden");
                showRoom();
            });
    } else {
        showRoom();
    }

    /* Minimap. */
    if (data.images && data.images.map) {
        mapImg.src = data.images.map;
        mapBox.classList.remove("hidden");
    } else {
        mapBox.classList.add("hidden");
        mapImg.removeAttribute("src");
    }

    /* Walkable world owns the viewport when a campaign world is active. */
    if (data.world && data.world.world && data.world.world.enabled) {
        const client = ensureWorldClient();
        if (client) client.setSnapshot(data.world);
        roomImg.classList.add("hidden");
        roomFallback.classList.add("hidden");
        arenaImg.classList.add("hidden");
        arenaLoading.classList.add("hidden");
        npcSpriteImg.classList.add("hidden");
        return;
    }

    /* Non-walkable scenes use server-authored entity presentation — no scene-name inference. */
    const activeEntities = data.presentation && Array.isArray(data.presentation.entities)
        ? data.presentation.entities
        : [];
    const activeNpc = activeEntities.find(entity => entity.token_url);
    if (activeNpc && activeNpc.token_url) {
        npcSpriteImg.src = activeNpc.token_url;
        npcSpriteImg.classList.remove("hidden");
        const behavior = activeNpc.dynamics && activeNpc.dynamics.behavior;
        if (behavior === "agitated" || behavior === "strained") npcSpriteImg.classList.add("animate-flicker");
        else if (activeNpc.id.includes("moldric")) npcSpriteImg.classList.add("animate-bobbing");
        else if (activeNpc.id.includes("sentient_casserole")) npcSpriteImg.classList.add("animate-glow");
        else npcSpriteImg.classList.add("animate-pulse");
        npcSpriteImg.onerror = function () {
            this.classList.add("hidden");
            this.removeAttribute("src");
        };
    }
}

/* ── Sidebars Renderers ────────────────────────────────────────────────── */

function renderSidebarStats(data) {
    const container = document.getElementById("stats-hud-body");
    const stats = data.stats || {};
    
    let html = `<div class="stats-list">`;
    const labelMapping = {
        health: "INTEGRITY (HP)",
        awkwardness: "SOCIAL COUREY (AWK)",
        bureaucracy: "PROCEDURAL PRESSURE (BUR)",
        ape_chaos: "FERAL CHAOS (APE)",
        moisture_pressure: "MOISTURE LEVEL (H2O)"
    };

    for (const key in labelMapping) {
        const val = stats[key] !== undefined ? stats[key] : 0;
        let meterColor = "var(--text-dim)";
        if (key === "health") meterColor = "var(--accent)";
        if (key === "awkwardness") meterColor = "var(--accent-cyan)";
        if (key === "bureaucracy") meterColor = "var(--accent-amber)";
        if (key === "ape_chaos") meterColor = "var(--accent-green)";

        html += `
            <div class="stat-item">
                <span class="stat-label">${labelMapping[key]}</span>
                <span class="stat-value ${key}">${val}</span>
            </div>
            <div style="background:#131825;height:4px;margin-bottom:10px;border-radius:2px;overflow:hidden;">
                <div style="background:${meterColor};height:100%;width:${Math.min(100, Math.max(0, val))}%"></div>
            </div>
        `;
    }
    html += `</div>`;

    const conditions = data.conditions || {};
    const conditionIds = Object.keys(conditions);
    if (conditionIds.length) {
        html += `<div class="system-subpanel"><strong>ACTIVE CONDITIONS</strong>` +
            conditionIds.map(id => `<div class="condition-chip">${esc(id.replace("condition.", "").replace(/_/g, " "))} · ${conditions[id] < 0 ? "persistent" : conditions[id] + "t"}</div>`).join("") +
            `</div>`;
    }

    const memories = data.npc_memory || {};
    const remembered = Object.entries(memories).filter(([, value]) => value !== 0);
    if (remembered.length) {
        html += `<div class="system-subpanel"><strong>RELATIONSHIPS</strong>` +
            remembered.map(([id, value]) => `<div class="memory-row"><span>${esc(id.replace("npc.", "").replace(/_/g, " "))}</span><b>${value > 0 ? "+" : ""}${value}</b></div>`).join("") +
            `</div>`;
    }
    container.innerHTML = html;
}

function renderSidebarQuests(data) {
    const container = document.getElementById("quests-hud-body");
    const acts = (data.progression && data.progression.acts) || [];
    if (acts.length === 0) {
        container.innerHTML = "<div style='color:var(--text-dim);font-style:italic;'>Protocol state unavailable.</div>";
        return;
    }

    let html = "<ul>";
    for (const act of acts) {
        if (act.active) {
            html += `<li><span style="color:var(--accent-cyan);font-weight:bold">&#x25B6; [ACTIVE]</span> ${esc(act.name)}</li>`;
        } else if (act.done) {
            html += `<li style="opacity:0.5;text-decoration:line-through"><span style="color:var(--accent-green);">&#x2714;</span> ${esc(act.name)}</li>`;
        } else {
            html += `<li style="opacity:0.3">&#x25CB; ${esc(act.name)}</li>`;
        }
    }
    html += "</ul>";
    container.innerHTML = html;
}

function selectInventoryItem(itemId) {
    if (!currentState) return;
    const details = currentState.inventory_details || [];
    const item = details.find(i => i.id === itemId);
    if (!item) return;

    if (selectedInventoryItem && selectedInventoryItem.id === itemId) {
        selectedInventoryItem = null;
        showToast(`Deselected ${item.name}`);
    } else {
        selectedInventoryItem = item;
        showToast(`Armed ${item.name}. Tap a target in the room and use USE!`);
        // On mobile, take player back to adventure tab
        switchMobileTab("adventure");
    }
    renderSidebarInventory(currentState);
}

function renderSidebarInventory(data) {
    const container = document.getElementById("inventory-hud-body");
    const details = data.inventory_details || [];

    if (details.length === 0) {
        container.innerHTML = "<div style='color:var(--text-dim);font-style:italic;'>No relics in inventory.</div>";
        return;
    }

    let html = `<div class="inventory-list">`;
    for (const item of details) {
        const iconUrl = item.icon_url || `/api/assets/items/${item.id}.png`;
        const isActive = selectedInventoryItem && selectedInventoryItem.id === item.id;
        html += `<div class="inventory-card ${isActive ? "active-item" : ""}" onclick="selectInventoryItem('${esc(item.id)}')">
            <div class="inventory-card-header">
                <img class="inventory-item-icon" src="${esc(iconUrl)}" alt="${esc(item.name)}" onerror="this.style.display='none'">
                <div class="inventory-name"><span style="color:var(--accent-amber);">&#x2666;</span> ${esc(item.name)}${isActive ? " [ARMED]" : ""}</div>
            </div>
            <div class="inventory-desc">${esc(item.description || "")}</div>`;
        for (const action of (item.actions || [])) {
            html += `<button class="item-use-btn" ${action.available === false ? "disabled" : ""}
                onclick="event.stopPropagation(); useItemAction('${esc(action.id)}')">&#x2699; ${esc(action.label)}${action.available === false ? " — " + esc(action.locked_reason || "LOCKED") : ""}</button>`;
        }
        html += `</div>`;
    }
    html += `</div>`;
    container.innerHTML = html;
}

function renderSidebarLore(data) {
    const container = document.getElementById("lore-hud-body");
    const flags = data.flags || {};
    
    let fragments = [];
    if (flags.wetberry_seen) {
        fragments.push("<strong>[WETBERRY ANALYSIS]</strong>: Product box turns toward warmth. Social hazard level 2.");
    }
    if (flags.fridge_unlocked) {
        fragments.push("<strong>[MEMENTO FRIDGE]</strong>: Unlocked using damp containment napkins. social boundaries violated.");
    }
    if (flags.met_moldric) {
        fragments.push("<strong>[DUKE MOLDRIC]</strong>: An entity residing in expired mustard jars. Governs expiration denial.");
    }
    if (flags.act2_fridge_visions_seen) {
        fragments.push("<strong>[FROSTBITE MEMORIES]</strong>: Optional visions seen. Corporate neglect transcends timelines.");
    }
    if (flags.accountability_token_obtained) {
        fragments.push("<strong>[SLOT CODE]</strong>: Accountability Token acquired. Paid in memories of forgotten lunch boxes.");
    }
    if (flags.casserole_resolved_compassion) {
        fragments.push("<strong>[EXORCISM PROTOCOL]</strong>: resolved boss with compassion. The casserole lid is fragments.");
    }
    if (flags.summons_received) {
        fragments.push("<strong>[DEPARTMENT OF ADJUDICATION]</strong>: A summons arrived unprompted. The building processes you whether or not you consent to be processed.");
    }
    if (flags.evidence_gathered) {
        fragments.push("<strong>[CLERK PELL]</strong>: Forty-one entries, forty-one handwritings, one name. The Records Hall remembers everything the breakroom forgot.");
    }
    if (flags.testimony_given) {
        fragments.push("<strong>[BAILIFF GORRUM]</strong>: Say the true thing. It goes faster and it goes easier. AWK.");
    }
    if (flags.hearing_entered) {
        fragments.push("<strong>[HEARING ARENA]</strong>: The ring measures what you bring into it. Bureaucracy and chaos both leave a reading.");
    }
    if (flags.verdict_rendered) {
        fragments.push("<strong>[MAGISTRATE ORLA]</strong>: I don't decide who was right. I decide what happens next. Those are different jobs.");
    }
    if (flags.act5_complete) {
        fragments.push("<strong>[VERDICT SEAL]</strong>: The Department processed you. For once, that felt less like punishment and more like being seen.");
    }
    if (flags.wetberry_contained) {
        fragments.push("<strong>[CONTAINMENT RECORD]</strong>: Wetberry was physically contained. The Hive remembers that you brought tools instead of bare hands.");
    }
    if (flags.department_verdict) {
        fragments.push(`<strong>[LIVE VERDICT]</strong>: ${esc(String(flags.department_verdict).replace(/_/g, " ").toUpperCase())}. The result was derived from your actual record.`);
    }

    if (fragments.length === 0) {
        container.innerHTML = "<div style='color:var(--text-dim);font-style:italic;'>No archive entries unlocked. Examine relics to fill database.</div>";
        return;
    }

    container.innerHTML = "<ul>" + fragments.map(f => `<li style="margin-bottom:8px;font-size:0.75rem;">${f}</li>`).join("") + "</ul>";
}

function renderSidebarLogs(data) {
    const container = document.getElementById("log-hud-body");
    const logs = data.log || [];
    
    if (logs.length === 0) {
        container.innerHTML = "<div style='color:var(--text-dim);font-style:italic;'>Chronicle empty.</div>";
        return;
    }

    // Render clean logs feed
    container.innerHTML = "<ul>" + logs.map(l => `<li style="font-size:0.75rem;"><span style="color:var(--accent-cyan);">></span> ${esc(l)}</li>`).join("") + "</ul>";
}

/* ── Choice selection ──────────────────────────────────────────────────── */

async function makeChoice(choiceId) {
    const data = await api("/api/choice", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ choice_id: choiceId })
    });
    if (!data || data.error) {
        if (data) showToast("Error: " + data.error, true);
        return;
    }
    currentState = data;
    render(data);
    if (data.result) showToast(data.result);
}

async function useItemAction(actionId) {
    const data = await api("/api/item/use", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action_id: actionId })
    });
    if (!data || data.error) {
        if (data) showToast("Error: " + data.error, true);
        return;
    }
    currentState = data;
    render(data);
    if (data.result) showToast(data.result);
}

/* ── Save / Load API bindings ─────────────────────────────────────────── */

function stateSummary(data) {
    if (!data) return "current state";
    const location = data.location && (data.location.name || data.location.id) ? (data.location.name || data.location.id) : "Unknown location";
    const act = data.progression && data.progression.current_label ? data.progression.current_label : "Act I";
    return `${location} · ${act}`;
}

async function doSave() {
    const data = await api("/api/save", { method: "POST" });
    if (!data) return;
    if (data.error) {
        showToast(data.error, true);
        return;
    }
    showToast(`Saved — ${stateSummary(currentState)}`);
}

async function doLoad() {
    const data = await api("/api/load", { method: "POST" });
    if (!data) return;
    if (data.error) {
        showToast(data.error, true);
        return;
    }
    currentState = data;
    render(data);
    showToast(`Loaded — ${stateSummary(data)}`);
}

/* ── Overlays and Fallbacks (Legacy compliance) ────────────────────────── */

function showPanel(type) {
    if (!currentState) return;
    const overlay = document.getElementById("side-panels");
    const title = document.getElementById("panel-title");
    const body = document.getElementById("panel-body");
    overlay.classList.remove("hidden");

    if (type === "inventory") {
        title.textContent = "Inventory Relics";
        const items = currentState.inventory;
        body.innerHTML = items.length === 0 ? "<em>Empty.</em>" : "<ul>" + items.map(i => "<li>" + esc(i) + "</li>").join("") + "</ul>";
    } else if (type === "flags") {
        title.textContent = "State Flags";
        const flags = currentState.flags;
        const keys = Object.keys(flags).sort();
        body.innerHTML = "<ul>" + keys.map(k => {
            const cls = flags[k] ? "flag-true" : "flag-false";
            return '<li><span class="' + cls + '">' + esc(k) + "</span> = " + esc(String(flags[k])) + "</li>";
        }).join("") + "</ul>";
    } else if (type === "stats") {
        title.textContent = "Core Stats";
        const stats = currentState.stats;
        const keys = Object.keys(stats).sort();
        body.innerHTML = "<ul>" + keys.map(k => "<li>" + esc(k) + ": " + esc(String(stats[k])) + "</li>").join("") + "</ul>";
    } else if (type === "log") {
        title.textContent = "Chronicle logs";
        body.innerHTML = "<ul>" + (currentState.log || []).map(l => "<li>" + esc(l) + "</li>").join("") + "</ul>";
    } else if (type === "assets") {
        title.textContent = "Current visual links";
        const imgs = currentState.images || {};
        body.innerHTML = `<ul><li><strong>Map:</strong> ${esc(imgs.map || "None")}</li><li><strong>Room:</strong> ${esc(imgs.room || "None")}</li></ul>`;
    }
}

function hidePanels() {
    document.getElementById("side-panels").classList.add("hidden");
}

/* ── Help screen ──────────────────────────────────────────────────────── */

function showHelp() {
    const overlay = document.getElementById("side-panels");
    const title = document.getElementById("panel-title");
    const body = document.getElementById("panel-body");
    title.textContent = "Systems Manual";
    body.innerHTML = `
        <p><strong>Strawberry Omen</strong> — Illustrated Retro Adventure RPG.</p>
        <hr style='border-color:var(--border);margin:8px 0'>
        <p><strong>HOW TO SURVIVE:</strong></p>
        <ul>
          <li><strong>Movement:</strong> In walkable rooms, tap the floor to move. On desktop, WASD or arrow keys move your avatar.</li>
          <li><strong>Proximity Interaction:</strong> Move close to Keith, Darla, or Wetberry. A glowing proximity ring and interaction prompt will appear. Press E / Enter or tap Interact.</li>
          <li><strong>Classic Adventure Verbs:</strong> Use LOOK, TALK, TAKE, USE, OPEN, GO to interact seamlessly with the environment and characters.</li>
          <li><strong>Evidence & Containment:</strong> Keith holds the Evidence Bag of Not My Business in the Utility Corner. Talk to Keith, obtain the bag, then use it on the Wetberry on the Central Table.</li>
          <li><strong>Emotional Dynamics:</strong> Keith and Darla's portraits reflect their live emotional state (steady, annoyed, engaged) based on your interactions.</li>
          <li><strong>Procedural Pressure vs Feral Chaos:</strong> Manage Bureaucracy and Ape Chaos to navigate institutional adjudication.</li>
        </ul>
        <br>
        <p><strong>UI INTERFACE LEGEND:</strong></p>
        <ul>
          <li><strong>Viewport:</strong> The primary illustrated adventure scene with real-time character depth sorting.</li>
          <li><strong>Narration & Dialogue:</strong> Active NPC portraits and CRT terminal text.</li>
          <li><strong>Gear & Archives:</strong> Tactile pixel inventory slots and unlocked Hive lore fragments.</li>
        </ul>
        <hr style='border-color:var(--border);margin:8px 0'>
        <div style="margin: 12px 0; text-align: center;">
            <button type="button" class="bar-btn" onclick="toggleDebugMode()" style="background:var(--surface-highlight);border:1px solid var(--accent);color:var(--accent);padding:8px 16px;">
                Toggle Developer Debug Diagnostics
            </button>
        </div>
        <p style='color:var(--text-dim);font-size:0.75rem'>Phone-first controls: no Desktop Site mode required. Help is local and does not change game state.</p>
    `;
    overlay.classList.remove("hidden");
}

/* ── Image Preview Viewport modal ──────────────────────────────────────── */

function openPreview(type) {
    const data = currentState;
    if (!data) return;
    const url = type === "map" ? data.images.map : data.images.room;
    if (!url) return;
    const modal = document.getElementById("preview-modal");
    const img = document.getElementById("preview-img");
    const label = document.getElementById("preview-label");
    img.src = url;
    label.textContent = type === "map" ? "Map View — " + (data.location.name || "") : "Room View — " + (data.location.name || "");
    modal.classList.remove("hidden");
    document.body.style.overflow = "hidden";
}

function closePreview() {
    document.getElementById("preview-modal").classList.add("hidden");
    document.body.style.overflow = "";
}

/* ── Utility String escaper ────────────────────────────────────────────── */

function esc(s) {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
}

/* ── Boot Initializer ─────────────────────────────────────────────────── */

refresh();
switchMobileTab("adventure");
