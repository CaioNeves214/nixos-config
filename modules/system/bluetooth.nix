{ ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Reduz timeout na fase de estabelecimento de conexão (ajuda com BCM2046).
        FastConnectable = true;
        # Habilita código LE mais recente do bluez 5.x.
        Experimental = true;
      };
      Policy.AutoEnable = true;
    };
  };

  services.blueman.enable = true;

  # BCM2046 (Apple 05AC:821D) aborta conexões LE quando o USB autosuspend
  # coloca o chip em baixo consumo durante o handshake. Desabilitar resolve.
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=0
  '';
}
