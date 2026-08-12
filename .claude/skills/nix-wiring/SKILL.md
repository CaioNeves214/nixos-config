---
name: nix-wiring
description: O wiring Nix deste flake — onde adicionar pacote, módulo, serviço ou dotfile linkado, e a fronteira system vs home. Use ao editar flake.nix, hosts/macbookpro2012/*, home/caio.nix, qualquer arquivo em modules/system/ ou modules/home/, ao instalar/remover um pacote, ao habilitar um serviço (systemd, DBus, udev), ao decidir se algo precisa de nixos-rebuild ou pega ao vivo, ao empacotar/wrappar um binário, e para qualquer dúvida sobre os comandos de build/validação do flake.
---

# Wiring Nix — onde as coisas se ligam

Config NixOS + Home Manager de um MacBook Pro 2012 rodando NixOS 25.05 com Hyprland, gerenciada
como flake. **Um único host**, `macbookpro2012`, em `x86_64-linux`.

> **MCP first:** qualquer dúvida sobre pacote nixpkgs, opção NixOS/home-manager, canal, flake ou
> cache binário vai em `mcp__nixos__nix` / `mcp__nixos__nix_versions` — nunca em conhecimento de
> treinamento nem em `nix search` manual. A opção pode ter mudado de nome, o pacote pode não
> existir mais neste canal, e a validação custa uma chamada.

## Comandos

```bash
# Aplica system + home. É o ÚNICO comando de switch.
# home-manager roda como módulo NixOS aqui e o flake expõe só `nixosConfigurations` —
# não existe output `homeConfigurations`, então `home-manager switch --flake .#macbookpro2012` FALHA.
sudo nixos-rebuild switch --flake .#macbookpro2012

# Validação rápida, sem build e sem sudo (use isto para checar seu trabalho)
nix eval .#nixosConfigurations.macbookpro2012.config.system.build.toplevel.drvPath

nix flake check      # valida outputs/sintaxe
nix flake update     # atualiza inputs (nixpkgs, home-manager)
```

Como o `home-manager` roda via `home-manager.nixosModules.home-manager`, **um `nixos-rebuild
switch` reconstrói system e home simultaneamente**.

## Mapa dos módulos

```
flake.nix                          # inputs + nixosConfigurations
hosts/macbookpro2012/
  configuration.nix                # hardware, display, rede, portais XDG; importa modules/system/*
  hardware-configuration.nix       # gerado — NÃO editar à mão
home/caio.nix                      # entry point do Home Manager; importa modules/home/*
modules/system/                    # audio bluetooth boot fan locale login networking
                                   # packages power storage udev users zsh
modules/home/                      # dev easyeffects git hyprland kitty packages quickshell
                                   # rofi theme walker waybar
```

Módulos de `modules/home/` que apontam para dotfiles seguem todos o mesmo formato: apontam para um
caminho **constante** sob `~/.config/theme/active/` (skill **`theme-profiles`**).

## Onde adicionar um pacote

| Caso | Lugar |
|---|---|
| CLI/daemon do sistema, ou precisa rodar como root | `modules/system/packages.nix` |
| App do usuário, ferramenta de desktop | `modules/home/packages.nix` |
| Toolchain de dev | `modules/home/dev.nix` |

`nixpkgs.config.allowUnfree = true` é global — pacotes unfree (discord etc.) entram sem override
por pacote. `nix-command` e `flakes` estão habilitados em `nix.settings`.

## Dotfiles: quando um switch é necessário

Os dotfiles entram em `~/.config/` via **`config.lib.file.mkOutOfStoreSymlink`** — um symlink
fora do store apontando de volta para a working tree do repo, hardcoded em
`/home/caio/nix-config`.

- **Editar um arquivo em `dotfiles/` tem efeito imediato** — nada de `switch`, só recarregar o app.
- **`switch` é obrigatório só quando o wiring Nix muda**: adicionar/remover um arquivo linkado,
  editar um módulo, mexer numa opção.

## Padrão: serviço DBus atravessa a fronteira system/home

Tudo que é backed por DBus aqui se divide em duas metades. O backend privilegiado é uma opção
NixOS; o cliente/daemon de usuário é um pacote de home iniciado por `exec-once`. Exemplos reais:

| Backend (system) | Cliente (home) |
|---|---|
| `services.udisks2.enable` (`modules/system/storage.nix`) | `udiskie` em `modules/home/packages.nix`, `exec-once = udiskie --tray` |
| `services.upower.enable` (`modules/system/power.nix`) | módulo de bateria do `nous` via `Quickshell.Services.UPower` |
| `security.polkit` (`configuration.nix`) | agentes de autenticação |

**Autostart é `exec-once` no `hyprland.conf` do perfil, não um serviço systemd do Home Manager** —
nada aqui inicia `graphical-session.target`, então os user services do HM não têm em que se
pendurar. Mesmo padrão para waybar, hyprpaper, quickshell, udiskie.

⚠️ Quando o backend falta, o cliente costuma falhar **em silêncio**, não com erro: sem
`services.upower.enable` o serviço UPower do Quickshell devolve `0%`/`Unknown` sem reclamar. Ver
skill **`hardware-quirks`**.

## Padrão: wrappar um binário para forçar env

Quando um pacote de nixpkgs precisa de uma variável de ambiente **sempre** (não só quando chamado
pelo keybind), wrappe o binário em vez de setar a var no keybind:

```nix
(pkgs.symlinkJoin {
  name = "walker-wrapped";
  paths = [ pkgs.walker ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/walker --set GSK_RENDERER ngl
  '';
})
```

Esse é o padrão usado em `modules/home/packages.nix` para o `walker` (GTK4 nesta GPU — skill
**`hardware-quirks`**) e para o `volume-popup` (typelibs GTK3 — skill **`gtk-popups`**).

`nix-ld` está habilitado com um conjunto amplo de bibliotecas dinâmicas para suportar binários
pré-compilados (apps Electron, extensões do VS Code).

## Checklist ao mexer no wiring

1. Consulte `mcp__nixos__nix` para confirmar nome do pacote / da opção **neste canal**.
2. Escolha o lado da fronteira (system vs home) pelos padrões acima.
3. Edite o módulo certo — nunca `hardware-configuration.nix`.
4. Valide sem sudo: `nix eval .#nixosConfigurations.macbookpro2012.config.system.build.toplevel.drvPath`.
5. `sudo nixos-rebuild switch --flake .#macbookpro2012`.
6. Se a mudança é estrutural, atualize o `CLAUDE.md` (macro) ou a skill correspondente (detalhe) —
   é regra permanente deste repo.
