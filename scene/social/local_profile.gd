class_name LocalPlayerProfile
extends Node
## Identidade local offline (sem conta). 03/11: fluxo completo de solicitações.
## - `friends`: contatos. status `local_unverified` (adicionado à mão) ou
##   `session_mutual_unverified` (aceito pelos dois lados numa sessão privada real).
## - `requests`: rascunhos locais `local_pending_not_sent` (nunca saíram do aparelho).
##   Pedidos enviados a um assento da sessão vivem só na memória da SocialBridge.
## - `incoming`: recebidas de participantes de uma sessão privada (identidade declarada,
##   não verificada por servidor de contas). Nada aqui representa amizade online.
## Schema 1 inalterado: chaves novas (`incoming`, `avatar`, `privacy.friend_requests`)
## são opcionais na leitura e só são gravadas na próxima alteração do próprio usuário.
const DOCUMENT := preload("res://scene/persistence/atomic_document.gd")
const TEXT := preload("res://scene/social/text_safety.gd")
const AVATARS := ["jhon", "jackson", "kai", "spark"]
const MAX_INCOMING := 32
const MAX_CONTACTS := 200
const NAME_LIMIT := 24
signal changed
var repository: AtomicDocument = DOCUMENT.new()
var data: Dictionary = {}
var last_error := ""
var connection_status := "offline"


func initialize(path: String = "user://identity_v1") -> bool:
	if not data.is_empty():
		return true
	repository.directory = path
	var loaded: Dictionary = repository.read()
	if loaded.is_empty():
		if repository.has_files():
			last_error = "identity_recovery_required"
			return false
		loaded = {"schema_version": 1, "player_id": _id(16), "public_id": _id(8),
			"display_name": "Jogador", "avatar": "jhon",
			"privacy": {"visibility": "private", "allow_invites": "friends", "share_presence": false, "friend_requests": "session"},
			"friends": {}, "requests": {}, "incoming": {}, "invites": {}, "blocked": {}}
		if not repository.write(loaded):
			last_error = repository.error
			return false
	if not _valid(loaded):
		last_error = "invalid_profile"
		return false
	data = _with_defaults(loaded)
	return true


func _id(bytes: int) -> String:
	return Crypto.new().generate_random_bytes(bytes).hex_encode()


func _valid(value: Dictionary) -> bool:
	if int(value.get("schema_version", 0)) != 1 or value.get("player_id") is not String or value.get("public_id") is not String or value.get("display_name") is not String:
		return false
	if value.player_id.length() != 32 or not value.player_id.is_valid_hex_number(false) or not _valid_public_id(value.public_id) or value.display_name.length() > 40:
		return false
	for key in ["privacy", "friends", "requests", "invites", "blocked"]:
		if value.get(key) is not Dictionary:
			return false
	if value.has("incoming") and value.incoming is not Dictionary:
		return false
	if value.has("avatar") and value.avatar is not String:
		return false
	return true


## Perfis gravados antes de 03/11 não têm as chaves novas; nada é regravado aqui.
func _with_defaults(value: Dictionary) -> Dictionary:
	var next: Dictionary = value.duplicate(true)
	if not next.has("incoming"):
		next.incoming = {}
	if String(next.get("avatar", "")) not in AVATARS:
		next.avatar = "jhon"
	if String(next.privacy.get("friend_requests", "")) not in ["session", "none"]:
		next.privacy.friend_requests = "session"
	return next


func public_view() -> Dictionary:
	if data.is_empty():
		return {}
	return {"public_id": data.public_id, "display_name": data.display_name,
		"avatar": data.avatar, "verified_online": false, "connection_status": connection_status}


## Cartão mínimo entregue a quem recebe uma solicitação numa sessão privada.
func session_card() -> Dictionary:
	if data.is_empty():
		return {}
	return {"public_id": data.public_id, "name": data.display_name, "avatar": data.avatar}


