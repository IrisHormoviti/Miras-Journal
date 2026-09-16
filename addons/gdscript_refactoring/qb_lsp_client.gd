@tool
extends RefCounted

## Minimal LSP client for the GDScript Renamer plugin.
## Communicates with Godot's built-in GDScript language server (port 6005).
## Protocol: JSON-RPC 2.0 over TCP with Content-Length framing.

const LSP_PORT := 6005
const LSP_HOST := "127.0.0.1"

var _tcp:         StreamPeerTCP    = null
var _next_id:     int              = 1
var _recv_buf:    PackedByteArray  = PackedByteArray()
var _initialized: bool             = false
var _responses:   Dictionary       = {}  # id → result (null = error)
var _scene_tree:  SceneTree        = null


# -------------------------------------------------------------------------
# Connection lifecycle
# -------------------------------------------------------------------------

## Must pass the SceneTree so the client can await frames.
func setup(tree: SceneTree) -> void:
	_scene_tree = tree


func connect_to_lsp(root_uri: String) -> bool:
	_tcp = StreamPeerTCP.new()
	var err := _tcp.connect_to_host(LSP_HOST, LSP_PORT)
	if err != OK:
		push_error("LSP: connect_to_host failed (err=%d). Is Godot's LSP running on port %d?" % [err, LSP_PORT])
		return false


	# Poll until connected (non-blocking, yield between polls)
	var attempts := 0
	while attempts < 100:
		_tcp.poll()
		var status := _tcp.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			break
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			push_error("LSP: TCP error during connect (status=%d)" % status)
			return false
		await _scene_tree.process_frame
		attempts += 1

	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_error("LSP: timed out waiting for connection")
		return false


	# Send initialize request
	var init_id := _send_request("initialize", {
		"processId": OS.get_process_id(),
		"clientInfo": {"name": "GDScript Refactoring", "version": "1.0"},
		"capabilities": {
			"textDocument": {
				"rename": {"dynamicRegistration": false, "prepareSupport": false},
				"synchronization": {"dynamicRegistration": false}
			},
			"workspace": {
				"applyEdit": true,
				"workspaceEdit": {"documentChanges": false}
			}
		},
		"rootUri": root_uri
	})

	var result = await _wait_for_response(init_id, 5.0)
	if result == null:
		push_error("LSP: initialize timed out or failed")
		return false


	# Required handshake notification
	_send_notify("initialized", {})
	_initialized = true
	return true


func disconnect_from_lsp() -> void:
	if _tcp and _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_tcp.disconnect_from_host()
	_tcp         = null
	_initialized = false
	_responses.clear()
	_recv_buf.clear()


# -------------------------------------------------------------------------
# High-level API
# -------------------------------------------------------------------------

func did_open(file_uri: String, source: String, version: int = 1) -> void:
	_send_notify("textDocument/didOpen", {
		"textDocument": {
			"uri":        file_uri,
			"languageId": "gdscript",
			"version":    version,
			"text":       source
		}
	})


## Async variant of did_open: yields to the engine while the send buffer is
## full, so the OS network layer can actually flush the socket. Use this when
## streaming many files in a row (blocking sends deadlock or stall).
func did_open_async(file_uri: String, source: String, version: int = 1) -> void:
	await _send_msg_async({
		"jsonrpc": "2.0",
		"method": "textDocument/didOpen",
		"params": {
			"textDocument": {
				"uri":        file_uri,
				"languageId": "gdscript",
				"version":    version,
				"text":       source
			}
		}
	})


## Forces the server to replace the document content (full sync).
## IMPORTANT: the LSP protocol ignores didChange whose version is <= the
## last known version of the document — and the server state survives our
## TCP disconnects. Callers must supply a monotonically increasing version
## (e.g. Time.get_ticks_msec()) so the change is never silently dropped.
func did_change(file_uri: String, source: String, version: int) -> void:
	_send_notify("textDocument/didChange", {
		"textDocument": {
			"uri":     file_uri,
			"version": version
		},
		"contentChanges": [
			{"text": source}   # full-document sync (no range = replace all)
		]
	})


