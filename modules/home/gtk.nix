{ config, lib, pkgs, ... }:

let
  repoDir = "/home/caio/nix-config";
  thunarSeed = "${repoDir}/dotfiles/thunar/thunar-xfconf.xml";
  xfconfTarget = "${config.home.homeDirectory}/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml";
in
{
  gtk = {
    enable = true;
    theme = { name = "Adwaita-dark"; }; # base coerente sob o CSS — Adwaita compila
    # regras com hex literal e ignora @define-color do usuário fora do que
    # escrevermos no gtk.css do perfil, então um base escuro evita remendo.
    iconTheme = { name = "Tela-black-dark"; package = pkgs.tela-icon-theme; };
    font = { name = "IBM Plex Sans"; size = 10; }; # baseline; perfil sobrescreve via CSS
    gtk3.extraConfig = { gtk-application-prefer-dark-theme = 1; };
    # gtk.gtk3.extraCss NÃO é usado: o módulo do HM só declara gtk-3.0/gtk.css
    # sob mkIf (extraCss != ""), e é essa brecha que libera o arquivo para o
    # symlink out-of-store do perfil abaixo. Ver invariante 3 do plano.
  };

  # Symlinks: caminho constante sob active/ (padrão de kitty.nix/rofi.nix).
  xdg.configFile."gtk-3.0/gtk.css".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/gtk/gtk.css";

  xdg.configFile."Thunar/uca.xml".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/dotfiles/thunar/uca.xml";

  # O Thunar reescreve xfconf/xfce-perchannel-xml/thunar.xml por rename atômico
  # a cada mudança de preferência — um symlink para o repo quebraria nessa
  # troca. Por isso a semente é copiada, uma única vez, se o arquivo ainda não
  # existir (mesmo padrão do hook themeProfileBootstrap em theme.nix).
  home.activation.thunarXfconfSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${xfconfTarget}" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "${xfconfTarget}")"
      $DRY_RUN_CMD cp "${thunarSeed}" "${xfconfTarget}"
    fi
  '';
}
