{ config, ... }:

{
  # Aponta para o perfil ativo (ver comentário em hyprland.nix).
  xdg.configFile."kitty/kitty.conf".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/kitty/kitty.conf";
}
