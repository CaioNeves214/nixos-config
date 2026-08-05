{ config, ... }:

{
  # Perfis visuais: o HM aponta para um caminho CONSTANTE
  # (~/.config/theme/active/...), e é o symlink `active` que muda de perfil.
  # Como o alvo declarado aqui nunca varia, o check-link-targets do HM nunca
  # acusa colisão — um script re-apontando um caminho declarado pelo HM faria
  # o `nixos-rebuild switch` abortar. Ver "Perfis visuais" no CLAUDE.md.
  #
  # hyprpaper.conf é gerado/gerido pelo theme.nix (design system).
  xdg.configFile."hypr/hyprland.conf".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/hypr/hyprland.conf";
}
