extends Node
## Liga o perfil local ao relay privado. Única via REAL de solicitações entre jogadores
## hoje: participantes já autorizados (por convite) na mesma sessão privada.
## Sem servidor de contas, nada aqui é "amizade online": identidades são declaradas.
## Pedidos enviados e o mapa assento→pedido recebido ficam só em memória (por sessão).
signal changed(message: String)
var profile: Node
var session: Node
## peer -> {"name", "room_id", "sent_at"} (pedidos que ESTE aparelho enviou).
var sent: Dictionary = {}
## public_id -> {"peer", "room_id"} (de quem veio cada pedido recebido nesta sessão).
var incoming_peers: Dictionary = {}


func setup(local_profile: Node, private_session: Node) -> void:
	profile = local_profile
	session = private_session
	session.friend_request_received.connect(_on_request)
	session.friend_response_received.connect(_on_response)
	session.status_changed.connect(_on_status)


func online_accounts_available() -> bool:
	# Não há backend de contas configurado; não simular operações online.
	return false


func can_send_to(peer: int) -> bool:
	return session.is_connected_session() and peer != int(session.peer_id) and not sent.has(peer) \
		and bool(session.roster_entry(peer).get("connected", false))


func send_request(peer: int) -> Error:
	if not profile.initialize() or not can_send_to(peer):
		return ERR_UNAVAILABLE
	var result: Error = session.send_friend_request(peer, profile.session_card())
	if result == OK:
		sent[peer] = {"name": String(session.roster_entry(peer).get("name", "")), "room_id": session.room_id,
			"sent_at": Time.get_ticks_msec()}
		changed.emit("Solicitação enviada pela sessão privada. Aguardando resposta.")
	return result


func cancel_sent(peer: int) -> void:
	# O relay não guarda pedidos; cancelar ignora uma eventual aceitação posterior.
	sent.erase(peer)
	changed.emit("Solicitação cancelada neste aparelho.")


func accept(public_id: String) -> String:
	var entry: Dictionary = profile.accept_request(public_id)
	if entry.is_empty():
		return "Não foi possível aceitar. Verifique bloqueios e o armazenamento."
	var route: Dictionary = incoming_peers.get(public_id, {})
	incoming_peers.erase(public_id)
	if _route_alive(route) and session.send_friend_response(int(route.peer), true, profile.session_card()) == OK:
		return "Aceito. O outro jogador foi avisado pela sessão."
	return "Aceito neste aparelho. O outro jogador só é avisado se ainda estiver na mesma sessão."


func decline(public_id: String) -> String:
	if not profile.decline_request(public_id):
		return "Solicitação não encontrada."
	var route: Dictionary = incoming_peers.get(public_id, {})
	incoming_peers.erase(public_id)
	if _route_alive(route):
		session.send_friend_response(int(route.peer), false)
	return "Solicitação recusada."


func block(public_id: String) -> bool:
	incoming_peers.erase(public_id)
	return profile.block(public_id)


func _route_alive(route: Dictionary) -> bool:
	return not route.is_empty() and String(route.get("room_id", "")) == String(session.room_id) and session.is_connected_session() \
		and bool(session.roster_entry(int(route.peer)).get("connected", false))


func _on_request(peer: int, card: Dictionary) -> void:
	if not profile.initialize():
		return
	if profile.receive_request(card, "session"):
		incoming_peers[String(card.public_id)] = {"peer": peer, "room_id": session.room_id}
		changed.emit("Nova solicitação de amizade recebida na sessão.")


func _on_response(peer: int, accepted: bool, card: Dictionary) -> void:
	if not sent.has(peer):
		return  # sem pedido nosso para esse assento: ninguém é adicionado à força
	var request: Dictionary = sent[peer]
	sent.erase(peer)
	if String(request.room_id) != String(session.room_id):
		return
	if accepted and profile.add_session_friend(card):
		changed.emit("%s aceitou sua solicitação." % String(card.get("name", "Jogador")))
	elif not accepted:
		changed.emit("Solicitação não aceita.")


func _on_status() -> void:
	if not session.is_connected_session() and session.status in ["offline", "error", "suspended"]:
		sent.clear()
		incoming_peers.clear()
