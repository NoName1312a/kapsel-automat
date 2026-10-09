class_name Fmt
## Zahlen lesbar machen: 1.234 → "1,23 K", 5e9 → "5,00 Mrd".

const SUFFIX := ["", " K", " Mio", " Mrd", " Bio", " Brd", " Trio", " Trd", " Quad", " Quadr", " Quin", " Quinrd", " Sext"]


static func num(x: float) -> String:
	var neg := x < 0.0
	x = absf(x)
	var s: String
	if x < 1000.0:
		s = str(int(floor(x)))
	else:
		var e := int(floor(log(x) / log(1000.0) + 1e-9))
		if e < SUFFIX.size():
			var m := x / pow(1000.0, e)
			s = ("%.2f" % m if m < 10.0 else "%.1f" % m if m < 100.0 else "%.0f" % m) + SUFFIX[e]
		else:
			var e10 := int(floor(log(x) / log(10.0)))
			s = "%.2fe%d" % [x / pow(10.0, e10), e10]
	return ("-" if neg else "") + s.replace(".", ",")


## Wie num(), aber kleine Werte mit einer Nachkommastelle (für Einkommen pro Sekunde).
static func rate(x: float) -> String:
	if x < 100.0:
		return ("%.1f" % x).replace(".", ",")
	return num(x)


static func duration(secs: float) -> String:
	var h := int(secs / 3600.0)
	var m := int(fmod(secs, 3600.0) / 60.0)
	return "%d h %02d min" % [h, m] if h > 0 else "%d min" % m
