# Quickshell 0.3.0 — API de referência: serviços e integrações

Mesma extração e mesma notação de `api-core.md` (ver o cabeçalho de lá). Estes são os
módulos que expõem **dados vivos do sistema** — é daqui que sai o conteúdo dos widgets.

Regra geral destes módulos: quase tudo é um `[SINGLETON]` com uma lista
(`UntypedObjectModel`) de objetos `[uncreatable]`. Para iterar em QML:

- num `Repeater`/`ListView`: `model: Servico.lista` direto (é um QAbstractListModel).
- em JavaScript: `Servico.lista.values` → um array normal, com `.filter`/`.map`.

`UntypedObjectModel` (= `ObjectModel`) expõe `readonly values: list<QObject>` e
`fn indexOf(QObject) -> int`, mais os sinais `objectInsertedPre/Post` e
`objectRemovedPre/Post`.

**Importante sobre `UPower`, `Pipewire` e `SystemTray`:** as propriedades desses objetos só
ficam populadas enquanto algo estiver "olhando" para elas. No Pipewire isso é explícito e
obrigatório — veja `PwObjectTracker` e a nota no fim deste arquivo.

---

## `Quickshell.Hyprland`

### GlobalShortcut  : PostReloadHook
  readonly pressed: bool
  appid: string
  name: string
  description: string
  triggerDescription: string
  signal pressed()
  signal released()

### Hyprland  [SINGLETON]
  readonly usingLua: bool
  readonly requestSocketPath: string
  readonly eventSocketPath: string
  readonly focusedMonitor: HyprlandMonitor
  readonly focusedWorkspace: HyprlandWorkspace
  readonly activeToplevel: HyprlandToplevel
  readonly monitors: UntypedObjectModel
  readonly workspaces: UntypedObjectModel
  readonly toplevels: UntypedObjectModel
  fn dispatch(string request) -> void
  fn monitorFor(QuickshellScreenInfo screen) -> HyprlandMonitor
  fn refreshMonitors() -> void
  fn refreshWorkspaces() -> void
  fn refreshToplevels() -> void
  signal rawEvent(HyprlandIpcEvent event)

### HyprlandEvent  [uncreatable]
  readonly name: string
  readonly data: string
  fn parse(int argumentCount) -> string

### HyprlandFocusGrab
  active: bool
  windows: QObjectList
  signal cleared()

### HyprlandMonitor  [uncreatable]
  readonly id: int
  readonly name: string
  readonly description: string
  readonly x: int
  readonly y: int
  readonly width: int
  readonly height: int
  readonly scale: double
  readonly lastIpcObject: varMap
  readonly activeWorkspace: HyprlandWorkspace
  readonly focused: bool

### HyprlandToplevel  [uncreatable]
  readonly address: string
  readonly handle: HyprlandToplevel
  readonly wayland: Toplevel
  readonly title: string
  readonly activated: bool
  readonly urgent: bool
  readonly lastIpcObject: varMap
  readonly workspace: HyprlandWorkspace
  readonly monitor: HyprlandMonitor

### HyprlandWindow  [uncreatable]
  opacity: double
  visibleMask: PendingRegion

### HyprlandWorkspace  [uncreatable]
  readonly id: int
  readonly name: string
  readonly active: bool
  readonly focused: bool
  readonly urgent: bool
  readonly hasFullscreen: bool
  readonly lastIpcObject: varMap
  readonly monitor: HyprlandMonitor
  readonly toplevels: UntypedObjectModel
  fn activate() -> void

---

## `Quickshell.Services.Mpris`

### Mpris  [SINGLETON]
  readonly players: UntypedObjectModel

### MprisLoopState  [SINGLETON]
  enum: None | Track | Playlist
  fn toString(Enum status) -> string

### MprisPlaybackState  [SINGLETON]
  enum: Stopped | Playing | Paused
  fn toString(Enum status) -> string

