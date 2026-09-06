/* Strawberry Omen service worker — static shell cache only */

const CACHE_NAME = "wetberry-shell-v070-rpg1";
const SHELL_ASSETS = [
  "/",
  "/static/strawberry.css",
  "/static/strawberry.js",
  "/static/world_client.js",
  "/static/manifest.webmanifest",
  "/static/icons/icon-192.png",
  "/static/icons/icon-512.png",
  "/api/assets/rooms/room.breakroom.illustrated.png",
  "/api/assets/rooms/room.breakroom.central_table.png",
  "/api/assets/portraits/keith_neutral.png",
  "/api/assets/portraits/keith_annoyed.png",
  "/api/assets/portraits/keith_engaged.png",
  "/api/assets/portraits/darla_neutral.png",
  "/api/assets/portraits/darla_annoyed.png",
  "/api/assets/portraits/darla_engaged.png",
  "/api/assets/portraits/tammy_procedural.png",
  "/api/assets/items/item.evidence_bag_not_my_business.png",
  "/api/assets/items/item.bagged_wetberry_evidence.png",
  "/api/assets/items/item.wetberry.png",
  "/api/assets/items/item.damp_napkin.png"
];

/* Install: pre-cache the app shell */
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(SHELL_ASSETS))
      .then(() => self.skipWaiting())
  );
});

/* Activate: clean old caches */
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(
        names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n))
      )
    ).then(() => self.clients.claim())
  );
});

/* Fetch: network-first for API; network-first shell avoids stale playtest UI. */
self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  /* Never intercept API calls — let them hit the network */
  if (url.pathname.startsWith("/api/")) {
    event.respondWith(
      fetch(event.request).catch(() => {
        return new Response(
          JSON.stringify({ error: "Server unavailable. Make sure the local server is running." }),
          { status: 503, headers: { "Content-Type": "application/json" } }
        );
      })
    );
    return;
  }

  /* Shell assets: network-first so a new local build is visible immediately. */
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response.ok && url.origin === self.location.origin) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