func rename(name: String) -> bool:
	var clean := TEXT.clean_name(name, NAME_LIMIT)
	if data.is_empty() or clean.is_empty():
		return false
	var next: Dictionary = data.duplicate(true)
	next.display_name = clean
	return _commit(next)


func set_avatar(avatar: String) -> bool:
	if data.is_empty() or avatar not in AVATARS:
		return false
	var next: Dictionary = data.duplicate(true)
	next.avatar = avatar
	return _commit(next)


func add_local_contact(public_id: String, name: String) -> bool:
	public_id = normalize_id(public_id)
	if data.is_empty() or not _valid_public_id(public_id) or public_id == data.public_id or data.blocked.has(public_id):
		return false
	if not data.friends.has(public_id) and data.friends.size() >= MAX_CONTACTS:
		last_error = "contact_limit"
		return false
	var next: Dictionary = data.duplicate(true)
	var clean := TEXT.clean_name(name, NAME_LIMIT)
	next.friends[public_id] = {"public_id": public_id, "display_name": clean if not clean.is_empty() else "Contato " + public_id.left(4).to_upper(), "status": "local_unverified"}
	next.incoming.erase(public_id)
	return _commit(next)


func remove_contact(public_id: String) -> bool:
	public_id = normalize_id(public_id)
	if data.is_empty() or not data.friends.has(public_id):
		return false
	var next: Dictionary = data.duplicate(true)
	next.friends.erase(public_id)
	return _commit(next)


func block(public_id: String) -> bool:
	public_id = normalize_id(public_id)
	if data.is_empty() or not _valid_public_id(public_id) or public_id == data.public_id:
		return false
	var next: Dictionary = data.duplicate(true)
	var known := String(next.friends.get(public_id, next.incoming.get(public_id, next.requests.get(public_id, {}))).get("display_name", ""))
	next.blocked[public_id] = {"display_name": known, "blocked_at": Time.get_datetime_string_from_system(true)}
	next.friends.erase(public_id)
	for key in ["requests", "invites", "incoming"]:
		next[key].erase(public_id)
		for id: Variant in next[key].keys():
			if next[key][id] is Dictionary and next[key][id].get("public_id", "") == public_id:
				next[key].erase(id)
	return _commit(next)


func unblock(public_id: String) -> bool:
	public_id = normalize_id(public_id)
	if data.is_empty() or not data.blocked.has(public_id):
		return false
	var next: Dictionary = data.duplicate(true)
	next.blocked.erase(public_id)
	return _commit(next)


func is_blocked(public_id: String) -> bool:
	return not data.is_empty() and data.blocked.has(normalize_id(public_id))


## Rascunho local: registrado no aparelho, nunca enviado (não há servidor de contas).
func request_contact(public_id: String, name: String = "") -> bool:
	public_id = normalize_id(public_id)
	if data.is_empty() or not _valid_public_id(public_id) or data.blocked.has(public_id) or public_id == data.public_id or data.friends.has(public_id):
		return false
	var next: Dictionary = data.duplicate(true)
	next.requests[public_id] = {"public_id": public_id, "display_name": TEXT.clean_name(name, NAME_LIMIT), "state": "local_pending_not_sent"}
	return _commit(next)


func cancel_request(public_id: String) -> bool:
	public_id = normalize_id(public_id)
	if data.is_empty() or not data.requests.has(public_id):
		return false
	var next: Dictionary = data.duplicate(true)
	next.requests.erase(public_id)
	return _commit(next)


