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
            text: i18n("Next Substrate Theme")
            icon.name: "go-next"
            onTriggered: substrate.nextTheme()
        },
        PlasmaCore.Action {
            text: i18n("Restart Substrate Pattern")
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

    // Frame rate overlay, on a dark box so it stays readable on bright themes
    Rectangle {
        visible: root.config.ShowFps
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        width: fpsLabel.implicitWidth + 16
        height: fpsLabel.implicitHeight + 8
        radius: 4
        color: "#99000000"

        Text {
            id: fpsLabel
            anchors.centerIn: parent
            font.family: "monospace"
            font.pixelSize: 16
            color: "white"
            text: "FPS: " + substrate.renderFps + (root.paused ? " (paused)" : "")
        }
    }
}
