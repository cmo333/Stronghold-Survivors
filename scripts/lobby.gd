extends Control

# FFA lobby. Host creates a session; clients join by IP. Shows the roster and a
# 2-minute fill countdown (host-owned). At zero (or when the host presses START
# NOW), the host fills empty slots with bots and launches everyone into the
# match scene. Solo play never reaches this screen.
#
# Styling intentionally lightweight (flat boxes) to avoid coupling to
# main_menu's asset pipeline; the gothic theme can be layered on later.

const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

const FONT_PIXEL := "res://assets/ui/pixel_font.ttf"
const COLOR_BG := Color(0.05, 0.04, 0.09, 1.0)
const COLOR_TEXT := Color(0.88, 0.86, 0.92)
const COLOR_ACCENT := Color(0.45, 0.95, 1.0)
const COLOR_TITLE := Color(1.0, 0.85, 0.35)
const COLOR_DIM := Color(0.62, 0.60, 0.70)

var _font: FontFile = null
var _roster_box: VBoxContainer = null
var _status_label: Label = null
var _countdown_label: Label = null
var _connect_panel: VBoxContainer = null
var _lobby_panel: VBoxContainer = null
var _browse_panel: VBoxContainer = null
var _browse_list_box: VBoxContainer = null
var _ip_edit: LineEdit = null
var _start_button: Button = null

# Host advertise / join-string UI.
var _join_string_label: Label = null
var _join_hint_label: Label = null
var _ip_http: HTTPRequest = null
var _public_ip: String = ""
var _upnp_opened: bool = false

# Lobby-browser polling.
var _poll_timer: Timer = null

var _countdown_active: bool = false
var _countdown_left: float = 0.0
var _last_announced: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_right = 1.0
	anchor_bottom = 1.0
	_font = _load_font()
	_build_background()
	_build_layout()
	_connect_net_signals()
	_show_connect_ui()
	_maybe_autostart_from_cmdline()

func _process(delta: float) -> void:
	if not _countdown_active:
		return
	# Host owns the authoritative countdown.
	if not Net.is_host:
		return
	_countdown_left = max(0.0, _countdown_left - delta)
	var secs := int(ceil(_countdown_left))
	if secs != _last_announced:
		_last_announced = secs
		Net.lobby_countdown.emit(secs)
		_rpc_countdown.rpc(secs)
		_update_countdown_label(secs)
	if _countdown_left <= 0.0:
		_countdown_active = false
		_launch_match()

# ---- Net wiring ----

func _connect_net_signals() -> void:
	Net.roster_changed.connect(_refresh_roster)
	Net.match_starting.connect(_on_match_starting)
	Net.connection_failed_signal.connect(_on_connection_failed)
	Net.server_disconnected_signal.connect(_on_server_disconnected)
	var ll := get_node_or_null("/root/LobbyList")
	if ll != null:
		ll.list_received.connect(_on_list_received)
		ll.list_failed.connect(_on_list_failed)
	# Steam matchmaking (no-ops when GodotSteam is absent — Steamworks is a safe stub).
	var sw := get_node_or_null("/root/Steamworks")
	if sw != null:
		if sw.has_signal("lobby_list"):
			sw.lobby_list.connect(_on_steam_lobby_list)
		if sw.has_signal("lobby_join_requested"):
			sw.lobby_join_requested.connect(_on_steam_join_requested)

# True when Steam transport is usable; gates the Steam vs ENet/IP UI paths.
func _using_steam() -> bool:
	return Net.has_method("steam_available") and Net.steam_available()

@rpc("authority", "call_remote", "reliable")
func _rpc_countdown(secs: int) -> void:
	# Clients display the host's countdown.
	_update_countdown_label(secs)

func _on_match_starting(_roster: Array, _seed: int) -> void:
	_stop_polling()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_connection_failed() -> void:
	_stop_polling()
	_set_status("Connection failed. Host may need to forward UDP %d." % Net.DEFAULT_PORT, true)
	_show_connect_ui()

func _on_server_disconnected() -> void:
	_stop_polling()
	_set_status("Host disconnected.", true)
	_show_connect_ui()

# ---- Actions ----

