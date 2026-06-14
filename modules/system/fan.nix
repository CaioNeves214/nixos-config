# modules/system/fan.nix

{
  services.mbpfan = {
    enable = true;
    settings.general = {
      min_fan1_speed = 2500;
      max_fan1_speed = 6200;

      low_temp = 40;
      high_temp = 60;
      max_temp = 75;
    };
  };
}
