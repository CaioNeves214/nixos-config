{ config, ... }:

{
  # Aponta para o perfil ativo (ver comentário em hyprland.nix).
  # config.rasi faz `@theme "theme.rasi"` relativo, que resolve dentro do próprio
  # perfil — cada perfil traz o seu tema.
  xdg.configFile."rofi/config.rasi".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/rofi/config.rasi";

  xdg.configFile."rofi/theme.rasi".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/rofi/theme.rasi";
}