### MprisPlayer  [uncreatable]
  readonly canControl: bool
  readonly canPlay: bool
  readonly canPause: bool
  readonly canTogglePlaying: bool
  readonly canSeek: bool
  readonly canGoNext: bool
  readonly canGoPrevious: bool
  readonly canQuit: bool
  readonly canRaise: bool
  readonly canSetFullscreen: bool
  readonly identity: string
  readonly desktopEntry: string
  readonly dbusName: string
  position: double
  readonly positionSupported: bool
  readonly length: double
  readonly lengthSupported: bool
  volume: double
  readonly volumeSupported: bool
  readonly metadata: varMap
  readonly uniqueId: uint
  readonly trackTitle: string
  readonly trackArtist: string
  readonly trackArtists: string
  readonly trackAlbum: string
  readonly trackAlbumArtist: string
  readonly trackArtUrl: string
  playbackState: Enum
  isPlaying: bool
  loopState: Enum
  readonly loopSupported: bool
  rate: double
  readonly minRate: double
  readonly maxRate: double
  shuffle: bool
  readonly shuffleSupported: bool
  fullscreen: bool
  readonly supportedUriSchemes: list<string>
  readonly supportedMimeTypes: list<string>
  fn raise() -> void
  fn quit() -> void
  fn openUri(string uri) -> void
  fn next() -> void
  fn previous() -> void
  fn seek(double offset) -> void
  fn play() -> void
  fn pause() -> void
  fn stop() -> void
  fn togglePlaying() -> void
  signal ready()

---

## `Quickshell.Services.Pipewire`

### Pipewire  [SINGLETON]
  readonly nodes: UntypedObjectModel
  readonly links: UntypedObjectModel
  readonly linkGroups: UntypedObjectModel
  readonly defaultAudioSink: PwNodeIface
  readonly defaultAudioSource: PwNodeIface
  preferredDefaultAudioSink: PwNodeIface
  preferredDefaultAudioSource: PwNodeIface
  readonly ready: bool

### PwAudioChannel  [SINGLETON]
  enum: Unknown | NA | Mono | FrontCenter | FrontLeft | FrontRight | FrontLeftCenter | FrontRightCenter | FrontLeftWide | FrontRightWide | FrontCenterHigh | FrontLeftHigh | FrontRightHigh | LowFrequencyEffects | LowFrequencyEffects2 | LowFrequencyEffectsLeft | LowFrequencyEffectsRight | SideLeft | SideRight | RearCenter | RearLeft | RearRight | RearLeftCenter | RearRightCenter | TopCenter | TopFrontCenter | TopFrontLeft | TopFrontRight | TopFrontLeftCenter | TopFrontRightCenter | TopSideLeft | TopSideRight | TopRearCenter | TopRearLeft | TopRearRight | BottomCenter | BottomLeftCenter | BottomRightCenter | AuxRangeStart | AuxRangeEnd | CustomRangeStart
  fn toString(Enum value) -> string

### PwLink  [uncreatable]  : PwObjectIface
  readonly id: uint
  readonly target: PwNodeIface
  readonly source: PwNodeIface
  readonly state: Enum

### PwLinkGroup  [uncreatable]
  readonly target: PwNodeIface
  readonly source: PwNodeIface
  readonly state: Enum

### PwLinkState  [SINGLETON]
  enum: Error | Unlinked | Init | Negotiating | Allocating | Paused | Active
  fn toString(Enum value) -> string

### PwNode  [uncreatable]  : PwObjectIface
  readonly id: uint
  readonly name: string
  readonly description: string
  readonly nickname: string
  readonly isSink: bool
  readonly isStream: bool
  readonly type: Flags
  readonly properties: varMap
  readonly audio: PwNodeAudioIface
  readonly ready: bool

### PwNodeAudio  [uncreatable]
  muted: bool
  volume: float
  readonly channels: list<Enum>
  volumes: list<float>

### PwNodeLinkTracker
  node: PwNodeIface
  readonly linkGroups: list<PwLinkGroupIface>

### PwNodePeakMonitor
  node: PwNodeIface
  enabled: bool
  readonly peaks: list<float>
  readonly peak: float
  readonly channels: list<Enum>

### PwNodeType  [SINGLETON]
  enum: Untracked | Audio | Video | Stream | Source | Sink | AudioSink | AudioSource | AudioDuplex | AudioOutStream | AudioInStream | VideoSource | VideoSink
  fn toString(Flags type) -> string

### PwObjectTracker
  objects: QObjectList
  fn objectDestroyed(QObject object) -> void

---

## `Quickshell.Services.UPower`

### PerformanceDegradationReason  [SINGLETON]
  enum: None | LapDetected | HighTemperature
  fn toString(Enum reason) -> string

