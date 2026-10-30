import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "lib"
import "selection.js" as Selection

WallpaperItem {
    id: root

    readonly property var config: wallpaper.configuration
    readonly property bool onBattery: PowerMonitor.onBattery

    // Reasons not to draw
    readonly property bool covered: coveredLoader.item ? coveredLoader.item.covered : false
    readonly property bool paused: (config.BatteryMode === "pause" && onBattery)
                                   || (config.PauseWhenLocked && PowerMonitor.screenLocked)
                                   || (config.PauseWhenCovered && covered)

    // Frame limit: the lower of the chosen limit and, on battery, the battery limit
    readonly property int frameLimit: {
        var limit = config.MaxFps;
        if (config.BatteryMode === "limit" && onBattery)
            limit = limit > 0 ? Math.min(limit, config.BatteryFps) : config.BatteryFps;
        return limit;
    }

    Component.onCompleted: ThemeStore.builtinDir = Qt.resolvedUrl("../themes")

    contextualActions: [
        PlasmaCore.Action {
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Next Substrate Theme")
            icon.name: "go-next"
            onTriggered: substrate.nextTheme()
        },
        PlasmaCore.Action {
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Restart Substrate Pattern")
            icon.name: "view-refresh"
            onTriggered: substrate.restart()
        }
    ]

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Substrate {
        id: substrate
        anchors.fill: parent
        themes: ThemeStore.themes
        selection: Selection.parse(root.config.ThemeSelection, root.config.Theme)
        fps: root.config.TargetFps
        maxFps: root.frameLimit
        resolutionScale: root.config.ResolutionPercent / 100
        running: !root.paused
    }

    // Only built when needed, a missing task manager module just turns the detection off
    Loader {
        id: coveredLoader
        active: root.config.PauseWhenCovered
        source: "CoveredDetector.qml"
    }

    // Frame rate and resource use overlay, on a dark box so it stays readable on bright themes
    Rectangle {
        visible: root.config.ShowFps
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        width: usageLabel.implicitWidth + 16
        height: usageLabel.implicitHeight + 8
        radius: 4
        color: "#99000000"

        Text {
            id: usageLabel
            anchors.centerIn: parent
            font.family: "monospace"
            font.pixelSize: 16
            color: "white"
            // Simulation and picture are all this wallpaper does on the CPU; the GPU has one texture to show
            // and the sparks to draw, so what is sent to it is the number that counts there
            readonly property var usage: substrate.usage
            text: "FPS: " + substrate.renderFps + (root.paused ? " (paused)" : "")
                  + (usage.simMs !== undefined
                     ? "\nCPU: " + usage.simLoad.toFixed(1) + " % of a core (" + usage.simMs.toFixed(2) + " ms/step)"
                       + "\nRAM: " + Math.round(usage.memoryMb) + " MB"
                       + "\nGPU: " + Math.round(usage.uploadMb) + " MB/s sent, " + usage.sparkCount + " sparks"
                     : "")
        }
    }
}
