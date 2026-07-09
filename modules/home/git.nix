{ ... }:

{
  programs.git = {
    enable = true;

    userName = "CaioNeves214";

    userEmail = "workspace2144@gmail.com";
  };

  # Mantém a chave SSH carregada entre reinicializações do compositor,
  # evitando que apps como o Antigravity peçam login a cada push por SSH.
  services.ssh-agent.enable = true;
}