## Requests a rename at the given 0-based line/character position.
## Returns a WorkspaceEdit dict, or null on failure/timeout.
func rename(file_uri: String, line: int, character: int, new_name: String) -> Variant:
	if not _initialized:
		return null
	var req_id := _send_request("textDocument/rename", {
		"textDocument": {"uri": file_uri},
		"position":     {"line": line, "character": character},
		"newName":      new_name
	})
	return await _wait_for_response(req_id, 10.0)


## Requests every reference (usages) of the symbol at the given position.
## Returns an Array of Location dicts: [{ "uri":..., "range": {...} }, ...]
## (or null on failure). includeDeclaration keeps the declaration itself.
func references(file_uri: String, line: int, character: int,
		include_declaration: bool = true) -> Variant:
	if not _initialized:
		return null
	var req_id := _send_request("textDocument/references", {
		"textDocument": {"uri": file_uri},
		"position":     {"line": line, "character": character},
		"context":      {"includeDeclaration": include_declaration}
	})
	return await _wait_for_response(req_id, 10.0)


func did_close(file_uri: String) -> void:
	_send_notify("textDocument/didClose", {
		"textDocument": {"uri": file_uri}
	})


# -------------------------------------------------------------------------
# Apply WorkspaceEdit to files on disk  (static helper)
# -------------------------------------------------------------------------

static func apply_workspace_edit(edit: Dictionary) -> Dictionary:
	var results: Dictionary = {}

	var changes: Dictionary = {}
	if edit.has("changes"):
		changes = edit["changes"]
	elif edit.has("documentChanges"):
		for dc in edit["documentChanges"]:
			changes[dc["textDocument"]["uri"]] = dc["edits"]

	for uri in changes:
		var abs_path := uri_to_path(uri)
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f == null:
			push_warning("LSP apply: cannot open %s" % abs_path)
			continue
		var source := f.get_as_text()
		f.close()

		# Sort edits bottom-to-top so earlier positions stay valid
		var edits: Array = Array(changes[uri]).duplicate()
		edits.sort_custom(func(a, b):
			var al: int = a["range"]["start"]["line"]
			var bl: int = b["range"]["start"]["line"]
			if al != bl: return al > bl
			return a["range"]["start"]["character"] > b["range"]["start"]["character"]
		)

		var lines: Array = Array(source.split("\n"))

		for edit_item in edits:
			var sl: int = edit_item["range"]["start"]["line"]
			var sc: int = edit_item["range"]["start"]["character"]
			var el: int = edit_item["range"]["end"]["line"]
			var ec: int = edit_item["range"]["end"]["character"]
			var nt: String = edit_item["newText"]

			if sl == el:
				var ln: String = lines[sl]
				lines[sl] = ln.substr(0, sc) + nt + ln.substr(ec)
			else:
				var first: String = lines[sl].substr(0, sc) + nt
				var last:  String = lines[el].substr(ec)
				lines = lines.slice(0, sl) + [first + last] + lines.slice(el + 1)

		var new_source := "\n".join(PackedStringArray(lines))

		var out := FileAccess.open(abs_path, FileAccess.WRITE)
		if out:
			out.store_string(new_source)
			out.close()
			results[uri] = new_source
		else:
			push_warning("LSP apply: cannot write %s" % abs_path)

	return results


# -------------------------------------------------------------------------
# Transport
# -------------------------------------------------------------------------

func _send_request(method: String, params: Variant) -> int:
	var id := _next_id
	_next_id += 1
	_send_msg({"jsonrpc": "2.0", "id": id, "method": method, "params": params})
	return id


func _send_notify(method: String, params: Variant) -> void:
	_send_msg({"jsonrpc": "2.0", "method": method, "params": params})