### PowerProfile  [SINGLETON]
  enum: PowerSaver | Balanced | Performance
  fn toString(Enum profile) -> string

### PowerProfiles  [SINGLETON]
  profile: Enum
  readonly hasPerformanceProfile: bool
  readonly degradationReason: Enum
  readonly holds: list<PowerProfileHold>

### UPower  [SINGLETON]
  readonly displayDevice: UPowerDevice
  readonly devices: UntypedObjectModel
  readonly onBattery: bool

### UPowerDevice  [uncreatable]
  readonly type: Enum
  readonly powerSupply: bool
  readonly energy: double
  readonly energyCapacity: double
  readonly changeRate: double
  readonly timeToEmpty: double
  readonly timeToFull: double
  readonly percentage: double
  readonly isPresent: bool
  readonly state: Enum
  readonly healthPercentage: double
  readonly healthSupported: bool
  readonly iconName: string
  readonly isLaptopBattery: bool
  readonly nativePath: string
  readonly model: string
  readonly ready: bool

### UPowerDeviceState  [SINGLETON]
  enum: Unknown | Charging | Discharging | Empty | FullyCharged | PendingCharge | PendingDischarge
  fn toString(Enum status) -> string

### UPowerDeviceType  [SINGLETON]
  enum: Unknown | LinePower | Battery | Ups | Monitor | Mouse | Keyboard | Pda | Phone | MediaPlayer | Tablet | Computer | GamingInput | Pen | Touchpad | Modem | Network | Headset | Speakers | Headphones | Video | OtherAudio | RemoteControl | Printer | Scanner | Camera | Wearable | Toy | BluetoothGeneric
  fn toString(Enum type) -> string

### powerProfileHold  [uncreatable]  : var
  profile: Enum
  applicationId: string
  reason: var

---

## `Quickshell.Services.Notifications`

### Notification  [uncreatable]
  readonly id: uint
  tracked: bool
  readonly lastGeneration: bool
  readonly expireTimeout: double
  readonly appName: string
  readonly appIcon: string
  readonly summary: string
  readonly body: string
  readonly urgency: Enum
  readonly actions: NotificationAction>
  readonly hasActionIcons: bool
  readonly resident: bool
  readonly transient: bool
  readonly desktopEntry: string
  readonly image: string
  readonly hasInlineReply: bool
  readonly inlineReplyPlaceholder: string
  readonly hints: varMap
  fn expire() -> void
  fn dismiss() -> void
  fn sendInlineReply(string replyText) -> void
  signal closed(Enum reason)

### NotificationAction  [uncreatable]
  readonly identifier: string
  readonly text: string
  fn invoke() -> void

### NotificationCloseReason  [SINGLETON]
  enum: Expired | Dismissed | CloseRequested
  fn toString(Enum value) -> string

### NotificationServer  : PostReloadHook
  keepOnReload: bool
  persistenceSupported: bool
  bodySupported: bool
  bodyMarkupSupported: bool
  bodyHyperlinksSupported: bool
  bodyImagesSupported: bool
  actionsSupported: bool
  actionIconsSupported: bool
  imageSupported: bool
  inlineReplySupported: bool
  readonly trackedNotifications: UntypedObjectModel
  extraHints: list<string>
  signal notification(Notification notification)

### NotificationUrgency  [SINGLETON]
  enum: Low | Normal | Critical
  fn toString(Enum value) -> string

---

## `Quickshell.Services.SystemTray`

### Category  [uncreatable]  : var
  enum: Hardware | SystemServices | ApplicationStatus | Communications

### Status  [uncreatable]  : var
  enum: Passive | Active | NeedsAttention

### SystemTray  [SINGLETON]
  readonly items: UntypedObjectModel

### SystemTrayItem  [uncreatable]
  readonly id: string
  readonly title: string
  readonly status: Enum
  readonly category: Enum
  readonly icon: string
  readonly tooltipTitle: string
  readonly tooltipDescription: string
  readonly hasMenu: bool
  readonly menu: DBusMenuHandle
  readonly onlyMenu: bool
  fn activate() -> void
  fn secondaryActivate() -> void
  fn scroll(int delta, bool horizontal) -> void
  fn display(QObject parentWindow, int relativeX, int relativeY) -> void
  signal ready()

---

## `Quickshell.Bluetooth`

