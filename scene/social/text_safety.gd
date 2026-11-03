extends RefCounted
## Nomes exibidos para outras pessoas: remove controles, quebras de linha e marcas
## bidi/invisíveis (evita nomes falsificados na interface), limita o tamanho.

static func clean_name(value: String, limit := 24) -> String:
	var result := ""
	for index in value.length():
		var code := value.unicode_at(index)
		if code < 32 or code == 127 or (code >= 0x80 and code < 0xA0):
			continue
		if (code >= 0x200B and code <= 0x200F) or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069) or code == 0xFEFF or code == 0x2028 or code == 0x2029:
			continue
		result += char(code)
	return result.strip_edges().left(limit)


static func valid_public_id(id: String) -> bool:
	return id.length() == 16 and id.is_valid_hex_number(false) and id == id.to_lower()
