import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "lib"
import "selection.js" as Selection

ColumnLayout {
    id: page

    property string cfg_Theme
    property string cfg_ThemeSelection
    property alias cfg_ShowFps: showFpsBox.checked
    property alias cfg_TargetFps: speedBox.value
    property alias cfg_MaxFps: maxFpsBox.value
    property alias cfg_ResolutionPercent: resolutionBox.value
    property alias cfg_BatteryFps: batteryFpsBox.value
    property alias cfg_PauseWhenLocked: lockedBox.checked
    property alias cfg_PauseWhenCovered: coveredBox.checked
    property string cfg_BatteryMode

    // Set by Plasma's wallpaper settings page
    property var configDialog
    property var wallpaperConfiguration

    signal configurationChanged()

    Component.onCompleted: ThemeStore.builtinDir = Qt.resolvedUrl("../themes")

    readonly property var selection: Selection.parse(cfg_ThemeSelection, cfg_Theme)

    // Some room at the sides, the settings page is otherwise flush with the border of the dialog
    readonly property int sideMargin: Kirigami.Units.gridUnit

    QQC2.TabBar {
        id: tabs
        Layout.fillWidth: true
        Layout.leftMargin: page.sideMargin
        Layout.rightMargin: page.sideMargin
        QQC2.TabButton { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Themes") }
        QQC2.TabButton { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Performance") }
        QQC2.TabButton { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Power") }
    }

    StackLayout {
        currentIndex: tabs.currentIndex
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: page.sideMargin
        Layout.rightMargin: page.sideMargin

        // ---- Themes -----------------------------------------------------------
        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            // Label and buttons on the left, the selection takes all the room that is left
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    level: 2
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Substrate %1", ThemeStore.version)
                }

                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Manage themes…")
                    icon.name: "document-edit"
                    Layout.fillWidth: true
                    onClicked: manager.show()
                }

                QQC2.CheckBox {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Disable built-in themes")
                    checked: ThemeStore.hideBuiltin
                    onToggled: ThemeStore.hideBuiltin = checked
                }

                QQC2.Label {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Choose which collections and themes run on your desktop. Tick a whole collection or single themes from it. The ticked ones take turns at every reset. If nothing is ticked, all themes run.")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing

                ThemeSelector {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
                    selection: page.selection
                    onSelectionEdited: function (list) { page.cfg_ThemeSelection = Selection.stringify(list); }
                }
            }
        }

        // ---- Performance ---------------------------------------------------------
        Kirigami.FormLayout {
            QQC2.SpinBox {
                id: speedBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Animation speed:")
                from: 1
                to: 480
                stepSize: 5
                editable: true
                textFromValue: function (value) { return i18nd("plasma_wallpaper_com.github.spider19996.substrate", "%1 steps/s", value); }
                valueFromText: function (text) { return parseInt(text) || 60; }
            }

            QQC2.SpinBox {
                id: maxFpsBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Maximum frame rate:")
                from: 0
                to: 1000
                stepSize: 10
                editable: true
                textFromValue: function (value) { return value === 0 ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Screen refresh rate") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "%1 FPS", value); }
                valueFromText: function (text) { return parseInt(text) || 0; }
            }

            QQC2.Label {
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Lower values save power. Themes without sparks only draw when a new simulation step is due anyway.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }

            QQC2.SpinBox {
                id: resolutionBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Resolution:")
                from: 10
                to: 200
                stepSize: 5
                editable: true
                textFromValue: function (value) { return value + " %"; }
                valueFromText: function (text) { return Math.max(10, Math.min(200, parseInt(text) || 100)); }
            }

            QQC2.Label {
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Share of the screen size the picture is calculated at. Lower values use less memory and power but look coarser.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }

            QQC2.Label {
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Shows frames per second and what this wallpaper costs: CPU time of the simulation, memory for the picture, and the data sent to the GPU per second.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }

            QQC2.CheckBox {
                id: showFpsBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Overlay:")
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Show frame rate and resource use")
            }
        }

        // ---- Power ------------------------------------------------------------
        Kirigami.FormLayout {
            QQC2.ComboBox {
                id: batteryModeBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "On battery:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Keep running normally"), value: "normal" },
                    { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Limit the frame rate"), value: "limit" },
                    { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Pause"), value: "pause" }
                ]
                function sync() { currentIndex = Math.max(0, indexOfValue(page.cfg_BatteryMode)); }
                Component.onCompleted: sync()
                Connections {
                    target: page
                    function onCfg_BatteryModeChanged() { batteryModeBox.sync(); }
                }
                onActivated: page.cfg_BatteryMode = currentValue
            }

            QQC2.SpinBox {
                id: batteryFpsBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Battery frame rate:")
                enabled: page.cfg_BatteryMode === "limit"
                from: 1
                to: 240
                stepSize: 5
                editable: true
                textFromValue: function (value) { return i18nd("plasma_wallpaper_com.github.spider19996.substrate", "%1 FPS", value); }
                valueFromText: function (text) { return parseInt(text) || 30; }
            }

            QQC2.CheckBox {
                id: lockedBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Pause while:")
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "the screen is locked")
            }

            QQC2.CheckBox {
                id: coveredBox
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "a maximized or fullscreen window covers the desktop")
            }

            QQC2.Label {
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Pausing keeps the picture as it is and costs no power. Drawing continues where it stopped.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }
        }
    }

    ThemeManager {
        id: manager
    }
}
