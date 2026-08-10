# Media widget (Quickshell)

> **`nous` migrated off this design.** In that profile the media card is now a page inside
> the bar's own hub panel (`dotfiles/profiles/nous/quickshell/ui/Hub.qml` +
> `HubPanel.qml`/`PanelMedia.qml`) — the whole bar is Quickshell, not just this widget, so
> there's no separate surface anchoring against a waybar exclusive zone anymore. See
> `docs/quickshell-bar-nous.md`. This document still describes the `default` profile's widget
> as implemented, and the anchor-math/gotchas here are still the reference for `default`.

The now-playing control that sits in the waybar's row and drops a card down on hover.

**Source:** `dotfiles/profiles/<name>/quickshell/shell.qml` + `quickshell/ui/MediaButton.qml`
(it is **per-profile** — edit the copy under the profile you are actually running;
`theme-profile` with no argument tells you which).
**Wiring:** `modules/home/quickshell.nix` symlinks it live into `~/.config/quickshell/`;
`exec-once = quickshell` in `hyprland.conf` starts it.

> **Before writing or debugging any QML here, use the `quickshell` skill**
> (`.claude/skills/quickshell/`). It carries the exact 0.3.0 API extracted from the installed
> package (`references/api-core.md`, `references/api-services.md`), ready-made widget recipes
> (`references/patterns.md`), and the pitfalls that already cost debugging time —
> layer-shell surface sizing, `HoverHandler` hit regions, anchor offsets vs. waybar's
> exclusive zone, and the Intel HD 4000 animation budget (`references/gotchas.md`).

---

## Why it isn't a waybar module

GTK/waybar drawers can only expand **horizontally**, inside the bar's own row. The goal was a
card that **drops down below** the bar on hover with fluid animation and retracts on
mouse-leave (inspired by adaptive eww music widgets on r/unixporn). That needs its own
compositor surface — hence a separate Quickshell layer-shell app.

It replaced `group/mediaplayer` and its `custom/media-*` children, which were removed from
`wallust/templates/waybar-config.jsonc` and the waybar CSS. `hyprland/window` (focused window
title) was dropped from `modules-left` at the same time: its width varied with the title,
making any alignment impossible.

The old `playerctl`+`jq` polling scripts (`waybar-media-play`, `waybar-media-info`, polling at
`interval: 1`) are gone — everything comes from Quickshell's native **MPRIS service**
(`Quickshell.Services.Mpris`). `playerctl` stays installed only as a CLI convenience.

## Surface and positioning