func _on_host_pressed() -> void:
	# Prefer Steam P2P (no port-forwarding) when the plugin is available; otherwise host
	# over direct-IP ENet and advertise via UPnP / public-IP / HTTP lobby list.
	if _using_steam():
		if Net.create_host_steam():
			_set_status("Hosting via Steam. Invite friends or wait for players...", false)
			_show_lobby_ui(true)
			_start_countdown()
			if _join_string_label != null:
				_set_join_string("Steam lobby — friends can Join via the Steam overlay")
			if _join_hint_label != null:
				_join_hint_label.text = "No port-forwarding needed. Others can also pick you from Browse."
			return
		_set_status("Steam host failed; falling back to direct IP.", true)
	if Net.create_host():
		_set_status("Hosting. Waiting for players...", false)
		_show_lobby_ui(true)
		_start_countdown()
		_begin_advertise()
	else:
		_set_status("Failed to host (port in use?).", true)

func _on_join_pressed() -> void:
	# In Steam mode there is no IP to type — players join via Browse or a Steam invite.
	if _using_steam():
		_set_status("Use Browse to pick a Steam lobby, or accept a Steam invite.", false)
		_on_browse_pressed()
		return
	var hp := _parse_host_port(_ip_edit.text)
	var ip: String = hp["ip"]
	var port: int = hp["port"]
	if Net.join(ip, port):
		_set_status("Connecting to %s:%d..." % [ip, port], false)
		_show_lobby_ui(false)
	else:
		_set_status("Failed to start client.", true)

# Parse "host" or "host:port" (split on the LAST colon so IPv4 is safe). Empty
# input falls back to localhost. An invalid port falls back to the default.
func _parse_host_port(raw: String) -> Dictionary:
	var s := raw.strip_edges()
	if s == "":
		return {"ip": "127.0.0.1", "port": int(Net.DEFAULT_PORT)}
	var port: int = int(Net.DEFAULT_PORT)
	var ip: String = s
	var colon := s.rfind(":")
	if colon > 0:
		var port_str := s.substr(colon + 1).strip_edges()
		if port_str.is_valid_int():
			port = int(port_str)
			ip = s.substr(0, colon).strip_edges()
	return {"ip": ip, "port": port}

func _on_start_now_pressed() -> void:
	if Net.is_host:
		_countdown_active = false
		_launch_match()

func _on_back_pressed() -> void:
	Net.shutdown()
	get_tree().change_scene_to_file(MENU_SCENE)

func _start_countdown() -> void:
	_countdown_left = float(Net.LOBBY_FILL_SECONDS)
	_countdown_active = true
	_last_announced = -1

func _launch_match() -> void:
	if Net.is_host:
		# Flag the lobby as in-progress so it stops appearing in the browser.
		var ll := get_node_or_null("/root/LobbyList")
		if ll != null and ll.has_method("send_heartbeat"):
			ll.send_heartbeat(Net.real_player_count(), true)
		# Same for the Steam lobby browser (best-effort; no-op without Steam).
		if Net.transport == Net.Transport.STEAM and Net.steam_lobby_id != 0:
			var sw := get_node_or_null("/root/Steamworks")
			if sw != null and sw.has_method("set_lobby_data"):
				sw.set_lobby_data(Net.steam_lobby_id, "started", "1")
		Net.host_launch_match()

# ---- Host advertise (public IP + UPnP + lobby registration) ----

func _begin_advertise() -> void:
	_public_ip = ""
	_upnp_opened = false
	_set_join_string("detecting public IP...")
	# Try UPnP off the main thread (discover() blocks ~1-2s).
	WorkerThreadPool.add_task(_upnp_task)
	# Fetch public IP via HTTP as the reliable fallback / primary if no UPnP.
	if _ip_http != null:
		_ip_http.cancel_request()
		var err := _ip_http.request("https://api.ipify.org")
		if err != OK:
			_set_join_string("(could not detect public IP)")
	# Register with the optional lobby browser so others can find this game.
	var ll := get_node_or_null("/root/LobbyList")
	if ll != null and ll.has_method("is_configured") and ll.is_configured():
		ll.register_host("FFA Game", int(Net.DEFAULT_PORT), int(Net.MAX_PLAYERS), Net.real_player_count())
		if ll.has_method("start_heartbeat"):
			ll.start_heartbeat(Callable(Net, "real_player_count"))

