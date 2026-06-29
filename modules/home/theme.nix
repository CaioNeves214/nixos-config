{ config, pkgs, ... }:

let
  repoDir = "/home/caio/nix-config";

  # ── Picker GTK3: janela popup de seleção de wallpaper (SUPER+W) ────────────
  pickerScript = "${repoDir}/dotfiles/scripts/wallpaper-picker.py";

  pickerEnv = pkgs.python3.withPackages (ps: with ps; [ pygobject3 pycairo ]);

  pickerTypelibs = builtins.concatStringsSep ":" [
    "${pkgs.gtk3}/lib/girepository-1.0"
    "${pkgs.glib.out}/lib/girepository-1.0"
    "${pkgs.pango.out}/lib/girepository-1.0"
    "${pkgs.gdk-pixbuf}/lib/girepository-1.0"
    "${pkgs.at-spi2-core}/lib/girepository-1.0"
    "${pkgs.harfbuzz}/lib/girepository-1.0"
  ];

  wallpaperPicker = pkgs.writeShellScriptBin "wallpaper-picker" ''
    export GI_TYPELIB_PATH="${pickerTypelibs}:''${GI_TYPELIB_PATH:-}"
    exec ${pickerEnv}/bin/python3 ${pickerScript} "$@"
  '';

  # ── Wrapper que aplica wallpaper + regenera a paleta + recarrega os apps ───
  updateTheme = pkgs.writeShellScriptBin "update-theme" ''
    set -euo pipefail
    export PATH="${pkgs.lib.makeBinPath [ pkgs.wallust pkgs.procps pkgs.coreutils ]}:$PATH"

    WALLPAPER_DIR="$HOME/.config/wallpapers"
    CURRENT="$HOME/.cache/current-wallpaper"

    # Resolve a imagem: argumento (nome ou caminho absoluto) ou o wallpaper atual.
    arg="''${1:-}"
    if [ -z "$arg" ]; then
      if [ -e "$CURRENT" ]; then
        wp="$(readlink -f "$CURRENT")"
      else
        echo "Uso: update-theme <imagem|caminho>  (nenhum wallpaper atual definido)" >&2
        exit 1
      fi
    elif [ -f "$arg" ]; then
      wp="$(readlink -f "$arg")"
    elif [ -f "$WALLPAPER_DIR/$arg" ]; then
      wp="$(readlink -f "$WALLPAPER_DIR/$arg")"
    else
      echo "Wallpaper não encontrado: $arg" >&2
      exit 1
    fi

    echo ":: Wallpaper: $wp"

    # Ponteiro 'current' usado pelo hyprpaper para reaplicar no boot.
    mkdir -p "$(dirname "$CURRENT")"
    ln -sf "$wp" "$CURRENT"

    # Aplica o wallpaper ao vivo (hyprctl vem da sessão Hyprland em execução).
    if command -v hyprctl >/dev/null 2>&1; then
      hyprctl hyprpaper unload all      >/dev/null 2>&1 || true
      hyprctl hyprpaper preload "$wp"   >/dev/null 2>&1 || true
      hyprctl hyprpaper wallpaper ",$wp" >/dev/null 2>&1 || true
    fi

    # Extrai a paleta e renderiza os includes de cor (kitty/hypr/waybar).
    wallust run -q "$wp"

    # Recarrega os apps para aplicar as novas cores.
    command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
    pkill -SIGUSR2 waybar 2>/dev/null || true
    pkill -SIGUSR1 kitty  2>/dev/null || true

    echo ":: Tema atualizado."
  '';
in
{
  home.packages = [ updateTheme wallpaperPicker ];

  # Symlinks ao vivo: editar no repo reflete sem rebuild.
  xdg.configFile."wallust/wallust.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/dotfiles/wallust/wallust.toml";

  xdg.configFile."wallust/templates".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/dotfiles/wallust/templates";

  xdg.configFile."wallpapers".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/dotfiles/wallpapers";

  # hyprpaper reaplica o wallpaper atual no boot via o ponteiro 'current'.
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = /home/caio/.cache/current-wallpaper
    wallpaper = ,/home/caio/.cache/current-wallpaper
    splash = false
  '';
}
