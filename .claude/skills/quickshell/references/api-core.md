# Quickshell 0.3.0 — API de referência: núcleo

Extraído dos `.qmltypes` do **pacote instalado** (`quickshell-0.3.0`, nixpkgs), não de memória
nem da web — é a assinatura exata que este sistema roda. Notação:

- `readonly x: T` — propriedade só de leitura (não dá para bindar do lado de fora).
- `fn nome(T arg) -> R` — função invocável do QML.
- `signal nome(T arg)` — sinal; use `onNome:` no QML.
- `[SINGLETON]` — importe o módulo e use direto (`Quickshell.screens`), não instancie.
- `[uncreatable]` — você recebe instâncias do serviço, mas não pode criar com `Tipo { }`.
- `enum:` — valores válidos do enum, usados como `Tipo.Valor`.

Sinais `xChanged` foram omitidos: **toda** propriedade tem o seu, gerado automaticamente.

Tipos definidos em QML (não em C++) não aparecem no metadata e estão documentados à mão
na seção final: `FileView`, `IconImage`, `ClippingRectangle`, `WrapperRectangle`,
`WrapperItem`, `WrapperMouseArea`, `ClippingWrapperRectangle`.

## Herança das janelas — leia antes de usar `PanelWindow`

Cada tipo lista **só o que ele acrescenta**. `PanelWindow`, `PopupWindow` e `FloatingWindow`
herdam todas as propriedades de janela de **`QsWindow`** — inclusive as que você mais usa:

```
visible / implicitWidth / implicitHeight / width / height
color            // "transparent" para janela arredondada ou com alpha
screen           // ShellScreen; setar para mover de monitor
mask             // Region: onde a janela aceita clique (o resto passa direto)
surfaceFormat    // .opaque = false quando precisa de transparência real
contentItem / devicePixelRatio / updatesEnabled
fn itemPosition(Item) / itemRect(Item) / mapFromItem(...)
signal closed() / windowConnected() / resourcesLost()
```

Então `PanelWindow { color: "transparent"; implicitHeight: 42 }` é válido mesmo que nada
disso apareça no bloco de `PanelWindow` abaixo — está em `QsWindow`.

O específico do `PanelWindow`:

- `anchors` — `{ top, bottom, left, right }` booleanos. Ancorar dois lados opostos estica
  naquela dimensão. Todos começam `false` (evita bloquear a tela inteira sem querer).
- `margins` — `{ top, bottom, left, right }`; só valem para os lados ancorados.
  **Podem ser negativas** — é assim que se compensa a zona exclusiva de outra camada.
- `exclusiveZone` — espaço reservado (empurra as janelas). Precisa de ≥1 âncora. Setar isto
  força `exclusionMode` para `Normal`. Use `0` para flutuar por cima sem empurrar nada.
- `exclusionMode` — `Normal | Ignore | Auto` (default `Auto`).
- `aboveWindows` — mapeia para `WlrLayershell.layer` no Wayland.
- `focusable` — mapeia para `WlrLayershell.keyboardFocus`.

Sob Wayland, `WlrLayershell` é um **attached object** do `PanelWindow` e dá controle fino:

```qml
PanelWindow {
    WlrLayershell.layer: WlrLayer.Overlay          // Background | Bottom | Top | Overlay
    WlrLayershell.namespace: "quickshell-media"    // aparece no `hyprctl layers`
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None   // None | Exclusive | OnDemand
}
```

`namespace` **não pode mudar** depois de `windowConnected`. Defina sempre — é o que torna o
debug com `hyprctl layers` possível.

---

## `Quickshell`

### BoundComponent
  readonly item: QObject
  sourceComponent: QQmlComponent
  source: string
  bindValues: bool
  readonly implicitWidth: double
  readonly implicitHeight: double
  signal loaded()

### ColorQuantizer
  readonly colors: list<QColor>
  source: QUrl
  depth: double
  imageRect: QRect
  rescaleSize: double
  fn operationFinished(QColor result) -> void