# Runs on a worker thread; marshals results back via call_deferred.
func _upnp_task() -> void:
	var upnp := UPNP.new()
	var ext_ip: String = ""
	var opened: bool = false
	if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS:
		var gw := upnp.get_gateway()
		if gw != null and gw.is_valid_gateway():
			var res := upnp.add_port_mapping(int(Net.DEFAULT_PORT), int(Net.DEFAULT_PORT), "StrongholdSurvivors", "UDP", 0)
			opened = (res == UPNP.UPNP_RESULT_SUCCESS)
			var queried: String = upnp.query_external_address()
			if queried != "":
				ext_ip = queried
	call_deferred("_on_upnp_done", opened, ext_ip)

func _on_upnp_done(opened: bool, ext_ip: String) -> void:
	_upnp_opened = opened
	if ext_ip != "":
		# UPnP's external address is the most reliable; prefer it.
		_public_ip = ext_ip
		_set_join_string("%s:%d" % [_public_ip, int(Net.DEFAULT_PORT)])
	_update_join_hint()

func _on_ip_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_update_join_hint()
		return
	var ip := body.get_string_from_utf8().strip_edges()
	if ip != "" and _public_ip == "":
		_public_ip = ip
		_set_join_string("%s:%d" % [_public_ip, int(Net.DEFAULT_PORT)])
	_update_join_hint()

func _set_join_string(text: String) -> void:
	if _join_string_label != null:
		_join_string_label.text = text

func _update_join_hint() -> void:
	if _join_hint_label == null:
		return
	if _upnp_opened:
		_join_hint_label.text = "UPnP opened the port automatically. Share the code above."
	elif _public_ip != "":
		_join_hint_label.text = "Share the code. Host must allow/forward UDP %d on their router." % int(Net.DEFAULT_PORT)
	else:
		_join_hint_label.text = "Could not detect public IP. Use your IP + forward UDP %d." % int(Net.DEFAULT_PORT)

func _on_copy_pressed() -> void:
	if _join_string_label != null:
		DisplayServer.clipboard_set(_join_string_label.text)
		_set_status("Join code copied to clipboard.", false)

# ---- Lobby browser ----

func _on_browse_pressed() -> void:
	# Steam path: list public Steam lobbies for this game (no extra server needed).
	if _using_steam():
		_show_browse_ui()
		_set_status("Searching for Steam games...", false)
		var sw := get_node_or_null("/root/Steamworks")
		if sw != null and sw.has_method("request_lobby_list"):
			sw.request_lobby_list()
		return
	# Fallback path: optional HTTP lobby registry.
	var ll := get_node_or_null("/root/LobbyList")
	if ll == null or not ll.has_method("is_configured") or not ll.is_configured():
		_set_status("Lobby browser not configured. Use a join code instead.", true)
		return
	_show_browse_ui()
	_start_polling()
	ll.fetch_list()

func _start_polling() -> void:
	if _poll_timer != null and _poll_timer.is_stopped():
		_poll_timer.start()

func _stop_polling() -> void:
	if _poll_timer != null and not _poll_timer.is_stopped():
		_poll_timer.stop()

func _on_poll_tick() -> void:
	var ll := get_node_or_null("/root/LobbyList")
	if ll != null and ll.has_method("fetch_list"):
		ll.fetch_list()

func _on_refresh_pressed() -> void:
	var ll := get_node_or_null("/root/LobbyList")
	if ll != null and ll.has_method("fetch_list"):
		ll.fetch_list()

func _on_browse_back_pressed() -> void:
	_stop_polling()
	_show_connect_ui()

func _on_list_received(lobbies: Array) -> void:
	if _browse_list_box == null:
		return
	for c in _browse_list_box.get_children():
		c.queue_free()
	if lobbies.is_empty():
		var empty := Label.new()
		empty.text = "No open games. Host one!"
		_apply_font(empty, 12, COLOR_DIM)
		_browse_list_box.add_child(empty)
		return
	for entry in lobbies:
		_browse_list_box.add_child(_make_lobby_row(entry))

func _on_list_failed(reason: String) -> void:
	_set_status(reason, true)

