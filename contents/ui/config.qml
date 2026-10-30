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
        QQC2.TabButton { text: i18n("Themes") }
        QQC2.TabButton { text: i18n("Performance") }
        QQC2.TabButton { text: i18n("Power") }
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
                    text: i18n("Substrate %1", ThemeStore.version)
                }

                QQC2.Button {
                    text: i18n("Manage themes…")
                    icon.name: "document-edit"
                    Layout.fillWidth: true
                    onClicked: manager.show()
                }

                QQC2.CheckBox {
                    text: i18n("Disable built-in themes")
                    checked: ThemeStore.hideBuiltin
                    onToggled: ThemeStore.hideBuiltin = checked
                }

                QQC2.Label {
                    text: i18n("Choose which collections and themes run on your desktop. Tick a whole collection or single themes from it. The ticked ones take turns at every hard reset. If nothing is ticked, all themes run.")
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
                Kirigami.FormData.label: i18n("Animation speed:")
                from: 1
                to: 480
                stepSize: 5
                editable: true
                textFromValue: function (value) { return i18n("%1 steps/s", value); }
                valueFromText: function (text) { return parseInt(text) || 60; }
            }

            QQC2.SpinBox {
                id: maxFpsBox
                Kirigami.FormData.label: i18n("Maximum frame rate:")
                from: 0
                to: 1000
                stepSize: 10
                editable: true
                textFromValue: function (value) { return value === 0 ? i18n("Screen refresh rate") : i18n("%1 FPS", value); }
                valueFromText: function (text) { return parseInt(text) || 0; }
            }

            QQC2.Label {
                text: i18n("Lower values save power. Themes without sparks only draw when a new simulation step is due anyway.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }

            QQC2.SpinBox {
                id: resolutionBox
                Kirigami.FormData.label: i18n("Resolution:")
                from: 10
                to: 200
                stepSize: 5
                editable: true
                textFromValue: function (value) { return value + " %"; }
                valueFromText: function (text) { return Math.max(10, Math.min(200, parseInt(text) || 100)); }
            }

            QQC2.Label {
                text: i18n("Share of the screen size the picture is calculated at. Lower values use less memory and power but look coarser.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }

            QQC2.CheckBox {
                id: showFpsBox
                Kirigami.FormData.label: i18n("Overlay:")
                text: i18n("Show frame rate")
            }
        }

        // ---- Power ------------------------------------------------------------
        Kirigami.FormLayout {
            QQC2.ComboBox {
                id: batteryModeBox
                Kirigami.FormData.label: i18n("On battery:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Keep running normally"), value: "normal" },
                    { text: i18n("Limit the frame rate"), value: "limit" },
                    { text: i18n("Pause"), value: "pause" }
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
                Kirigami.FormData.label: i18n("Battery frame rate:")
                enabled: page.cfg_BatteryMode === "limit"
                from: 1
                to: 240
                stepSize: 5
                editable: true
                textFromValue: function (value) { return i18n("%1 FPS", value); }
                valueFromText: function (text) { return parseInt(text) || 30; }
            }

            QQC2.CheckBox {
                id: lockedBox
                Kirigami.FormData.label: i18n("Pause while:")
                text: i18n("the screen is locked")
            }

            QQC2.CheckBox {
                id: coveredBox
                text: i18n("a maximized or fullscreen window covers the desktop")
            }

            QQC2.Label {
                text: i18n("Pausing keeps the picture as it is and costs no power. Drawing continues where it stopped.")
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
