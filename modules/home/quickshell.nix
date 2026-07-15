{ config, ... }:

{
  # Edição ao vivo: mudanças em dotfiles/quickshell/ recarregam sem switch
  # (Quickshell observa o QML e recarrega sozinho).
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/quickshell;
}
