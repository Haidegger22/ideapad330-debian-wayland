import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    property string cpuText: "--"
    property string nvmeText: "--"
    property color cpuColour: "#8f8f8f"
    property color nvmeColour: "#8f8f8f"

    function colourFor(value, warn, hot) {
        if (isNaN(value)) return "#8f8f8f"
        if (value >= hot) return "#f25c4c"
        if (value >= warn) return "#f2c241"
        return "#74db75"
    }

    function apply(line) {
        var c = /CPU\s+([0-9.]+)/.exec(line)
        var n = /NVMe\s+([0-9.]+)/.exec(line)
        var cpu = c ? parseFloat(c[1]) : NaN
        var nvme = n ? parseFloat(n[1]) : NaN
        root.cpuText = isNaN(cpu) ? "--" : Math.round(cpu) + "\u00b0"
        root.nvmeText = isNaN(nvme) ? "--" : Math.round(nvme) + "\u00b0"
        root.cpuColour = colourFor(cpu, 50, 70)
        root.nvmeColour = colourFor(nvme, 50, 70)
    }

    preferredRepresentation: fullRepresentation

    fullRepresentation: RowLayout {
        spacing: 6
        PlasmaComponents3.Label {
            text: "CPU"
            color: root.cpuColour
            font.bold: true
        }
        PlasmaComponents3.Label {
            text: root.cpuText
        }
        PlasmaComponents3.Label {
            text: "NVMe"
            color: root.nvmeColour
            font.bold: true
        }
        PlasmaComponents3.Label {
            text: root.nvmeText
        }
    }

    P5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            if (data["stdout"]) root.apply(data["stdout"])
            execSource.disconnectSource(source)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: execSource.connectSource("__HOME__/.local/bin/temp-line.sh")
    }
}