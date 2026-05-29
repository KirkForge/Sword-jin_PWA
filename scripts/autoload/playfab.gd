extends Node
## PlayFab — Online leaderboard integration via PlayFab REST API
## v0.86 — LoginWithCustomID, UpdatePlayerStatistics, GetLeaderboard
##
## Setup:
##   1. Create a title at https://developer.playfab.com
##   2. Set PLAYFAB_TITLE_ID below (or in project metadata)
##   3. Create a statistic named "ChapterTime" in PlayFab dashboard
##   4. Free tier: up to 100K MAU

signal login_succeeded(session_ticket: String, playfab_id: String)
signal login_failed(error: String)
signal score_submitted(chapter_id: String, time: float)
signal score_submit_failed(chapter_id: String, error: String)
signal leaderboard_received(chapter_id: String, entries: Array)
signal leaderboard_failed(chapter_id: String, error: String)

# ─── Config ──────────────────────────────────────────────────────────────────
# Set your PlayFab Title ID here or via project settings
var TITLE_ID := ""  # e.g. "ABC12"
const API_BASE := "https://titleId.playfabapi.com/Client"
const STATISTIC_NAME := "ChapterTime"

# ─── State ───────────────────────────────────────────────────────────────────
var session_ticket := ""
var playfab_id := ""
var custom_id := ""
var is_logged_in := false
var _pending_submits: Array = []  # Queue scores before login completes

# ─── HTTP ────────────────────────────────────────────────────────────────────
var _http: HTTPRequest

func _ready():
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	
	# Load saved custom ID or generate one
	custom_id = _load_or_create_custom_id()
	
	# Try auto-login if title ID is set
	if TITLE_ID != "":
		login()

# ─── Public API ──────────────────────────────────────────────────────────────

func is_configured() -> bool:
	"""Check if PlayFab is configured with a title ID."""
	return TITLE_ID != ""

func login(custom_id_override: String = ""):
	"""Login with a custom ID (anonymous, no password)."""
	if TITLE_ID == "":
		login_failed.emit("PlayFab title ID not set")
		return
	
	if custom_id_override != "":
		custom_id = custom_id_override
	
	var body := {
		"TitleId": TITLE_ID,
		"CustomId": custom_id,
		"CreateAccount": true,
	}
	
	_send_request("/LoginWithCustomID", body, "_handle_login")

func submit_chapter_time(chapter_id: String, completion_time: float):
	"""Submit a chapter completion time to the leaderboard."""
	if not is_logged_in:
		_pending_submits.append({"chapter_id": chapter_id, "time": completion_time})
		if not is_configured():
			return  # Silently skip if not configured
		if not is_logged_in:
			login()  # Try login to flush queue
		return
	
	# Statistic format: "ch001_time" → value in centiseconds for precision
	var stat_key := chapter_id.replace("act0", "a").replace("_ch0", "c").replace("_ch", "c")
	
	var body := {
		"Statistics": [
			{
				"StatisticName": STATISTIC_NAME,
				"Value": int(completion_time * 100),  # Centiseconds
			}
		],
		"CustomTags": {
			"chapter": chapter_id,
		}
	}
	
	_send_request("/UpdatePlayerStatistics", body, "_handle_submit", {"chapter_id": chapter_id, "time": completion_time})

func get_leaderboard(chapter_id: String, max_results: int = 10):
	"""Fetch the leaderboard for a chapter. Lower time = better rank."""
	if not is_logged_in:
		leaderboard_failed.emit(chapter_id, "Not logged in")
		return
	
	var body := {
		"StatisticName": STATISTIC_NAME,
		"MaxResultsCount": max_results,
	}
	
	_send_request("/GetLeaderboard", body, "_handle_leaderboard", {"chapter_id": chapter_id})

func get_leaderboard_around_player(chapter_id: String, max_results: int = 10):
	"""Fetch the leaderboard centered on the current player."""
	if not is_logged_in:
		leaderboard_failed.emit(chapter_id, "Not logged in")
		return
	
	var body := {
		"StatisticName": STATISTIC_NAME,
		"MaxResultsCount": max_results,
		"PlayFabId": playfab_id,
	}
	
	_send_request("/GetLeaderboardAroundPlayer", body, "_handle_leaderboard", {"chapter_id": chapter_id})

# ─── HTTP Layer ──────────────────────────────────────────────────────────────

var _request_queue: Array = []
var _is_requesting := false
var _current_callback := ""
var _current_context: Dictionary = {}

func _send_request(endpoint: String, body: Dictionary, callback: String, context: Dictionary = {}):
	var url := API_BASE.replace("titleId", TITLE_ID) + endpoint
	var headers := ["Content-Type: application/json"]
	
	if session_ticket != "":
		headers.append("X-Authorization: " + session_ticket)
	
	var json_body := JSON.stringify(body)
	
	_request_queue.append({
		"url": url,
		"headers": headers,
		"body": json_body,
		"callback": callback,
		"context": context,
	})
	
	_process_queue()

