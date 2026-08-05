#!/usr/bin/env python3
"""Converte o palette.toml semântico de um perfil no colorscheme do wallust.

O wallust espera um JSON plano de 19 chaves (`background`, `foreground`,
`cursor`, `color0`..`color15`) — nomes que não dizem nada sobre o papel de cada
cor no design system. Este script deixa o perfil ser escrito em termos dos 5
tokens que os templates realmente usam, e faz o mapeamento aqui:

    base      -> background      text   -> foreground
    primary   -> color4          secondary -> color2      alert -> color1

Esse contrato é o mesmo dos templates em dotfiles/wallust/templates/ (ver a
tabela "Design System" no CLAUDE.md). Se ele mudar lá, muda aqui.

Uso:  palette-to-wallust <palette.toml>   # escreve o JSON no stdout
"""

import json
import sys
import tomllib

# Token semântico -> chave que o wallust (e os templates) esperam.
TOKEN_TO_WALLUST = {
    "base": "background",
    "text": "foreground",
    "primary": "color4",
    "secondary": "color2",
    "alert": "color1",
}

ANSI_KEYS = [f"color{i}" for i in range(16)]


def die(msg):
    print(f"palette-to-wallust: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        die("uso: palette-to-wallust <palette.toml>")

    path = sys.argv[1]
    try:
        with open(path, "rb") as fh:
            data = tomllib.load(fh)
    except FileNotFoundError:
        die(f"arquivo não encontrado: {path}")
    except tomllib.TOMLDecodeError as exc:
        die(f"TOML inválido em {path}: {exc}")

    missing = [t for t in TOKEN_TO_WALLUST if t not in data]
    if missing:
        die(f"tokens ausentes em {path}: {', '.join(sorted(missing))}")

    out = {}

    # A paleta ANSI completa vem primeiro: o kitty consome os 16, e o template
    # do waybar usa color6/color8 no calendário.
    ansi = data.get("ansi", {})
    for key in ANSI_KEYS:
        if key in ansi:
            out[key] = ansi[key]

    # Os tokens semânticos são a autoridade sobre os slots que ocupam — se o
    # bloco [ansi] também definiu color1/color2/color4, eles perdem aqui.
    for token, wallust_key in TOKEN_TO_WALLUST.items():
        out[wallust_key] = data[token]

    # O wallust exige os 16 slots. Faltando algum, é melhor falhar agora do que
    # deixar o kitty renderizar com uma cor indefinida.
    absent = [k for k in ANSI_KEYS if k not in out]
    if absent:
        die(f"faltam cores ANSI em {path}: {', '.join(absent)} (bloco [ansi])")

    out["cursor"] = data.get("cursor", data["primary"])

    # Ordem estável (background/foreground/cursor, depois color0..15) para o
    # diff do arquivo gerado ficar legível.
    ordered = {k: out[k] for k in ["background", "foreground", "cursor"] + ANSI_KEYS}
    json.dump(ordered, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
