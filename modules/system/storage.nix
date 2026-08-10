{ ... }:

{
  # Backend DBus para gerenciamento de dispositivos removíveis (pendrives, HDs externos).
  # Necessário mesmo usando udiskie no lado do usuário — sem isso o mount falha
  # porque o serviço DBus do UDisks2 não existe.
  services.udisks2.enable = true;
}