## Chegou de outro participante pela sessão privada. Bloqueados e privacidade "none"
## são descartados em silêncio (o remetente não descobre que foi bloqueado).
func receive_request(card: Dictionary, source := "session") -> bool:
	if data.is_empty() or String(data.privacy.get("friend_requests", "session")) == "none":
		return false
	var public_id := normalize_id(String(card.get("public_id", "")))
	var name := TEXT.clean_name(String(card.get("name", "")), NAME_LIMIT)
	if not _valid_public_id(public_id) or public_id == data.public_id or data.blocked.has(public_id) or data.friends.has(public_id):
		return false
	if not data.incoming.has(public_id) and data.incoming.size() >= MAX_INCOMING:
		return false
	var next: Dictionary = data.duplicate(true)
	var avatar := String(card.get("avatar", "jhon"))
	next.incoming[public_id] = {"public_id": public_id, "display_name": name if not name.is_empty() else "Jogador " + public_id.left(4).to_upper(),
		"avatar": avatar if avatar in AVATARS else "jhon", "source": source,
		"received_at": Time.get_datetime_string_from_system(true)}
	return _commit(next)


## Aceita uma solicitação recebida: vira contato confirmado pelos dois lados da sessão
## (identidade continua declarada, não verificada por servidor). Retorna o cartão aceito.
func accept_request(public_id: String) -> Dictionary:
	public_id = normalize_id(public_id)
	if data.is_empty() or not data.incoming.has(public_id) or data.blocked.has(public_id):
		return {}
	if data.friends.size() >= MAX_CONTACTS:
		last_error = "contact_limit"
		return {}
	var next: Dictionary = data.duplicate(true)
	var entry: Dictionary = next.incoming[public_id]
	next.incoming.erase(public_id)
	next.requests.erase(public_id)
	next.friends[public_id] = {"public_id": public_id, "display_name": String(entry.get("display_name", "")),
		"avatar": String(entry.get("avatar", "jhon")), "status": "session_mutual_unverified"}
	if not _commit(next):
		return {}
	return entry


func decline_request(public_id: String) -> bool:
	public_id = normalize_id(public_id)
	if data.is_empty() or not data.incoming.has(public_id):
		return false
	var next: Dictionary = data.duplicate(true)
	next.incoming.erase(public_id)
	return _commit(next)


## Quem recebeu a NOSSA solicitação aceitou (a ponte social confere que ela foi
## enviada a esse assento nesta sessão). Identidade declarada, não verificada.
func add_session_friend(card: Dictionary) -> bool:
	var public_id := normalize_id(String(card.get("public_id", "")))
	if data.is_empty() or not _valid_public_id(public_id) or public_id == data.public_id or data.blocked.has(public_id):
		return false
	if not data.friends.has(public_id) and data.friends.size() >= MAX_CONTACTS:
		last_error = "contact_limit"
		return false
	var next: Dictionary = data.duplicate(true)
	var name := TEXT.clean_name(String(card.get("name", "")), NAME_LIMIT)
	var avatar := String(card.get("avatar", "jhon"))
	next.friends[public_id] = {"public_id": public_id, "display_name": name if not name.is_empty() else "Jogador " + public_id.left(4).to_upper(),
		"avatar": avatar if avatar in AVATARS else "jhon", "status": "session_mutual_unverified"}
	next.incoming.erase(public_id)
	next.requests.erase(public_id)
	return _commit(next)


func set_privacy(invites: String, share_presence: bool, friend_requests := "") -> bool:
	if data.is_empty() or invites not in ["none", "friends"]:
		return false
	if not friend_requests.is_empty() and friend_requests not in ["none", "session"]:
		return false
	var next: Dictionary = data.duplicate(true)
	next.privacy.allow_invites = invites
	next.privacy.share_presence = share_presence
	if not friend_requests.is_empty():
		next.privacy.friend_requests = friend_requests
	return _commit(next)


func authenticate_online(_credential: String) -> Error:
	# A local public ID is never an authenticated backend identity.
	return ERR_UNAVAILABLE


static func normalize_id(id: String) -> String:
	return id.strip_edges().replace(" ", "").replace("-", "").to_lower()


func _valid_public_id(id: String) -> bool:
	return id.length() == 16 and id.is_valid_hex_number(false)


func _commit(next: Dictionary) -> bool:
	if not repository.write(next):
		last_error = repository.error
		return false
	data = next
	last_error = ""
	changed.emit()
	return true