func _make_lobby_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ip: String = str(entry.get("host_ip", "?"))
	var port: int = int(entry.get("port", Net.DEFAULT_PORT))
	var players: int = int(entry.get("players", 0))
	var max_players: int = int(entry.get("max_players", 8))
	var lbl := Label.new()
	lbl.text = "%s   %d/%d   %s:%d" % [str(entry.get("name", "Game")), players, max_players, ip, port]
	_apply_font(lbl, 12, COLOR_TEXT)
	lbl.custom_minimum_size = Vector2(360, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var join_btn := _make_button("JOIN", _on_list_join.bind(ip, port))
	join_btn.custom_minimum_size = Vector2(120, 40)
	row.add_child(join_btn)
	return row

func _on_list_join(ip: String, port: int) -> void:
	_stop_polling()
	if Net.join(ip, port):
		_set_status("Connecting to %s:%d..." % [ip, port], false)
		_show_lobby_ui(false)
	else:
		_set_status("Failed to start client.", true)

# ---- Steam matchmaking handlers ----

# Steam returned the list of public lobbies for this game; render each as a Join row.
func _on_steam_lobby_list(lobby_ids: Array) -> void:
	if _browse_list_box == null:
		return
	for c in _browse_list_box.get_children():
		c.queue_free()
	var sw := get_node_or_null("/root/Steamworks")
	var rows := 0
	for raw_id in lobby_ids:
		var lid := int(raw_id)
		# Skip lobbies that already launched.
		if sw != null and str(sw.get_lobby_data(lid, "started")) == "1":
			continue
		_browse_list_box.add_child(_make_steam_lobby_row(lid, sw))
		rows += 1
	if rows == 0:
		var empty := Label.new()
		empty.text = "No open Steam games. Host one!"
		_apply_font(empty, 12, COLOR_DIM)
		_browse_list_box.add_child(empty)
	_set_status("Found %d Steam game(s)." % rows, false)

func _make_steam_lobby_row(lobby_id: int, sw: Node) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lobby_name := "Steam Game"
	var players := 0
	if sw != null:
		var nm := str(sw.get_lobby_data(lobby_id, "name"))
		if nm != "":
			lobby_name = nm
		players = int(sw.get_lobby_member_count(lobby_id))
	var lbl := Label.new()
	lbl.text = "%s   %d/%d   (Steam)" % [lobby_name, players, int(Net.MAX_PLAYERS)]
	_apply_font(lbl, 12, COLOR_TEXT)
	lbl.custom_minimum_size = Vector2(360, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var join_btn := _make_button("JOIN", _on_steam_list_join.bind(lobby_id))
	join_btn.custom_minimum_size = Vector2(120, 40)
	row.add_child(join_btn)
	return row

func _on_steam_list_join(lobby_id: int) -> void:
	_stop_polling()
	if Net.join_steam(lobby_id):
		_set_status("Joining Steam game...", false)
		_show_lobby_ui(false)
	else:
		_set_status("Failed to join Steam game.", true)

# Steam overlay "Join Game" / accepted invite — route straight into the lobby.
func _on_steam_join_requested(lobby_id: int) -> void:
	if Net.join_steam(lobby_id):
		_set_status("Joining Steam game (invite)...", false)
		_show_lobby_ui(false)

# ---- UI construction ----

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_layout() -> void:
	var title := Label.new()
	title.text = "FREE-FOR-ALL  (PROTOTYPE)"
	_apply_font(title, 22, COLOR_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -360.0
	title.offset_right = 360.0
	title.offset_top = 40.0
	add_child(title)

	var center := CenterContainer.new()
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -300.0
	center.offset_top = -180.0
	center.offset_right = 300.0
	center.offset_bottom = 220.0
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.custom_minimum_size = Vector2(540, 0)
	center.add_child(root)

	# Connect panel (host / join).
	_connect_panel = VBoxContainer.new()
	_connect_panel.add_theme_constant_override("separation", 12)
	root.add_child(_connect_panel)

	_connect_panel.add_child(_make_button("HOST GAME", _on_host_pressed))
	_connect_panel.add_child(_make_button("BROWSE GAMES", _on_browse_pressed))

	var join_hint := Label.new()
	join_hint.text = "Or paste a friend's join code (host:port):"
	_apply_font(join_hint, 11, COLOR_DIM)
	_connect_panel.add_child(join_hint)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "1.2.3.4:8642"
	_ip_edit.custom_minimum_size = Vector2(280, 44)
	_apply_font(_ip_edit, 14, COLOR_TEXT)
	join_row.add_child(_ip_edit)
	var join_btn := _make_button("JOIN", _on_join_pressed)
	join_btn.custom_minimum_size = Vector2(140, 44)
	join_row.add_child(join_btn)
	_connect_panel.add_child(join_row)

	_connect_panel.add_child(_make_button("BACK", _on_back_pressed))

	# Lobby panel (roster + countdown + controls).
	_lobby_panel = VBoxContainer.new()
	_lobby_panel.add_theme_constant_override("separation", 10)
	root.add_child(_lobby_panel)

	# Host-only "join code" advert: a copyable host:port string + connectivity hint.
	var code_title := Label.new()
	code_title.text = "YOUR JOIN CODE"
	_apply_font(code_title, 13, COLOR_ACCENT)
	_lobby_panel.add_child(code_title)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	_join_string_label = Label.new()
	_join_string_label.text = ""
	_apply_font(_join_string_label, 14, COLOR_TITLE)
	_join_string_label.custom_minimum_size = Vector2(360, 0)
	_join_string_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	code_row.add_child(_join_string_label)
	var copy_btn := _make_button("COPY", _on_copy_pressed)
	copy_btn.custom_minimum_size = Vector2(120, 40)
	code_row.add_child(copy_btn)
	_lobby_panel.add_child(code_row)

	_join_hint_label = Label.new()
	_join_hint_label.text = ""
	_apply_font(_join_hint_label, 10, COLOR_DIM)
	_join_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_join_hint_label.custom_minimum_size = Vector2(500, 0)
	_lobby_panel.add_child(_join_hint_label)

	var roster_title := Label.new()
	roster_title.text = "PLAYERS"
	_apply_font(roster_title, 14, COLOR_ACCENT)
	_lobby_panel.add_child(roster_title)

	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 4)
	_roster_box.custom_minimum_size = Vector2(0, 200)
	_lobby_panel.add_child(_roster_box)

	_countdown_label = Label.new()
	_apply_font(_countdown_label, 16, COLOR_TITLE)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_panel.add_child(_countdown_label)

	_start_button = _make_button("START NOW", _on_start_now_pressed)
	_lobby_panel.add_child(_start_button)
	_lobby_panel.add_child(_make_button("LEAVE", _on_back_pressed))

	# Browse panel (live list of open lobbies).
	_browse_panel = VBoxContainer.new()
	_browse_panel.add_theme_constant_override("separation", 10)
	root.add_child(_browse_panel)

	var browse_title := Label.new()
	browse_title.text = "OPEN LOBBIES"
	_apply_font(browse_title, 14, COLOR_ACCENT)
	_browse_panel.add_child(browse_title)

	_browse_list_box = VBoxContainer.new()
	_browse_list_box.add_theme_constant_override("separation", 6)
	_browse_list_box.custom_minimum_size = Vector2(0, 220)
	_browse_panel.add_child(_browse_list_box)

	var browse_buttons := HBoxContainer.new()
	browse_buttons.add_theme_constant_override("separation", 8)
	var refresh_btn := _make_button("REFRESH", _on_refresh_pressed)
	refresh_btn.custom_minimum_size = Vector2(200, 44)
	browse_buttons.add_child(refresh_btn)
	var browse_back := _make_button("BACK", _on_browse_back_pressed)
	browse_back.custom_minimum_size = Vector2(200, 44)
	browse_buttons.add_child(browse_back)
	_browse_panel.add_child(browse_buttons)

	# Status line.
	_status_label = Label.new()
	_apply_font(_status_label, 11, COLOR_DIM)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)

	# Public-IP fetch (host advertise) + lobby-browser poll timer.
	_ip_http = HTTPRequest.new()
	_ip_http.timeout = 6.0
	add_child(_ip_http)
	_ip_http.request_completed.connect(_on_ip_request_completed)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = 5.0
	_poll_timer.one_shot = false
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_tick)

