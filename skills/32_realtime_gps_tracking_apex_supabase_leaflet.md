# Skill 32: Real-Time GPS Tracking in Oracle APEX with Supabase and Leaflet

**Category:** Oracle APEX | Realtime | Integration | **Level:** Intermediate

---

## Overview

Oracle APEX has no native way to push an event to a connected browser — pages either poll or wait for a manual refresh. This skill pairs APEX with **Supabase** (Postgres + a Realtime WebSocket channel) and **Leaflet.js** (map rendering) to add a live GPS/location-tracking feature — a shared map where markers move the instant a tracked entity's position changes — without standing up a custom Node.js server or message broker. Oracle keeps its usual job: durable storage, PL/SQL, ORDS-exposed reference data and images. Supabase carries only the ephemeral live-position stream.

---

## How It Works

```
Oracle APEX page (browser)
     │
     ├── Leaflet.js ─────────────► OpenStreetMap tiles
     │
     ├── Supabase JS client ─────► Supabase Realtime (WebSocket)
     │        │
     │        ▼
     │   postgres_changes event (UPDATE on vehicle_location)
     │        │
     │        ▼
     │   ID-keyed marker registry moves the right marker
     │
     ├── ORDS REST endpoint ─────► Oracle BLOB (marker images, reference data)
     │
     └── OSRM public API ────────► road-network routing (no API key needed)
```

---

## Step-by-Step

### 1. Create the Supabase Table and Realtime Policies

```sql
-- In the Supabase SQL editor
create table vehicle_location (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null,
    lat         double precision,
    lng         double precision,
    updated_at  timestamptz default now()
);

alter table vehicle_location enable row level security;

-- Without this, anonymous writes from the browser fail silently
create policy "anon can update own location"
    on vehicle_location for update
    to anon
    using (true)
    with check (true);
```

Enable Realtime for the table from the Supabase dashboard (Database → Replication) so `postgres_changes` events actually fire.

### 2. Build the ID-Keyed Marker Registry

The most common live-map bug is a new marker spawning on every update instead of the existing one moving. Fix it with a registry keyed by entity ID, always removing the old layer first:

```javascript
const trackedEntities = {};

function updateEntityPosition(entityId, lat, lng) {
    const existing = trackedEntities[entityId];
    if (existing) map.removeLayer(existing.marker);

    const marker = L.marker([lat, lng], { icon: vehicleIcon() }).addTo(map);
    trackedEntities[entityId] = { marker, lat, lng };
}
```

### 3. Subscribe To Live Position Changes

```javascript
supabase
    .channel('vehicle-location-changes')
    .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'vehicle_location' },
        (payload) => updateEntityPosition(payload.new.id, payload.new.lat, payload.new.lng)
    )
    .subscribe();
```

### 4. Build the Tracker Page (GPS Capture)

```javascript
navigator.geolocation.watchPosition(
    async (position) => {
        await supabase
            .from('vehicle_location')
            .update({
                lat: position.coords.latitude,
                lng: position.coords.longitude,
                updated_at: new Date().toISOString(),
            })
            .eq('user_id', currentUserId);
    },
    (error) => console.error('Geolocation error:', error),
    { enableHighAccuracy: true }
);

// Keep the screen awake during an active tracking session
await navigator.wakeLock.request('screen');
```

Enable APEX's native PWA support (Application Properties, available since 21.2) so the tracker page installs like an app on a phone. For guaranteed background tracking beyond what a browser PWA can do, wrap the page in a native shell (e.g. Capacitor) with a background-geolocation plugin — say this explicitly rather than overpromising PWA capability.

### 5. Add Road-Network Routing With OSRM

```javascript
async function getDrivingRoute(origin, destination) {
    const coords = `${origin.lng},${origin.lat};${destination.lng},${destination.lat}`;
    const url = `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson`;
    const { routes } = await (await fetch(url)).json();
    return routes[0];
}

// OSRM returns [lng, lat] — Leaflet needs [lat, lng]
const leafletCoords = routes[0].geometry.coordinates.map(([lng, lat]) => [lat, lng]);
L.polyline(leafletCoords).addTo(map);
```

---

## Common Pitfalls Checklist

- [ ] Row Level Security policy added for the exact anonymous operation used (`insert`/`update`) — otherwise writes fail silently
- [ ] Realtime replication enabled for the table in the Supabase dashboard, not just RLS
- [ ] Old marker removed with `map.removeLayer()` before adding the new one — never skip this step
- [ ] OSRM coordinates flipped (`[lng, lat]` → `[lat, lng]`) before drawing with Leaflet
- [ ] Background-tracking expectations set correctly — PWA is not equivalent to a native background-geolocation plugin
- [ ] Live-position writes routed to Supabase, not Oracle — keep Oracle for durable/reference data only

---

## Related Skills

- [Skill 06: Oracle APEX AI Assistant](06_oracle_apex_ai_assistant.md)
- [Skill 24: OCI Object Storage: Loading Data into Oracle AI Pipelines](24_oci_object_storage_ai_pipeline.md)

**#OracleAPEX #Supabase #Leaflet #Realtime #WebSocket #GPS #GIS**
