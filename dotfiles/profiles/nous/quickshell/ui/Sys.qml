// Fonte de dados para os módulos sem serviço nativo (CPU, memória,
// temperatura, backlight). UM Timer de 2s só, em vez de quatro Timer/Process
// separados — num Core i5 de 2012 isso importa (ver DESIGN.md / gotchas §10).
//
// watchChanges não serve em procfs (o kernel não emite inotify em /proc);
// o polling é dirigido pelo Timer daqui, não pelo FileView.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── CPU (/proc/stat) ────────────────────────────────────────────────
    property real cpuUsage: 0 // 0.0–1.0
    property real avgFrequencyGhz: 0
    property real _prevIdle: -1
    property real _prevTotal: -1

    FileView {
        id: statFile
        path: "/proc/stat"
        blockLoading: true
        onLoaded: root._parseStat(text())
    }

    function _parseStat(text) {
        const line = text.split("\n")[0];
        const f = line.trim().split(/\s+/).slice(1).map(Number);
        if (f.length < 8)
            return;
        const idle = f[3] + f[4]; // idle + iowait
        const total = f.reduce((a, b) => a + b, 0);
        if (root._prevTotal >= 0) {
            const dIdle = idle - root._prevIdle;
            const dTotal = total - root._prevTotal;
            root.cpuUsage = dTotal > 0 ? Math.max(0, Math.min(1, 1 - dIdle / dTotal)) : 0;
        }
        root._prevIdle = idle;
        root._prevTotal = total;
    }

    // ── Memória (/proc/meminfo) ─────────────────────────────────────────
    property real memUsedFrac: 0 // 0.0–1.0
    property real memUsedGB: 0
    property real memTotalGB: 0
    property real swapUsedGB: 0
    property real swapTotalGB: 0

    FileView {
        id: memFile
        path: "/proc/meminfo"
        blockLoading: true
        onLoaded: root._parseMeminfo(text())
    }

    function _parseMeminfo(text) {
        const kv = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                kv[m[1]] = Number(m[2]);
        }
        const totalKb = kv.MemTotal ?? 0;
        const availKb = kv.MemAvailable ?? totalKb;
        const usedKb = Math.max(0, totalKb - availKb);
        root.memTotalGB = totalKb / 1048576;
        root.memUsedGB = usedKb / 1048576;
        root.memUsedFrac = totalKb > 0 ? usedKb / totalKb : 0;

        const swapTotalKb = kv.SwapTotal ?? 0;
        const swapFreeKb = kv.SwapFree ?? swapTotalKb;
        root.swapTotalGB = swapTotalKb / 1048576;
        root.swapUsedGB = Math.max(0, swapTotalKb - swapFreeKb) / 1048576;
    }

    // ── Temperatura (hwmon do coretemp, resolvido uma vez no startup) ────
    property real tempCelsius: 0
    property bool tempAvailable: false
    property string _tempPath: ""

    Process {
        id: tempResolver
        running: true
        command: ["sh", "-c", "echo /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p && p.indexOf("*") === -1) {
                    root._tempPath = p;
                    root.tempAvailable = true;
                    tempFile.reload();
                } else {
                    console.warn("nous/Sys: hwmon do coretemp não encontrado — módulo de temperatura desabilitado");
                }
            }
        }
    }

    FileView {
        id: tempFile
        path: root._tempPath
        blockLoading: true
        onLoaded: {
            const v = parseInt(text().trim(), 10);
            if (!isNaN(v))
                root.tempCelsius = v / 1000;
        }
    }

    // ── Backlight (/sys/class/backlight/<device>, resolvido no startup) ──
    property real backlightFrac: 0 // 0.0–1.0
    property bool backlightAvailable: false
    property string _backlightDir: ""
    property real _backlightMax: 1

    Process {
        id: backlightResolver
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p) {
                    root._backlightDir = p;
                    root.backlightAvailable = true;
                    backlightMaxFile.reload();
                    backlightFile.reload();
                } else {
                    console.warn("nous/Sys: nenhum /sys/class/backlight/* encontrado — módulo de brilho desabilitado");
                }
            }
        }
    }

    FileView {
        id: backlightMaxFile
        path: root._backlightDir ? root._backlightDir + "max_brightness" : ""
        blockLoading: true
        onLoaded: {
            const v = parseInt(text().trim(), 10);
            if (!isNaN(v) && v > 0)
                root._backlightMax = v;
        }
    }

    FileView {
        id: backlightFile
        path: root._backlightDir ? root._backlightDir + "brightness" : ""
        blockLoading: true
        onLoaded: {
            const v = parseInt(text().trim(), 10);
            if (!isNaN(v))
                root.backlightFrac = Math.max(0, Math.min(1, v / root._backlightMax));
        }
    }

    // ── Rede e Bluetooth (fallback via nmcli/bluetoothctl) ────────────────
    // A verificação antecipada do plano (passo 2) mandava confirmar que
    // Quickshell.Networking e Quickshell.Bluetooth funcionam NESTE build
    // antes de investir neles. O tipo QML existe (.qmltypes presentes), mas
    // em teste isolado os dois voltam vazios em regime permanente —
    // Networking.devices.values.length === 0 e Bluetooth.adapters.values.length
    // === 0 — mesmo com NetworkManager e bluez rodando e com dispositivo
    // real conectado (confirmado via busctl/nmcli/bluetoothctl direto no
    // D-Bus). É o ponto de fallback que o plano previu: polling por Process,
    // no mesmo Timer de 2s, em vez do serviço nativo quebrado.
    property string networkKind: "disconnected" // "wifi" | "ethernet" | "disconnected"
    property int networkSignal: 0 // 0–100, só relevante para wifi
    property bool btPowered: false
    property int btConnectedCount: 0

    function _networkScript() {
        return [
            'dev=$(nmcli -g DEVICE,TYPE,STATE device status | awk -F: \'$3=="connected"{print $1":"$2; exit}\')',
            'if [ -z "$dev" ]; then echo disconnected:0; exit 0; fi',
            'name=${dev%%:*}',
            'type=${dev##*:}',
            'if [ "$type" = wifi ]; then',
            '  sig=$(nmcli -g IN-USE,SIGNAL device wifi list ifname "$name" | awk -F: \'$1=="*"{print $2; exit}\')',
            '  echo "wifi:${sig:-0}"',
            'else',
            '  echo "ethernet:0"',
            'fi'
        ].join('\n');
    }

    function _btScript() {
        return [
            'p=$(bluetoothctl show | awk -F": " \'/Powered/{print $2}\')',
            'c=$(bluetoothctl devices Connected 2>/dev/null | wc -l)',
            'echo "${p:-no}:$c"'
        ].join('\n');
    }

    function _parseNetwork(text) {
        const parts = text.trim().split(":");
        root.networkKind = parts[0] || "disconnected";
        root.networkSignal = parts.length > 1 ? (parseInt(parts[1], 10) || 0) : 0;
    }

    function _parseBluetooth(text) {
        const parts = text.trim().split(":");
        root.btPowered = parts[0] === "yes";
        root.btConnectedCount = parts.length > 1 ? (parseInt(parts[1], 10) || 0) : 0;
    }

    function toggleBluetooth() {
        Quickshell.execDetached(["bluetoothctl", "power", root.btPowered ? "off" : "on"]);
    }

    Process {
        id: netProc
        stdout: StdioCollector {
            onStreamFinished: root._parseNetwork(this.text)
        }
    }

    Process {
        id: btProc
        stdout: StdioCollector {
            onStreamFinished: root._parseBluetooth(this.text)
        }
    }

    Component.onCompleted: {
        netProc.exec(["sh", "-c", root._networkScript()]);
        btProc.exec(["sh", "-c", root._btScript()]);
    }

    // ── Timer único ──────────────────────────────────────────────────────
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            statFile.reload();
            memFile.reload();
            if (root.tempAvailable)
                tempFile.reload();
            if (root.backlightAvailable)
                backlightFile.reload();
            netProc.exec(["sh", "-c", root._networkScript()]);
            btProc.exec(["sh", "-c", root._btScript()]);
        }
    }
}
