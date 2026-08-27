extends Node

# Steamworks — defensive GodotSteam wrapper (autoload, registered as `Steamworks`).
#
# This is the ONLY place that touches the raw GodotSteam `Steam` singleton. The rest of
# the game talks to this node's typed API + signals, so the absence of the GodotSteam
# GDExtension is a clean no-op (every method early-returns and `is_ready()` is false).
#
# IMPORTANT: GodotSteam is a binary GDExtension that is not present in CI / headless
# sandboxes. We deliberately fetch the singleton via `Engine.get_singleton("Steam")`
# (a Variant) and `call(...)` into it dynamically, so this script PARSES and RUNS even
# when the plugin is missing. When missing, online play falls back to direct-IP ENet
# (see net_manager.gd). See STEAM_SETUP.md for installing the plugin + App ID.

# Spacewar test App ID. Lets Steam networking work for development without owning a store
# page. Replace with the real Steamworks App ID before release (also update steam_appid.txt).
const STEAM_APP_ID := 480

# Mirror of Steam's ELobbyType (we avoid referencing the plugin enum so this parses w/o it).
const LOBBY_TYPE_PUBLIC := 2          # k_ELobbyTypePublic
# Mirror of Steam's ELobbyComparison for string filters.
const LOBBY_COMPARISON_EQUAL := 0     # k_ELobbyComparisonEqual

# Re-emitted, decoupled from the raw Steam callback signatures.
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_join_requested(lobby_id: int)   # Steam overlay "Join Game" / accepted invite
signal lobby_list(lobby_ids: Array)
signal lobby_data_changed(lobby_id: int)

var initialized: bool = false
var _steam: Object = null

func _ready() -> void:
	# Feature-detect the GodotSteam singleton. Absent in this sandbox -> graceful no-op.
	if not Engine.has_singleton("Steam"):
		print("[Steamworks] GodotSteam not present — online uses direct-IP fallback.")
		return
	_steam = Engine.get_singleton("Steam")
	if _steam == null:
		print("[Steamworks] Steam singleton null — online uses direct-IP fallback.")
		return
	# steam_appid.txt next to the binary (or project root in editor) must contain the id.
	#
	# GodotSteam's init signature CHANGED across versions, so we can't assume one form:
	#   * SDK 1.61+ (newer plugins): steamInitEx(app_id, embed_callbacks)
	#   * SDK <=1.60 (e.g. the Godot 4.2-line v4.7 build): the FIRST arg was a bool
	#     (retrieve stats), i.e. steamInitEx(retrieve_stats, app_id, embed_callbacks)
	# Calling the wrong form makes the binding read 480 as a bool and return status=1.
	# To stay version-proof we try the known forms and accept whichever reports OK.
	var status := _try_steam_init()
	if status != 0:
		print("[Steamworks] Steam init failed (status=", status, ") — using fallback.")
		print("[Steamworks]   (Steam client must be running + logged in, and steam_appid.txt with '", STEAM_APP_ID, "' must sit next to the binary / in the project root.)")
		_steam = null
		return
	initialized = true
	_connect_steam_signals()
	print("[Steamworks] Steam initialized (app_id=", STEAM_APP_ID, ", user=", persona_name(), ")")

# Attempts each known GodotSteam init signature and returns the resulting status
# code (0 == OK). Stops at the first form that reports success. Every call is wrapped
# so a binding that rejects an arg count can't crash boot — we just try the next form.
func _try_steam_init() -> int:
	var last_status := 1
	# DIAGNOSTIC: report what the singleton actually exposes so we can see the real cause.
	print("[Steamworks] DIAG has steamInitEx=", _steam.has_method("steamInitEx"),
		" steamInit=", _steam.has_method("steamInit"),
		" isSteamRunning=", (_steam.call("isSteamRunning") if _steam.has_method("isSteamRunning") else "n/a"))
	# Modern two-arg form: steamInitEx(app_id, embed_callbacks).
	if _steam.has_method("steamInitEx"):
		var r1 = _safe_init_call("steamInitEx", [STEAM_APP_ID, true])
		print("[Steamworks] DIAG steamInitEx(app_id, true) -> ", r1)
		last_status = _init_status(r1)
		if last_status == 0:
			return 0
		# Legacy three-arg form (v4.7 / SDK<=1.60): (retrieve_stats, app_id, embed_callbacks).
		var r2 = _safe_init_call("steamInitEx", [true, STEAM_APP_ID, true])
		print("[Steamworks] DIAG steamInitEx(true, app_id, true) -> ", r2)
		last_status = _init_status(r2)
		if last_status == 0:
			return 0
	# Oldest fallback: steamInit(...). Some builds return a Dictionary, others an int/bool.
	if _steam.has_method("steamInit"):
		var r3 = _safe_init_call("steamInit", [STEAM_APP_ID, true])
		print("[Steamworks] DIAG steamInit(app_id, true) -> ", r3)
		last_status = _init_status(r3)
		if last_status == 0:
			return 0
		var r4 = _safe_init_call("steamInit", [true, STEAM_APP_ID, true])
		print("[Steamworks] DIAG steamInit(true, app_id, true) -> ", r4)
		last_status = _init_status(r4)
		if last_status == 0:
			return 0
	return last_status

