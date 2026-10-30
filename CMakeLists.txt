cmake_minimum_required(VERSION 3.21)
project(substrate-wallpaper VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick DBus)
qt_standard_project_setup(REQUIRES 6.5)

# Shown on the settings page
set(SUBSTRATE_VERSION "${PROJECT_VERSION}" CACHE STRING "Version of Substrate")

add_subdirectory(src)

# Headless benchmark: cmake -DSUBSTRATE_BUILD_BENCH=ON
option(SUBSTRATE_BUILD_BENCH "Build the engine benchmark" OFF)
if(SUBSTRATE_BUILD_BENCH)
    add_executable(substrate-bench tests/bench.cpp src/substrateengine.cpp)
    target_link_libraries(substrate-bench PRIVATE Qt6::Gui)
endif()
