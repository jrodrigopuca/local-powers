#!/usr/bin/env python3
"""Reparte y juega una mano de blackjack (21) contra Claude y arma la respuesta.

Uso: python3 b21.py [plan]
  plan: el total en el que te plantás, un entero de 12 a 21 (por defecto 17).
Salida (JSON):
  {"plan": 17, "resultado": "gana_usuario|gana_claude|empate",
   "usuario": {"cartas": ["K♠", "7♥"], "total": 17},
   "crupier": {"cartas": ["10♣", "6♦", "9♠"], "total": 25},
   "respuesta": {"es": ..., "en": ...}}
"respuesta" es la respuesta completa que Claude muestra, en markdown: un bloque
con el log de lo que pasó y, después, un título con el resultado.

Reglas: mazo de 52 mezclado antes de repartir (el plan no lo toca). Reparto:
usuario, crupier, usuario, crupier (la segunda del crupier queda tapada). Un
blackjack natural se resuelve al instante (si lo tienen los dos, empate). El
usuario pide mientras su mejor total sea menor que el plan; el as vale 11 salvo
que eso lo pase de 21. El crupier da vuelta su tapada y pide hasta 17: se planta
en todo 17, también en el blando. Si el usuario se pasó, el crupier no pide.
"""
import json
import re
import secrets
import sys

PLAN_MIN, PLAN_MAX, PLAN_DEFECTO = 12, 21, 17
CRUPIER_SE_PLANTA_EN = 17
RANGOS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
PALOS = ["♠", "♥", "♦", "♣"]  # para palos en versión emoji: "♠️", "♥️", "♦️", "♣️"

# Las líneas del log. {t}/{t2} son totales, {bl}/{bl2} el rótulo de blando (o
# nada), {c} una carta, {cs} varias. Nada se alinea a la derecha de un palo, una
# flecha o un emoji: solo las etiquetas (ASCII) llevan relleno.
PLANTILLAS = {
    "es": {
        "sec_reparto": "Reparto",
        "sec_turno_u": "Tu turno (plan {n})",
        "sec_turno_c": "Mi turno",
        "sec_bj": "Blackjack",
        "u_reparto": "  Vos: {cs} → {t}{bl}",
        "u_reparto_bj": "  Vos: {cs} → 21 ¡blackjack!",
        "c_reparto": "  Yo:  {c} [?]",
        "u_pide": "  Con {t}{bl} pedís {c} → {t2}{bl2}",
        "u_pasa": "  Con {t}{bl} pedís {c} → {t2} 💥 te pasás",
        "u_planta": "  Con {t}{bl} te plantás.",
        "as_vale_1": "  El as pasa a valer 1.",
        "c_vuelta": "  Doy vuelta {c} → {t}{bl}",
        "c_vuelta_bj": "  Doy vuelta {c} → 21 ¡blackjack!",
        "c_pide": "  Con {t}{bl} pido {c} → {t2}{bl2}",
        "c_pasa": "  Con {t}{bl} pido {c} → {t2} 💥 me paso",
        "c_planta": "  Con {t}{bl} me planto.",
        "c_no_pide": "  Ya gané: no pido carta.",
        "bj_u": "  No tengo blackjack: ganás.",
        "bj_c": "  Blackjack mío: gané directo.",
        "bj_ambos": "  Blackjack de los dos: empate.",
        "final": "Final: Vos {tu}{xu}, Yo {tc}{xc}",
        "blando": " blando",
    },
    "en": {
        "sec_reparto": "Deal",
        "sec_turno_u": "Your turn (plan {n})",
        "sec_turno_c": "My turn",
        "sec_bj": "Blackjack",
        "u_reparto": "  You: {cs} → {t}{bl}",
        "u_reparto_bj": "  You: {cs} → 21 blackjack!",
        "c_reparto": "  Me:  {c} [?]",
        "u_pide": "  With {t}{bl} you hit {c} → {t2}{bl2}",
        "u_pasa": "  With {t}{bl} you hit {c} → {t2} 💥 you bust",
        "u_planta": "  With {t}{bl} you stand.",
        "as_vale_1": "  The ace now counts as 1.",
        "c_vuelta": "  I flip {c} → {t}{bl}",
        "c_vuelta_bj": "  I flip {c} → 21 blackjack!",
        "c_pide": "  With {t}{bl} I hit {c} → {t2}{bl2}",
        "c_pasa": "  With {t}{bl} I hit {c} → {t2} 💥 I bust",
        "c_planta": "  With {t}{bl} I stand.",
        "c_no_pide": "  I already won, so I don't draw.",
        "bj_u": "  I have no blackjack: you win.",
        "bj_c": "  My blackjack: I win outright.",
        "bj_ambos": "  Both of us have blackjack: tie.",
        "final": "Final: You {tu}{xu}, Me {tc}{xc}",
        "blando": " soft",
    },
}
TITULO = {
    "es": {"gana_usuario": "🎉 ¡Ganaste!", "gana_claude": "🤖 Gané", "empate": "🤝 Empate"},
    "en": {"gana_usuario": "🎉 You won!", "gana_claude": "🤖 I won", "empate": "🤝 Tie"},
}
BUST = " 💥"


