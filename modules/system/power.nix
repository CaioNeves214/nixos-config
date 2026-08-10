{ ... }:

{
  # Backend DBus de estado de bateria/energia. Sem ele, Quickshell.Services.UPower
  # fica com propriedades zeradas em silêncio (sem erro) — "0%" / "Unknown".
  # A waybar (perfil default) não depende disso: lê /sys/class/power_supply direto.
  services.upower.enable = true;
}
