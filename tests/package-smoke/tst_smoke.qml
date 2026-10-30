import QtQuick
import QtTest
import "lib"

// Runs inside the unpacked wallpaper package (contents/ui), so "lib" is the plugin that ships with it
TestCase {
    name: "package"

    function test_plugin_loads() {
        verify(ThemeStore.version.length > 0)
        verify(PowerMonitor.onBattery === true || PowerMonitor.onBattery === false)
    }

    function test_themes_are_found() {
        ThemeStore.builtinDir = Qt.resolvedUrl("../themes")
        verify(ThemeStore.themes.length > 0)
        verify(ThemeStore.collections.indexOf("oled/sparks") >= 0)
    }
}
