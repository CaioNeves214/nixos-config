{ config, ... }:

{
  # config.jsonc NÃO é symlinkado aqui: é gerado pelo wallust (design system),
  # pois o calendário usa cores inline (Pango markup, sem @import).
  # Fonte: dotfiles/wallust/templates/waybar-config.jsonc.
  xdg.configFile."waybar/style.css".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/waybar/style.css;
}