func _show_connect_ui() -> void:
	if _connect_panel != null:
		_connect_panel.visible = true
	if _lobby_panel != null:
		_lobby_panel.visible = false
	if _browse_panel != null:
		_browse_panel.visible = false

func _show_browse_ui() -> void:
	if _connect_panel != null:
		_connect_panel.visible = false
	if _lobby_panel != null:
		_lobby_panel.visible = false
	if _browse_panel != null:
		_browse_panel.visible = true

func _show_lobby_ui(host: bool) -> void:
	if _connect_panel != null:
		_connect_panel.visible = false
	if _lobby_panel != null:
		_lobby_panel.visible = true
	if _browse_panel != null:
		_browse_panel.visible = false
	if _start_button != null:
		_start_button.visible = host
	# The join-code advert only makes sense for the host.
	_set_join_code_visible(host)
	_refresh_roster()

func _set_join_code_visible(host: bool) -> void:
	if _join_string_label != null:
		_join_string_label.get_parent().visible = host
	if _join_hint_label != null:
		_join_hint_label.visible = host

func _refresh_roster() -> void:
	if _roster_box == null:
		return
	for c in _roster_box.get_children():
		c.queue_free()
	for id in Net.get_player_ids():
		var p: Dictionary = Net.lobby_players[id]
		var lbl := Label.new()
		var tag := "  [BOT]" if p["is_bot"] else ""
		var you := "  (you)" if id == Net.local_peer_id else ""
		lbl.text = "Slot %d:  %s%s%s" % [int(p["slot"]) + 1, p["name"], tag, you]
		_apply_font(lbl, 12, COLOR_TEXT)
		_roster_box.add_child(lbl)

