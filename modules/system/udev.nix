{ pkgs, ... }:
{
  # Força o reload imediato da waybar (SIGUSR2 = "reload" por padrão,
  # mesmo sinal usado por update-theme) sempre que o kernel emitir um
  # evento no subsistema power_supply (plugar/desplugar o carregador,
  # ou a bateria mudar de estado). Puramente orientado a evento — sem
  # polling nem serviço residente novo.
  #
  # Nota: o módulo "battery" da waybar não suporta a opção "signal"
  # (isso só existe para módulos "custom/*"), então não há como pedir
  # o refresh de só esse módulo — SIGUSR2 recarrega a barra inteira.
  #
  # O reload é agendado com ~1s de atraso via `systemd-run --on-active`
  # (unidade timer descartável, fora da árvore de processos do udev)
  # porque, neste hardware, o uevent do adaptador AC (ADP1) chega um
  # instante antes de o kernel terminar de atualizar BAT0/status — sem
  # esse atraso a waybar recarrega lendo o status antigo (ícone invertido
  # no instante de plugar/desplugar).
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", RUN+="${pkgs.systemd}/bin/systemd-run --on-active=1 --collect ${pkgs.procps}/bin/pkill -SIGUSR2 waybar"
  '';
}
