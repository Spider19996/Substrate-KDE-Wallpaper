import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

import "lib"
import "assistant.js" as Generator
import "parameters.js" as Params

// Asks for the basics (background, palette, ...) and rolls the rest. Shows a live preview of the
// current roll and creates one or many themes in a collection.
Window {
    id: assistant

    title: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Theme assistant")
    width: Kirigami.Units.gridUnit * 52
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 40
    minimumHeight: Kirigami.Units.gridUnit * 30
    color: Kirigami.Theme.backgroundColor

    // The themes were created: first one, for the manager to select
    signal created(string firstKey)

    property var generated: ({})
    property var customBackground: [30, 30, 60]

    function options() {
        return {
            background: backgroundBox.currentValue,
            customBackground: assistant.customBackground,
            palette: paletteBox.currentValue,
            colorCount: colorCountBox.value,
            rainbow: rainbowBox.checked,
            curved: curvedBox.currentValue,
            speed: speedBox.currentValue,
            sand: sandBox.currentValue,
            sparks: sparksBox.currentValue,
            explosions: explosionsBox.currentValue,
            explosionSand: explosionSandBox.checked,
            variation: variationSlider.value,
            accentHue: Math.max(0, Kirigami.Theme.highlightColor.hslHue) * 360
        };
    }

    function roll() {
        generated = Generator.generate(options());
    }

    // Existing collections that take new themes
    readonly property var existing: {
        var list = ThemeStore.collections.filter(function (c) { return !ThemeStore.isBuiltinCollection(c); });
        if (list.indexOf("own") < 0) list.unshift("own");
        return list;
    }
    // The choices of the collection popup: a new one first, then the existing ones
    readonly property var targets: [{ text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "New collection…"), value: "" }].concat(
        existing.map(function (c) { return { text: c, value: c }; }))
    // New collections can go inside an existing one (and inherit its defaults)
    readonly property var parents: [{ text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "(top level)"), value: "" }].concat(
        existing.map(function (c) { return { text: c, value: c }; }))

    readonly property bool makeCollection: targetBox.currentValue === ""
    readonly property string newCollectionPath: {
        var name = collectionField.text.trim();
        var parent = parentBox.currentValue || "";
        return parent ? parent + "/" + name : name;
    }
    // Where the themes go
    readonly property string collectionPath: makeCollection ? newCollectionPath : targetBox.currentValue
    readonly property bool canCreate: makeCollection
        ? ThemeStore.isValidName(collectionField.text) && ThemeStore.collections.indexOf(newCollectionPath) < 0
          && !ThemeStore.isBuiltinCollection(newCollectionPath)
        : collectionPath !== ""

    // What the preview looks like in the chosen collection: its defaults under the rolled settings.
    // A new collection has no defaults yet, only the one it is created in hands some down.
    readonly property var previewConfig: {
        var inherited = ThemeStore.inheritedFor(makeCollection ? (parentBox.currentValue || "") : collectionPath, true).values;
        return Object.assign({}, Params.defaults(), inherited, generated);
    }

    function start(collection) {
        var i = existing.indexOf(collection);
        // The first entry of the popup is "New collection…"
        targetBox.currentIndex = i >= 0 ? i + 1 : 0;
        parentBox.currentIndex = 0;
        collectionField.text = i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Generated");
        nameField.text = i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Generated");
        roll();
        show();
        raise();
    }

    function uniqueName(collection, base) {
        var name = base, n = 2;
        while (ThemeStore.theme(collection + "/" + name).key !== undefined) name = base + " " + n++;
        return name;
    }

    function create() {
        var collection = collectionPath;
        if (makeCollection && !ThemeStore.createCollection(collection)) return;
        var base = nameField.text.trim() || i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Generated");
        var first = "";
        for (var i = 0; i < countBox.value; i++) {
            var config = i === 0 ? generated : Generator.generate(options());
            var name = uniqueName(collection, countBox.value > 1 ? base + " " + (i + 1) : base);
            if (!ThemeStore.saveTheme(collection, name, ThemeStore.rebase(config, collection), "")) return;
            if (i === 0) first = collection + "/" + name;
        }
        created(first);
        close();
    }

    // Rolling again after every change would be wasteful while a slider moves
    Timer {
        id: rollSoon
        interval: 250
        onTriggered: assistant.roll()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // ---- questions -----------------------------------------------------
        QQC2.ScrollView {
            id: scroll
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24
            contentWidth: availableWidth

            Kirigami.FormLayout {
                width: scroll.availableWidth

                QQC2.ComboBox {
                    id: backgroundBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Background:")
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Black"), value: "black" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "White"), value: "white" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Dark tone"), value: "dark" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Light tone"), value: "light" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Own color"), value: "custom" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Random"), value: "random" }
                    ]
                    onActivated: rollSoon.restart()
                }

                QQC2.Button {
                    visible: backgroundBox.currentValue === "custom"
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Background color:")
                    onClicked: backgroundDialog.open()
                    contentItem: RowLayout {
                        Rectangle {
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.small
                            radius: 3
                            color: Params.toColor(assistant.customBackground)
                            border.color: Kirigami.Theme.textColor
                        }
                        QQC2.Label { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Choose…") }
                    }
                }

                QQC2.ComboBox {
                    id: paletteBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Colors:")
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Random mix"), value: "random" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Neighbouring hues"), value: "analogous" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Complementary"), value: "complementary" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Triad"), value: "triadic" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "One hue, many shades"), value: "monochrome" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Warm"), value: "warm" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Cool"), value: "cool" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Pastel"), value: "pastel" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Neon"), value: "neon" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Around the Plasma accent color"), value: "accent" }
                    ]
                    onActivated: rollSoon.restart()
                }

                QQC2.SpinBox {
                    id: colorCountBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Number of colors:")
                    from: 1
                    to: 16
                    value: 6
                    editable: true
                    onValueModified: rollSoon.restart()
                }

                QQC2.CheckBox {
                    id: rainbowBox
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Rainbow lines")
                    onToggled: rollSoon.restart()
                }

                Item { Kirigami.FormData.isSection: true }

                QQC2.ComboBox {
                    id: curvedBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Curved lines:")
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: 2
                    model: [
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "None"), value: "none" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Few"), value: "few" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Normal"), value: "normal" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Many"), value: "many" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Random"), value: "random" }
                    ]
                    onActivated: rollSoon.restart()
                }

                QQC2.ComboBox {
                    id: speedBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Speed:")
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: 1
                    model: [
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Slow"), value: "slow" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Normal"), value: "normal" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Fast"), value: "fast" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Random"), value: "random" }
                    ]
                    onActivated: rollSoon.restart()
                }

                QQC2.ComboBox {
                    id: sandBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Sand:")
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: 2
                    model: [
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "None"), value: "none" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Subtle"), value: "subtle" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Normal"), value: "normal" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Strong"), value: "strong" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Random"), value: "random" }
                    ]
                    onActivated: rollSoon.restart()
                }

                QQC2.ComboBox {
                    id: sparksBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Sparks:")
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: 2
                    model: [
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "None"), value: "none" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Few"), value: "few" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Normal"), value: "normal" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Lots"), value: "lots" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Random"), value: "random" }
                    ]
                    onActivated: rollSoon.restart()
                }

                QQC2.ComboBox {
                    id: explosionsBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Explosions:")
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Off"), value: "off" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Rare"), value: "rare" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Often"), value: "often" },
                        { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Random"), value: "random" }
                    ]
                    onActivated: rollSoon.restart()
                }

                QQC2.CheckBox {
                    id: explosionSandBox
                    enabled: explosionsBox.currentValue !== "off"
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Sand burst at explosions")
                    checked: true
                    onToggled: rollSoon.restart()
                }

                Item { Kirigami.FormData.isSection: true }

                ColumnLayout {
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Randomness:")
                    Kirigami.FormData.labelAlignment: Qt.AlignTop
                    spacing: 0

                    QQC2.Slider {
                        id: variationSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: 5
                        value: 40
                        onMoved: rollSoon.restart()
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "How far speed, sand, sparks and explosions may wander from their typical values: %1 %", variationSlider.value)
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ---- preview and creation ---------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 10
                color: "black"
                clip: true

                Substrate {
                    anchors.fill: parent
                    running: assistant.visible
                    themes: [ { key: "preview", collection: "preview", config: assistant.previewConfig } ]
                    selection: ["t:preview/preview"]
                    fps: 60
                    sparks: true
                }

                QQC2.Label {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.smallSpacing
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Preview")
                    color: "white"
                    opacity: 0.6
                }
            }

            QQC2.Button {
                Layout.alignment: Qt.AlignHCenter
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Roll again")
                icon.name: "roll"
                onClicked: assistant.roll()
            }

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.ComboBox {
                    id: targetBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Collection:")
                    textRole: "text"
                    valueRole: "value"
                    model: assistant.targets
                }

                QQC2.TextField {
                    id: collectionField
                    visible: assistant.makeCollection
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Collection name:")
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Generated")
                    color: assistant.canCreate ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
                }

                QQC2.ComboBox {
                    id: parentBox
                    visible: assistant.makeCollection
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Inside:")
                    textRole: "text"
                    valueRole: "value"
                    model: assistant.parents
                }

                QQC2.TextField {
                    id: nameField
                    Kirigami.FormData.label: countBox.value > 1 ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Theme name:") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Name:")
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Generated")
                }

                QQC2.SpinBox {
                    id: countBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "How many:")
                    from: 1
                    to: 30
                    value: 1
                    editable: true
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: (countBox.value > 1
                       ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "The preview becomes the first theme, the others are rolled with the same answers. ")
                       : "") + (assistant.makeCollection
                       ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "The collection is created first; the themes inherit what the assistant does not set from the collection they are inside.")
                       : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "The themes inherit everything this assistant does not set from their collection."))
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }
                QQC2.Button {
                    text: countBox.value > 1 ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Create %1 themes", countBox.value) : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Create theme")
                    icon.name: "list-add"
                    enabled: assistant.canCreate
                    onClicked: assistant.create()
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Cancel")
                    icon.name: "dialog-cancel"
                    onClicked: assistant.close()
                }
            }
        }
    }

    ColorDialog {
        id: backgroundDialog
        selectedColor: Params.toColor(assistant.customBackground)
        onAccepted: {
            assistant.customBackground = Params.fromColor(selectedColor);
            rollSoon.restart();
        }
    }
}