### DesktopAction  [uncreatable]
  id: var
  name: string
  icon: string
  execString: string
  command: list<string>
  fn execute() -> void

### DesktopEntries  [SINGLETON]
  readonly applications: UntypedObjectModel
  fn byId(string id) -> DesktopEntry
  fn heuristicLookup(string name) -> DesktopEntry

### DesktopEntry  [uncreatable]
  id: var
  name: string
  genericName: string
  startupClass: string
  noDisplay: bool
  comment: string
  icon: string
  execString: string
  command: list<string>
  workingDirectory: string
  runInTerminal: bool
  categories: list<string>
  keywords: list<string>
  readonly actions: QList<DesktopAction>
  fn execute() -> void

### EasingCurve
  curve: QEasingCurve
  fn valueAt(double x) -> double
  fn interpolate(double x, double a, double b) -> double
  fn interpolate(double x, QPointF a, QPointF b) -> QPointF
  fn interpolate(double x, QRectF a, QRectF b) -> QRectF

### Edges  [uncreatable]  : var
  enum: None | Top | Left | Right | Bottom

### ElapsedTimer
  fn elapsed() -> void
  fn restart() -> void
  fn elapsedMs() -> void
  fn restartMs() -> void
  fn elapsedNs() -> void
  fn restartNs() -> void

### ExclusionMode  [uncreatable]  : var
  enum: Normal | Ignore | Auto

### FloatingWindow  : WindowInterface
  title: string
  minimumSize: QSize
  maximumSize: QSize
  minimized: bool
  maximized: bool
  fullscreen: bool
  parentWindow: QObject
  fn startSystemMove() -> void
  fn startSystemResize(Edges edges) -> bool

### Intersection  [uncreatable]  : var
  enum: Combine | Subtract | Intersect | Xor

### LazyLoader  : Reloadable
  readonly item: QObject
  loading: bool
  active: bool
  activeAsync: bool
  component: QQmlComponent
  source: string

### ObjectModel  [uncreatable]  : QAbstractListModel
  readonly values: QObjectList
  fn indexOf(QObject object) -> qsizetype
  signal objectInsertedPre(QObject object, qsizetype index)
  signal objectInsertedPost(QObject object, qsizetype index)
  signal objectRemovedPre(QObject object, qsizetype index)
  signal objectRemovedPost(QObject object, qsizetype index)

### PanelWindow  [uncreatable]  : WindowInterface
  anchors: Anchors
  margins: Margins
  exclusiveZone: int
  exclusionMode: Enum
  aboveWindows: bool
  focusable: bool

### PersistentProperties  : Reloadable
  signal loaded()
  signal reloaded()

### PopupAdjustment  [uncreatable]  : var
  enum: None | SlideX | SlideY | Slide | FlipX | FlipY | Flip | ResizeX | ResizeY | Resize | All

### PopupAnchor  [uncreatable]
  window: QObject
  item: QQuickItem
  rect: Box
  margins: Margins
  edges: Flags
  gravity: Flags
  adjustment: Flags
  signal anchoring()

### PopupWindow  : ProxyWindowBase
  parentWindow: QObject
  relativeX: int
  relativeY: int
  readonly anchor: PopupAnchor
  grabFocus: bool
  fn reposition() -> void

### QsMenuAnchor
  readonly anchor: PopupAnchor
  menu: QsMenuHandle
  readonly visible: bool
  fn open() -> void
  fn close() -> void
  signal opened()
  signal closed()

### QsMenuButtonType  [SINGLETON]
  enum: None | CheckBox | RadioButton
  fn toString(Enum value) -> string

### QsMenuEntry  [uncreatable]  : QsMenuHandle
  readonly isSeparator: bool
  readonly enabled: bool
  readonly text: string
  readonly icon: string
  readonly buttonType: Enum
  readonly checkState: CheckState
  readonly hasChildren: bool
  fn display(QObject parentWindow, int relativeX, int relativeY) -> void
  signal triggered()
  signal opened()
  signal closed()