func _update_countdown_label(secs: int) -> void:
	if _countdown_label == null:
		return
	_countdown_label.text = "Launching in %d:%02d" % [secs / 60, secs % 60]

func _set_status(msg: String, is_error: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = msg
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5) if is_error else COLOR_DIM)

# ---- Headless / CLI test support ----
# godot --path <proj> -- --ffa-host
# godot --path <proj> -- --ffa-join 127.0.0.1
func _maybe_autostart_from_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	# Steam cold-launch: Steam passes `+connect_lobby <id>` (overlay invite / "Join Game"
	# from a desktop shortcut). Steam puts these in the *regular* cmdline, not user args.
	var raw := OS.get_cmdline_args()
	if raw.has("+connect_lobby"):
		var ci := raw.find("+connect_lobby")
		if ci >= 0 and ci + 1 < raw.size():
			var clid := int(raw[ci + 1])
			if clid != 0 and Net.has_method("join_steam"):
				call_deferred("_steam_cold_join", clid)
				return
	# Steam test hooks (parallel to the ENet --ffa-* helpers above).
	if args.has("--steam-host"):
		call_deferred("_on_host_pressed")
		if args.has("--ffa-now"):
			get_tree().create_timer(6.0).timeout.connect(_on_start_now_pressed)
		return
	elif args.has("--steam-join"):
		var sidx := args.find("--steam-join")
		if sidx >= 0 and sidx + 1 < args.size():
			var slid := int(args[sidx + 1])
			if slid != 0 and Net.has_method("join_steam"):
				call_deferred("_steam_cold_join", slid)
		return
	if args.has("--ffa-host"):
		call_deferred("_on_host_pressed")
		# Test helper: launch quickly instead of waiting the full fill timer.
		if args.has("--ffa-now"):
			get_tree().create_timer(6.0).timeout.connect(_on_start_now_pressed)
	elif args.has("--ffa-join"):
		var idx := args.find("--ffa-join")
		var ip := "127.0.0.1"
		if idx >= 0 and idx + 1 < args.size():
			ip = args[idx + 1]
		_ip_edit.text = ip
		call_deferred("_on_join_pressed")
	elif args.has("--ffa-browse"):
		call_deferred("_on_browse_pressed")

# Deferred Steam join entry-point shared by overlay invites and cold-launch args.
func _steam_cold_join(lobby_id: int) -> void:
	if not Net.has_method("join_steam"):
		return
	_show_lobby_ui(false)
	_set_status("Joining Steam game…", false)
	Net.join_steam(lobby_id)

# ---- Style helpers ----

func _load_font() -> FontFile:
	if not ResourceLoader.exists(FONT_PIXEL):
		return null
	var f = load(FONT_PIXEL)
	return f if f is FontFile else null

func _apply_font(ctrl: Control, size: int, color: Color) -> void:
	if _font != null:
		ctrl.add_theme_font_override("font", _font)
	ctrl.add_theme_font_size_override("font_size", size)
	ctrl.add_theme_color_override("font_color", color)

func _make_button(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	_apply_font(btn, 14, COLOR_TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.12, 0.20, 0.95)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.pressed.connect(handler)
	return btn
