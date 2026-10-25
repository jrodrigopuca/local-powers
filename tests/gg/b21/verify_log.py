"""Verificador independiente de una respuesta de b21.

Lee SOLO el texto (el log y el título) y recalcula todo desde las cartas que
muestra, con su propia cuenta de totales y sus propias reglas: no importa nada
del motor, así que un error del motor en las cuentas o en las decisiones no
puede pasar de largo. Sirve para las pruebas sin modelo (selftest.py) y para
las respuestas reales del modelo (check.sh).

    verificar(texto, "es"|"en")  ->  None si todo cierra, o el primer error.

Qué comprueba: la forma (un bloque ```text, una línea en blanco, un título
"## …"; líneas de hasta 40 columnas y sin espacios al final); cada carta aparece
una sola vez; cada total mostrado, y cada rótulo de blando, coincide con el
recalculado; el usuario pide si y solo si su total es menor que el plan (12 a
21) y se planta si no; el crupier pide si y solo si tiene menos de 17 y no pide
si el usuario se pasó; la línea "El as pasa a valer 1" aparece justo cuando
corresponde; los blackjack naturales; el 💥 en los totales mayores a 21; la
línea Final; y que el título sea el resultado que sale de los totales.
"""
import re
import unicodedata

CARTA = r"(?:10|[2-9AJQK])[♠♥♦♣]"
BUST = "💥"

IDIOMAS = {
    "es": dict(
        deal="Reparto", turn_u=r"Tu turno \(plan (\d+)\)", turn_c="Mi turno", bj="Blackjack",
        u="Vos", c="Yo", soft="blando", nat="¡blackjack!", con="Con",
        hit_u="pedís", hit_c="pido", stand_u="te plantás", stand_c="me planto",
        bust_u="te pasás", bust_c="me paso", flip="Doy vuelta",
        ace="  El as pasa a valer 1.", no_draw="  Ya gané: no pido carta.",
        bj_u="  No tengo blackjack: ganás.", bj_c="  Blackjack mío: gané directo.",
        bj_ambos="  Blackjack de los dos: empate.",
        title={"u": "🎉 ¡Ganaste!", "c": "🤖 Gané", "tie": "🤝 Empate"},
    ),
    "en": dict(
        deal="Deal", turn_u=r"Your turn \(plan (\d+)\)", turn_c="My turn", bj="Blackjack",
        u="You", c="Me", soft="soft", nat="blackjack!", con="With",
        hit_u="you hit", hit_c="I hit", stand_u="you stand", stand_c="I stand",
        bust_u="you bust", bust_c="I bust", flip="I flip",
        ace="  The ace now counts as 1.", no_draw="  I already won, so I don't draw.",
        bj_u="  I have no blackjack: you win.", bj_c="  My blackjack: I win outright.",
        bj_ambos="  Both of us have blackjack: tie.",
        title={"u": "🎉 You won!", "c": "🤖 I won", "tie": "🤝 Tie"},
    ),
}


class Invalido(Exception):
    pass


def _exigir(cond, msg):
    if not cond:
        raise Invalido(msg)


def _total(cartas):
    """(mejor total, blando) de una lista de cartas como "K♠"."""
    t, ases = 0, 0
    for c in cartas:
        r = c[:-1]
        if r == "A":
            t, ases = t + 11, ases + 1
        else:
            t += 10 if r in ("J", "Q", "K") else int(r)
    while t > 21 and ases:
        t, ases = t - 10, ases - 1
    return t, ases > 0


def _ancho(linea):
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in linea)


def _rx(*partes):
    return re.compile("".join(partes))


class _Mano:
    def __init__(self, cartas):
        self.cartas = list(cartas)

    @property
    def total(self):
        return _total(self.cartas)


def verificar(texto, idioma):
    try:
        _verificar(texto, idioma)
    except Invalido as e:
        return str(e)
    return None


