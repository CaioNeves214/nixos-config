---
name: gtk-popups
description: Popups GTK3 em Python (PyGObject) deste rice — volume-popup e wallpaper-picker: como empacotá-los no NixOS (GI_TYPELIB_PATH, typelibs .out) e como fazem para ler a paleta em runtime. Use ao criar/editar qualquer script Python com Gtk/PyGObject, ao depurar "Namespace not available"/typelib faltando, ao mexer em dotfiles/scripts/*.py, dotfiles/waybar/scripts/volume-popup.py, ou nos lets giTypelibs/pickerTypelibs em modules/home/{packages,theme}.nix.
---

# Popups GTK3 em Python

Dois scripts PyGObject compõem a camada de popup deste rice:

| Script | O que é | Disparo |
|---|---|---|
| `dotfiles/waybar/scripts/volume-popup.py` | popup de volume | módulo/keybind |
| `dotfiles/scripts/wallpaper-picker.py` | seletor de tema/wallpaper | **SUPER+W** no `hyprland.conf` |

Ambos são wrappados em Nix (`modules/home/packages.nix` para o volume, `modules/home/theme.nix`
para o picker) e ficam no `PATH`. Como são scripts em `dotfiles/`, **editar o `.py` tem efeito
imediato** — só a mudança do wrapper exige `nixos-rebuild switch`.

## Empacotamento: `GI_TYPELIB_PATH` é obrigatório

No NixOS o PyGObject não acha os typelibs sozinho. O wrapper tem que injetar
`GI_TYPELIB_PATH` com os **outputs `.out`** das libs — não o output default, que não contém
`lib/girepository-1.0/`. Padrão usado aqui (lets `giTypelibs` / `pickerTypelibs`):

```nix
let
  giTypelibs = with pkgs; [
    glib.out
    gtk3
    pango.out
    gdk-pixbuf
    atk
    harfbuzz.out
    at-spi2-core          # necessário mesmo sem acessibilidade explícita
    gobject-introspection
  ];
in
pkgs.symlinkJoin {
  name = "volume-popup";
  paths = [ script ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/volume-popup \
      --set GI_TYPELIB_PATH "${pkgs.lib.makeSearchPath "lib/girepository-1.0" giTypelibs}" \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.pulseaudio ]}
  '';
}
```

Pontos que já quebraram antes:

- **`.out` explícito** em `glib`, `pango`, `harfbuzz` — sem isso o typelib não está no caminho.
- **`at-spi2-core`** entra mesmo sem usar acessibilidade; o GTK3 o carrega.
- **`--prefix PATH`** com as CLIs que o script chama (`pulseaudio`/`pactl` para o volume). Um
  script que chama binário externo sem isso funciona no terminal e falha quando lançado pelo
  Hyprland.
- **GTK3, não GTK4.** GTK4 nesta GPU precisa de `GSK_RENDERER=ngl` ou não desenha texto — skill
  **`hardware-quirks`**. Se for escrever um popup novo, GTK3 é o caminho já pavimentado.

Padrão geral de wrapper: skill **`nix-wiring`**.

## Cor: leitura em runtime, não `@import`

Esses scripts não têm mecanismo de import de CSS externo, então leem o `rofi/colors.rasi`
**gerado** em runtime com um `load_colors()` de regex e montam o CSS a partir dos tokens:

```python
def load_colors():
    path = os.path.expanduser("~/.config/rofi/colors.rasi")
    colors = dict(FALLBACK)                      # só entra em ação se o arquivo faltar
    try:
        text = open(path).read()
    except OSError:
        return colors
    for name, value in re.findall(r"(\w+):\s*(#[0-9a-fA-F]{3,8});", text):
        colors[name] = value
    return colors
```

Duas regras:

1. **A paleta de fallback existe só para checkout limpo** (o `colors.rasi` é gitignored e não
   existe antes do primeiro `update-theme`). Nunca é onde se escolhe cor.
2. **Mantenha os fallbacks dos dois scripts em sincronia.** Eles usam o mesmo padrão; divergir
   produz dois looks diferentes num checkout novo.

Um perfil pode sobrepor o estilo dos popups via `dotfiles/profiles/<name>/gtk/popups.css`. Detalhes
do pipeline de cor: skill **`design-system`**.

## Depurar

- Rode pelo terminal primeiro; erro de typelib aparece como
  `ValueError: Namespace <X> not available`.
- Se funciona no terminal mas não pelo keybind, é `PATH`/env faltando no wrapper — o Hyprland não
  passa o ambiente do shell.
- Para navegar o código destes scripts, use `mcp__codebase-memory__*` antes de `Read` — eles estão
  indexados (`get_code_snippet`, `search_graph`).