### QsMenuHandle  [uncreatable]

### QsMenuOpener
  menu: QsMenuHandle
  readonly children: UntypedObjectModel

### QsWindow  [uncreatable]  : Reloadable
  readonly contentItem: QQuickItem
  visible: bool
  readonly backingWindowVisible: bool
  implicitWidth: int
  implicitHeight: int
  width: int
  height: int
  readonly devicePixelRatio: double
  screen: QuickshellScreenInfo
  readonly windowTransform: QObject
  color: QColor
  mask: PendingRegion
  surfaceFormat: QsSurfaceFormat
  updatesEnabled: bool
  readonly data: list<QObject>
  fn itemPosition(QQuickItem item) -> QPointF
  fn itemRect(QQuickItem item) -> QRectF
  fn mapFromItem(QQuickItem item, QPointF point) -> QPointF
  fn mapFromItem(QQuickItem item, double x, double y) -> QPointF
  fn mapFromItem(QQuickItem item, QRectF rect) -> QRectF
  fn mapFromItem(QQuickItem item, double x, double y, double width, double height) -> QRectF
  signal closed()
  signal resourcesLost()
  signal windowConnected()

### Quickshell  [SINGLETON]
  readonly processId: int
  readonly instanceId: string
  readonly shellId: string
  readonly appId: string
  readonly launchTime: QDateTime
  readonly screens: list<QuickshellScreenInfo>
  readonly shellDir: string
  readonly configDir: string
  readonly shellRoot: string
  workingDirectory: string
  watchFiles: bool
  clipboardText: string
  readonly dataDir: string
  readonly stateDir: string
  readonly cacheDir: string
  fn reload(bool hard) -> void
  fn env(string variable) -> var
  fn execDetached(string command) -> void
  fn execDetached(ProcessContext context) -> void
  fn iconPath(string icon) -> string
  fn iconPath(string icon, bool check) -> string
  fn iconPath(string icon, string fallback) -> string
  fn hasThemeIcon(string icon) -> bool
  fn shellPath(string path) -> string
  fn configPath(string path) -> string
  fn dataPath(string path) -> string
  fn statePath(string path) -> string
  fn cachePath(string path) -> string
  fn inhibitReloadPopup() -> void
  fn hasVersion(int major, int minor, stringList features) -> bool
  fn hasVersion(int major, int minor) -> bool
  fn hasQtVersion(int major, int minor) -> bool
  signal lastWindowClosed()
  signal reloadCompleted()
  signal reloadFailed(string errorString)

### QuickshellSettings  [uncreatable]
  workingDirectory: string
  watchFiles: bool
  signal lastWindowClosed()

### Region
  shape: Enum
  intersection: Enum
  item: QQuickItem
  x: var
  y: var
  width: var
  height: var
  radius: int
  topLeftRadius: int
  topRightRadius: int
  bottomLeftRadius: int
  bottomRightRadius: int
  readonly regions: list<PendingRegion>
  signal changed()

### RegionShape  [uncreatable]  : var
  enum: Rect | Ellipse

### Reloadable  [uncreatable]
  reloadableId: var

### Retainable  [uncreatable]
  readonly retained: bool
  fn lock() -> void
  fn unlock() -> void
  fn forceUnlock() -> void
  signal dropped()
  signal aboutToDestroy()

### RetainableLock
  object: QObject
  locked: bool
  readonly retained: bool
  signal dropped()
  signal aboutToDestroy()

### Scope  : Reloadable
  readonly children: list<QObject>

### ScriptModel  : QAbstractListModel
  values: varList
  objectProp: string

### ShellRoot  : ReloadPropagator
  readonly settings: QuickshellSettings

### ShellScreen  [uncreatable]
  readonly name: string
  readonly model: string
  readonly serialNumber: string
  readonly x: int
  readonly y: int
  readonly width: int
  readonly height: int
  readonly physicalPixelDensity: double
  readonly logicalPixelDensity: double
  readonly devicePixelRatio: double
  readonly orientation: ScreenOrientation
  readonly primaryOrientation: ScreenOrientation
  fn toString() -> void

