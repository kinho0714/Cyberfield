extends RefCounted
## Código de convite privado: endpoint wss + ID da sessão + capacidade de uso único,
## num texto só para o anfitrião enviar por um canal privado e o convidado colar.
## O código É o segredo (quem o possui ocupa um assento até expirar). Nunca é gravado
## em disco nem em log pelo jogo; a área de transferência é responsabilidade do usuário.
const PREFIX := "CF1-"
const MAX_LENGTH := 1024
const TOKEN_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"


static func valid_endpoint(url: String) -> bool:
	if not url.begins_with("wss://") or url.length() > 512:
		return false
	for forbidden in ["@", "?", "#", " ", "\\", "\n", "\r", "\t"]:
		if forbidden in url:
			return false
	var host := url.substr(6).split("/", true, 1)[0]
	return not host.is_empty() and not host.begins_with(":")


static func valid_room(room_id: String) -> bool:
	return room_id.length() == 32 and room_id.is_valid_hex_number(false)


static func valid_token(token: String) -> bool:
	if token.length() < 32 or token.length() > 256:
		return false
	for index in token.length():
		if TOKEN_CHARS.find(token[index]) < 0:
			return false
	return true


static func encode(endpoint: String, room_id: String, token: String) -> String:
	if not valid_endpoint(endpoint) or not valid_room(room_id) or not valid_token(token):
		return ""
	var json := JSON.stringify({"v": 1, "e": endpoint, "r": room_id, "t": token})
	var b64 := Marshalls.utf8_to_base64(json).replace("+", "-").replace("/", "_").replace("=", "")
	return PREFIX + b64


## Retorna {"endpoint", "room_id", "token"} ou {} se o código não for válido.
static func decode(code: String) -> Dictionary:
	var text := code.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
	if not text.begins_with(PREFIX) or text.length() > MAX_LENGTH:
		return {}
	var b64 := text.substr(PREFIX.length()).replace("-", "+").replace("_", "/")
	for index in b64.length():
		if "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".find(b64[index]) < 0:
			return {}
	while b64.length() % 4 != 0:
		b64 += "="
	var raw := Marshalls.base64_to_raw(b64)
	# Bytes NUL truncariam a string e aceitariam lixo depois do JSON: recusa estrita.
	if raw.is_empty() or raw.has(0):
		return {}
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or parser.data is not Dictionary:
		return {}
	var value: Dictionary = parser.data
	if int(value.get("v", 0)) != 1 or value.get("e") is not String or value.get("r") is not String or value.get("t") is not String:
		return {}
	if value.size() != 4 or not valid_endpoint(value.e) or not valid_room(value.r) or not valid_token(value.t):
		return {}
	return {"endpoint": String(value.e), "room_id": String(value.r), "token": String(value.t)}
