{ pkgs, ... }:

 {
   home.packages = with pkgs; [
     brave # Web Browser
     kitty # Terminal
     fastfetch # Fastfecth
     waybar # TaskBar
     rofi # Launcher program
     hyprpaper # Wallpaper
     xfce.thunar # File Explorer
     mako # ? (find out)
     discord # voice channel
     gsimplecal # Calendário popup (abre ao clicar no relógio)
     brightnessctl # Controle de brilho via scroll no módulo backlight
     pavucontrol # Mixer de áudio (abre ao clicar no volume)

     # Fonts (Nerd Fonts para ícones da waybar)
     nerd-fonts.jetbrains-mono
     nerd-fonts.symbols-only
   ];
 }
