{ config, lib, ... }:

{
  # Symlinks por ARQUIVO/SUBDIR, não do diretório inteiro: assim
  # ~/.config/quickshell/ é um diretório real e gravável, onde o wallust escreve
  # colors.json. Com o symlink de diretório que existia antes, esse gerado caía
  # dentro da working tree do repo (e chegou a ser versionado por causa disso).
  #
  # O Quickshell registra ~/.config/quickshell/shell.qml como a config 'default'
  # (`qs --help`), então não é preciso -c/-p.
  #
  # Aponta para o perfil ativo (ver comentário em hyprland.nix).
  xdg.configFile."quickshell/shell.qml".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/quickshell/shell.qml";

  # Componentes locais (MediaButton.qml e futuros). O `import "ui"` do shell.qml
  # resolve contra ~/.config/quickshell/, então este alvo tem de existir aqui.
  xdg.configFile."quickshell/ui".source =
    config.lib.file.mkOutOfStoreSymlink "/home/caio/.config/theme/active/quickshell/ui";

  # Migração do symlink de diretório para symlinks de arquivo.
  # O cleanOldGen do HM NÃO remove o ~/.config/quickshell antigo a tempo, e o
  # linkGeneration então falha com "mkdir: cannot create directory: File exists"
  # (um symlink-para-diretório conta como existente). Precisa rodar antes do
  # linkGeneration, e só age se o caminho for symlink — um diretório real é o
  # estado correto e nunca deve ser removido.
  home.activation.migrateQuickshellDirSymlink =
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ -L "$HOME/.config/quickshell" ]; then
        $DRY_RUN_CMD rm "$HOME/.config/quickshell"
        echo ":: quickshell: symlink de diretório antigo removido (migração)"
      fi
    '';
}
