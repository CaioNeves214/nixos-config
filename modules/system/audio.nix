{
  # MacBook Pro 2012's Cirrus Logic CS4206 codec needs this quirk, otherwise
  # the generic HDA autoparser skips the amp/GPIO fixups and speaker output
  # comes out thin/tinny ("radio-like").
  boot.extraModprobeConfig = ''
    options snd-hda-intel model=mbp101
  '';

  services.pipewire = {
    enable = true;

    pulse.enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;
  };
  
  services.pulseaudio.enable = false;

  security.rtkit.enable = true;

  # Required for the EasyEffects daemon (modules/home/easyeffects.nix) to run correctly.
  programs.dconf.enable = true;
}
