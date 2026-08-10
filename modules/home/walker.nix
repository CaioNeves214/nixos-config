{ config, ... }:

{
  # Aponta para o perfil ativo (ver comentário em hyprland.nix/rofi.nix).
  # Symlinks individuais, NÃO o diretório "walker/" inteiro: o wallust
  # escreve colors.css direto em ~/.config/walker/ (ver template
  # colors-walker.css em wallust.toml), então esse diretório precisa
  # continuar real/gravável — mesmo motivo do gotcha documentado para o
  # quickshell.
  xdg.configFile."walker/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/walker/config.toml";

  xdg.configFile."walker/themes/walker.css".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/walker/themes/walker.css";
}