def mazo_nuevo():
    return [(rango, palo) for palo in PALOS for rango in RANGOS]


def mezclar():
    """Un mazo nuevo de 52 cartas, mezclado con el generador del sistema."""
    mazo = mazo_nuevo()
    secrets.SystemRandom().shuffle(mazo)
    return mazo


def carta(c):
    return c[0] + c[1]


def cartas(cs):
    return " ".join(carta(c) for c in cs)


def valor(rango):
    if rango == "A":
        return 11
    return 10 if rango in ("J", "Q", "K") else int(rango)


def total(mano):
    """(mejor total, blando). El as vale 11 mientras no pase la mano de 21;
    blando es que algún as sigue valiendo 11."""
    t = sum(valor(rango) for rango, _ in mano)
    ases = sum(rango == "A" for rango, _ in mano)
    while t > 21 and ases:
        t -= 10
        ases -= 1
    return t, ases > 0


def es_natural(mano):
    return len(mano) == 2 and total(mano)[0] == 21


def jugar(plan, mazo):
    """Una mano completa con el mazo dado (no lo modifica). Devuelve las manos
    finales, si hubo blackjack natural y el resultado."""
    mazo = list(mazo)
    u, c = [mazo.pop(0)], [mazo.pop(0)]
    u.append(mazo.pop(0))
    c.append(mazo.pop(0))
    nu, nc = es_natural(u), es_natural(c)
    if nu or nc:
        resultado = "empate" if nu and nc else ("gana_usuario" if nu else "gana_claude")
        return {"plan": plan, "usuario": u, "crupier": c, "natural": True, "resultado": resultado}
    while total(u)[0] < plan:
        u.append(mazo.pop(0))
    tu = total(u)[0]
    if tu <= 21:
        while total(c)[0] < CRUPIER_SE_PLANTA_EN:
            c.append(mazo.pop(0))
    tc = total(c)[0]
    if tu > 21:
        resultado = "gana_claude"
    elif tc > 21 or tu > tc:
        resultado = "gana_usuario"
    else:
        resultado = "gana_claude" if tc > tu else "empate"
    return {"plan": plan, "usuario": u, "crupier": c, "natural": False, "resultado": resultado}


def _lab(blando, T):
    return T["blando"] if blando else ""


