// Tema de login (SDDM / Qt6).
//
// Layout: avatar circular ao centro, nome do usuário abaixo, campo de senha abaixo.
// Fundo: o wallpaper atual, borrado. Ao logar, o borrão se dissolve e a UI some —
// as duas animações têm a mesma duração e o mesmo easing, então "saem juntas".
//
// Cores e imagens NÃO são hardcoded: vêm de dataDir (ver theme.conf), populado pelo
// `update-theme` / wallust. Os valores abaixo são apenas fallback se o diretório
// ainda não existir (checkout novo, antes do primeiro update-theme).

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Effects

Rectangle {
    id: root

    property string dataDir: config.dataDir || "/var/lib/sddm-theme"
    property int animMs: parseInt(config.animationDuration) || 700
    property string uiFont: config.font || "Sans"

    // ── Design tokens (sobrescritos por dataDir/colors.conf, gerado pelo wallust) ──
    property color colBase: "#11111b"
    property color colText: "#cdd6f4"
    property color colPrimary: "#89b4fa"
    property color colSecondary: "#a6e3a1"
    property color colAlert: "#f38ba8"

    property string userName: ""
    property string realName: ""

    color: colBase

    Component.onCompleted: {
        // Nunca deixe a paleta derrubar a UI: sem cores, seguem os fallbacks.
        try {
            loadColors();
        } catch (e) {}
        enterAnim.start();
    }

    // Lê os tokens gerados pelo wallust. Exige QML_XHR_ALLOW_FILE_READ=1 no ambiente
    // do greeter (ver modules/system/login.nix) — o Qt6 bloqueia file:// por padrão.
    function loadColors() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "file://" + dataDir + "/colors.conf", false);
        xhr.send(null);
        if (xhr.status !== 200 && xhr.status !== 0)
            return;

        var lines = xhr.responseText.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var sep = lines[i].indexOf("=");
            if (sep < 0)
                continue;
            var key = lines[i].slice(0, sep).trim();
            var val = lines[i].slice(sep + 1).trim();
            if (val === "")
                continue;

            if (key === "base")
                colBase = val;
            else if (key === "text")
                colText = val;
            else if (key === "primary")
                colPrimary = val;
            else if (key === "secondary")
                colSecondary = val;
            else if (key === "alert")
                colAlert = val;
        }
    }

    // O userModel do SDDM só expõe os papéis (name/realName) dentro de um delegate.
    Repeater {
        model: userModel
        Item {
            Component.onCompleted: {
                if (index !== userModel.lastIndex)
                    return;
                root.userName = model.name;
                root.realName = model.realName || model.name;
            }
        }
    }

    // ── Fundo: wallpaper nítido, coberto pela versão borrada ──────────────────
    Image {
        id: bgSharp
        anchors.fill: parent
        source: root.dataDir + "/wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
    }

    Image {
        id: bgBlur
        anchors.fill: parent
        source: root.dataDir + "/wallpaper-blur.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
    }

    // Véu escuro: garante contraste do texto sobre qualquer wallpaper.
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: root.colBase
        opacity: 0.45
    }

    // ── Conteúdo: avatar → nome → senha ───────────────────────────────────────
    Column {
        id: content
        anchors.centerIn: parent
        spacing: 22
        opacity: 0

        Item {
            id: avatarBox
            width: 148
            height: 148
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                id: avatarImg
                anchors.fill: parent
                source: root.dataDir + "/avatar.png"
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: false
                cache: false
                sourceSize.width: 296
                sourceSize.height: 296
            }

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: avatarImg
                maskEnabled: true
                maskSource: avatarMask
                visible: avatarImg.status === Image.Ready
            }

            // Sem foto em dataDir: círculo com a inicial.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: avatarImg.status !== Image.Ready
                color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.22)

                Text {
                    anchors.centerIn: parent
                    text: root.realName.charAt(0).toUpperCase()
                    color: root.colText
                    font.family: root.uiFont
                    font.pixelSize: 56
                    font.bold: true
                }
            }

            // Anel de destaque.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.85)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.realName
            color: root.colText
            font.family: root.uiFont
            font.pixelSize: 24
            font.weight: Font.Medium
        }

        TextField {
            id: password
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 44
            echoMode: TextInput.Password
            color: root.colText
            font.family: root.uiFont
            font.pixelSize: 15
            horizontalAlignment: TextInput.AlignHCenter
            leftPadding: 14
            rightPadding: 14
            focus: true
            enabled: !exitAnim.running

            background: Rectangle {
                radius: 10
                color: Qt.rgba(root.colBase.r, root.colBase.g, root.colBase.b, 0.55)
                border.width: 1
                border.color: password.activeFocus ? root.colPrimary : Qt.rgba(root.colText.r, root.colText.g, root.colText.b, 0.25)

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // Placeholder próprio: o estilo Basic esconde o placeholderText nativo
            // quando o campo está focado e centralizado — e ele nasce focado.
            Text {
                anchors.centerIn: parent
                visible: password.text.length === 0
                text: "Senha"
                color: Qt.rgba(root.colText.r, root.colText.g, root.colText.b, 0.45)
                font.family: root.uiFont
                font.pixelSize: 15
            }

            onAccepted: root.tryLogin()
            onTextChanged: errorMsg.text = ""
        }

        Text {
            id: errorMsg
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.colAlert
            font.family: root.uiFont
            font.pixelSize: 13
            height: 16
        }
    }

    function tryLogin() {
        if (password.text === "")
            return;
        errorMsg.text = "";
        sddm.login(root.userName, password.text, sessionModel.lastIndex);
    }

    // ── Ações de energia ──────────────────────────────────────────────────────
    component PowerAction: Text {
        property bool available: true

        visible: available
        color: hover.containsMouse ? root.colPrimary : root.colText
        font.family: root.uiFont
        font.pixelSize: 13

        signal triggered

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.triggered()
        }
    }

    Row {
        id: powerRow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 18
        opacity: content.opacity * 0.7

        PowerAction {
            text: "Suspender"
            available: sddm.canSuspend
            onTriggered: sddm.suspend()
        }
        PowerAction {
            text: "Reiniciar"
            available: sddm.canReboot
            onTriggered: sddm.reboot()
        }
        PowerAction {
            text: "Desligar"
            available: sddm.canPowerOff
            onTriggered: sddm.powerOff()
        }
    }

    // ── Animações ─────────────────────────────────────────────────────────────
    // Entrada: a UI aparece em fade sobre o fundo já borrado.
    NumberAnimation {
        id: enterAnim
        target: content
        property: "opacity"
        from: 0
        to: 1
        duration: root.animMs
        easing.type: Easing.OutCubic
    }

    // Login aceito: o borrão se dissolve enquanto a UI some, na mesma velocidade,
    // revelando o wallpaper nítido — a transição para a sessão.
    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: bgBlur
            property: "opacity"
            to: 0
            duration: root.animMs
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: scrim
            property: "opacity"
            to: 0
            duration: root.animMs
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0
            duration: root.animMs
            easing.type: Easing.InOutQuad
        }
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            exitAnim.start();
        }

        function onLoginFailed() {
            errorMsg.text = "Senha incorreta";
            password.text = "";
            password.forceActiveFocus();
            shake.start();
        }
    }

    SequentialAnimation {
        id: shake
        loops: 2
        NumberAnimation {
            target: password
            property: "anchors.horizontalCenterOffset"
            to: 8
            duration: 45
        }
        NumberAnimation {
            target: password
            property: "anchors.horizontalCenterOffset"
            to: -8
            duration: 45
        }
        NumberAnimation {
            target: password
            property: "anchors.horizontalCenterOffset"
            to: 0
            duration: 45
        }
    }
}
