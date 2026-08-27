# Steam Multiplayer Setup (Stronghold Survivors)

This game's FFA online mode can run over **Steam lobbies + Steam P2P** so players can host
and join with **no port-forwarding** (Steam's relay handles NAT traversal). Steam support is
delivered as **code + this guide** — the game already ships with all the Steam logic, but it
is *inactive* until you install the GodotSteam plugin and provide an App ID.

If the GodotSteam plugin is **not** installed (or Steam isn't running), the game
automatically falls back to the existing **direct-IP / LAN** flow. Nothing breaks; the Steam
features simply stay hidden.

---

## 1. Install the GodotSteam GDExtension

GodotSteam is a precompiled binary GDExtension. It is **not** bundled here (it can't be built
or tested in CI) — you add it locally.

1. Download the **GodotSteam GDExtension** build that matches this project's engine:
   **Godot 4.2.x**. Get it from the official source:
   - https://godotsteam.com  →  *Downloads → GDExtension*
   - or GitHub: https://github.com/CoaguCo-Industries/GodotSteam/releases
     (pick the **GDExtension** asset for Godot 4.2, not the "module" build).
2. Unzip it into the project so you end up with:
   ```
   addons/godotsteam/
     godotsteam.gdextension
     win64/  macos/  linux/   (the platform binaries)
   ```
3. Restart the Godot editor. Open the project and confirm in the editor that the singleton
   exists — open **Project → Project Settings → Globals/Autoload** or run the game once and
   check the log. On boot you should now see:
   ```
   [Steamworks] Steam initialized (app_id=480, user=<your name>)
   ```
   instead of:
   ```
   [Steamworks] GodotSteam not present — online uses direct-IP fallback.
   ```

The game detects the plugin at runtime via `Engine.has_singleton("Steam")` and
`ClassDB.class_exists("SteamMultiplayerPeer")`. No code edits are required to "turn it on".

---

## 2. Provide an App ID (dev = Spacewar 480)

During development the project uses Valve's public **Spacewar** test App ID **480**, which
lets Steam networking work without owning a store page.

1. Create a file named **`steam_appid.txt`** containing a single line:
   ```
   480
   ```
2. Place that file:
   - in the **project root** (next to `project.godot`) for editor runs, **and**
   - **beside the exported game binary** for exported builds.
3. The **Steam client must be running and logged in** on the machine before launching the
   game. (Steam injects the overlay and provides the logged-in identity.)

The App ID is also set in code at `scripts/steam_manager.gd`:
```gdscript
const STEAM_APP_ID := 480
```
Keep this in sync with `steam_appid.txt`.

---

## 3. Test it (two instances / two accounts)

> Because both instances use App ID 480, you can test on one machine with two copies, but
> **two separate Steam accounts on two machines is the most reliable** test (Steam dislikes
> two clients per account).

### A. Public lobby browser
1. On the **host** machine: launch the game → **FREE-FOR-ALL** → **Host**. You should see a
   "Steam game created" hint and the host enters the lobby UI. A public Steam lobby is now
   advertised (filtered to this game).
2. On the **second** machine: launch → **FREE-FOR-ALL** → **Join** (this opens the Steam
   browser) → the host's lobby appears with its name + player count → **JOIN**.
3. Confirm the match starts on both: shared roster, enemies spawning, synced clock.

### B. Steam overlay invite / "Join Game"
1. Host as above.
2. From the second account, open the Steam friends list, right-click the host →
   **Join Game** (or accept an invite). The game routes the invite straight into
   `Net.join_steam(...)` and joins the lobby.

### C. Headless test hooks (developers)
The lobby supports cmdline autostart flags (note the required `--` separator):
```
# Host a Steam FFA and quick-start after the fill timer:
Godot --path . res://scenes/lobby.tscn -- --steam-host --ffa-now

# Join a known Steam lobby id:
Godot --path . res://scenes/lobby.tscn -- --steam-join <lobby_id>
```
Steam's own cold-launch arg `+connect_lobby <id>` (used by the overlay / desktop shortcuts)
is also handled automatically.

---

## 4. Before release (real App ID)

1. Get your real **Steamworks App ID** from the Steamworks partner site.
2. Replace `480` in **both** places:
   - `scripts/steam_manager.gd` → `const STEAM_APP_ID := <your_app_id>`
   - `steam_appid.txt` → `<your_app_id>`
3. In the Steamworks backend, enable **Steam Networking / Steam Datagram Relay** for the app
   so P2P relay traversal is allowed.
4. Re-test the flows in section 3 on the real App ID.
5. Ship the GodotSteam binaries inside `addons/godotsteam/` with the export, and ensure
   `steam_appid.txt` sits next to the executable (Steam strips/ignores it for the live build
   once launched through Steam, but it's needed for local launches).

---

## 5. Fallback behavior (no Steam)

If the plugin is missing, the App ID is wrong, or the Steam client isn't running:
- `Steamworks.is_ready()` is `false` and `Net.steam_available()` returns `false`.
- **Host** uses ENet + the existing UPnP / public-IP advertise path.
- **Join** shows the IP entry box and the HTTP lobby list.
- Everything works exactly as it did before Steam support was added — the transport simply
  swaps back to direct-IP ENet.

This is by design: the same build runs for players with or without working Steam networking.