### Singleton  : ReloadPropagator

### SystemClock
  enum: Hours | Minutes | Seconds
  enabled: bool
  precision: Enum
  readonly date: QDateTime
  readonly hours: uint
  readonly minutes: uint
  readonly seconds: uint

### TransformWatcher
  a: QQuickItem
  b: QQuickItem
  commonParent: QQuickItem
  readonly transform: QObject
  fn recalcChains() -> void
  fn itemDestroyed() -> void
  fn aDestroyed() -> void
  fn bDestroyed() -> void

### Variants  : Reloadable
  delegate: var
  model: var
  readonly instances: list<QObject>

---

## `Quickshell.Io`

### FileViewError  [SINGLETON]
  enum: Success | Unknown | FileNotFound | PermissionDenied | NotAFile
  fn toString(Enum value) -> string

### IpcHandler  : PostReloadHook
  enabled: bool
  target: string

### JsonAdapter  : FileViewAdapter

### JsonObject

### Process  : PostReloadHook
  running: bool
  readonly processId: var
  command: list<string>
  workingDirectory: string
  environment: varHash
  clearEnvironment: bool
  stdout: DataStreamParser
  stderr: DataStreamParser
  stdinEnabled: bool
  fn exec(string command) -> void
  fn exec(ProcessContext context) -> void
  fn signal(int signal) -> void
  fn write(string data) -> void
  fn startDetached() -> void
  signal started()
  signal exited(int exitCode, ExitStatus exitStatus)

### Socket  : DataStream
  connected: bool
  path: string
  fn write(string data) -> void
  fn flush() -> void
  signal error(LocalSocketError error)

### SocketServer  : Reloadable
  active: bool
  path: string
  handler: QQmlComponent

### SplitParser  : DataStreamParser
  splitMarker: string

### StdioCollector  : DataStreamParser
  readonly text: string
  readonly data: QByteArray
  waitForEnd: bool
  signal streamFinished()

---

## `Quickshell.Wayland`

### BackgroundEffect  [uncreatable]
  blurRegion: PendingRegion

### IdleInhibitor
  enabled: bool
  window: QObject

### IdleMonitor  : PostReloadHook
  enabled: bool
  timeout: double
  respectInhibitors: bool
  readonly isIdle: bool

### ScreencopyView
  captureSource: QObject
  paintCursor: bool
  live: bool
  readonly hasContent: bool
  readonly sourceSize: QSize
  constraintSize: QSizeF
  fn captureFrame() -> void
  signal stopped()

### ShortcutInhibitor
  enabled: bool
  window: QObject
  readonly active: bool
  signal cancelled()

### Toplevel  [uncreatable]
  readonly appId: string
  readonly title: string
  readonly parent: Toplevel
  readonly activated: bool
  readonly screens: QList<QuickshellScreenInfo>
  maximized: bool
  minimized: bool
  fullscreen: bool
  fn activate() -> void
  fn close() -> void
  fn fullscreenOn(QuickshellScreenInfo screen) -> void
  fn setRectangle(QObject window, QRect rect) -> void
  fn unsetRectangle() -> void
  signal closed()

### ToplevelManager  [SINGLETON]
  readonly toplevels: UntypedObjectModel
  readonly activeToplevel: Toplevel

### WlSessionLock  : Reloadable
  locked: bool
  readonly secure: bool
  surface: QQmlComponent
  fn unlock() -> void

### WlSessionLockSurface  : Reloadable
  readonly contentItem: QQuickItem
  readonly visible: bool
  readonly width: int
  readonly height: int
  readonly screen: QuickshellScreenInfo
  color: QColor
  readonly data: list<QObject>

### WlrKeyboardFocus  [uncreatable]  : var
  enum: None | Exclusive | OnDemand

### WlrLayer  [uncreatable]  : var
  enum: Background | Bottom | Top | Overlay

