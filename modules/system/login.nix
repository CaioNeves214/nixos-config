# Tela de login (SDDM) com tema QML próprio: avatar + nome + senha sobre o
# wallpaper borrado, com fade + desborrão ao entrar na sessão.
#
# O greeter roda como o usuário 'sddm' e não enxerga /home/caio, então as cores e
# imagens vivem em /var/lib/sddm-theme — diretório do usuário caio, mundo-legível,
# populado pelo `update-theme` (ver modules/home/theme.nix) e pelo wallust.

{ pkgs, ... }:

let
  themeName = "caio";

  sddmTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "sddm-theme-${themeName}";
    version = "1.0";
    src = ../../dotfiles/sddm/theme;

    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/sddm/themes/${themeName}
      cp -r $src/* $out/share/sddm/themes/${themeName}/
      runHook postInstall
    '';
  };
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = themeName;

    # O padrão no 25.05 ainda é o sddm Qt5; o tema usa QtQuick.Effects (Qt6).
    package = pkgs.kdePackages.sddm;

    # QtQuick.Effects (máscara circular do avatar) + Controls usados pelo Main.qml.
    extraPackages = with pkgs.kdePackages; [
      qtdeclarative
      qtsvg
    ];
  };

  environment.systemPackages = [ sddmTheme ];

  # O Main.qml lê o colors.conf via XMLHttpRequest em file://, que o Qt6 bloqueia
  # por padrão. O greeter herda o ambiente do daemon do sddm.
  systemd.services.display-manager.environment.QML_XHR_ALLOW_FILE_READ = "1";

  # O greeter não herda as fontes do Home Manager — precisam ser do sistema.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Artefatos do tema: wallpaper.jpg, wallpaper-blur.jpg, avatar.png, colors.conf.
  # Dono = caio para que `update-theme` escreva sem sudo; 0755 para o sddm ler.
  systemd.tmpfiles.rules = [
    "d /var/lib/sddm-theme 0755 caio users -"
  ];
}
