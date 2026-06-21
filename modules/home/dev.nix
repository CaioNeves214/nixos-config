{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodejs_24
    python311
    claude-code
  ];
}