### Bluetooth  [SINGLETON]
  readonly defaultAdapter: BluetoothAdapter
  readonly adapters: UntypedObjectModel
  readonly devices: UntypedObjectModel

### BluetoothAdapter  [uncreatable]
  readonly name: string
  enabled: bool
  readonly state: Enum
  discoverable: bool
  discoverableTimeout: uint
  discovering: bool
  pairable: bool
  pairableTimeout: uint
  readonly devices: UntypedObjectModel
  readonly adapterId: string
  readonly dbusPath: string

### BluetoothAdapterState  [SINGLETON]
  enum: Disabled | Enabled | Enabling | Disabling | Blocked
  fn toString(Enum state) -> string

### BluetoothDevice  [uncreatable]
  readonly address: string
  name: string
  readonly deviceName: string
  readonly icon: string
  readonly state: Enum
  connected: bool
  readonly paired: bool
  readonly bonded: bool
  readonly pairing: bool
  trusted: bool
  blocked: bool
  wakeAllowed: bool
  readonly batteryAvailable: bool
  readonly battery: double
  readonly adapter: BluetoothAdapter
  readonly dbusPath: string
  fn connect() -> void
  fn disconnect() -> void
  fn pair() -> void
  fn cancelPair() -> void
  fn forget() -> void

### BluetoothDeviceState  [SINGLETON]
  enum: Disconnected | Connected | Disconnecting | Connecting
  fn toString(Enum state) -> string

---

## `Quickshell.Networking`

### ConnectionFailReason  [SINGLETON]
  enum: Unknown | NoSecrets | WifiClientDisconnected | WifiClientFailed | WifiAuthTimeout | WifiNetworkLost
  fn toString(Enum reason) -> string

### ConnectionState  [SINGLETON]
  enum: Unknown | Connecting | Connected | Disconnecting | Disconnected
  fn toString(Enum state) -> string

### DeviceType  [SINGLETON]
  enum: None | Wifi | Wired
  fn toString(Enum type) -> string

### Network  [uncreatable]
  readonly name: string
  readonly device: NetworkDevice
  readonly nmSettings: QList<NMSettings>
  readonly connected: bool
  readonly known: bool
  readonly state: Enum
  readonly stateChanging: bool
  fn connect() -> void
  fn connectWithSettings(NMSettings settings) -> void
  fn disconnect() -> void
  fn forget() -> void
  signal connectionFailed(Enum reason)
  signal requestConnect()
  signal requestConnectWithSettings(NMSettings settings)
  signal requestDisconnect()
  signal requestForget()

### NetworkBackendType  [SINGLETON]
  enum: None | NetworkManager
  fn toString(Enum type) -> string

### NetworkConnectivity  [SINGLETON]
  enum: Unknown | None | Portal | Limited | Full
  fn toString(Enum conn) -> string

### NetworkDevice  [uncreatable]
  readonly type: Enum
  readonly name: string
  readonly networks: UntypedObjectModel
  readonly address: string
  readonly connected: bool
  readonly state: Enum
  nmManaged: bool
  autoconnect: bool
  fn disconnect() -> void
  signal requestDisconnect()
  signal requestSetAutoconnect(bool autoconnect)
  signal requestSetNmManaged(bool managed)

### Networking  [SINGLETON]
  readonly devices: UntypedObjectModel
  readonly backend: Enum
  wifiEnabled: bool
  readonly wifiHardwareEnabled: bool
  readonly canCheckConnectivity: bool
  connectivityCheckEnabled: bool
  readonly connectivity: Enum
  fn checkConnectivity() -> void

### WifiDevice  [uncreatable]  : NetworkDevice
  scannerEnabled: bool
  readonly mode: Enum

### WifiDeviceMode  [SINGLETON]
  enum: AdHoc | Station | AccessPoint | Mesh | Unknown
  fn toString(Enum mode) -> string

### WifiNetwork  [uncreatable]  : Network
  readonly signalStrength: double
  readonly security: Enum
  fn connectWithPsk(string psk) -> void
  signal requestConnectWithPsk(string psk)

### WifiSecurityType  [SINGLETON]
  enum: Wpa3SuiteB192 | Sae | Wpa2Eap | Wpa2Psk | WpaEap | WpaPsk | StaticWep | DynamicWep | Leap | Owe | Open | Unknown
  fn toString(Enum type) -> string

