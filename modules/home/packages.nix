{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [ pygobject3 pycairo ]);

  # GObject introspection typelib paths required by the GTK3 Python popup.
  # Note: glib/pango default output is "bin" (no typelibs) — must use .out.
  # atk was merged into at-spi2-core in modern nixpkgs.
  giTypelibs = builtins.concatStringsSep ":" [
    "${pkgs.gtk3}/lib/girepository-1.0"
    "${pkgs.glib.out}/lib/girepository-1.0"
    "${pkgs.pango.out}/lib/girepository-1.0"
    "${pkgs.gdk-pixbuf}/lib/girepository-1.0"
    "${pkgs.at-spi2-core}/lib/girepository-1.0"
    "${pkgs.harfbuzz}/lib/girepository-1.0"
  ];

  volumePopupScript = pkgs.writeText "volume-popup.py"
    (builtins.readFile ../../dotfiles/waybar/scripts/volume-popup.py);

  volumePopup = pkgs.writeShellScriptBin "waybar-volume-popup" ''
    export GI_TYPELIB_PATH="${giTypelibs}:$GI_TYPELIB_PATH"
    export PATH="${pkgs.pulseaudio}/bin:$PATH"
    exec ${pythonEnv}/bin/python3 ${volumePopupScript} "$@"
  '';

  # Wrapper around brightnessctl that enforces a 5% floor — going to 0%
  # blanks the screen with no way to see it again to bring it back up.
  brightnessCtl = pkgs.writeShellScriptBin "brightness-ctl" ''
    set -euo pipefail
    MIN=5
    dir="$1"
    step="''${2:-5}"

    cur=$(${pkgs.brightnessctl}/bin/brightnessctl -m | awk -F, '{print $4}' | tr -d '%')

    if [ "$dir" = "inc" ]; then
      ${pkgs.brightnessctl}/bin/brightnessctl set "+''${step}%"
    else
      target=$((cur - step))
      if [ "$target" -lt "$MIN" ]; then
        target=$MIN
      fi
      ${pkgs.brightnessctl}/bin/brightnessctl set "''${target}%"
    fi
  '';

  # Wrapper around pactl that caps sink volume at 100% — pactl's raw +N%
  # otherwise allows boosting past 100% (up to ~153%), which distorts audio.
  volumeCtl = pkgs.writeShellScriptBin "volume-ctl" ''
    set -euo pipefail
    MAX=100
    PACTL=${pkgs.pulseaudio}/bin/pactl
    dir="$1"
    step="''${2:-5}"

    if [ "$dir" = "mute" ]; then
      $PACTL set-sink-mute @DEFAULT_SINK@ toggle
      exit 0
    fi

    cur=$($PACTL get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+(?=%)' | head -1)
    $PACTL set-sink-mute @DEFAULT_SINK@ 0

    if [ "$dir" = "inc" ]; then
      target=$((cur + step))
      if [ "$target" -gt "$MAX" ]; then
        target=$MAX
      fi
    else
      target=$((cur - step))
      if [ "$target" -lt 0 ]; then
        target=0
      fi
    fi
    $PACTL set-sink-volume @DEFAULT_SINK@ "''${target}%"
  '';
in

{
  home.packages = with pkgs; [
    brave # Web Browser
    kitty # Terminal
    fastfetch # Fastfetch
    waybar # TaskBar
    rofi # Launcher program
    hyprpaper # Wallpaper
    wallust # Gera paleta de cores a partir do wallpaper (design system)
    xfce.thunar # File Explorer
    mako # Notification daemon
    discord # Voice channel
    gsimplecal # Calendário popup (abre ao clicar no relógio)
    brightnessctl # Controle de brilho via scroll no módulo backlight
    pavucontrol # Mixer de áudio completo
    pulseaudio # Ferramentas de cliente PulseAudio (pactl) — compatível com PipeWire

    # Fonts (Nerd Fonts para ícones da waybar)
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only

    # Volume popup para waybar
    volumePopup

    # Wrapper de brilho com piso de 5% (protege contra tela apagada em 0%)
    brightnessCtl

    # Wrapper de volume com teto de 100% (evita distorção do áudio)
    volumeCtl
  ];
}
