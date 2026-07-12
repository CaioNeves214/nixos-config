{ ... }:

let
  # 10-band IIR EQ curve shared by both channels: lifts the low end the
  # MacBook Pro 2012's small speakers can't reproduce on their own, trims the
  # boxy 500Hz-1kHz midrange, and adds a touch of top-end air for perceived
  # depth/clarity.
  eqBand = frequency: gain: {
    inherit frequency gain;
    mode = "RLC (BT)";
    mute = false;
    q = 1.5047602375372453;
    slope = "x1";
    solo = false;
    type = "Bell";
  };

  eqCurve = {
    band0 = eqBand 32.0 3.5;
    band1 = eqBand 64.0 2.5;
    band2 = eqBand 125.0 1.0;
    band3 = eqBand 250.0 0.0;
    band4 = eqBand 500.0 (-1.0);
    band5 = eqBand 1000.0 0.0;
    band6 = eqBand 2000.0 0.0;
    band7 = eqBand 4000.0 1.0;
    band8 = eqBand 8000.0 1.5;
    band9 = eqBand 16000.0 1.0;
  };
in
{
  services.easyeffects = {
    enable = true;
    preset = "depth-boost";

    extraPresets = {
      depth-boost = {
        output = {
          blocklist = [ ];
          plugins_order = [
            "bass_enhancer"
            "equalizer"
          ];

          bass_enhancer = {
            amount = 6.0;
            blend = 0.0;
            floor = 20.0;
            "floor-active" = false;
            harmonics = 8.5;
            "input-gain" = 0.0;
            "output-gain" = 0.0;
            scope = 80.0;
          };

          equalizer = {
            "input-gain" = 0.0;
            "output-gain" = 0.0;
            mode = "IIR";
            "num-bands" = 10;
            "split-channels" = false;
            left = eqCurve;
            right = eqCurve;
          };
        };
      };
    };
  };
}
