extends Node

# Net — multiplayer session manager (autoload).
#
# Holds session/peer state that must survive the menu -> lobby -> match scene
# changes, and abstracts the transport so gameplay code only ever touches the
# Godot MultiplayerAPI (`multiplayer.*` / `@rpc`) and never an ENet class
# directly. This keeps a future WebSocket/WebRTC swap (for browser play)
# isolated to this file.
#
# Authority model: server-authoritative. The host (peer id 1) simulates the
# world; clients send input + build requests. See plan: FFA prototype.
#
# Solo play keeps `mode == "solo"` and never creates a peer, so the existing
# single-player code path is fully untouched.

signal roster_changed
signal lobby_countdown(seconds_left: int)
signal match_starting(roster: Array, rng_seed: int)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connection_failed_signal
signal server_disconnected_signal

const DEFAULT_PORT := 8642
const MAX_PLAYERS := 8          # hard cap on real ENet peers
const MIN_PLAYERS := 4          # bots fill up to this many slots
const LOBBY_FILL_SECONDS := 120 # 2-minute fill timer
const BOT_ID_BASE := -1000      # synthetic ids for bots (always negative)

# Transport selector. ENET = direct-IP/LAN (always available). STEAM = Steam P2P via
# GodotSteam (zero port-forwarding, but requires the plugin + a running Steam client).
enum Transport { ENET, STEAM }
var transport: int = Transport.ENET
var steam_lobby_id: int = 0     # active Steam lobby (0 when not in a Steam session)

# "solo" | "ffa". Gates every multiplayer branch in gameplay code.
var mode: String = "solo"
var is_host: bool = false
var local_peer_id: int = 1

# peer_id -> { name, hero, is_bot, slot, ready }
var lobby_players: Dictionary = {}

# Final roster captured at match launch (array of dicts, ordered by slot).
var match_roster: Array = []
var match_seed: int = 0

var _peer: MultiplayerPeer = null
var _next_slot: int = 0

func _ready() -> void:
	# Connect to the MultiplayerAPI lifecycle once. These fire only while a
	# peer exists; in solo they never trigger.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Steam lobby lifecycle (no-ops when GodotSteam is absent — Steamworks is a safe stub).
	var sw := get_node_or_null("/root/Steamworks")
	if sw != null:
		if sw.has_signal("lobby_created") and not sw.lobby_created.is_connected(_on_steam_lobby_created):
			sw.lobby_created.connect(_on_steam_lobby_created)
		if sw.has_signal("lobby_joined") and not sw.lobby_joined.is_connected(_on_steam_lobby_joined):
			sw.lobby_joined.connect(_on_steam_lobby_joined)

func is_multiplayer() -> bool:
	return mode == "ffa"

func is_solo() -> bool:
	return mode != "ffa"

# ---- Transport (the ONLY place an ENet class is referenced) ----

