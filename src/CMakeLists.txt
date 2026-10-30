qt_add_qml_module(substrate
    URI com.github.spider19996.substrate
    VERSION 1.0
    PLUGIN_TARGET substrate
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/com/github/spider19996/substrate
    SOURCES
        substrateengine.cpp
        substrateengine.h
        substrateitem.cpp
        substrateitem.h
        powermonitor.cpp
        powermonitor.h
        themestore.cpp
        themestore.h
)

# The QML files import the module from contents/ui/lib (import "lib"), so the wallpaper package carries its own
# plugin and needs no system-wide installation. The build puts it there; the folder is not part of the sources.
set(SUBSTRATE_LIB_DIR ${PROJECT_SOURCE_DIR}/contents/ui/lib)
file(MAKE_DIRECTORY ${SUBSTRATE_LIB_DIR})
file(WRITE ${SUBSTRATE_LIB_DIR}/qmldir "module com.github.spider19996.substrate\nplugin substrate\n")
add_custom_command(TARGET substrate POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:substrate> ${SUBSTRATE_LIB_DIR}/
    COMMENT "Copying the plugin to contents/ui/lib")

target_compile_definitions(substrate PRIVATE SUBSTRATE_VERSION="${SUBSTRATE_VERSION}")
target_link_libraries(substrate PRIVATE Qt6::Quick Qt6::Gui Qt6::Qml Qt6::DBus)
