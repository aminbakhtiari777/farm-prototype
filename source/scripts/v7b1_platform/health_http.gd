class_name HealthHttp
extends Node
## Tiny HTTP /health (and /) responder for free-tier keepalives and load balancers.
## Bound separately from the WebSocket game port. Godot has no HTTPServer, so this
## is a minimal TCPServer that answers GET with 200 JSON.

var port: int = 9081
var _tcp: TCPServer
var _clients: Array = []  ## StreamPeerTCP
var ok_payload: String = '{"ok":true,"service":"farm-town","players":0,"rooms":0}'


func start(p: int, initial: String = "") -> int:
	port = p
	if initial != "":
		ok_payload = initial
	_tcp = TCPServer.new()
	var err := _tcp.listen(port, "0.0.0.0")
	if err != OK:
		push_warning("HealthHttp: cannot listen on %d: %s" % [port, error_string(err)])
		return err
	print("HEALTH READY port=%d" % port)
	return OK


func set_stats(players: int, rooms: int, version: String = "") -> void:
	ok_payload = '{"ok":true,"service":"farm-town","version":"%s","players":%d,"rooms":%d}' % [
		version.replace('"', ""), players, rooms]


func _process(_delta: float) -> void:
	if _tcp == null:
		return
	while _tcp.is_connection_available():
		var c := _tcp.take_connection()
		if c:
			_clients.append({"peer": c, "buf": ""})
	var i := 0
	while i < _clients.size():
		var entry: Dictionary = _clients[i]
		var peer: StreamPeerTCP = entry["peer"]
		peer.poll()
		var st := peer.get_status()
		if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
			_clients.remove_at(i)
			continue
		if peer.get_available_bytes() > 0:
			entry["buf"] = str(entry["buf"]) + peer.get_utf8_string(peer.get_available_bytes())
			if "\r\n\r\n" in str(entry["buf"]) or "\n\n" in str(entry["buf"]):
				_reply(peer, str(entry["buf"]))
				_clients.remove_at(i)
				continue
		i += 1


func _reply(peer: StreamPeerTCP, req: String) -> void:
	var path := "/"
	var first := req.split("\n")[0] if req != "" else "GET /"
	var parts := first.strip_edges().split(" ")
	if parts.size() >= 2:
		path = parts[1].split("?")[0]
	var body := ok_payload
	var code := "200 OK"
	if path not in ["/", "/health", "/healthz", "/ping", "/stats"]:
		body = '{"ok":false,"error":"not_found"}'
		code = "404 Not Found"
	var resp := "HTTP/1.1 %s\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-store\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
		code, body.to_utf8_buffer().size(), body]
	peer.put_data(resp.to_utf8_buffer())
	peer.disconnect_from_host()