func create_host(port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("Net: failed to create server on port %d (err %d)" % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	_peer = peer
	is_host = true
	mode = "ffa"
	local_peer_id = 1
	lobby_players.clear()
	_next_slot = 0
	_add_player(1, _local_hero_name(), _local_hero(), false)
	roster_changed.emit()
	return true

func join(ip: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Net: failed to create client to %s:%d (err %d)" % [ip, port, err])
		return false
	multiplayer.multiplayer_peer = peer
	_peer = peer
	is_host = false
	mode = "ffa"
	return true

# ---- Steam transport (GodotSteam P2P). Falls back to ENet when unavailable. ----

# True only when the GodotSteam plugin is installed AND initialized. In this sandbox /
# for players without the plugin this returns false and callers use the ENet path.
func steam_available() -> bool:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return false
	var sw := get_node_or_null("/root/Steamworks")
	return sw != null and sw.has_method("is_ready") and bool(sw.is_ready())

func _new_steam_peer() -> MultiplayerPeer:
	# Instantiate via ClassDB so this script parses without the binary GDExtension.
	var obj: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	if obj is MultiplayerPeer:
		return obj as MultiplayerPeer
	return null

# Host over Steam P2P. Creates the Steam-socket host peer immediately (so the host's
# unique id is 1 and the roster seeds exactly like ENet) then asks Steam to create the
# public lobby; lobby metadata is written in _on_steam_lobby_created once we have the id.
func create_host_steam() -> bool:
	if not steam_available():
		return false
	var peer := _new_steam_peer()
	if peer == null:
		push_error("Net: SteamMultiplayerPeer unavailable; cannot host over Steam")
		return false
	# create_host(virtual_port) — 0 is the default Steam networking channel.
	var err: int = OK
	if peer.has_method("create_host"):
		err = int(peer.call("create_host", 0))
	if err != OK:
		push_error("Net: Steam create_host failed (err %d)" % err)
		return false
	multiplayer.multiplayer_peer = peer
	_peer = peer
	transport = Transport.STEAM
	is_host = true
	mode = "ffa"
	local_peer_id = 1
	lobby_players.clear()
	_next_slot = 0
	_add_player(1, _local_hero_name(), _local_hero(), false)
	roster_changed.emit()
	var sw := get_node_or_null("/root/Steamworks")
	if sw != null and sw.has_method("create_lobby"):
		sw.create_lobby(MAX_PLAYERS)
	return true

# Join a Steam lobby. The actual peer connection is established in _on_steam_lobby_joined
# once Steam confirms entry and we can read the host's Steam id from lobby metadata.
func join_steam(lobby_id: int) -> bool:
	if not steam_available() or lobby_id == 0:
		return false
	transport = Transport.STEAM
	is_host = false
	mode = "ffa"
	var sw := get_node_or_null("/root/Steamworks")
	if sw != null and sw.has_method("join_lobby"):
		sw.join_lobby(lobby_id)
		return true
	return false

func _on_steam_lobby_created(lobby_id: int) -> void:
	steam_lobby_id = lobby_id
	var sw := get_node_or_null("/root/Steamworks")
	if sw == null:
		return
	# Tag the lobby so the in-game browser only lists this game, and record the host id
	# so joiners know which Steam peer to connect their socket to.
	sw.set_lobby_data(lobby_id, "game", "stronghold_survivors")
	sw.set_lobby_data(lobby_id, "name", "FFA Game")
	sw.set_lobby_data(lobby_id, "host_steam_id", str(sw.get_steam_id()))
	sw.set_lobby_data(lobby_id, "players", str(real_player_count()))
	sw.set_lobby_data(lobby_id, "started", "0")

func _on_steam_lobby_joined(lobby_id: int) -> void:
	steam_lobby_id = lobby_id
	if is_host:
		return  # host already has its peer; joining its own lobby is a no-op
	var sw := get_node_or_null("/root/Steamworks")
	if sw == null:
		return
	var host_id := 0
	var meta: String = str(sw.get_lobby_data(lobby_id, "host_steam_id"))
	if meta != "" and meta.is_valid_int():
		host_id = int(meta)
	if host_id == 0 and sw.has_method("get_lobby_host_id"):
		host_id = int(sw.get_lobby_host_id(lobby_id))
	if host_id == 0:
		push_error("Net: Steam lobby has no host id; cannot connect")
		connection_failed_signal.emit()
		return
	var peer := _new_steam_peer()
	if peer == null:
		connection_failed_signal.emit()
		return
	var err: int = OK
	if peer.has_method("create_client"):
		err = int(peer.call("create_client", host_id, 0))
	if err != OK:
		push_error("Net: Steam create_client failed (err %d)" % err)
		connection_failed_signal.emit()
		return
	multiplayer.multiplayer_peer = peer
	_peer = peer
	transport = Transport.STEAM

func shutdown() -> void:
	# Best-effort: clear our entry from the optional lobby browser so finished /
	# abandoned games disappear from the list. Guarded so solo + tests without
	# the LobbyList autoload never error.
	var ll := get_node_or_null("/root/LobbyList")
	if ll != null and ll.has_method("end_lobby"):
		ll.end_lobby()
	# Leave the Steam lobby (if any) so it disappears from the public list.
	if transport == Transport.STEAM and steam_lobby_id != 0:
		var sw := get_node_or_null("/root/Steamworks")
		if sw != null and sw.has_method("leave_lobby"):
			sw.leave_lobby(steam_lobby_id)
	steam_lobby_id = 0
	transport = Transport.ENET
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_peer = null
	is_host = false
	mode = "solo"
	local_peer_id = 1
	lobby_players.clear()
	match_roster.clear()
	_next_slot = 0

# ---- Roster management (host-authoritative) ----

func _add_player(peer_id: int, pname: String, hero: String, is_bot: bool) -> void:
	if lobby_players.has(peer_id):
		return
	lobby_players[peer_id] = {
		"name": pname,
		"hero": hero,
		"is_bot": is_bot,
		"slot": _next_slot,
		"ready": false,
	}
	_next_slot += 1

func get_player_ids() -> Array:
	var ids := lobby_players.keys()
	ids.sort_custom(func(a, b):
		return lobby_players[a]["slot"] < lobby_players[b]["slot"]
	)
	return ids

func real_player_count() -> int:
	var n := 0
	for id in lobby_players.keys():
		if not lobby_players[id]["is_bot"]:
			n += 1
	return n

# Host fills empty slots with bots up to MIN_PLAYERS, then captures the roster
# and tells everyone to launch. Safe to call only on the host.
func host_launch_match() -> void:
	if not is_host:
		return
	var bots_needed: int = max(0, MIN_PLAYERS - lobby_players.size())
	for i in range(bots_needed):
		var bid := BOT_ID_BASE - i
		_add_player(bid, "Bot %d" % (i + 1), "hunter", true)
	match_seed = randi()
	match_roster = _build_roster_array()
	_rpc_begin_match.rpc(match_roster, match_seed)

func _build_roster_array() -> Array:
	var arr: Array = []
	for id in get_player_ids():
		var p: Dictionary = lobby_players[id]
		arr.append({
			"peer_id": id,
			"name": p["name"],
			"hero": p["hero"],
			"is_bot": p["is_bot"],
			"slot": p["slot"],
		})
	return arr

# ---- RPCs ----

# Client -> host: register myself after connecting.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_register(pname: String, hero: String) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	_add_player(sender, pname, hero, false)
	if _verbose():
		print("[Net] registered peer ", sender, " roster_size=", lobby_players.size())
	_push_roster()

# Host -> all: authoritative roster snapshot.
@rpc("authority", "call_remote", "reliable")
func _rpc_roster(roster: Array) -> void:
	if _verbose():
		print("[Net] received roster snapshot, size=", roster.size())
	lobby_players.clear()
	_next_slot = 0
	for entry in roster:
		lobby_players[int(entry["peer_id"])] = {
			"name": entry["name"],
			"hero": entry["hero"],
			"is_bot": entry["is_bot"],
			"slot": entry["slot"],
			"ready": false,
		}
		_next_slot = max(_next_slot, int(entry["slot"]) + 1)
	roster_changed.emit()

func _push_roster() -> void:
	if not is_host:
		return
	_rpc_roster.rpc(_build_roster_array())
	roster_changed.emit()

# Host -> all (call_local so the host launches too): start the match.
@rpc("authority", "call_local", "reliable")
func _rpc_begin_match(roster: Array, rng_seed: int) -> void:
	match_roster = roster
	match_seed = rng_seed
	seed(rng_seed)
	match_starting.emit(roster, rng_seed)

# ---- MultiplayerAPI callbacks ----

func _on_peer_connected(id: int) -> void:
	peer_joined.emit(id)
	if _verbose():
		print("[Net] peer_connected: ", id, " (host=", is_host, ") roster_size=", lobby_players.size())
	if is_host:
		# New client will register itself; push current roster so it can render.
		_push_roster()

func _on_peer_disconnected(id: int) -> void:
	if is_host and lobby_players.has(id):
		lobby_players.erase(id)
		_push_roster()
	peer_left.emit(id)

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	# Tell the host who we are.
	_rpc_register.rpc_id(1, _local_hero_name(), _local_hero())

func _on_connection_failed() -> void:
	shutdown()
	connection_failed_signal.emit()

func _on_server_disconnected() -> void:
	shutdown()
	server_disconnected_signal.emit()

# ---- Local identity helpers ----

func _meta() -> Node:
	return get_node_or_null("/root/MetaProgression")

func _local_hero() -> String:
	var meta := _meta()
	if meta != null and "pending_hero" in meta:
		return str(meta.pending_hero)
	return "hunter"

func _local_hero_name() -> String:
	# Simple display name for the prototype lobby.
	return "Player"

func _verbose() -> bool:
	# Diagnostic logging, gated behind a CLI flag so normal play stays quiet:
	#   godot ... -- --net-verbose
	return OS.get_cmdline_user_args().has("--net-verbose")
