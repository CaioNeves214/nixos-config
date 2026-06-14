{
  pkgs,
  ...
}:

{
  environment.systemPackages =
    with pkgs; [
      lm_sensors
      networkmanagerapplet  
      home-manager
      btop
      mbpfan
    ];
}
