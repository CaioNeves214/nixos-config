{ config, ... }:

{
  # config.jsonc NÃO é symlinkado aqui: é gerado pelo wallust (design system),
  # pois o calendário usa cores inline (Pango markup, sem @import).
  # Fonte: dotfiles/wallust/templates/waybar-config.jsonc.
  #
  # Aponta para o perfil ativo (ver comentário em hyprland.nix).
  xdg.configFile."waybar/style.css".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/waybar/style.css";
}
