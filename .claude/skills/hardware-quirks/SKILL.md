---
name: hardware-quirks
description: As peculiaridades deste MacBook Pro 2012 já diagnosticadas e pagas — áudio Cirrus CS4206, GPU Intel HD 4000 (Ivy Bridge) e GTK4/GSK, controle de fan, bateria/AC, UPower, nix-ld. Use ao mexer em áudio/EasyEffects, em qualquer coisa de bateria/energia/brilho, ao criar ou depurar um app GTK4, ao investigar performance/render/animação/blur, ao editar modules/system/{audio,fan,power,udev}.nix ou modules/home/easyeffects.nix, e sempre que algo "renderiza quase certo" ou falha em silêncio.
---

# Peculiaridades deste hardware

MacBook Pro 2012: CPU Core i5 Ivy Bridge, GPU **Intel HD 4000**, codec de áudio **Cirrus Logic
CS4206**. Cada item abaixo já custou uma sessão de debug — não re-descubra.

## Áudio: CS4206 precisa de quirk + compensação em software

O codec onboard precisa de `options snd-hda-intel model=mbp101`
(`modules/system/audio.nix`, via `boot.extraModprobeConfig`) — sem isso o autoparser genérico de
HDA do kernel produz som fino/metálico nos alto-falantes.

Mesmo com o quirk, os alto-falantes pequenos de 2012 são fisicamente pobres de graves. Por isso
`modules/home/easyeffects.nix` adiciona um preset PipeWire de EQ + bass-enhancer
(**`depth-boost`**, auto-carregado) para compensar em software. Ele exige
`programs.dconf.enable = true` (setado junto com o quirk em `audio.nix`) para o daemon do
EasyEffects rodar.

## GPU: apps GTK4 precisam de `GSK_RENDERER=ngl`

**Na Intel HD 4000, o backend Vulkan default do GSK não desenha texto.** Descoberto via `walker`
(o primeiro app GTK4 deste rice — waybar/rofi/thunar são todos GTK3, pipeline de render
diferente): com o Vulkan default, backgrounds CSS de cor sólida renderizam bem, mas **nenhum
glyph aparece** — sem erro, sem crash, zero texto. Isolado setando
`#label { color: red; background: yellow; }`: o amarelo apareceu, o texto vermelho não.

`modules/home/packages.nix` wrappa `pkgs.walker` com `symlinkJoin` + `makeWrapper` para forçar
`GSK_RENDERER=ngl` **no binário** (não só no keybind), então valendo em toda invocação.
**Qualquer pacote GTK4 novo neste flake provavelmente precisa do mesmo wrapper** — padrão do
wrapper na skill **`nix-wiring`**.

## GPU: limites de efeito visual

Esta GPU não quer blur em tempo real de tela cheia. As duas consequências assumidas no repo:

- **Blur do SDDM é pré-renderizado**, não um efeito QML ao vivo: o `update-theme` gera
  `wallpaper-blur.jpg` com ImageMagick e a animação faz cross-fade. Skill **`sddm-login`**.
- **Nada de blur em QML** nos widgets Quickshell; profundidade se faz com alpha e raio. Skill
  **`quickshell`**.

Animações: `OutCubic`, ~160–280ms, e só em `opacity`/`width`/`height`/`x`/`y`/`scale`.

## Fan

Controle de fan é `mbpfan`, com thresholds ajustados para o perfil térmico do MacBook Pro
(`modules/system/fan.nix`).

## Bateria e AC

Dois mecanismos diferentes, um por tipo de barra:

**Waybar (perfil `default`)** — atualiza instantaneamente ao plugar/desplugar o carregador via uma
regra `services.udev.extraRules` (`modules/system/udev.nix`) que manda **`SIGUSR2`** (o sinal de
"reload" default da waybar) em qualquer evento `change` do subsistema `power_supply`. Puramente
event-driven, sem serviço de polling.

> A opção `"signal"` de módulo da waybar **só se aplica a módulos `custom/*`**, não a built-ins
> como `battery` — por isso é um reload de barra inteira via `SIGUSR2` e não um refresh de módulo
> específico.

**Quickshell (perfil `nous`)** — o módulo de bateria lê `Quickshell.Services.UPower` direto e
reage por conta própria; nenhuma regra udev envolvida. Requer
`services.upower.enable = true` (`modules/system/power.nix`).

⚠️ **Sem o `upower` habilitado, o serviço devolve `0%`/`Unknown` em silêncio, sem erro** (o log
mostra apenas `Could not launch service org.freedesktop.UPower`). A waybar nunca precisou disso —
ela lê `/sys/class/power_supply` direto.

## O padrão que se repete aqui: falha silenciosa

Neste host, serviços DBus e backends de render **não dão erro quando faltam** — eles devolvem
zeros, ou não desenham, e o resultado renderiza "quase certo". Ao depurar algo que parece
funcionar mas está vazio/errado:

1. Confirme que o daemon/backend existe **fora** do app (`busctl`, `nmcli`, `bluetoothctl`,
   `pactl`).
2. Teste o componente isolado (`qs -p arquivo.qml`, `sddm-greeter-qt6 --test-mode`).
3. Só então suspeite do seu código.

Casos já confirmados como binding vazio apesar do daemon rodando: `Quickshell.Networking` e
`Quickshell.Bluetooth` (skill **`quickshell`**).

## `nix-ld`

Habilitado com um conjunto amplo de bibliotecas dinâmicas para rodar binários pré-compilados
(apps Electron, extensões do VS Code) que não foram feitos para o NixOS.
