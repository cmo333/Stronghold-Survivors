extends Node

# LobbyList — client half of the optional internet lobby browser (autoload).
#
# Talks to the standalone registry in tools/lobby_server.gd over plain HTTP/JSON
# so FFA hosts can advertise their game and joiners can see a live list. This is
# ENTIRELY OPTIONAL: if no server URL is configured (or the server is down),
# is_configured()/best-effort calls keep solo + direct-IP play fully working.
#
# Gameplay traffic never goes through here — only "who is hosting" metadata.
#
# Configure the server URL (first match wins):
#   1. CLI:  godot ... -- --lobby-server http://my-host:8650
#   2. env:  STRONGHOLD_LOBBY_SERVER=http://my-host:8650
#   3. default below (127.0.0.1 for local dev; no real host leaks into git)

signal list_received(lobbies: Array)
signal list_failed(reason: String)

const DEFAULT_SERVER_URL: String = "http://127.0.0.1:8650"
const HEARTBEAT_INTERVAL: float = 5.0
const REQUEST_TIMEOUT: float = 6.0

var server_url: String = ""
var current_id: String = ""

var _list_http: HTTPRequest = null
var _action_http: HTTPRequest = null   # register / heartbeat / end
var _hb_timer: Timer = null
var _get_players: Callable = Callable()
var _started: bool = false


func _ready() -> void:
	server_url = _resolve_server_url()

	_list_http = HTTPRequest.new()
	_list_http.timeout = REQUEST_TIMEOUT
	add_child(_list_http)
	_list_http.request_completed.connect(_on_list_completed)

	_action_http = HTTPRequest.new()
	_action_http.timeout = REQUEST_TIMEOUT
	add_child(_action_http)
	_action_http.request_completed.connect(_on_action_completed)

	_hb_timer = Timer.new()
	_hb_timer.wait_time = HEARTBEAT_INTERVAL
	_hb_timer.one_shot = false
	add_child(_hb_timer)
	_hb_timer.timeout.connect(_on_heartbeat_tick)


func _resolve_server_url() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--lobby-server" and i + 1 < args.size():
			return args[i + 1].strip_edges()
	var env: String = OS.get_environment("STRONGHOLD_LOBBY_SERVER").strip_edges()
	if env != "":
		return env
	return DEFAULT_SERVER_URL


func is_configured() -> bool:
	return server_url.strip_edges() != ""


# ---- List polling ----

func fetch_list() -> void:
	if not is_configured():
		list_failed.emit("Lobby browser not configured.")
		return
	# Cancel any in-flight list request so polling never stacks.
	_list_http.cancel_request()
	var err: int = _list_http.request(server_url + "/list", PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		list_failed.emit("Could not reach lobby server.")


func _on_list_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		list_failed.emit("Lobby server unreachable.")
		return
	var data: Dictionary = _parse_body(body)
	if data.is_empty() or not bool(data.get("ok", false)):
		list_failed.emit("Bad response from lobby server.")
		return
	var lobbies: Array = data.get("lobbies", [])
	list_received.emit(lobbies)


# ---- Host registration + heartbeat ----

func register_host(room_name: String, port: int, max_players: int, players: int = 1) -> void:
	if not is_configured():
		return
	var payload: Dictionary = {
		"name": room_name,
		"port": port,
		"max_players": max_players,
		"players": players,
	}
	_post("/register", payload)


func start_heartbeat(get_players: Callable) -> void:
	_get_players = get_players
	_started = false
	if not _hb_timer.is_stopped():
		_hb_timer.stop()
	_hb_timer.start()


func stop_heartbeat() -> void:
	if _hb_timer != null and not _hb_timer.is_stopped():
		_hb_timer.stop()


func send_heartbeat(players: int, started: bool) -> void:
	_started = started
	if not is_configured() or current_id == "":
		return
	_post("/heartbeat", {"id": current_id, "players": players, "started": started})


func _on_heartbeat_tick() -> void:
	if current_id == "" or not is_configured():
		return
	var players: int = 1
	if _get_players.is_valid():
		players = int(_get_players.call())
	send_heartbeat(players, _started)


func end_lobby() -> void:
	stop_heartbeat()
	if not is_configured() or current_id == "":
		current_id = ""
		return
	var id: String = current_id
	current_id = ""
	_started = false
	_post("/end", {"id": id})


# ---- Internal HTTP ----

func _post(path: String, payload: Dictionary) -> void:
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	var body: String = JSON.stringify(payload)
	# Use the action channel; cancel any in-flight action so the latest wins.
	_action_http.cancel_request()
	var err: int = _action_http.request(server_url + path, headers, HTTPClient.METHOD_POST, body)
	if err != OK and path == "/register":
		list_failed.emit("Could not register lobby.")


func _on_action_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var data: Dictionary = _parse_body(body)
	if data.is_empty():
		return
	# Registration response carries our new lobby id.
	if data.has("id") and current_id == "":
		current_id = str(data["id"])
		return
	# A stale heartbeat means the server forgot us (e.g. it restarted): drop our
	# id so the next host action would have to re-register.
	if bool(data.get("stale", false)):
		current_id = ""


func _parse_body(body: PackedByteArray) -> Dictionary:
	var text: String = body.get_string_from_utf8()
	if text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return {}
	return parsed
