#!/usr/bin/env python3
"""Elige la jugada de Claude al azar, decide el resultado y arma la línea a mostrar.

Uso: python3 jugada.py <piedra|papel|tijera>   (también rock, paper, scissors)
Salida (JSON):
  {"usuario": ..., "claude": ..., "resultado": "gana_usuario|gana_claude|empate",
   "linea": {"es": "Vos: ✊ piedra · Claude: ✋ papel → gana Claude 🤖",
             "en": "You: ✊ rock · Claude: ✋ paper → Claude wins 🤖"}}
"""
import json
import secrets
import sys
import unicodedata

OPCIONES = ["piedra", "papel", "tijera"]
GANA_A = {"piedra": "tijera", "papel": "piedra", "tijera": "papel"}
ALIAS = {
    "tijeras": "tijera", "roca": "piedra", "hoja": "papel",
    "rock": "piedra", "stone": "piedra",
    "paper": "papel",
    "scissors": "tijera", "scissor": "tijera",
}

# Lo que se muestra: el emoji de cada mano, los nombres en inglés y el resultado.
EMOJI = {"piedra": "✊", "papel": "✋", "tijera": "✌️"}
EN = {"piedra": "rock", "papel": "paper", "tijera": "scissors"}
RESULTADO = {
    "es": {"gana_usuario": "ganás vos 🎉", "gana_claude": "gana Claude 🤖", "empate": "empate 🤝"},
    "en": {"gana_usuario": "you win 🎉", "gana_claude": "Claude wins 🤖", "empate": "tie 🤝"},
}


def normalizar(texto: str) -> str:
    texto = unicodedata.normalize("NFKD", texto.strip().lower())
    texto = "".join(c for c in texto if not unicodedata.combining(c))
    return ALIAS.get(texto, texto)


def resolver(usuario: str, claude: str) -> str:
    """Resultado de una ronda; las dos jugadas ya normalizadas."""
    if usuario == claude:
        return "empate"
    return "gana_usuario" if GANA_A[usuario] == claude else "gana_claude"


def linea(usuario: str, claude: str, resultado: str) -> dict:
    """La línea que Claude muestra, en cada idioma."""
    def mano(jugada, nombre):
        return f"{EMOJI[jugada]} {nombre}"
    return {
        "es": f"Vos: {mano(usuario, usuario)} · Claude: {mano(claude, claude)} → {RESULTADO['es'][resultado]}",
        "en": f"You: {mano(usuario, EN[usuario])} · Claude: {mano(claude, EN[claude])} → {RESULTADO['en'][resultado]}",
    }


def main() -> int:
    if len(sys.argv) != 2:
        print(json.dumps({"error": "Indica una jugada: piedra, papel o tijera"}))
        return 1
    usuario = normalizar(sys.argv[1])
    if usuario not in OPCIONES:
        print(json.dumps({"error": f"Jugada no válida: {sys.argv[1]}"}, ensure_ascii=False))
        return 1
    claude = secrets.choice(OPCIONES)  # no depende de la jugada del usuario
    resultado = resolver(usuario, claude)
    print(json.dumps(
        {"usuario": usuario, "claude": claude, "resultado": resultado,
         "linea": linea(usuario, claude, resultado)},
        ensure_ascii=False,
    ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
