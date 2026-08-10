// Visualizer de áudio real (Pipewire), extraído do shell.qml original.
// PwNodePeakMonitor lê o nível de pico do sink padrão — leitura de VU, não
// FFT, mas é dado de áudio de verdade, não uma curva senoidal fake.
// PwObjectTracker é obrigatório (gotchas §9): sem ele o Pipewire não assina
// as propriedades do node e tudo fica zerado, em silêncio.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

RowLayout {
    id: root

    property bool active: false // true quando o player está tocando
    readonly property int bars: 5
    readonly property int barW: 3
    property color color: Theme.cPrimary

    spacing: 3
    property var samples: new Array(bars).fill(0)

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    PwNodePeakMonitor {
        id: peakMonitor
        node: Pipewire.defaultAudioSink
        enabled: root.active
        // Ao pausar/parar, assenta as barras em 0 em vez de congelar no
        // último nível — sem isto o visualizer "trava" aceso.
        onEnabledChanged: {
            if (!enabled)
                root.samples = new Array(root.bars).fill(0);
        }
    }

    // sqrt() aproxima a resposta perceptual do ouvido (não-linear); o ganho
    // de 1.4 compensa picos de mixagem que raramente chegam perto de 1.0.
    Timer {
        interval: 90
        running: peakMonitor.enabled
        repeat: true
        onTriggered: {
            const level = Math.min(1, Math.sqrt(peakMonitor.peak) * 1.4);
            const next = root.samples.slice(1);
            next.push(level);
            root.samples = next;
        }
    }

    Repeater {
        model: root.bars
        delegate: Rectangle {
            id: bar
            required property int index

            Layout.preferredWidth: root.barW
            Layout.preferredHeight: 4 + (root.samples[index] ?? 0) * 20
            Layout.alignment: Qt.AlignVCenter
            radius: 0 // barras retas: leitura de VU, não de pílula
            color: root.active ? root.color : Qt.alpha(Theme.cText, 0.35)

            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }
}