### WiredDevice  [uncreatable]  : NetworkDevice
  readonly network: Network
  readonly linkSpeed: uint
  readonly hasLink: bool

---

## `Quickshell.Services.Pam`

### PamContext
  active: bool
  config: string
  configDirectory: string
  user: string
  readonly message: string
  readonly messageIsError: bool
  readonly responseRequired: bool
  readonly responseVisible: bool
  fn start() -> void
  fn abort() -> void
  fn respond(string response) -> void
  signal completed(Enum result)
  signal error(Enum error)
  signal pamMessage()

### PamError  [SINGLETON]
  enum: StartFailed | TryAuthFailed | InternalError
  fn toString(Enum value) -> string

### PamResult  [SINGLETON]
  enum: Success | Failed | Error | MaxTries
  fn toString(Enum value) -> string

---

## `Quickshell.Services.Greetd`

### Greetd  [SINGLETON]
  readonly available: bool
  readonly state: Enum
  readonly user: string
  fn createSession(string user) -> void
  fn cancelSession() -> void
  fn respond(string response) -> void
  fn launch(string command) -> void
  fn launch(string command, string environment) -> void
  fn launch(string command, string environment, bool quit) -> void
  signal authMessage(string message, bool error, bool responseRequired, bool echoResponse)
  signal authFailure(string message)
  signal readyToLaunch()
  signal launched()
  signal error(string error)

### GreetdState  [SINGLETON]
  enum: Inactive | Authenticating | ReadyToLaunch | Launching | Launched
  fn toString(Enum value) -> string

---

## `Quickshell.DBusMenu`

### DBusMenuHandle  [uncreatable]
  readonly menu: DBusMenuItem

### DBusMenuItem  [uncreatable]  : QsMenuEntry
  readonly menuHandle: DBusMenu
  fn sendOpened() -> void
  fn sendClosed() -> void
  fn sendTriggered() -> void
  signal layoutUpdated()
---

## Nota obrigatória: `PwObjectTracker`

O Pipewire expõe centenas de objetos e o Quickshell **não assina as propriedades de todos**
por padrão (seria caro). Um `PwNode` que ninguém rastreia tem `audio.volume`/`muted`
desatualizados ou zerados. Para ler ou escrever volume você **precisa** manter um tracker vivo
enquanto o widget existir:

```qml
import Quickshell.Services.Pipewire

PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
}
```

Sem isso, o volume simplesmente não atualiza — e não há erro no log. É o erro nº 1 de quem
escreve um widget de áudio em Quickshell.

`volume` é `float` de 0.0 a 1.0 (pode passar de 1.0 em over-amplification).

## Nota sobre `Hyprland.dispatch`

`Hyprland.dispatch("...")` recebe a mesma string de um `hyprctl dispatch`, sem o prefixo:

```qml
Hyprland.dispatch("workspace 3")
Hyprland.dispatch("exec kitty")
Hyprland.dispatch("killactive")
```

Para trocar de workspace prefira `HyprlandWorkspace.activate()`, que é mais direto e não
depende de montar string.

`Hyprland.rawEvent` dá acesso ao socket de eventos cru quando algo não está exposto como
propriedade — `event.name` e `event.data`, com `event.parse(n)` para quebrar o data em n
campos separados por vírgula.

## Nota sobre `SystemTray` + `DBusMenu`

`SystemTrayItem.menu` devolve um `DBusMenuHandle`, não um menu pronto. Para renderizar,
abra com `QsMenuOpener`:

```qml
QsMenuOpener {
    id: opener
    menu: trayItem.menu
}
// opener.children -> lista de QsMenuEntry para popular um Repeater
```

`QsMenuOpener` e `QsMenuEntry` moram em `Quickshell` (core), não em `Quickshell.DBusMenu` —
importe `Quickshell`. `opener.children` é um `UntypedObjectModel`: use direto como `model:`,
ou `.values` em JS.

`QsMenuEntry` (tudo readonly): `text`, `icon`, `enabled`, `isSeparator`, `hasChildren`,
`buttonType`, `checkState`. Acionar um item é **emitir o sinal** `triggered()` —
`entry.triggered()` — não existe função `trigger()`. Alternativamente
`SystemTrayItem.display(window, x, y)` abre o menu nativo da aplicação sem você desenhar nada.