func _send_msg(obj: Dictionary) -> void:
	if _tcp == null or _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_warning("LSP: tried to send but not connected")
		return
	var body       := JSON.stringify(obj)
	var body_bytes := body.to_utf8_buffer()
	# Content-Length MUST be byte count, not character count
	var frame := ("Content-Length: %d\r\n\r\n" % body_bytes.size()).to_utf8_buffer()
	frame.append_array(body_bytes)
	# Send with put_partial_data (non-blocking) rather than put_data (blocking).
	# When sending hundreds of files, the OS send buffer fills up; a blocking
	# put_data would then wait for the server to read, while the server may be
	# blocked trying to write its own replies into our full receive buffer — a
	# classic TCP deadlock (Godot sits at 0% CPU, frozen). By sending in chunks
	# and draining incoming data between chunks, both directions keep flowing.
	var offset := 0
	var total := frame.size()
	var guard := 0
	while offset < total:
		_tcp.poll()
		var chunk := frame.slice(offset, total)
		var res := _tcp.put_partial_data(chunk)
		if res[0] != OK:
			push_error("LSP: put_partial_data error %d" % res[0])
			return
		var written: int = res[1]
		offset += written
		if written == 0:
			# Send buffer full: drain incoming replies to unblock the server,
			# then pause briefly so the OS can flush the socket. A tiny delay
			# avoids a 100%-CPU busy loop while keeping both directions moving.
			_poll()
			OS.delay_msec(1)
			guard += 1
			if guard > 5000:
				push_error("LSP: send stalled, aborting frame")
				return
	# Keep the receive buffer drained after every send.
	_poll()


## Async send: like _send_msg but yields a frame (instead of a busy delay) when
## the OS send buffer is full, letting Godot's network layer flush the socket.
## This is what makes streaming hundreds of files fast and stall-free.
func _send_msg_async(obj: Dictionary) -> void:
	if _tcp == null or _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_warning("LSP: tried to send but not connected")
		return
	var body       := JSON.stringify(obj)
	var body_bytes := body.to_utf8_buffer()
	var frame := ("Content-Length: %d\r\n\r\n" % body_bytes.size()).to_utf8_buffer()
	frame.append_array(body_bytes)
	var offset := 0
	var total := frame.size()
	while offset < total:
		_tcp.poll()
		var chunk := frame.slice(offset, total)
		var res := _tcp.put_partial_data(chunk)
		if res[0] != OK:
			push_error("LSP: put_partial_data error %d" % res[0])
			return
		var written: int = res[1]
		offset += written
		if written == 0:
			# Buffer full: drain replies and yield a frame so the socket flushes.
			_poll()
			if _scene_tree:
				await _scene_tree.process_frame
	_poll()


## Public: drains the TCP receive buffer. Call this regularly while sending
## many notifications in a row, otherwise the server's replies fill the
## socket buffers and put_data() deadlocks.
func poll() -> void:
	_poll()


## Returns the byte index just past the first "\r\n\r\n" in buf, or -1 if
## not present yet. Pure byte comparison -- CRLFCRLF is ASCII, so this never
## needs to (and must not, per the incomplete-buffer note in _poll()) decode
## buf as UTF-8 to find it.
func _find_header_end(buf: PackedByteArray) -> int:
	var n := buf.size()
	var i := 0
	while i + 3 < n:
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			return i + 4
		i += 1
	return -1


## Polls TCP and parses incoming LSP messages into _responses.
func _poll() -> void:
	if _tcp == null:
		return
	_tcp.poll()
	var available := _tcp.get_available_bytes()
	if available > 0:
		var r := _tcp.get_data(available)
		if r[0] == OK:
			_recv_buf.append_array(r[1])

	# Parse all complete messages
	while true:
		# Find the header/body separator (CRLFCRLF) at the BYTE level, not by
		# decoding the whole buffer as UTF-8 first. The Content-Length body
		# (JSON, which can contain multi-byte UTF-8 -- e.g. accented
		# characters from this project's French doc comments) very often
		# hasn't fully arrived yet when _poll() runs (LSP responses routinely
		# exceed one TCP recv()), so _recv_buf's tail is frequently cut mid
		# multi-byte character. Decoding that partial buffer as UTF-8 (the
		# previous behavior) reliably produced "Invalid UTF-8 leading byte"/
		# "Unicode parsing error" ERR_PRINTs on every such poll while an LSP
		# request was in flight -- purely to locate an ASCII header separator
		# that never needed UTF-8 decoding in the first place. The header
		# itself (up to and including CRLFCRLF) is always plain ASCII per the
		# LSP/HTTP-style framing spec, so it's safe to decode in isolation
		# once located; the body is only decoded below after its full length
		# is confirmed present (that part was already correct).
		var sep_end := _find_header_end(_recv_buf)
		if sep_end == -1:
			break
		var header := _recv_buf.slice(0, sep_end).get_string_from_utf8()
		# Find Content-Length
		var cl := -1
		for h in header.split("\r\n"):
			if h.to_lower().begins_with("content-length:"):
				cl = int(h.split(":")[1].strip_edges())
				break
		if cl == -1:
			break
		var header_bytes := sep_end
		if _recv_buf.size() < header_bytes + cl:
			break  # incomplete body

		var body_bytes := _recv_buf.slice(header_bytes, header_bytes + cl)
		_recv_buf = _recv_buf.slice(header_bytes + cl)

		var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
		if parsed == null:
			continue

		if parsed.has("id"):
			var rid: int = parsed["id"]
			if parsed.has("result"):
				_responses[rid] = parsed["result"]
			elif parsed.has("error"):
				push_warning("LSP error for id %d: %s" % [rid, str(parsed["error"])])
				_responses[rid] = null
		# Notifications (no id) are ignored