def _verificar(texto, idioma):
    L = IDIOMAS[idioma]
    soft = re.escape(L["soft"])
    nat = re.escape(L["nat"])
    t = unicodedata.normalize("NFC", texto.replace("\r\n", "\n")).replace("️", "").strip()
    m = re.fullmatch(r"```text\n(.*)\n```\n\n## (.+)", t, re.S)
    _exigir(m, "forma: se esperaba un bloque ```text, una línea en blanco y un título '## …'")
    log, titulo = m.group(1), m.group(2)

    lineas = log.split("\n")
    for l in lineas:
        _exigir(l == l.rstrip(), f"espacio al final de la línea: {l!r}")
        _exigir(_ancho(l) <= 40, f"línea de más de 40 columnas: {l!r}")
    bloques, actual = [], []
    for l in lineas:
        if l == "":
            _exigir(actual, "dos líneas en blanco seguidas, o una al principio")
            bloques.append(actual)
            actual = []
        else:
            actual.append(l)
    _exigir(actual, "el log termina en una línea en blanco")
    bloques.append(actual)
    vistas = []  # todas las cartas que se van leyendo, para detectar repetidas

    def tomar(carta):
        _exigir(carta not in vistas, f"la carta {carta} aparece más de una vez")
        vistas.append(carta)

    def totales(mano, texto_t, texto_blando, donde):
        t, bl = mano.total
        _exigir(int(texto_t) == t, f"{donde}: dice {texto_t} y las cartas suman {t}")
        _exigir(bool(texto_blando) == bl and (bl or not texto_blando),
                f"{donde}: el rótulo '{L['soft']}' {'falta' if bl else 'sobra'} (total {t})")

    # --- Reparto
    reparto = bloques[0]
    _exigir(len(reparto) == 3 and reparto[0] == L["deal"], "el primer bloque no es el Reparto de tres líneas")
    mu = re.fullmatch(rf"  {L['u']}: ({CARTA} {CARTA}) → (\d+)( {soft})?( {nat})?", reparto[1])
    _exigir(mu, f"línea del reparto del usuario ilegible: {reparto[1]!r}")
    mc = re.fullmatch(rf"  {L['c']}:  ({CARTA}) \[\?\]", reparto[2])
    _exigir(mc, f"línea del reparto del crupier ilegible: {reparto[2]!r}")
    u = _Mano(mu.group(1).split())
    for c in u.cartas:
        tomar(c)
    c_up = mc.group(1)
    tomar(c_up)
    u_nat = u.total[0] == 21
    if u_nat:
        _exigir(mu.group(4) and not mu.group(3) and mu.group(2) == "21",
                "mano de 21 en el reparto: tiene que decir '→ 21 ¡blackjack!' sin rótulo de blando")
    else:
        _exigir(not mu.group(4), "dice blackjack sin tenerlo")
        totales(u, mu.group(2), mu.group(3), "reparto del usuario")

    # --- Carta tapada y flujo
    _exigir(len(bloques) in (3, 4), f"se esperaban 3 o 4 bloques y hay {len(bloques)}")
    natural_flujo = bloques[1][0] == L["bj"]
    _exigir(len(bloques) == (3 if natural_flujo else 4), "la cantidad de bloques no corresponde al tipo de mano")

    def leer_vuelta(linea, permitir_nat):
        mv = re.fullmatch(rf"  {L['flip']} ({CARTA}) → (\d+)( {soft})?( {nat})?", linea)
        _exigir(mv, f"línea de dar vuelta ilegible: {linea!r}")
        tomar(mv.group(1))
        c = _Mano([c_up, mv.group(1)])
        es_nat = c.total[0] == 21
        if es_nat:
            _exigir(mv.group(4) and not mv.group(3) and mv.group(2) == "21",
                    "el crupier tiene 21: tiene que decir '→ 21 ¡blackjack!' sin rótulo de blando")
        else:
            _exigir(not mv.group(4), "dice blackjack del crupier sin tenerlo")
            totales(c, mv.group(2), mv.group(3), "vuelta del crupier")
        _exigir(permitir_nat or not es_nat, "el crupier tiene blackjack pero no hay sección Blackjack")
        return c, es_nat

    if natural_flujo:
        bj = bloques[1]
        _exigir(len(bj) == 3, "la sección Blackjack tiene que tener tres líneas")
        c, c_nat = leer_vuelta(bj[1], True)
        _exigir(u_nat or c_nat, "hay sección Blackjack sin que nadie tenga blackjack")
        esperado = L["bj_ambos"] if u_nat and c_nat else L["bj_u"] if u_nat else L["bj_c"]
        _exigir(bj[2] == esperado, f"la frase de cierre no corresponde: {bj[2]!r}")
        ganador = "tie" if u_nat and c_nat else "u" if u_nat else "c"
        mano_c = c
    else:
        _exigir(not u_nat, "el usuario tiene blackjack y no hay sección Blackjack")
        turno_u = bloques[1]
        mp = re.fullmatch(L["turn_u"], turno_u[0])
        _exigir(mp, f"encabezado del turno del usuario ilegible: {turno_u[0]!r}")
        plan = int(mp.group(1))
        _exigir(12 <= plan <= 21, f"plan fuera de rango: {plan}")

        def leer_jugadas(bloque, mano, regla_pide, quien):
            """Recorre las líneas de decisión de un jugador. Devuelve si se pasó."""
            hit, stand, bust = L["hit_" + quien], L["stand_" + quien], L["bust_" + quien]
            con = L["con"]
            terminado, se_paso, i = False, False, 0
            while i < len(bloque):
                l = bloque[i]
                _exigir(not terminado, f"hay líneas después de que el jugador terminó: {l!r}")
                mh = re.fullmatch(rf"  {con} (\d+)( {soft})? {hit} ({CARTA}) → (\d+)( {soft})?", l)
                mb = re.fullmatch(rf"  {con} (\d+)( {soft})? {hit} ({CARTA}) → (\d+) {BUST} {bust}", l)
                ms = re.fullmatch(rf"  {con} (\d+)( {soft})? {stand}\.", l)
                _exigir(mh or mb or ms, f"línea de decisión ilegible: {l!r}")
                previo = mano.total
                g = (mh or mb or ms).groups()
                _exigir(int(g[0]) == previo[0] and bool(g[1]) == previo[1],
                        f"'{con} {g[0]}{' ' + L['soft'] if g[1] else ''}' no coincide con la mano ({previo[0]}{' blando' if previo[1] else ''}): {l!r}")
                if ms:
                    _exigir(not regla_pide(previo[0]) and previo[0] <= 21,
                            f"se planta con {previo[0]} cuando tendría que pedir: {l!r}")
                    terminado = True
                else:
                    _exigir(regla_pide(previo[0]), f"pide con {previo[0]} cuando tendría que plantarse: {l!r}")
                    tomar(g[2])
                    mano.cartas.append(g[2])
                    nuevo = mano.total
                    if mb:
                        _exigir(nuevo[0] > 21 and int(g[3]) == nuevo[0],
                                f"se pasa con {g[3]} y las cartas suman {nuevo[0]}: {l!r}")
                        terminado = se_paso = True
                    else:
                        _exigir(nuevo[0] <= 21, f"suma {nuevo[0]} y la línea no marca el pasarse: {l!r}")
                        _exigir(int(g[3]) == nuevo[0] and bool(g[4]) == nuevo[1],
                                f"total tras pedir mal: dice {g[3]}{' ' + L['soft'] if g[4] else ''}, "
                                f"las cartas suman {nuevo[0]}{' blando' if nuevo[1] else ''}: {l!r}")
                        if previo[1] and not nuevo[1]:  # el as pasó de 11 a 1
                            i += 1
                            _exigir(i < len(bloque) and bloque[i] == L["ace"],
                                    "falta la línea 'El as pasa a valer 1' después de que el as pasó de 11 a 1")
                i += 1
            _exigir(terminado, "el jugador no se planta ni se pasa al final de su turno")
            return se_paso

        u_pasa = leer_jugadas(turno_u[1:], u, lambda t: t < plan, "u")
        _exigir(u_pasa == (u.total[0] > 21), "el pasarse del usuario no coincide con su total")

        turno_c = bloques[2]
        _exigir(turno_c[0] == L["turn_c"], f"encabezado del turno del crupier: {turno_c[0]!r}")
        _exigir(len(turno_c) >= 2, "el turno del crupier no da vuelta la carta")
        c, c_nat = leer_vuelta(turno_c[1], False)
        if u_pasa:
            _exigir(turno_c[2:] == [L["no_draw"]], "si el usuario se pasó, el crupier no pide: falta o sobra algo")
        else:
            c_pasa = leer_jugadas(turno_c[2:], c, lambda t: t < 17, "c")
            _exigir(c_pasa == (c.total[0] > 21), "el pasarse del crupier no coincide con su total")
        mano_c = c
        tu, tc = u.total[0], mano_c.total[0]
        ganador = "c" if tu > 21 else "u" if tc > 21 or tu > tc else "c" if tc > tu else "tie"

    # --- Final y título
    fin = bloques[-1]
    _exigir(len(fin) == 1, "el último bloque tiene que ser la línea Final")
    mf = re.fullmatch(rf"Final: {L['u']} (\d+)( {BUST})?, {L['c']} (\d+)( {BUST})?", fin[0])
    _exigir(mf, f"línea Final ilegible: {fin[0]!r}")
    tu, tc = u.total[0], mano_c.total[0]
    _exigir(int(mf.group(1)) == tu and int(mf.group(3)) == tc,
            f"Final dice {mf.group(1)} y {mf.group(3)}; las cartas suman {tu} y {tc}")
    _exigir(bool(mf.group(2)) == (tu > 21) and bool(mf.group(4)) == (tc > 21), "el 💥 de la línea Final no coincide")
    _exigir(titulo == L["title"][ganador], f"el título {titulo!r} no es el resultado de las cartas ({ganador})")

    # --- Todas las cartas del log se leyeron una vez
    en_el_log = re.findall(CARTA, log)
    _exigir(sorted(en_el_log) == sorted(vistas), "hay cartas en el log que no se pudieron leer como parte de la mano")