# Calls a Steam init method with the given args via callv, guarding against an
# arg-count mismatch (returns a sentinel failure dict instead of crashing).
func _safe_init_call(method: String, args: Array) -> Variant:
	if _steam == null or not _steam.has_method(method):
		return {"status": 1}
	return _steam.callv(method, args)

# Normalizes the various return shapes (Dictionary {status}, int, or bool) into a
# status code where 0 means success.
func _init_status(result: Variant) -> int:
	if result is Dictionary:
		return int((result as Dictionary).get("status", 1))
	if result is int:
		# Some bindings return the EResult-like code directly (0 == OK).
		return int(result)
	if result is bool:
		return 0 if bool(result) else 1
	return 1

func _connect_steam_signals() -> void:
	if _steam == null:
		return
	# Names per GodotSteam 4.x. Guard each so a binding difference can't crash boot.
	_try_connect_steam("lobby_created", _on_steam_lobby_created)
	_try_connect_steam("lobby_joined", _on_steam_lobby_joined)
	_try_connect_steam("lobby_match_list", _on_steam_lobby_match_list)
	_try_connect_steam("lobby_data_update", _on_steam_lobby_data_update)
	_try_connect_steam("join_requested", _on_steam_join_requested)

func _try_connect_steam(sig: String, cb: Callable) -> void:
	if _steam != null and _steam.has_signal(sig) and not _steam.is_connected(sig, cb):
		_steam.connect(sig, cb)

func _process(_delta: float) -> void:
	if initialized and _steam != null and _steam.has_method("run_callbacks"):
		_steam.run_callbacks()

# ---- Public API (safe no-ops when Steam is absent) ----

func is_ready() -> bool:
	return initialized and _steam != null

func persona_name() -> String:
	if is_ready() and _steam.has_method("getPersonaName"):
		return str(_steam.getPersonaName())
	return "Player"

func get_steam_id() -> int:
	if is_ready() and _steam.has_method("getSteamID"):
		return int(_steam.getSteamID())
	return 0

func create_lobby(max_players: int) -> void:
	if not is_ready():
		return
	if _steam.has_method("createLobby"):
		_steam.createLobby(LOBBY_TYPE_PUBLIC, max_players)

func join_lobby(lobby_id: int) -> void:
	if not is_ready():
		return
	if _steam.has_method("joinLobby"):
		_steam.joinLobby(lobby_id)

func leave_lobby(lobby_id: int) -> void:
	if not is_ready() or lobby_id == 0:
		return
	if _steam.has_method("leaveLobby"):
		_steam.leaveLobby(lobby_id)

func request_lobby_list() -> void:
	if not is_ready():
		return
	# Only surface lobbies for THIS game (filter on our metadata key).
	if _steam.has_method("addRequestLobbyListStringFilter"):
		_steam.addRequestLobbyListStringFilter("game", "stronghold_survivors", LOBBY_COMPARISON_EQUAL)
	if _steam.has_method("requestLobbyList"):
		_steam.requestLobbyList()

func set_lobby_data(lobby_id: int, key: String, value: String) -> void:
	if not is_ready() or lobby_id == 0:
		return
	if _steam.has_method("setLobbyData"):
		_steam.setLobbyData(lobby_id, key, value)

func get_lobby_data(lobby_id: int, key: String) -> String:
	if not is_ready() or lobby_id == 0:
		return ""
	if _steam.has_method("getLobbyData"):
		return str(_steam.getLobbyData(lobby_id, key))
	return ""

func get_lobby_host_id(lobby_id: int) -> int:
	if not is_ready() or lobby_id == 0:
		return 0
	if _steam.has_method("getLobbyOwner"):
		return int(_steam.getLobbyOwner(lobby_id))
	return 0

func get_lobby_member_count(lobby_id: int) -> int:
	if not is_ready() or lobby_id == 0:
		return 0
	if _steam.has_method("getNumLobbyMembers"):
		return int(_steam.getNumLobbyMembers(lobby_id))
	return 0

# ---- Raw Steam callbacks -> decoupled signals ----

func _on_steam_lobby_created(connect_result: int, lobby_id: int) -> void:
	if int(connect_result) != 1:   # 1 == k_EResultOK
		print("[Steamworks] lobby_created failed (result=", connect_result, ")")
		return
	lobby_created.emit(int(lobby_id))

func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# response 1 == k_EChatRoomEnterResponseSuccess
	if int(response) != 1:
		print("[Steamworks] lobby_joined failed (response=", response, ")")
		return
	lobby_joined.emit(int(lobby_id))

func _on_steam_lobby_match_list(lobbies: Array) -> void:
	var ids: Array = []
	for l in lobbies:
		ids.append(int(l))
	lobby_list.emit(ids)

func _on_steam_lobby_data_update(_success: int, lobby_id: int, _member_id: int) -> void:
	lobby_data_changed.emit(int(lobby_id))

func _on_steam_join_requested(lobby_id: int, _friend_id: int) -> void:
	lobby_join_requested.emit(int(lobby_id))