## Waits up to `timeout_sec` for a response with the given id.
func _wait_for_response(id: int, timeout_sec: float) -> Variant:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000)
	while Time.get_ticks_msec() < deadline:
		_poll()
		if _responses.has(id):
			var result = _responses[id]
			_responses.erase(id)
			return result
		await _scene_tree.process_frame
	push_warning("LSP: timeout waiting for response id=%d" % id)
	return null


# -------------------------------------------------------------------------
# Path / URI helpers
# -------------------------------------------------------------------------

static func path_to_uri(abs_path: String) -> String:
	var p := abs_path.replace("\\", "/")
	if OS.get_name() == "Windows" and p.length() >= 2 and p[1] == ":":
		p = "/" + p  # Windows: /C:/path/...
	return "file://" + _percent_encode_path(p)


## Percent-encodes a path for use in a file:// URI: keeps the path separators
## and safe characters, escapes spaces, accents, and other non-ASCII bytes.
static func _percent_encode_path(p: String) -> String:
	var out := ""
	for ch in p:
		if _is_uri_safe(ch):
			out += ch
		else:
			for b in ch.to_utf8_buffer():
				out += "%%%02X" % b
	return out


static func _is_uri_safe(ch: String) -> bool:
	if ch.length() != 1:
		return false
	# Unreserved per RFC 3986 + path separators / drive colon we keep literal.
	if (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") \
			or (ch >= "0" and ch <= "9"):
		return true
	return ch in ["/", "-", "_", ".", "~", ":"]


static func uri_to_path(uri: String) -> String:
	var p := uri
	# Strip the scheme but KEEP the path's leading slash. On Linux/macOS a file
	# URI is file:///home/user/... — the third slash is part of the absolute
	# path, so we must only remove "file://" (7 chars), not "file:///" (8).
	if p.begins_with("file://"):
		p = p.substr(7)
	# Percent-decode ALL %XX sequences, rebuilding raw bytes first so that
	# multi-byte UTF-8 characters (e.g. "é" = %C3%A9) are decoded correctly.
	p = _percent_decode(p)
	# Windows: a URI path looks like /D:/path → strip the leading slash so it
	# becomes D:/path. Detect it by the ":" at index 2.
	if p.length() >= 3 and p[0] == "/" and p[2] == ":":
		p = p.substr(1)
	if OS.get_name() == "Windows":
		p = p.replace("/", "\\")
	return p


## Decodes every %XX escape in [s] into raw bytes, then interprets the whole
## byte stream as UTF-8. Handles multi-byte characters (accents, etc.).
static func _percent_decode(s: String) -> String:
	var bytes := PackedByteArray()
	var i := 0
	var n := s.length()
	while i < n:
		var c := s[i]
		if c == "%" and i + 2 < n:
			var hex := s.substr(i + 1, 2)
			var val := ("0x" + hex).hex_to_int()
			# hex_to_int returns 0 for invalid input; guard against a literal
			# "%00" vs a malformed escape by checking the two chars are hex.
			if _is_hex(s[i + 1]) and _is_hex(s[i + 2]):
				bytes.append(val)
				i += 3
				continue
		# Normal character: append its UTF-8 bytes.
		bytes.append_array(c.to_utf8_buffer())
		i += 1
	return bytes.get_string_from_utf8()


static func _is_hex(ch: String) -> bool:
	return ch.length() == 1 and (
		(ch >= "0" and ch <= "9") or
		(ch >= "a" and ch <= "f") or
		(ch >= "A" and ch <= "F"))
