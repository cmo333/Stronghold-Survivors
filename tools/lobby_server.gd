extends SceneTree

# Stronghold Survivors — lobby-list server (Phase 2 of internet multiplayer).
#
# A tiny, dependency-free registry that lets FFA hosts advertise their game and
# lets joiners see a live list of open lobbies. Gameplay traffic still flows
# peer-to-peer over ENet (this server only stores who-is-hosting metadata).
#
# Run it on any always-on box (a cheap VPS, a spare PC, a free cloud host):
#   Godot --headless --script tools/lobby_server.gd
#   Godot --headless --script tools/lobby_server.gd -- --lobby-port 8650
#
# Godot 4.2 ships no HTTP *server* class, so this speaks bare HTTP/1.1 over a
# TCPServer with JSON bodies. State is in-memory only; restarting clears it.
#
# Protocol (all JSON, Content-Type application/json):
#   POST /register  {name, port, max_players, [host_ip]} -> {ok, id}
#   POST /heartbeat {id, players, started}               -> {ok} | {ok:false, stale:true}
#   GET  /list                                           -> {ok, lobbies:[...]}
#   POST /end       {id}                                 -> {ok}   (idempotent)
#   GET  /health                                         -> {ok, count}
#
# A lobby is dropped automatically if it misses heartbeats for TTL_SECONDS, so
# crashed/force-quit hosts clear themselves without an explicit /end.

const DEFAULT_PORT: int = 8650
const TTL_SECONDS: float = 20.0
const SWEEP_INTERVAL: float = 5.0
const MAX_REQUEST_BYTES: int = 8192
const READ_TIMEOUT: float = 2.0

var _server: TCPServer = null
var _lobbies: Dictionary = {}      # id:String -> lobby dict
var _next_id: int = 1
var _sweep_accum: float = 0.0
var _port: int = DEFAULT_PORT


func _initialize() -> void:
	_port = _resolve_port()
	_server = TCPServer.new()
	var err: int = _server.listen(_port)
	if err != OK:
		push_error("lobby_server: failed to listen on port %d (err %d)" % [_port, err])
		quit(1)
		return
	print("[lobby_server] listening on 0.0.0.0:%d  (TTL=%ds)" % [_port, int(TTL_SECONDS)])


func _resolve_port() -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--lobby-port" and i + 1 < args.size():
			var v: String = args[i + 1]
			if v.is_valid_int():
				return int(v)
	return DEFAULT_PORT


func _process(delta: float) -> bool:
	# Accept any pending connections (non-blocking).
	while _server != null and _server.is_connection_available():
		var conn: StreamPeerTCP = _server.take_connection()
		if conn != null:
			_handle_connection(conn)

	# Periodic TTL sweep so crashed hosts disappear.
	_sweep_accum += delta
	if _sweep_accum >= SWEEP_INTERVAL:
		_sweep_accum = 0.0
		_sweep_expired()

	# Returning false keeps the SceneTree main loop running.
	return false


func _sweep_expired() -> void:
	var now: float = _now()
	var dead: Array = []
	for id in _lobbies.keys():
		var lobby: Dictionary = _lobbies[id]
		if now - float(lobby.get("last_seen", 0.0)) > TTL_SECONDS:
			dead.append(id)
	for id in dead:
		_lobbies.erase(id)
		print("[lobby_server] expired lobby %s (no heartbeat)" % str(id))


# ---- HTTP handling ----

func _handle_connection(conn: StreamPeerTCP) -> void:
	var raw: String = _read_request(conn)
	if raw == "":
		conn.disconnect_from_host()
		return

	var method: String = ""
	var path: String = ""
	var body: String = ""
	var parsed: Dictionary = _parse_http(raw)
	method = str(parsed.get("method", ""))
	path = str(parsed.get("path", ""))
	body = str(parsed.get("body", ""))

	var client_ip: String = ""
	# get_connected_host() is the NAT-translated source IP — exactly what a
	# joiner must reach, so we use it as the lobby host_ip by default.
	client_ip = conn.get_connected_host()

	var response: Dictionary = _route(method, path, body, client_ip)
	var code: int = int(response.get("code", 200))
	var payload: Dictionary = response.get("json", {})
	_write_json(conn, code, payload)
	conn.disconnect_from_host()


func _read_request(conn: StreamPeerTCP) -> String:
	var buffer: PackedByteArray = PackedByteArray()
	var deadline: float = _now() + READ_TIMEOUT
	var header_end: int = -1
	var content_length: int = -1

	while _now() < deadline:
		conn.poll()
		var status: int = conn.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED and status != StreamPeerTCP.STATUS_CONNECTING:
			break
		var avail: int = conn.get_available_bytes()
		if avail > 0:
			var chunk: Array = conn.get_partial_data(avail)
			# get_partial_data returns [err, PackedByteArray]
			if int(chunk[0]) == OK:
				buffer.append_array(chunk[1])
		if buffer.size() > MAX_REQUEST_BYTES:
			break

		if header_end < 0:
			var as_text: String = buffer.get_string_from_utf8()
			var idx: int = as_text.find("\r\n\r\n")
			if idx >= 0:
				header_end = idx
				content_length = _content_length_from(as_text.substr(0, idx))

		if header_end >= 0:
			var head_bytes: int = header_end + 4
			var have_body: int = buffer.size() - head_bytes
			if content_length <= 0 or have_body >= content_length:
				break

		# brief idle wait to let more data arrive
		OS.delay_msec(2)

	return buffer.get_string_from_utf8()


