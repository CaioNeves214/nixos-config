{ pkgs, ... }:
{
  programs.thunar = {
    enable = true; # já liga programs.xfconf.enable
    plugins = with pkgs.xfce; [ thunar-archive-plugin ];
  };

  services.gvfs.enable = true; # lixeira, montagem, backends remotos
  services.tumbler.enable = true; # miniaturas (imagem/vídeo/PDF)

  # thunar-volman fica deliberadamente fora: ele faz auto-ação em mídia
  # removível, papel que udiskie --tray já cumpre neste rice (modules/home/packages.nix).
  # Ligar os dois duplica notificação e montagem.
}
