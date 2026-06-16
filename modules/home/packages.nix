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
   ];
 }
