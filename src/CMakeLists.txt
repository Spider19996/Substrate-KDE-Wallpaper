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

target_compile_definitions(substrate PRIVATE SUBSTRATE_VERSION="${SUBSTRATE_VERSION}")
target_link_libraries(substrate PRIVATE Qt6::Quick Qt6::Gui Qt6::Qml Qt6::DBus)
