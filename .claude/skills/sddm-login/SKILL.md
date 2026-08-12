---
name: sddm-login
description: Tela de login — SDDM Qt6 com tema QML próprio (sddm-theme-caio). Use ao editar dotfiles/sddm/theme/ (Main.qml, theme.conf, metadata.desktop) ou modules/system/login.nix, ao mexer no avatar/wallpaper/blur/animação da tela de login, ao depurar o greeter, e sempre que aparecer "SDDM", "greeter", "tela de login", "lock/login screen", "avatar" ou "/var/lib/sddm-theme".
---

# Tela de login (SDDM + tema QML próprio)

`modules/system/login.nix` empacota `dotfiles/sddm/theme/` como um pacote de tema
(`sddm-theme-caio`) e aponta o SDDM para ele.

**Layout:** avatar circular centralizado, nome real abaixo, campo de senha abaixo; fundo é o
wallpaper atual, desfocado. No `loginSucceeded` o blur se dissolve enquanto a UI faz fade out —
mesma duração, mesmo easing (`animationDuration` em `theme.conf`).

## O greeter roda como o usuário `sddm` — e isso decide tudo

Ele **não lê `~/.config` nem `~/.cache`**. Todos os assets dele vivem em
**`/var/lib/sddm-theme/`** (criado por uma regra `systemd.tmpfiles`, owner `caio` para o
`update-theme` escrever sem sudo, `0755` para o sddm ler):

| Arquivo | Origem |
|---|---|
| `wallpaper.jpg` | wallpaper atual, via ImageMagick no `update-theme` |
| `wallpaper-blur.jpg` | idem, versão desfocada |
| `avatar.png` | `dotfiles/sddm/avatar.png`, center-cropped pelo `update-theme` |
| `colors.conf` | template wallust `colors-sddm.conf`, copiado de `~/.cache/sddm-colors.conf` |

`Main.qml` cai num fallback (paleta escura + círculo com a letra inicial) se qualquer um deles
faltar, então um checkout limpo ainda loga.

**A foto do usuário** vai em `dotfiles/sddm/avatar.png` — **gitignored** (é pessoal, e fica fora do
`/nix/store`, que é world-readable). Trocar a foto exige apenas `update-theme`, não um rebuild.

## Armadilhas

- **O blur é pré-renderizado, não um efeito QML ao vivo** — uma Intel HD 4000 não vai gaussian-blur
  uma imagem de tela cheia todo frame. A animação faz cross-fade da imagem desfocada para revelar
  a nítida. Ver skill **`hardware-quirks`**.
- **O SDDM tem que ser o pacote Qt6** (`pkgs.kdePackages.sddm`); o default do 25.05 ainda é Qt5 e o
  tema usa `QtQuick.Effects` (`MultiEffect`, para a máscara circular do avatar).
- **`QML_XHR_ALLOW_FILE_READ=1`** está setado no `display-manager.service`: o Qt6 bloqueia
  `XMLHttpRequest` em `file://` por default, e é assim que o `Main.qml` lê o `colors.conf`.
- **Fontes têm que ser fontes de sistema** (`fonts.packages`) — o greeter não vê as do Home
  Manager.
- **Erros QML não vão para o stderr**, vão para o journal.

## Depurar sem reiniciar

```bash
journalctl -t sddm-greeter-qt6                              # erros QML aparecem aqui
sddm-greeter-qt6 --test-mode --theme dotfiles/sddm/theme    # testa a mudança na hora
```

Em test mode, `sddm.canPowerOff`/`canReboot`/`canSuspend` são sempre `false`, então a linha de
botões de energia fica escondida ali — não é bug.

## Cor

O `colors-sddm.conf` renderiza os 5 tokens semânticos em `key=valor`. Para mexer na paleta, edite o
template, não o `Main.qml` — skill **`design-system`**.
