// Grid de mês — substitui o tooltip Pango do clock (que só existia porque
// Pango não tem @import — waybar-config.jsonc) e o `gsimplecal` do on-click.
// Navegação por mês com as setas; "hoje" fica sublinhado em @alert, mesma
// semântica de destaque que o tooltip original usava para {today}.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    readonly property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth() // 0-11

    readonly property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    readonly property var weekdayNames: ["D", "S", "T", "Q", "Q", "S", "S"]

    // Matriz de 42 dias (6 semanas), começando no domingo da semana do dia 1.
    readonly property var days: {
        const first = new Date(root.viewYear, root.viewMonth, 1);
        const start = new Date(first);
        start.setDate(1 - first.getDay());
        const out = [];
        for (var i = 0; i < 42; i++) {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            out.push(d);
        }
        return out;
    }

    function isToday(d) {
        return d.getFullYear() === root.today.getFullYear() && d.getMonth() === root.today.getMonth() && d.getDate() === root.today.getDate();
    }
    function isCurrentMonth(d) {
        return d.getMonth() === root.viewMonth;
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            id: monthLabel
            Layout.fillWidth: true
            text: root.monthNames[root.viewMonth] + " " + root.viewYear
            color: Theme.cText
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Text {
            text: "‹"
            color: Theme.cPrimary
            font.pixelSize: 14
            TapHandler {
                onTapped: {
                    if (root.viewMonth === 0) {
                        root.viewMonth = 11;
                        root.viewYear -= 1;
                    } else {
                        root.viewMonth -= 1;
                    }
                }
            }
        }
        Text {
            text: "›"
            color: Theme.cPrimary
            font.pixelSize: 14
            TapHandler {
                onTapped: {
                    if (root.viewMonth === 11) {
                        root.viewMonth = 0;
                        root.viewYear += 1;
                    } else {
                        root.viewMonth += 1;
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 3
        columnSpacing: 0

        Repeater {
            model: root.weekdayNames
            delegate: Text {
                required property string modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Qt.alpha(Theme.cText, 0.4)
                font.family: Theme.monoFont
                font.pixelSize: 10
            }
        }

        Repeater {
            model: root.days
            delegate: Item {
                id: cell
                required property date modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 22

                readonly property bool today: root.isToday(cell.modelData)
                readonly property bool inMonth: root.isCurrentMonth(cell.modelData)

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: Theme.radiusSharp
                    color: cell.today ? Theme.cAlert : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.getDate()
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                        color: cell.today ? Theme.cBg : (cell.inMonth ? Theme.cText : Qt.alpha(Theme.cText, 0.25))
                    }
                }
            }
        }
    }
}