### WlrLayershell  : ProxyWindowBase
  layer: Enum
  namespace: string
  keyboardFocus: Enum
  anchors: Anchors
  exclusiveZone: int
  exclusionMode: Enum
  margins: Margins
  aboveWindows: bool
  focusable: bool

---

## `Quickshell.Widgets`


---

## Tipos definidos em QML (fora do metadata C++)

Estes são arquivos `.qml` dentro do próprio módulo Quickshell, então não aparecem nos
`.qmltypes`. Assinaturas lidas direto do fonte instalado.

### `Quickshell.Io` → FileView

Acessor de arquivos pequenos. É o mecanismo que liga o design system ao Quickshell.

```
path: string                 // caminho do arquivo
preload: bool                // lê já na criação
blockLoading: bool           // primeira leitura síncrona (evita 1 frame sem cor)
blockAllReads: bool          // toda leitura síncrona
blockWrites: bool
atomicWrites: bool           // grava em temp + rename (default true)
watchChanges: bool           // emite fileChanged quando o arquivo muda em disco
printErrors: bool
adapter: FileViewAdapter     // ex.: JsonAdapter, para mapear JSON -> propriedades
readonly loaded: bool

fn text() -> string          // conteúdo como texto
fn data() -> var             // conteúdo como ArrayBuffer
fn reload() -> void
fn setText(string text) -> void
fn setData(var data) -> void

signal loaded()
signal loadFailed(FileViewError.Enum error)
signal saved()
signal saveFailed(FileViewError.Enum error)
signal fileChanged()         // requer watchChanges: true
signal adapterUpdated()
```

`FileViewError` enum: `Success | Unknown | FileNotFound | PermissionDenied | NotAFile`

> `watchChanges: true` **não** recarrega sozinho — ele só avisa. É preciso
> `onFileChanged: reload()`, e é exatamente por isso que `shell.qml` tem essa linha.

### `Quickshell.Widgets` → IconImage

Imagem otimizada para ícones (usa o path de `Quickshell.iconPath()`; faz mipmap e
escala correta, ao contrário de um `Image` cru).

```
source: url                  // alias de image.source
asynchronous: bool
mipmap: bool
status                       // alias de Image.status
backer: Image                // o Image interno, se precisar de mais controle
implicitSize: real           // define implicitWidth E implicitHeight juntos
readonly actualSize: real    // min(width, height)
```

### `Quickshell.Widgets` → ClippingRectangle

Retângulo que **recorta o conteúdo dentro da borda arredondada** — um `Rectangle`
comum com `clip: true` recorta no bounding box quadrado, ignorando o `radius`.

```
color: color
radius: real
topLeftRadius / topRightRadius / bottomLeftRadius / bottomRightRadius: real
border.color / border.width / border.pixelAligned
contentUnderBorder: bool     // conteúdo passa por baixo da borda (default false)
contentInsideBorder: bool    // = !contentUnderBorder
antialiasing: bool
default property data        // filhos vão para o contentItem
readonly contentItem: Item
```

### `Quickshell.Widgets` → WrapperItem / WrapperRectangle / WrapperMouseArea / ClippingWrapperRectangle

Resolvem o problema de "container que se dimensiona pelo filho" sem cair no loop de
binding do `childrenRect` (ver `gotchas.md`). Todos compartilham:

```
child: Item                  // o filho único (ou declare inline; é a default property)
margin: real                 // margem em todos os lados
extraMargin: real            // somado às margens individuais
topMargin / bottomMargin / leftMargin / rightMargin: real
resizeChild: bool            // redimensiona o filho junto (default true)
implicitWidth / implicitHeight: real   // derivados do filho + margens
```

`WrapperRectangle` acrescenta tudo de `Rectangle` (`color`, `radius`, `border`) e
`contentInsideBorder: bool`. `ClippingWrapperRectangle` é o mesmo com recorte no raio —
é o que a FAQ oficial recomenda para **arredondar uma imagem**.
