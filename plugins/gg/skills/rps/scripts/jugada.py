#!/usr/bin/env python3
"""Elige la jugada de Claude al azar, decide el resultado y arma la respuesta.

Uso: python3 jugada.py <piedra|papel|tijera>   (también rock, paper, scissors)
Salida (JSON):
  {"usuario": ..., "claude": ..., "resultado": "gana_usuario|gana_claude|empate",
   "respuesta": {"es": ..., "en": ...}}
"respuesta" es la respuesta completa que Claude muestra, en markdown: un título
con el resultado y, debajo, un bloque con las dos jugadas. Por ejemplo:

    ## 🎉 ¡Ganaste!

    ```text
    Vos  piedra ✊
    Yo   tijera ✌️
    ```
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

# Lo que se muestra. Claude habla en primera persona: "Yo" es Claude.
EMOJI = {"piedra": "✊", "papel": "✋", "tijera": "✌️"}
NOMBRE = {
    "es": {"piedra": "piedra", "papel": "papel", "tijera": "tijera"},
    "en": {"piedra": "rock", "papel": "paper", "tijera": "scissors"},
}
FILAS = {"es": ("Vos", "Yo"), "en": ("You", "Me")}
TITULO = {
    "es": {"gana_usuario": "🎉 ¡Ganaste!", "gana_claude": "🤖 Gané", "empate": "🤝 Empate"},
    "en": {"gana_usuario": "🎉 You won!", "gana_claude": "🤖 I won", "empate": "🤝 Tie"},
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


def respuesta(usuario: str, claude: str, resultado: str) -> dict:
    """La respuesta completa en cada idioma.

    En la tabla, el relleno es ASCII y va antes del emoji, que cierra la línea:
    así el ancho variable de los emojis no desalinea nada.
    """
    out = {}
    for idioma, nombres in NOMBRE.items():
        ancho_fila = max(len(f) for f in FILAS[idioma]) + 2
        ancho_jugada = max(len(n) for n in nombres.values())
        filas = [
            f"{fila:<{ancho_fila}}{nombres[jugada]:<{ancho_jugada}} {EMOJI[jugada]}"
            for fila, jugada in zip(FILAS[idioma], (usuario, claude))
        ]
        out[idioma] = "\n".join(
            [f"## {TITULO[idioma][resultado]}", "", "```text", *filas, "```"])
    return out


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
         "respuesta": respuesta(usuario, claude, resultado)},
        ensure_ascii=False,
    ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
