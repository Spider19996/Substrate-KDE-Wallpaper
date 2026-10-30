import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

import "lib"
import "parameters.js" as Params
import "tree.js" as Tree

// Window to browse, edit, create, duplicate and delete themes and theme collections.
//
// A collection holds default values for all themes in it and in its subcollections. A theme only stores
// the values it changes; everything else is inherited. Click a collection to edit its defaults.
Window {
    id: win

    title: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Substrate themes")
    width: Kirigami.Units.gridUnit * 64
    height: Kirigami.Units.gridUnit * 44
    minimumWidth: Kirigami.Units.gridUnit * 44
    minimumHeight: Kirigami.Units.gridUnit * 28
    color: Kirigami.Theme.backgroundColor

    // What is edited: a theme (selectedKey) or the defaults of a collection (headerSelected)
    property string selectedKey: ""
    property bool headerSelected: false
    property string selectedCollection: ""
    // The settings this theme or collection sets itself; everything else is inherited
    property var draftOwn: ({})
    property string draftName: ""
    property string draftCollection: ""
    property bool dirty: false
    // Selection waiting for the "discard changes?" answer: { kind: "theme", key } or { kind: "collection", path }
    property var pending: null
    // Target of the delete confirmations, so they can also act on items that are not selected
    property string confirmKey: ""
    property string confirmCollection: ""
    property string notice: ""

    // Collapsed collections (path -> true)
    property var collapsed: ({})
    // The collection shown in the list ("" = all of them), chosen in the popup above the list
    property string viewRoot: ""
    readonly property var rows: Tree.rows(ThemeStore.collections, ThemeStore.themes, collapsed, function (t, depth) {
        return { type: "theme", key: t.key, collection: t.collection, title: t.name, depth: depth, builtin: t.builtin,
                 overridesBuiltin: t.overridesBuiltin, config: t.config };
    }, viewRoot)

    // Entries of the popup: every collection, indented by its depth
    readonly property var viewChoices: {
        var list = [{ path: "", text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "All collections"), depth: 0 }];
        ThemeStore.collections.forEach(function (c) { list.push({ path: c, text: Tree.labelOf(c), depth: Tree.depthOf(c) + 1 }); });
        return list;
    }

    function setViewRoot(path) {
        viewRoot = path;
        ThemeStore.setCollapsedCollections("managerView", path ? [path] : []);
    }

    // Something selected outside of the shown collection brings back the full list
    function showCollection(path) {
        if (viewRoot && path && !Tree.within(path, viewRoot)) setViewRoot("");
    }

    function toggleCollection(path) {
        var c = Object.assign({}, collapsed);
        c[path] = !c[path];
        collapsed = c;
        ThemeStore.setCollapsedCollections("manager", Object.keys(c).filter(function (k) { return c[k]; }));
    }

    // Folded collections are remembered
    Component.onCompleted: {
        var c = {};
        ThemeStore.collapsedCollections("manager").forEach(function (name) { c[name] = true; });
        collapsed = c;
        var view = ThemeStore.collapsedCollections("managerView");
        if (view.length > 0 && ThemeStore.collections.indexOf(view[0]) >= 0) viewRoot = view[0];
    }

    readonly property var selected: {
        ThemeStore.themes; // re-evaluate when files change
        return selectedKey ? ThemeStore.theme(selectedKey) : ({});
    }
    readonly property var collectionInfo: {
        ThemeStore.collectionData;
        return selectedCollection ? ThemeStore.collectionInfo(selectedCollection) : ({});
    }
    // Themes of the "system" collection are generated from the Plasma colors and cannot be changed
    readonly property bool selectedIsSystem: selected.builtin === true && selected.collection === "system"
    readonly property bool collectionIsSystem: collectionInfo.system === true
    readonly property bool selectedIsUser: selected.key !== undefined && !selected.builtin
    readonly property string targetKey: draftCollection.trim() + "/" + draftName.trim()
    readonly property bool storable: ThemeStore.canStore(draftCollection, draftName)
    readonly property bool canSave: headerSelected
        ? dirty && !collectionIsSystem
        : ThemeStore.isValidName(draftName) && ThemeStore.isValidPath(draftCollection)
          && storable && (dirty || targetKey !== selectedKey)

    // What the edited theme (or collection) gets from the collections above it
    readonly property var inheritance: {
        ThemeStore.themes;
        return headerSelected ? ThemeStore.inheritedFor(selectedCollection, false)
                              : ThemeStore.inheritedFor(draftCollection, true);
    }
    readonly property var inheritedValues: inheritance.values || ({})
    readonly property var inheritedSources: inheritance.sources || ({})
    // The values that apply: own on top of inherited on top of the plain defaults
    readonly property var effective: Object.assign({}, Params.defaults(), inheritedValues, draftOwn)

    function isOwn(key) { return draftOwn.hasOwnProperty(key); }

    // Where a value comes from, for the label next to it
    function sourceText(key) {
        if (isOwn(key)) return headerSelected ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "set here") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "changed");
        var from = inheritedSources[key];
        return from ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "from \"%1\"", from) : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "default");
    }

    function clone(object) { return JSON.parse(JSON.stringify(object || {})); }

    function load(key) {
        var t = ThemeStore.theme(key);
        if (t.key === undefined) return;
        selectedKey = key;
        headerSelected = false;
        draftOwn = clone(t.own);
        draftName = t.name;
        draftCollection = t.collection;
        selectedCollection = t.collection;
        showCollection(t.collection);
        notice = "";
        dirty = false;
    }

    function loadCollection(path) {
        showCollection(path);
        selectedCollection = path;
        headerSelected = true;
        draftOwn = clone(ThemeStore.collectionInfo(path).defaults);
        notice = "";
        dirty = false;
    }

    // Selecting something else asks first if there are unsaved changes
    function requestSelect(target) {
        if (target.kind === "theme" && !headerSelected && target.key === selectedKey) return;
        if (target.kind === "collection" && headerSelected && target.path === selectedCollection) return;
        if (dirty) {
            pending = target;
            discardDialog.open();
        } else {
            openTarget(target);
        }
    }

    function openTarget(target) {
        if (target.kind === "theme") load(target.key);
        else loadCollection(target.path);
    }

    function revert() {
        if (headerSelected) loadCollection(selectedCollection);
        else if (selectedKey) load(selectedKey);
    }

    function askDelete(key) {
        confirmKey = key;
        deleteDialog.open();
    }

    function askDuplicateCollection(path) {
        confirmCollection = path;
        var parent = Tree.parentOf(path), base = Tree.labelOf(path) + " " + i18nd("plasma_wallpaper_com.github.spider19996.substrate", "copy");
        var copy = parent ? parent + "/" + base : base, n = 2;
        while (ThemeStore.collections.indexOf(copy) >= 0) copy = (parent ? parent + "/" : "") + base + " " + n++;
        duplicateName.text = copy;
        duplicateCollectionDialog.open();
    }

    function askDeleteCollection(path) {
        confirmCollection = path;
        deleteCollectionDialog.open();
    }

    function askNewCollection() {
        newInside.checked = canCreateInside(selectedCollection);
        collectionDialog.open();
    }

    function canCreateInside(path) {
        return path !== "" && !ThemeStore.isBuiltinCollection(path);
    }

    // User themes are moved, built-in ones can only be copied. The look stays the same: what the new
    // collection hands down is not repeated, what differs from it becomes the theme's own.
    function moveTheme(key, collection) {
        var t = ThemeStore.theme(key);
        if (t.key === undefined || t.collection === collection) return;
        if (ThemeStore.isBuiltinCollection(collection)) {
            notice = i18nd("plasma_wallpaper_com.github.spider19996.substrate", "The built-in collection \"%1\" takes no new themes.", collection);
            return;
        }
        if (dirty && !headerSelected && key === selectedKey) {
            notice = i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Save or revert your changes before moving this theme.");
            return;
        }
        var name = uniqueName(collection, t.name);
        if (ThemeStore.saveTheme(collection, name, ThemeStore.rebase(t.config, collection), t.builtin ? "" : key)) {
            notice = t.builtin ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Built-in themes cannot be moved, a copy was created in \"%1\".", collection) : "";
            if (!headerSelected && key === selectedKey) load(collection + "/" + name);
        }
    }

    function setValue(key, value) {
        var d = clone(draftOwn);
        d[key] = value;
        draftOwn = d;
        dirty = true;
    }

    // Back to what is inherited
    function resetValue(key) {
        var d = clone(draftOwn);
        delete d[key];
        draftOwn = d;
        dirty = true;
    }

    function resetAll() {
        draftOwn = ({});
        dirty = true;
    }

    function setColor(index, color) {
        if (index < 0) {
            setValue("BG_COLOR", Params.fromColor(color));
        } else {
            var colors = clone(effective.COLORS);
            colors[index] = Params.fromColor(color);
            setValue("COLORS", colors);
        }
    }

    function uniqueName(collection, base) {
        var name = base, n = 2;
        while (ThemeStore.theme(collection + "/" + name).key !== undefined) name = base + " " + n++;
        return name;
    }

    // New themes cannot go into built-in collections, "own" takes them instead
    function writableCollection(path) {
        return path && !ThemeStore.isBuiltinCollection(path) ? path : "own";
    }

    // A new unsaved theme. config is a full look (or empty for a plain one that inherits everything).
    function startNew(config, baseName, targetCollection) {
        var collection = writableCollection(targetCollection || selectedCollection || draftCollection);
        selectedKey = "";
        headerSelected = false;
        selectedCollection = collection;
        draftCollection = collection;
        showCollection(collection);
        draftOwn = config ? ThemeStore.rebase(config, collection) : ({});
        draftName = uniqueName(collection, baseName);
        notice = "";
        dirty = true;
    }

    function save() {
        if (headerSelected) {
            if (ThemeStore.saveCollectionDefaults(selectedCollection, draftOwn)) dirty = false;
            return;
        }
        var oldKey = selectedIsUser ? selectedKey : "";
        if (ThemeStore.saveTheme(draftCollection.trim(), draftName.trim(), draftOwn, oldKey)) {
            selectedKey = targetKey;
            dirty = false;
        }
    }

    // Hiding built-in themes or deleting a collection can remove what is being edited
    Connections {
        target: ThemeStore
        function onThemesChanged() {
            var gone = headerSelected ? ThemeStore.collections.indexOf(win.selectedCollection) < 0
                                      : win.selectedKey !== "" && ThemeStore.theme(win.selectedKey).key === undefined;
            if (!gone) return;
            if (!win.dirty && ThemeStore.themes.length > 0) win.load(ThemeStore.themes[0].key);
            else { win.selectedKey = ""; win.headerSelected = false; }
        }
    }

    onVisibleChanged: {
        if (visible && !selectedKey && !headerSelected && ThemeStore.themes.length > 0) load(ThemeStore.themes[0].key);
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // ---- theme list -------------------------------------------------
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            Layout.fillHeight: true

            // Which collection the list below shows
            QQC2.ComboBox {
                id: viewBox
                Layout.fillWidth: true
                model: win.viewChoices
                textRole: "text"
                displayText: win.viewRoot ? win.viewRoot : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "All collections")
                currentIndex: {
                    for (var i = 0; i < win.viewChoices.length; i++)
                        if (win.viewChoices[i].path === win.viewRoot) return i;
                    return 0;
                }
                onActivated: function (index) { win.setViewRoot(win.viewChoices[index].path); }
                delegate: QQC2.ItemDelegate {
                    width: viewBox.width
                    text: modelData.text
                    leftPadding: Kirigami.Units.largeSpacing + modelData.depth * Kirigami.Units.gridUnit
                    highlighted: viewBox.highlightedIndex === index
                    font.bold: modelData.depth <= 1
                }
            }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    clip: true
                    model: win.rows
                    delegate: QQC2.ItemDelegate {
                        id: row
                        readonly property bool isHeader: modelData.type === "header"
                        width: ListView.view.width
                        readonly property string collectionName: isHeader ? modelData.name : modelData.collection
                        highlighted: isHeader ? (win.headerSelected && modelData.name === win.selectedCollection)
                                              : (modelData.key === win.selectedKey && !win.headerSelected)
                        leftPadding: Kirigami.Units.smallSpacing + modelData.depth * Kirigami.Units.gridUnit
                        onClicked: {
                            if (isHeader) win.requestSelect({ kind: "collection", path: modelData.name });
                            else win.requestSelect({ kind: "theme", key: modelData.key });
                        }
                        onDoubleClicked: if (isHeader) win.toggleCollection(modelData.name)

                        // Right click: actions for this entry, selected or not
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: {
                                contextMenu.row = modelData;
                                contextMenu.popup();
                            }
                        }

                        // Drag a theme onto a collection (or a theme in it) to move it there
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.MoveAction
                        Drag.proposedAction: Qt.MoveAction
                        Drag.mimeData: isHeader ? ({}) : ({ "application/x-substrate-theme": modelData.key })
                        DragHandler {
                            enabled: !row.isHeader
                            target: null
                            onActiveChanged: {
                                if (active) row.grabToImage(function (r) { row.Drag.imageSource = r.url; });
                                row.Drag.active = active;
                            }
                        }
                        DropArea {
                            id: dropArea
                            anchors.fill: parent
                            onEntered: function (drag) {
                                drag.accepted = !ThemeStore.isBuiltinCollection(row.collectionName)
                                                && drag.formats.indexOf("application/x-substrate-theme") >= 0;
                            }
                            onDropped: function (drop) {
                                win.moveTheme(drop.getDataAsString("application/x-substrate-theme"), row.collectionName);
                                drop.accept(Qt.MoveAction);
                            }
                        }
                        background: Rectangle {
                            color: dropArea.containsDrag ? Qt.alpha(Kirigami.Theme.highlightColor, 0.35)
                                 : row.highlighted ? Kirigami.Theme.highlightColor
                                 : row.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.15) : "transparent"
                        }
                        contentItem: RowLayout {
                            Kirigami.Icon {
                                visible: row.isHeader
                                source: win.collapsed[modelData.name] ? "arrow-right" : "arrow-down"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth

                                // A click on the arrow folds the collection
                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    onTapped: win.toggleCollection(modelData.name)
                                }
                            }
                            Rectangle {
                                visible: !row.isHeader
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                radius: 3
                                color: row.isHeader ? "transparent" : Params.toColor(modelData.config.BG_COLOR || [0, 0, 0])
                                border.color: Kirigami.Theme.disabledTextColor
                                Row {
                                    anchors.centerIn: parent
                                    Repeater {
                                        model: row.isHeader ? [] : (modelData.config.COLORS || []).slice(0, 3)
                                        Rectangle { width: 3; height: 8; color: Params.toColor(modelData) }
                                    }
                                }
                            }
                            QQC2.Label {
                                text: row.isHeader ? modelData.label : modelData.title
                                font.bold: row.isHeader
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            QQC2.Label {
                                text: row.isHeader ? modelData.count
                                    : modelData.builtin ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "built-in")
                                    : modelData.overridesBuiltin ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "modified") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "own")
                                font: Kirigami.Theme.smallFont
                                opacity: 0.6
                            }
                        }
                    }
                }
            }

            GridLayout {
                columns: 2
                Layout.fillWidth: true

                // Create
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "New theme")
                    icon.name: "list-add"
                    Layout.fillWidth: true
                    onClicked: win.startNew(null, i18nd("plasma_wallpaper_com.github.spider19996.substrate", "New theme"))
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "New collection…")
                    icon.name: "folder-new"
                    Layout.fillWidth: true
                    onClicked: win.askNewCollection()
                }
                // Duplicate and Delete act on what is selected: a collection header or a theme
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Duplicate")
                    icon.name: win.headerSelected ? "folder-copy" : "edit-copy"
                    Layout.fillWidth: true
                    enabled: win.headerSelected ? win.rows.some(function (r) {
                                 return r.type === "header" && r.name === win.selectedCollection && r.count > 0; })
                                                : win.selectedKey !== ""
                    onClicked: {
                        if (win.headerSelected) win.askDuplicateCollection(win.selectedCollection);
                        else win.startNew(win.selected.config, win.draftName + " " + i18nd("plasma_wallpaper_com.github.spider19996.substrate", "copy"), win.draftCollection);
                    }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: win.headerSelected ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Copy the whole collection") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Copy the selected theme")
                }
                QQC2.Button {
                    text: !win.headerSelected && win.selected.overridesBuiltin ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Reset") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete")
                    icon.name: win.headerSelected ? "folder-remove"
                             : win.selected.overridesBuiltin ? "edit-undo" : "edit-delete"
                    Layout.fillWidth: true
                    enabled: win.headerSelected ? ThemeStore.hasUserCollection(win.selectedCollection) : win.selectedIsUser
                    onClicked: {
                        if (win.headerSelected) win.askDeleteCollection(win.selectedCollection);
                        else win.askDelete(win.selectedKey);
                    }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: win.headerSelected ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete the collection with your own themes and subcollections in it")
                                     : win.selected.overridesBuiltin ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Use the built-in version of this theme again")
                                                                     : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete the selected theme")
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Assistant…")
                    icon.name: "tools-wizard"
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    onClicked: assistant.start(win.writableCollection(win.selectedCollection))
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Answer a few questions and let the rest be rolled")
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Open theme folder")
                    icon.name: "folder-open"
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    onClicked: ThemeStore.openFolder(win.selectedCollection)
                }
                QQC2.CheckBox {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Disable built-in themes")
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    checked: ThemeStore.hideBuiltin
                    onToggled: ThemeStore.hideBuiltin = checked
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ---- editor -----------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Information
                text: win.notice
                visible: text.length > 0
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                text: ThemeStore.lastError
                visible: text.length > 0
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 10
                color: "black"
                clip: true

                Substrate {
                    anchors.fill: parent
                    // Only built while the window is shown
                    running: win.visible
                    themes: [ { key: "preview", collection: "preview", config: win.effective } ]
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

            // Theme: its name. Collection: what its defaults are for.
            GridLayout {
                columns: 3
                Layout.fillWidth: true
                visible: !win.headerSelected

                QQC2.Label { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Name:") }
                QQC2.TextField {
                    Layout.fillWidth: true
                    text: win.draftName
                    onTextEdited: win.draftName = text
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Inherit everything")
                    icon.name: "edit-clear-all"
                    enabled: Object.keys(win.draftOwn).length > 0
                    onClicked: win.resetAll()
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Remove all own values, the theme then looks like its collection")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: win.headerSelected

                Kirigami.Heading {
                    level: 3
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Defaults of \"%1\"", win.selectedCollection)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Clear defaults")
                    icon.name: "edit-clear-all"
                    visible: win.collectionInfo.hasUserDefaults === true && !win.collectionIsSystem
                    onClicked: {
                        if (ThemeStore.deleteCollectionDefaults(win.selectedCollection)) win.loadCollection(win.selectedCollection);
                    }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: win.collectionInfo.hasBuiltinDefaults === true
                                       ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Use the built-in defaults of this collection again")
                                       : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Remove all defaults of this collection")
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: win.headerSelected
                text: win.collectionIsSystem
                      ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "The colors of this collection come from your Plasma color scheme and cannot be changed.")
                      : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "These values apply to every theme in this collection and its subcollections, unless a theme sets its own.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: !win.headerSelected && !win.storable && !(win.selectedIsSystem && win.targetKey === win.selectedKey)
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Built-in collections take no new themes. Use \"Duplicate\" to make an own copy of this theme.")
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: !win.headerSelected && win.selectedIsSystem && win.targetKey === win.selectedKey
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "These colors come from your Plasma color scheme and cannot be saved. Use \"Duplicate\" to make an editable copy with the current colors.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: !win.headerSelected && win.selected.builtin === true && !win.selectedIsSystem && win.targetKey === win.selectedKey
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Built-in themes are not changed. Saving stores your version in your own theme folder, which then replaces the built-in one.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: !win.headerSelected
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Values marked \"from …\" or \"default\" are inherited. Change one to give this theme its own value; the arrow takes it back.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            QQC2.TabBar {
                id: tabBar
                Layout.fillWidth: true
                Repeater {
                    model: Params.tabs()
                    QQC2.TabButton { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", modelData) }
                }
            }

            QQC2.ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: scroll.availableWidth

                    // ---- colors (their own tab)
                    ColumnLayout {
                        visible: tabBar.currentIndex === 0
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        RowLayout {
                            Layout.fillWidth: true

                            QQC2.Button {
                                onClicked: colorDialog.edit(-1)
                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Kirigami.Icon {
                                        source: "color-picker"
                                        implicitWidth: Kirigami.Units.iconSizes.small
                                        implicitHeight: implicitWidth
                                    }
                                    QQC2.Label { text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Background") }
                                    Rectangle {
                                        implicitWidth: Kirigami.Units.iconSizes.medium
                                        implicitHeight: Kirigami.Units.iconSizes.small
                                        radius: 3
                                        color: Params.toColor(win.effective.BG_COLOR)
                                        border.color: Kirigami.Theme.textColor
                                    }
                                }
                            }
                            QQC2.Label {
                                text: win.sourceText("BG_COLOR")
                                font: Kirigami.Theme.smallFont
                                opacity: win.isOwn("BG_COLOR") ? 1 : 0.6
                            }
                            QQC2.ToolButton {
                                icon.name: "edit-undo"
                                visible: win.isOwn("BG_COLOR")
                                onClicked: win.resetValue("BG_COLOR")
                                QQC2.ToolTip.text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Use the inherited value")
                                QQC2.ToolTip.visible: hovered
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: win.effective.COLORS
                                Rectangle {
                                    width: Kirigami.Units.gridUnit * 2
                                    height: width
                                    radius: 4
                                    color: Params.toColor(modelData)
                                    border.color: Kirigami.Theme.textColor

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: colorDialog.edit(index)
                                    }
                                    QQC2.ToolButton {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        width: parent.width / 2
                                        height: width
                                        padding: 0
                                        icon.name: "edit-delete-remove"
                                        visible: win.effective.COLORS.length > 1
                                        onClicked: {
                                            var colors = win.clone(win.effective.COLORS);
                                            colors.splice(index, 1);
                                            win.setValue("COLORS", colors);
                                        }
                                        QQC2.ToolTip.text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Remove color")
                                        QQC2.ToolTip.visible: hovered
                                    }
                                }
                            }

                            QQC2.Button {
                                icon.name: "list-add"
                                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Color")
                                onClicked: {
                                    var colors = win.clone(win.effective.COLORS);
                                    colors.push([255, 255, 255]);
                                    win.setValue("COLORS", colors);
                                    colorDialog.edit(colors.length - 1);
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            QQC2.Label {
                                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Line colors: %1", win.sourceText("COLORS"))
                                font: Kirigami.Theme.smallFont
                                opacity: win.isOwn("COLORS") ? 1 : 0.6
                            }
                            QQC2.ToolButton {
                                icon.name: "edit-undo"
                                visible: win.isOwn("COLORS")
                                onClicked: win.resetValue("COLORS")
                                QQC2.ToolTip.text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Use the inherited value")
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                    }

                    // ---- all other settings, one tab per group
                    Kirigami.FormLayout {
                        visible: tabBar.currentIndex > 0
                        Layout.fillWidth: true

                        Repeater {
                            model: tabBar.currentIndex > 0 ? Params.sections[tabBar.currentIndex - 1].params : []

                            RowLayout {
                                id: paramRow
                                readonly property var param: modelData
                                readonly property bool own: win.isOwn(param.key)
                                Kirigami.FormData.label: i18nd("plasma_wallpaper_com.github.spider19996.substrate", param.label) + ":"

                                Loader {
                                    id: editor
                                    sourceComponent: paramRow.param.type === "bool" ? boolEditor
                                                   : paramRow.param.type === "enum" ? enumEditor
                                                   : numberEditor

                                    Component {
                                        id: boolEditor
                                        QQC2.CheckBox {
                                            checked: win.effective[paramRow.param.key] === true
                                            onToggled: win.setValue(paramRow.param.key, checked)
                                        }
                                    }

                                    Component {
                                        id: enumEditor
                                        QQC2.ComboBox {
                                            model: paramRow.param.options.map(function (o) { return { value: o.value, text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", o.text) }; })
                                            textRole: "text"
                                            valueRole: "value"
                                            currentIndex: Math.max(0, indexOfValue(win.effective[paramRow.param.key]))
                                            onActivated: win.setValue(paramRow.param.key, currentValue)
                                        }
                                    }

                                    Component {
                                        id: numberEditor
                                        // SpinBox only knows integers, so real values are scaled
                                        QQC2.SpinBox {
                                            readonly property var param: paramRow.param
                                            readonly property real factor: param.type === "int" ? 1 : 1000
                                            readonly property int decimals: param.type === "int" ? 0
                                                                          : param.step < 0.1 ? 2 : param.step < 1 ? 1 : 0
                                            from: Math.round(param.min * factor)
                                            to: Math.round(param.max * factor)
                                            stepSize: Math.max(1, Math.round((param.step || 1) * factor))
                                            editable: true
                                            value: Math.round(Number(win.effective[param.key]) * factor)
                                            onValueModified: win.setValue(param.key, param.type === "int" ? value : value / factor)
                                            textFromValue: function (v, locale) { return Number(v / factor).toLocaleString(locale, "f", decimals); }
                                            valueFromText: function (text, locale) { return Math.round(Number.fromLocaleString(locale, text) * factor); }
                                        }
                                    }
                                }

                                QQC2.Label {
                                    text: win.sourceText(paramRow.param.key)
                                    font: Kirigami.Theme.smallFont
                                    opacity: paramRow.own ? 1 : 0.6
                                }

                                QQC2.ToolButton {
                                    icon.name: "edit-undo"
                                    visible: paramRow.own
                                    onClicked: win.resetValue(paramRow.param.key)
                                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Use the inherited value")
                                    QQC2.ToolTip.visible: hovered
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                QQC2.Label {
                    Layout.fillWidth: true
                    text: win.headerSelected ? ThemeStore.userDir + "/" + win.selectedCollection
                                             : (win.selected.path ? win.selected.path : "")
                    elide: Text.ElideMiddle
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Revert")
                    icon.name: "edit-undo"
                    enabled: win.dirty && (win.selectedKey !== "" || win.headerSelected)
                    onClicked: win.revert()
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Save")
                    icon.name: "document-save"
                    enabled: win.canSave
                    onClicked: win.save()
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Close")
                    icon.name: "window-close"
                    onClicked: win.close()
                }
            }
        }
    }

    // ---- dialogs ----------------------------------------------------------

    ThemeAssistant {
        id: assistant
        onCreated: function (firstKey) {
            win.notice = "";
            if (!win.dirty) win.load(firstKey);
        }
    }

    ColorDialog {
        id: colorDialog
        property int target: -1
        function edit(index) {
            target = index;
            selectedColor = Params.toColor(index < 0 ? win.effective.BG_COLOR : win.effective.COLORS[index]);
            open();
        }
        onAccepted: win.setColor(target, selectedColor)
    }

    QQC2.Dialog {
        id: deleteDialog
        readonly property var target: { ThemeStore.themes; return win.confirmKey ? ThemeStore.theme(win.confirmKey) : ({}); }
        readonly property bool isReset: target.overridesBuiltin === true
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: isReset ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Reset theme") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete theme")
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        QQC2.Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: deleteDialog.isReset
                  ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Remove your version of \"%1\" and use the built-in one again?", deleteDialog.target.name || "")
                  : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete the theme \"%1\"?", deleteDialog.target.name || "")
        }
        onAccepted: {
            var key = win.confirmKey;
            if (!ThemeStore.deleteTheme(key)) return;
            if (win.headerSelected || key !== win.selectedKey) return;
            if (ThemeStore.theme(key).key !== undefined) win.load(key);
            else if (ThemeStore.themes.length > 0) win.load(ThemeStore.themes[0].key);
        }
    }

    QQC2.Dialog {
        id: deleteCollectionDialog
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete collection")
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        QQC2.Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete your collection \"%1\" with its defaults, all its own themes and all its subcollections? Built-in themes of the same collection stay.", win.confirmCollection)
        }
        onAccepted: {
            var path = win.confirmCollection;
            var editedHere = Tree.within(win.selectedCollection, path);
            if (!ThemeStore.deleteCollection(path)) return;
            if (editedHere) {
                win.dirty = false;
                win.headerSelected = false;
                win.selectedKey = "";
                if (ThemeStore.themes.length > 0) win.load(ThemeStore.themes[0].key);
            }
        }
    }

    QQC2.Menu {
        id: contextMenu
        property var row: ({})
        readonly property bool isHeader: row.type === "header"
        readonly property string collection: isHeader ? row.name : (row.collection || "")
        readonly property var theme: isHeader ? ({}) : ThemeStore.theme(row.key || "")

        QQC2.MenuItem {
            visible: !contextMenu.isHeader
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Duplicate")
            icon.name: "edit-copy"
            onTriggered: win.startNew(contextMenu.theme.config, contextMenu.theme.name + " " + i18nd("plasma_wallpaper_com.github.spider19996.substrate", "copy"), contextMenu.theme.collection)
        }
        QQC2.MenuItem {
            visible: !contextMenu.isHeader && contextMenu.theme.builtin !== true
            height: visible ? implicitHeight : 0
            text: contextMenu.theme.overridesBuiltin ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Reset to built-in") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete")
            icon.name: contextMenu.theme.overridesBuiltin ? "edit-undo" : "edit-delete"
            onTriggered: win.askDelete(contextMenu.row.key)
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader && !ThemeStore.isBuiltinCollection(contextMenu.collection)
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "New theme here")
            icon.name: "list-add"
            onTriggered: win.startNew(null, i18nd("plasma_wallpaper_com.github.spider19996.substrate", "New theme"), contextMenu.collection)
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader && win.canCreateInside(contextMenu.collection)
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "New subcollection…")
            icon.name: "folder-new"
            onTriggered: { win.selectedCollection = contextMenu.collection; win.askNewCollection(); }
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader
            height: visible ? implicitHeight : 0
            text: win.collapsed[contextMenu.collection] ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Expand") : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Collapse")
            icon.name: win.collapsed[contextMenu.collection] ? "arrow-right" : "arrow-down"
            onTriggered: win.toggleCollection(contextMenu.collection)
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader && contextMenu.row.count > 0
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Duplicate collection…")
            icon.name: "folder-copy"
            onTriggered: win.askDuplicateCollection(contextMenu.collection)
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader && ThemeStore.hasUserCollection(contextMenu.collection)
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Delete collection")
            icon.name: "folder-remove"
            onTriggered: win.askDeleteCollection(contextMenu.collection)
        }
        QQC2.MenuItem {
            text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Open folder")
            icon.name: "folder-open"
            onTriggered: ThemeStore.openFolder(contextMenu.collection)
        }
    }

    QQC2.Dialog {
        id: duplicateCollectionDialog
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Duplicate collection")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onOpened: { duplicateName.forceActiveFocus(); duplicateName.selectAll(); }
        onAccepted: {
            var path = duplicateName.text.trim();
            if (ThemeStore.duplicateCollection(win.confirmCollection, path) > 0) {
                win.notice = "";
                win.requestSelect({ kind: "collection", path: path });
            }
        }
        ColumnLayout {
            width: parent.width
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Copy \"%1\" with its defaults, themes and subcollections to a new collection of your own. Use a path like \"parent/name\" to put it into another collection.", win.confirmCollection)
            }
            QQC2.TextField {
                id: duplicateName
                Layout.fillWidth: true
                onAccepted: duplicateCollectionDialog.accept()
            }
        }
    }

    QQC2.Dialog {
        id: collectionDialog
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "New collection")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onOpened: { collectionName.text = ""; collectionName.forceActiveFocus(); }
        onAccepted: {
            var name = collectionName.text.trim();
            var path = newInside.checked ? win.selectedCollection + "/" + name : name;
            if (ThemeStore.createCollection(path)) win.requestSelect({ kind: "collection", path: path });
        }
        ColumnLayout {
            width: parent.width
            QQC2.TextField {
                id: collectionName
                Layout.fillWidth: true
                placeholderText: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Name")
                onAccepted: collectionDialog.accept()
            }
            QQC2.CheckBox {
                id: newInside
                visible: win.canCreateInside(win.selectedCollection)
                text: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Inside \"%1\" (inherits its defaults)", win.selectedCollection)
            }
        }
    }

    QQC2.Dialog {
        id: discardDialog
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Unsaved changes")
        standardButtons: QQC2.Dialog.Discard | QQC2.Dialog.Cancel
        QQC2.Label {
            text: win.headerSelected ? i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Discard the changes to the defaults of \"%1\"?", win.selectedCollection)
                                     : i18nd("plasma_wallpaper_com.github.spider19996.substrate", "Discard the changes to \"%1\"?", win.draftName)
        }
        onDiscarded: {
            win.dirty = false;
            if (win.pending) win.openTarget(win.pending);
            win.pending = null;
            close();
        }
    }
}
