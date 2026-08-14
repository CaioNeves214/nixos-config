{ config, lib, pkgs, ... }:

let
  repoDir = "/home/caio/nix-config";

  profilesDir = "${repoDir}/dotfiles/profiles";

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

  # palette.toml (semântico) -> colorscheme do wallust (19 chaves cruas).
  # tomllib é stdlib desde o 3.11, então não precisa de pacote extra.
  paletteToWallust = "${pkgs.python3}/bin/python3 ${repoDir}/dotfiles/scripts/palette-to-wallust.py";

  # Recarrega os apps para aplicar cor/estilo novos. Usado pelos dois comandos.
  reloadApps = ''
    command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true

    # Nem todo perfil roda waybar (o 'nous' usa uma barra Quickshell própria e
    # não tem dotfiles/profiles/nous/waybar/). Sobe/recarrega só quando o
    # perfil ativo tem essa pasta; mata quando não tem, senão a waybar do
    # perfil anterior continua rodando por cima da barra nova.
    if [ -d "$HOME/.config/theme/active/waybar" ]; then
      pgrep waybar >/dev/null 2>&1 || hyprctl dispatch exec waybar >/dev/null 2>&1 || true
      pkill -SIGUSR2 waybar 2>/dev/null || true
    else
      pkill waybar 2>/dev/null || true
    fi
    pkill -SIGUSR1 kitty  2>/dev/null || true

    # GTK3 só monitora o gtk.css, não o colors.css que ele @importa — apps GTK
    # abertos não pegam a paleta nova sozinhos. Mata só o daemon de fundo do
    # Thunar (reativado por D-Bus na próxima abertura, já com a paleta nova);
    # janelas abertas do usuário não são fechadas, pegam a cor ao reabrir.
    pkill -f 'thunar --daemon' 2>/dev/null || true

    # O Quickshell observa o inode resolvido do shell.qml; trocar para onde o
    # symlink 'active' aponta não emite evento de inotify, então ele não
    # recarrega sozinho numa troca de perfil — precisa reiniciar de fato.
    #
    # SEM `-x`: no NixOS o binário roda por um wrapper, então o `comm` do
    # processo é ".quickshell-wra" (truncado em 15 chars), não "quickshell".
    # Com -x o match falha em silêncio e o widget fica com o QML do perfil
    # anterior. Mesma razão pela qual os pkill de waybar/kitty acima não usam -x.
    if pgrep quickshell >/dev/null 2>&1; then
      pkill quickshell 2>/dev/null || true
      if command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch exec quickshell >/dev/null 2>&1 || true
      fi
    fi
  '';

  # ── Troca o perfil visual inteiro (hypr/kitty/waybar/rofi/quickshell) ──────
  themeProfile = pkgs.writeShellScriptBin "theme-profile" ''
    set -euo pipefail
    export PATH="${pkgs.lib.makeBinPath [ pkgs.wallust pkgs.procps pkgs.coreutils ]}:$PATH"

    ACTIVE="$HOME/.config/theme/active"
    SDDM_DIR="/var/lib/sddm-theme"

    name="''${1:-}"

    # Sem argumento: mostra o perfil atual e os disponíveis.
    if [ -z "$name" ]; then
      echo "Perfil atual: $(cat "$HOME/.cache/current-profile" 2>/dev/null || echo '(desconhecido)')"
      echo "Disponíveis:"
      for d in ${profilesDir}/*/; do
        [ -d "$d" ] && echo "  - $(basename "$d")"
      done
      exit 0
    fi

    if [ ! -d "${profilesDir}/$name" ]; then
      echo "Perfil não encontrado: $name" >&2
      echo "Rode 'theme-profile' sem argumento para listar os disponíveis." >&2
      exit 1
    fi

    # Flip atômico do ponteiro. Precisa vir ANTES de gerar as cores: o
    # config.jsonc renderizado inclui active/waybar/geometry.jsonc.
    mkdir -p "$HOME/.config/theme"
    ln -sfnT "${profilesDir}/$name" "$ACTIVE.tmp"
    mv -Tf "$ACTIVE.tmp" "$ACTIVE"

    mkdir -p "$HOME/.cache"
    printf '%s\n' "$name" > "$HOME/.cache/current-profile.tmp"
    mv -f "$HOME/.cache/current-profile.tmp" "$HOME/.cache/current-profile"

    echo ":: Perfil: $name"

    # Cores: paleta fixa do perfil, ou extração do wallpaper (comportamento
    # histórico, para perfis sem palette.toml).
    if [ -f "${profilesDir}/$name/palette.toml" ]; then
      mkdir -p "$HOME/.config/wallust/colorschemes"
      ${paletteToWallust} "${profilesDir}/$name/palette.toml" \
        > "$HOME/.config/wallust/colorschemes/$name.json.tmp"
      mv -f "$HOME/.config/wallust/colorschemes/$name.json.tmp" \
            "$HOME/.config/wallust/colorschemes/$name.json"
      # -s: não injeta sequências OSC em todo terminal aberto.
      wallust cs -q -s "$name"
      echo ":: Paleta fixa aplicada (palette.toml)."
    else
      if [ -e "$HOME/.cache/current-wallpaper" ]; then
        wallust run -q "$(readlink -f "$HOME/.cache/current-wallpaper")"
        echo ":: Paleta extraída do wallpaper atual."
      else
        echo ":: (aviso) sem wallpaper atual — rode 'update-theme <imagem>'." >&2
      fi
    fi

    # A tela de login segue só a cor; o wallpaper dela é trabalho do update-theme.
    if [ -w "$SDDM_DIR" ] && [ -f "$HOME/.cache/sddm-colors.conf" ]; then
      cp -f "$HOME/.cache/sddm-colors.conf" "$SDDM_DIR/colors.conf"
    fi

    ${reloadApps}

    echo ":: Perfil aplicado."
  '';

  # ── Wrapper que aplica wallpaper + regenera a paleta + recarrega os apps ───
  updateTheme = pkgs.writeShellScriptBin "update-theme" ''
    set -euo pipefail
    export PATH="${pkgs.lib.makeBinPath [ pkgs.wallust pkgs.procps pkgs.coreutils pkgs.imagemagick ]}:$PATH"

    WALLPAPER_DIR="$HOME/.config/wallpapers"
    CURRENT="$HOME/.cache/current-wallpaper"
    ACTIVE="$HOME/.config/theme/active"
    # Artefatos da tela de login: o greeter roda como 'sddm' e não lê $HOME.
    SDDM_DIR="/var/lib/sddm-theme"

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

    # Extrai a paleta e renderiza os includes de cor — MAS só se o perfil ativo
    # deriva cor do wallpaper. Num perfil de paleta fixa isso destruiria a
    # paleta; lá o wallpaper é só imagem de fundo.
    if [ -f "$ACTIVE/palette.toml" ]; then
      echo ":: Perfil ativo tem paleta fixa — cores preservadas."
    else
      wallust run -q "$wp"
    fi

    # Tela de login: mesmo wallpaper, nítido + versão borrada (o QML dissolve o
    # borrão ao logar), mais a foto de usuário recortada em quadrado.
    if [ -w "$SDDM_DIR" ]; then
      [ -f "$HOME/.cache/sddm-colors.conf" ] && \
        cp -f "$HOME/.cache/sddm-colors.conf" "$SDDM_DIR/colors.conf"

      magick "$wp" -resize '2560x2560>' -quality 90 "$SDDM_DIR/wallpaper.jpg"
      magick "$wp" -resize '1280x1280>' -blur 0x28 -resize 200% -quality 85 \
        "$SDDM_DIR/wallpaper-blur.jpg"

      avatar_src="$(ls ${repoDir}/dotfiles/sddm/avatar.* 2>/dev/null | head -n1 || true)"
      if [ -n "$avatar_src" ]; then
        magick "$avatar_src" -resize '296x296^' -gravity center -extent 296x296 \
          "$SDDM_DIR/avatar.png"
      fi
    else
      echo ":: (login) $SDDM_DIR ausente — rode 'sudo nixos-rebuild switch' uma vez." >&2
    fi

    ${reloadApps}

    echo ":: Tema atualizado."
  '';
in
{
  home.packages = [ updateTheme wallpaperPicker themeProfile ];

  # Os módulos de app apontam para ~/.config/theme/active/...; sem esse symlink
  # os alvos ficam pendurados e nenhum app acha a própria config. Idempotente:
  # só cria se estiver ausente (ou quebrado — `-e` segue o symlink).
  home.activation.themeProfileBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/theme/active" ]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.config/theme"
      $DRY_RUN_CMD ln -sfn "${profilesDir}/default" "$HOME/.config/theme/active"
      $DRY_RUN_CMD mkdir -p "$HOME/.cache"
      $DRY_RUN_CMD sh -c 'echo default > "$HOME/.cache/current-profile"'
      echo ":: perfil visual inicializado em 'default' (troque com: theme-profile <nome>)"
    fi
  '';

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