def _jugadas(mano, T, q):
    """Las líneas de las cartas pedidas y de plantarse; q es "u" o "c"."""
    lineas, actual = [], mano[:2]
    for nueva in mano[2:]:
        t, b = total(actual)
        actual = actual + [nueva]
        t2, b2 = total(actual)
        datos = {"t": t, "bl": _lab(b, T), "c": carta(nueva), "t2": t2, "bl2": _lab(b2, T)}
        if t2 > 21:
            lineas.append(T[q + "_pasa"].format(**datos))
        else:
            lineas.append(T[q + "_pide"].format(**datos))
            if b and not b2:
                lineas.append(T["as_vale_1"])
    t, b = total(actual)
    if t <= 21:
        lineas.append(T[q + "_planta"].format(t=t, bl=_lab(b, T)))
    return lineas


def renderizar(p, idioma):
    """La respuesta completa: el log en un bloque y, después, el título."""
    T = PLANTILLAS[idioma]
    u, c = p["usuario"], p["crupier"]
    tu0, bu0 = total(u[:2])
    tc0, bc0 = total(c[:2])

    reparto = [T["sec_reparto"]]
    if es_natural(u[:2]):
        reparto.append(T["u_reparto_bj"].format(cs=cartas(u[:2])))
    else:
        reparto.append(T["u_reparto"].format(cs=cartas(u[:2]), t=tu0, bl=_lab(bu0, T)))
    reparto.append(T["c_reparto"].format(c=carta(c[0])))
    bloques = [reparto]

    if p["natural"]:
        bj = [T["sec_bj"]]
        if es_natural(c[:2]):
            bj.append(T["c_vuelta_bj"].format(c=carta(c[1])))
        else:
            bj.append(T["c_vuelta"].format(c=carta(c[1]), t=tc0, bl=_lab(bc0, T)))
        bj.append(T["bj_ambos" if es_natural(u[:2]) and es_natural(c[:2])
                    else "bj_u" if es_natural(u[:2]) else "bj_c"])
        bloques.append(bj)
    else:
        bloques.append([T["sec_turno_u"].format(n=p["plan"])] + _jugadas(u, T, "u"))
        turno_c = [T["sec_turno_c"], T["c_vuelta"].format(c=carta(c[1]), t=tc0, bl=_lab(bc0, T))]
        if total(u)[0] > 21:
            turno_c.append(T["c_no_pide"])
        else:
            turno_c += _jugadas(c, T, "c")
        bloques.append(turno_c)

    tu, tc = total(u)[0], total(c)[0]
    bloques.append([T["final"].format(
        tu=tu, xu=BUST if tu > 21 else "", tc=tc, xc=BUST if tc > 21 else "")])

    log = "\n\n".join("\n".join(b) for b in bloques)
    return f"```text\n{log}\n```\n\n## {TITULO[idioma][p['resultado']]}"


def respuestas(p):
    return {idioma: renderizar(p, idioma) for idioma in PLANTILLAS}


def parsear_plan(texto):
    if not re.fullmatch(r"[0-9]{1,2}", texto) or not PLAN_MIN <= int(texto) <= PLAN_MAX:
        raise ValueError(f"Plan no válido: {texto}. Indica un número del {PLAN_MIN} al {PLAN_MAX}.")
    return int(texto)


def error(mensaje):
    print(json.dumps({"error": mensaje}, ensure_ascii=False))
    return 1


def main():
    args = sys.argv[1:]
    if len(args) > 1:
        return error(f"Indica como máximo un plan: un número del {PLAN_MIN} al {PLAN_MAX}.")
    try:
        plan = parsear_plan(args[0]) if args else PLAN_DEFECTO
    except ValueError as e:
        return error(str(e))
    p = jugar(plan, mezclar())  # el mazo se mezcla sin mirar el plan
    print(json.dumps({
        "plan": plan,
        "resultado": p["resultado"],
        "usuario": {"cartas": [carta(x) for x in p["usuario"]], "total": total(p["usuario"])[0]},
        "crupier": {"cartas": [carta(x) for x in p["crupier"]], "total": total(p["crupier"])[0]},
        "respuesta": respuestas(p),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