func _process_queue():
	if _is_requesting or _request_queue.is_empty():
		return
	
	_is_requesting = true
	var req = _request_queue.pop_front()
	_current_callback = req.callback
	_current_context = req.context
	
	var err = _http.request(req.url, req.headers, HTTPClient.METHOD_POST, req.body)
	if err != OK:
		push_error("[PlayFab] HTTP request failed: %d" % err)
		_is_requesting = false
		_process_queue()

func _on_request_completed(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray):
	_is_requesting = false
	
	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	
	if parse_err != OK:
		push_error("[PlayFab] JSON parse error")
		_process_queue()
		return
	
	var data: Dictionary = json.data
	var status: int = data.get("code", 500)
	
	# Call the appropriate handler
	if _current_callback == "_handle_login":
		_handle_login(data, status)
	elif _current_callback == "_handle_submit":
		_handle_submit(data, status, _current_context)
	elif _current_callback == "_handle_leaderboard":
		_handle_leaderboard(data, status, _current_context)
	
	_process_queue()

# ─── Handlers ────────────────────────────────────────────────────────────────

func _handle_login(data: Dictionary, status: int):
	if status == 200:
		var result: Dictionary = data.get("data", {})
		session_ticket = result.get("SessionTicket", "")
		playfab_id = result.get("PlayFabId", "")
		is_logged_in = session_ticket != ""
		
		print("[PlayFab] Logged in! ID: %s" % playfab_id)
		login_succeeded.emit(session_ticket, playfab_id)
		
		# Flush pending score submissions
		while not _pending_submits.is_empty():
			var pending = _pending_submits.pop_front()
			submit_chapter_time(pending.chapter_id, pending.time)
	else:
		var error: String = data.get("errorMessage", "Unknown error")
		push_error("[PlayFab] Login failed: %s" % error)
		login_failed.emit(error)

func _handle_submit(data: Dictionary, status: int, context: Dictionary):
	var chapter_id: String = context.get("chapter_id", "")
	var time: float = context.get("time", 0.0)
	
	if status == 200:
		print("[PlayFab] Score submitted for %s: %.2fs" % [chapter_id, time])
		score_submitted.emit(chapter_id, time)
	else:
		var error: String = data.get("errorMessage", "Unknown error")
		push_error("[PlayFab] Score submit failed for %s: %s" % [chapter_id, error])
		score_submit_failed.emit(chapter_id, error)

func _handle_leaderboard(data: Dictionary, status: int, context: Dictionary):
	var chapter_id: String = context.get("chapter_id", "")
	
	if status == 200:
		var result: Dictionary = data.get("data", {})
		var raw_entries: Array = result.get("Leaderboard", [])
		
		var entries: Array = []
		for entry in raw_entries:
			entries.append({
				"rank": entry.get("Position", 0) + 1,  # 1-indexed
				"name": entry.get("DisplayName", entry.get("PlayFabId", "???").left(8)),
				"time": float(entry.get("StatValue", 0)) / 100.0,  # Centiseconds → seconds
				"is_self": entry.get("PlayFabId", "") == playfab_id,
			})
		
		leaderboard_received.emit(chapter_id, entries)
	else:
		var error: String = data.get("errorMessage", "Unknown error")
		push_error("[PlayFab] Leaderboard failed for %s: %s" % [chapter_id, error])
		leaderboard_failed.emit(chapter_id, error)

# ─── Persistence ─────────────────────────────────────────────────────────────

const SAVE_PATH := "user://playfab_state.json"

func _load_or_create_custom_id() -> String:
	"""Load or generate a persistent custom ID for this device."""
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				var data: Dictionary = json.data
				var saved_id: String = data.get("custom_id", "")
				var saved_title: String = data.get("title_id", "")
				if saved_title != "" and TITLE_ID == "":
					TITLE_ID = saved_title
				if saved_id != "":
					return saved_id
	
	# Generate a new custom ID
	var new_id := "swordjin_%s_%s" % [
		OS.get_unique_id().left(16) if OS.get_unique_id() != "" else str(randi()),
		Time.get_unix_time_from_system()
	]
	_save_state(new_id)
	return new_id

func _save_state(id: String = ""):
	"""Save PlayFab state to disk."""
	var data := {
		"custom_id": id if id != "" else custom_id,
		"title_id": TITLE_ID,
		"playfab_id": playfab_id,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func set_title_id(title_id: String):
	"""Set the PlayFab title ID and attempt login."""
	TITLE_ID = title_id
	_save_state()
	login()