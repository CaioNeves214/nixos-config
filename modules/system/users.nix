{ pkgs, ... }:

{
  users.users.caio = {
    isNormalUser = true;

    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
    ];
 
    shell = pkgs.zsh;
  };
}
