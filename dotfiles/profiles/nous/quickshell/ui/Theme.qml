// Design system do perfil "nous" em QML — o equivalente do colors.css/palette.toml
// para a barra Quickshell. Fonte única de cor, fonte, raio, grid e duração; nenhum
// arquivo desta barra deve ter hex literal fora daqui.
//
// Valores portados literalmente de dotfiles/profiles/nous/waybar/{style.css,geometry.jsonc}
// e de palette.toml — ver DESIGN.md "Constantes calibradas" para o porquê de cada um.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Paleta (design system, via wallust) ─────────────────────────────
    // Espelha dotfiles/profiles/nous/palette.toml; only existe como fallback
    // porque colors.json é gerado por `update-theme`/`theme-profile` e
    // gitignored (não existe num checkout limpo).
    readonly property var fallbackColors: ({
        background: "#07070F",
        foreground: "#F5F5F5",
        primary: "#0000F2",
        secondary: "#575380",
        alert: "#F05252",
        text: "#F5F5F5",
        warning: "#FDBA8C",
        surface: "#3A3A4A"
    })
    property var colors: fallbackColors

    readonly property color cBg: colors.background
    readonly property color cText: colors.text
    readonly property color cPrimary: colors.primary
    readonly property color cSecondary: colors.secondary
    readonly property color cAlert: colors.alert
    readonly property color cWarning: colors.warning
    readonly property color cSurface: colors.surface

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true // só avisa da mudança; recarregar é com o onFileChanged
        blockLoading: true // 1ª leitura síncrona: nenhum frame com a paleta errada
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colors = Object.assign({}, root.fallbackColors, JSON.parse(text()));
            } catch (e) {
                console.warn("nous/Theme: colors.json inválido, mantendo fallback:", e);
            }
        }
    }

    // ── Geometria ─────────────────────────────────────────────────────
    // DESIGN.md: "Sharp corners (0-2px)". Um raio só, aplicado em tudo.
    readonly property int radiusSharp: 0

    readonly property int barHeight: 42 // waybar/geometry.jsonc
    // Altura reservada para o hub expandido (PanelMedia + PanelCalendar
    // empilhados, ColumnLayout). ÚNICO número a revisar ao adicionar uma
    // página nova ao hub — a superfície do painel é FIXA (nunca animada,
    // gotchas §1), então tem de caber a soma máxima das páginas.
    readonly property int panelZone: 460
    readonly property int panelWidth: 340

    // Grid de 3.5px do DESIGN.md — paddings 3.5 / 7 / 10.5 / 14.
    readonly property real grid: 3.5
    readonly property real gridHalf: 7
    readonly property real gridOneAndHalf: 10.5
    readonly property real gridDouble: 14

    // Largura mínima dos módulos de status: impede a barra de "pular" ao
    // trocar de estado (waybar/style.css: #backlight, #pulseaudio, ...).
    readonly property int statusMinWidth: 52

    // ── Tipografia ───────────────────────────────────────────────────
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property string uiFont: "IBM Plex Sans"
    readonly property string monoFont: "IBM Plex Mono"
    readonly property string displayFont: "IBM Plex Serif"

    readonly property real fontSize: 13.5
    readonly property real clockFontSize: 14
    readonly property int clockFontWeight: Font.Medium
    readonly property real workspaceFontSize: 12

    // ── Durações ─────────────────────────────────────────────────────
    // "Precise, technical": mais seco que o default (220/280).
    readonly property int animFast: 160
    readonly property int animNormal: 200

    // ── Tokens derivados (hierarquia por alpha, nunca cor nova) ───────
    readonly property color separatorColor: Qt.alpha(cText, 0.08)
    readonly property color hoverBg: Qt.alpha(cPrimary, 0.14)
    readonly property color borderBottom: Qt.alpha(cPrimary, 0.35)
}