func _content_length_from(header_block: String) -> int:
	for line in header_block.split("\r\n"):
		var low: String = line.to_lower()
		if low.begins_with("content-length:"):
			var v: String = line.substr(line.find(":") + 1).strip_edges()
			if v.is_valid_int():
				return int(v)
	return -1


func _parse_http(raw: String) -> Dictionary:
	var out: Dictionary = {"method": "", "path": "", "body": ""}
	var split_idx: int = raw.find("\r\n\r\n")
	var header_block: String = raw if split_idx < 0 else raw.substr(0, split_idx)
	var body: String = "" if split_idx < 0 else raw.substr(split_idx + 4)
	var lines: PackedStringArray = header_block.split("\r\n")
	if lines.size() > 0:
		var parts: PackedStringArray = lines[0].split(" ")
		if parts.size() >= 2:
			out["method"] = parts[0]
			var full_path: String = parts[1]
			# strip query string
			var q: int = full_path.find("?")
			out["path"] = full_path if q < 0 else full_path.substr(0, q)
	out["body"] = body
	return out


func _route(method: String, path: String, body: String, client_ip: String) -> Dictionary:
	if path == "/health":
		return {"code": 200, "json": {"ok": true, "count": _lobbies.size()}}
	if path == "/list":
		return {"code": 200, "json": {"ok": true, "lobbies": _joinable_list()}}
	if path == "/register":
		return _do_register(body, client_ip)
	if path == "/heartbeat":
		return _do_heartbeat(body)
	if path == "/end":
		return _do_end(body)
	return {"code": 404, "json": {"ok": false, "error": "not_found"}}


func _do_register(body: String, client_ip: String) -> Dictionary:
	var data: Dictionary = _parse_json(body)
	if data.is_empty():
		return {"code": 400, "json": {"ok": false, "error": "bad_json"}}
	var id: String = "L%d" % _next_id
	_next_id += 1
	var host_ip: String = str(data.get("host_ip", "")).strip_edges()
	if host_ip == "":
		host_ip = client_ip
	_lobbies[id] = {
		"id": id,
		"name": str(data.get("name", "Game")),
		"host_ip": host_ip,
		"port": int(data.get("port", 8642)),
		"players": int(data.get("players", 1)),
		"max_players": int(data.get("max_players", 8)),
		"started": false,
		"last_seen": _now(),
	}
	print("[lobby_server] register %s  %s:%d  '%s'" % [id, host_ip, int(_lobbies[id]["port"]), str(_lobbies[id]["name"])])
	return {"code": 200, "json": {"ok": true, "id": id}}


func _do_heartbeat(body: String) -> Dictionary:
	var data: Dictionary = _parse_json(body)
	var id: String = str(data.get("id", ""))
	if id == "" or not _lobbies.has(id):
		# Host should re-register (e.g. after a server restart).
		return {"code": 200, "json": {"ok": false, "stale": true}}
	var lobby: Dictionary = _lobbies[id]
	lobby["players"] = int(data.get("players", lobby.get("players", 1)))
	lobby["started"] = bool(data.get("started", lobby.get("started", false)))
	lobby["last_seen"] = _now()
	_lobbies[id] = lobby
	return {"code": 200, "json": {"ok": true}}


func _do_end(body: String) -> Dictionary:
	var data: Dictionary = _parse_json(body)
	var id: String = str(data.get("id", ""))
	if id != "" and _lobbies.has(id):
		_lobbies.erase(id)
		print("[lobby_server] end %s" % id)
	return {"code": 200, "json": {"ok": true}}


func _joinable_list() -> Array:
	var out: Array = []
	for id in _lobbies.keys():
		var lobby: Dictionary = _lobbies[id]
		if bool(lobby.get("started", false)):
			continue
		if int(lobby.get("players", 0)) >= int(lobby.get("max_players", 8)):
			continue
		out.append({
			"id": lobby["id"],
			"name": lobby["name"],
			"host_ip": lobby["host_ip"],
			"port": lobby["port"],
			"players": lobby["players"],
			"max_players": lobby["max_players"],
		})
	return out


# ---- helpers ----

func _parse_json(body: String) -> Dictionary:
	if body.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(body)
	if parsed == null or not (parsed is Dictionary):
		return {}
	return parsed


func _write_json(conn: StreamPeerTCP, code: int, payload: Dictionary) -> void:
	var body: String = JSON.stringify(payload)
	var body_bytes: PackedByteArray = body.to_utf8_buffer()
	var status_text: String = _status_text(code)
	var head: String = "HTTP/1.1 %d %s\r\n" % [code, status_text]
	head += "Content-Type: application/json\r\n"
	head += "Content-Length: %d\r\n" % body_bytes.size()
	head += "Access-Control-Allow-Origin: *\r\n"
	head += "Connection: close\r\n\r\n"
	conn.put_data(head.to_utf8_buffer())
	conn.put_data(body_bytes)


func _status_text(code: int) -> String:
	match code:
		200:
			return "OK"
		400:
			return "Bad Request"
		404:
			return "Not Found"
		_:
			return "OK"


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