- A `PanelWindow` anchored `top`+`left`, `exclusiveZone: 0` (doesn't push windows), drawn above
  windows and visually flush with the waybar. It only *looks* like part of the bar.
- **`margins.top` is negative.** Hyprland anchors a layer-shell surface *after* the zone other
  layers already reserved, so the rule is `top = y_wanted - reserved.top`. The number is
  **per-profile and measured, never derived** — see that profile's `DESIGN.md`. Read the
  current value with `hyprctl monitors -j` → `reserved` (array order is
  `[left, top, right, bottom]`).
- **`margins.left` is computed, not constant.** `hyprland/workspaces` only draws workspaces
  that *exist*, so the left group grows by a button whenever one appears; a fixed value
  misaligns on the first workspace switch. `shell.qml` reads `Hyprland.workspaces` (Quickshell's
  Hyprland IPC service) and computes `base + 40 * workspaceCount`. `base` is again per-profile
  and measured on screen (`grim` + a pixel-row scan). Re-measure if the waybar font size or the
  `#workspaces button` padding changes.
  Moving a layer-shell surface is cheap — only *resizing* one is not — so this is a plain
  binding, deliberately un-animated (waybar's own relayout is instant too).
- **The whole surface is `visible: root.hasPlayer`.** With no MPRIS player holding an actual
  track, the widget disappears completely rather than leaving an invisible surface catching the
  mouse. Brave/Chromium register an empty player, so the filter is on `trackTitle`, not on the
  player's existence.

## The thumb and the audio visualizer

The trigger is a Nerd Font glyph sitting in the bar's row, lit in `primary` while playing.

**Its width is animated, not fixed.** With no player it's just the glyph (`panel.barHeight`);
the moment a player appears it grows (`Behavior on width`, `Easing.OutBack`, 340ms) to open
space for the visualizer — the same "pill growing" gesture `hyprland/workspaces` does when a
workspace appears. This works even though the surface only becomes `visible` at that same
instant: QML property bindings and Behaviors keep evaluating on invisible items, so the width
is already mid-animation by the time the compositor maps the surface. No need to keep the
surface always-mapped.

The 5 bars are driven by **real audio**, not a fake animation:
`Quickshell.Services.Pipewire`'s `PwNodePeakMonitor` on `Pipewire.defaultAudioSink` reads the
output's live peak level — native, event-driven, no external process (no `cava`). A `Timer`
(90ms) samples `sqrt(peak) * 1.4` (perceptual gain) into a 5-value sliding window
(`root.waveSamples`); each bar's `Layout.preferredHeight` binds to one slot with its own
`Behavior`. `enabled: root.hasPlayer && root.player.isPlaying` gates the monitor and resets
`waveSamples` to zero on `onEnabledChanged`, so the bars settle instead of freezing mid-level.

> `PwObjectTracker { objects: [Pipewire.defaultAudioSink] }` is **mandatory** — without it
> Pipewire never subscribes to the node's properties and everything reads zero, silently
> (skill gotchas §9).

It is a peak/VU reading (one float per sample), **not** an FFT spectrum: the bars pulse with
real volume, not per-frequency-band data.

## Animation architecture

- **The `PanelWindow`'s size is fixed and never animated.** `implicitWidth`/`implicitHeight`
  are constant (`barHeight + cardHeight`), sized for the fully-expanded state up front.
  Animating a wlr-layer-shell surface's size directly (what an earlier version did) makes the
  compositor reconfigure the Wayland surface every frame; Hyprland doesn't do that smoothly and
  it showed up as the card rendering half-clipped and stale.
- The open/close animation happens **inside** the fixed surface: the card lives in a
  `clip: true` `Item` (`cardClip`) whose `height` animates — a plain QML property animation.
- **Open and close are deliberately asymmetric**, via QML `States`/`Transitions` rather than one
  symmetric `Behavior`. Opening is slower, with a slight `Easing.OutBack` overshoot on the
  content's slide-in, staggered behind a short `PauseAnimation` so the height has room first.
  Closing is faster and `Easing.InCubic` (no overshoot), so the card doesn't look like it's
  lingering after the mouse has left.

## Input handling

- **Input mask.** The surface is a fixed 320×(bar+card) rectangle, so without a mask it would
  swallow every click in a 320px-wide band reaching well below the bar, over ordinary windows.
  `mask: Region` narrows the clickable area to the thumb, plus the card while expanded.
  The card's region uses **explicit geometry** driven by `root.expanded`, *not* `item: cardClip`:
  the clip's height is mid-animation while opening, and an input region lagging behind it would
  drop the pointer as it moved down into the card, closing it again. For the same reason the
  mask's card region snaps to its target height instantly and must not be animated.
- **Hover.** Two `HoverHandler`s — one nested inside the thumb `Rectangle`, one inside
  `cardClip` — combined into `root.expanded` via a `Binding`. A `HoverHandler`'s hit region
  follows its **parent Item's geometry**, not its `target` property, so each is declared *inside*
  the item it should track. Attaching one to the top-level `PanelWindow` would make the entire
  fixed 320px-wide surface hoverable, including empty space beside the icon.

## Card contents

- Album art in a `ClippingRectangle` (`Quickshell.Widgets`). A plain `Rectangle` + `clip: true`
  clips to the square bounding box and ignores `radius`, leaving the art's corners square.
  `asynchronous: true` on the `Image` keeps cover loading off the render thread.
- Title / artist / `player.identity`.
- A progress bar that **seeks on click** (`canSeek`, writing `player.position`).
- prev / play-pause / next, plus shuffle and loop. Shuffle and loop are **hidden** unless the
  player reports `shuffleSupported` / `loopSupported` — a dead button is worse than an absent
  one. Loop cycles None → Playlist → Track and encodes the mode in **color**, not in a third glyph.
- The five buttons share `quickshell/ui/MediaButton.qml` (hover highlight + `active` gating).
  It's a separate file because a QML **inline component cannot reference the enclosing file's
  ids**, so everything has to arrive by property anyway.

## Keyboard / CLI control

An `IpcHandler { target: "media" }` exposes `playPause`, `next`, `previous`, `toggle` (pins the
card open) and `status`.

`hyprland.conf` binds the MacBook's media keys (`XF86AudioPlay/Next/Prev`, as `bindl` so they
survive the lock screen) and `SUPER SHIFT+M` to `qs ipc call media …` rather than to
`playerctl`: the widget has already resolved *which* MPRIS player is the active one, and a
parallel `playerctl` could pick a different one.

Inspect with **`qs ipc show`** — with no arguments. (`qs ipc show target media` is rejected by
the argument parser.)

## Colors

Wallust palette, not album-art-derived (unlike the eww reference), to stay consistent with the
rest of the design system. Alpha over the tokens is the only way to build hierarchy
(`Qt.alpha(token, a)` is native — no hand-rolled hex helper). The palette is merged over an
embedded fallback on load, so a missing or incomplete `colors.json` can't leave a token
undefined, and `blockLoading: true` on the `FileView` means the first frame is already themed.

See the design-system table in `CLAUDE.md` for how `colors.json` is generated.

## Constraints of this host

- **`nix-ricing` doesn't cover Quickshell.** There is no `mcp__nix-ricing__quickshell_*` tool;
  edit the QML directly like any other dotfile. It live-reloads on save (Quickshell watches its
  config) — but **not** on a profile switch, because the watch is on the resolved inode and
  flipping the `active` symlink emits no inotify event. `theme-profile` kills and respawns it.
- **`UPower` is not enabled**, so a Quickshell battery widget would silently read 0%. It needs
  `services.upower.enable = true;` plus a rebuild. Waybar's battery works without it because it
  reads `/sys/class/power_supply` directly.
- **Intel HD 4000** (2012 MacBook Pro) — same lesson as the SDDM greeter's pre-rendered blur:
  keep animations to opacity, height and position; avoid heavy shader effects.
