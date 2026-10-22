cmake_minimum_required(VERSION 3.20)
project(polkit_restart_regression LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Qml)
find_package(PkgConfig REQUIRED)
pkg_check_modules(POLKIT REQUIRED IMPORTED_TARGET polkit-agent-1)
if(NOT DEFINED QUICKSHELL_SOURCE)
  message(FATAL_ERROR "Set QUICKSHELL_SOURCE to the unpacked, patched Quickshell source")
endif()
set(POLKIT_SOURCE "${QUICKSHELL_SOURCE}/src/services/polkit")
add_executable(polkit-restart
  main.cpp
  "${POLKIT_SOURCE}/flow.cpp" "${POLKIT_SOURCE}/flow.hpp"
  "${POLKIT_SOURCE}/identity.cpp" "${POLKIT_SOURCE}/identity.hpp"
  "${POLKIT_SOURCE}/session.hpp"
  "${QUICKSHELL_SOURCE}/src/core/retainable.cpp"
  "${QUICKSHELL_SOURCE}/src/core/retainable.hpp")
target_include_directories(polkit-restart PRIVATE "${POLKIT_SOURCE}")
target_link_libraries(polkit-restart PRIVATE Qt6::Core Qt6::Qml PkgConfig::POLKIT)
