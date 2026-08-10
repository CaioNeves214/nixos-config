// A barra em si: uma única superfície layer-shell, fundo sólido ponta-a-ponta
// (nada de placas flutuantes — DESIGN.md: "the fundo mora na superfície da
// janela"). Reserva Theme.barHeight de exclusiveZone — a aritmética negativa
// que o widget de mídia antigo precisava contra a waybar deixa de existir.
//
// A superfície nasce alta o bastante para o hub expandido (Theme.panelZone)
// e NUNCA muda de tamanho (gotchas §1) — os drop-downs (HubPanel e os
// próprios módulos da direita, quando ganharem popup) animam por dentro,
// clipados.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    // Passado explicitamente aos módulos que abrem PopupWindow (tray, volume):
    // `anchor.window: QsWindow.window` (o attached property) crasha aqui —
    // é avaliado durante a montagem inicial do item tree, antes da janela
    // estar totalmente pronta, e o Quickshell 0.3.0 lê um QQuickItem::window()
    // nulo dentro de PopupAnchor::onItemWindowChanged (SIGSEGV). Um id
    // explícito, passado por propriedade, não sofre esse problema de timing.

    anchors {
        top: true
        left: true
        right: true
    }

    // Reserva a faixa da barra de verdade — a aritmética negativa que o
    // widget de mídia antigo precisava contra a waybar não existe mais: um
    // painel-irmão ancorado no topo (ex.: Notifications.qml) cai em y=42
    // sozinho, com margins.top: 0.
    exclusiveZone: Theme.barHeight

    implicitHeight: Theme.barHeight + Theme.panelZone // FIXO — nunca animado
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top // Top, não Overlay: não cobre fullscreen
    WlrLayershell.namespace: "quickshell-bar"

    // Enquanto não há painel algum aberto, a máscara é só a faixa da barra —
    // o resto da superfície (panelZone) não deve capturar clique nenhum.
    // Cada módulo com drop-down soma sua própria região aqui quando abre
    // (ver Hub.qml / HubPanel.qml, tarefa 5).
    mask: Region {
        Region {
            x: 0
            y: 0
            width: bar.width
            height: Theme.barHeight
        }
        // Painel do hub: geometria EXPLÍCITA dirigida pelo booleano de
        // estado, nunca `item: hub` — a altura real do clip está animando, e
        // a região de input precisa já valer a altura-alvo desde o primeiro
        // frame da abertura, senão o ponteiro sai da máscara ao descer para
        // o painel e ele fecha sozinho (gotchas / media-widget.md).
        Region {
            x: hub.x
            y: Theme.barHeight
            width: Theme.panelWidth
            height: hub.expanded ? Theme.panelZone : 0
        }
    }

    // Faixa sólida da barra — cor e filete inferior de 1px, a assinatura
    // visual do perfil (waybar/style.css: window#waybar).
    Rectangle {
        width: parent.width
        height: Theme.barHeight
        color: Theme.cBg
        border.width: 0 // workaround QTBUG-137166

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.borderBottom
        }

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Theme.gridHalf
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gridOneAndHalf

            Workspaces {}
            WindowTitle {}
        }

        Hub {
            id: hub
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            barWindow: bar
        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            ModTray {
                hostWindow: bar
            }
            ModBluetooth {}
            ModBacklight {}
            ModVolume {
                hostWindow: bar
            }
            ModNetwork {}
            ModTemperature {}
            ModCpu {}
            ModMemory {}
            ModBattery {}
        }
    }
}
