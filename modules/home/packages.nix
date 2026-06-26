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
  ];
}
