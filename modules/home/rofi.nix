{ config, ... }:

{
  xdg.configFile."rofi/config.rasi".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/rofi/config.rasi;

  xdg.configFile."rofi/theme.rasi".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/rofi/theme.rasi;
}
