cmake_minimum_required(VERSION 3.14)
project(BettboxInstallerLauncher LANGUAGES CXX)

if(NOT DEFINED BETTBOX_LAUNCHER_OUTPUT_DIR)
  message(FATAL_ERROR "BETTBOX_LAUNCHER_OUTPUT_DIR is required")
endif()

if(NOT DEFINED BETTBOX_LAUNCHER_VERSION)
  set(BETTBOX_LAUNCHER_VERSION "1.0.0")
endif()

string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)"
  BETTBOX_LAUNCHER_NUMERIC_VERSION "${BETTBOX_LAUNCHER_VERSION}")
if(NOT BETTBOX_LAUNCHER_NUMERIC_VERSION)
  message(FATAL_ERROR "BETTBOX_LAUNCHER_VERSION must start with three numbers")
endif()
set(BETTBOX_VERSION_MAJOR "${CMAKE_MATCH_1}")
set(BETTBOX_VERSION_MINOR "${CMAKE_MATCH_2}")
set(BETTBOX_VERSION_PATCH "${CMAKE_MATCH_3}")

add_executable(BettboxInstallerLauncher WIN32
  installer_launcher.cpp
  installer_launcher.rc
)

target_compile_features(BettboxInstallerLauncher PRIVATE cxx_std_17)
target_compile_options(BettboxInstallerLauncher PRIVATE
  "$<$<COMPILE_LANGUAGE:CXX>:/W4;/WX;/EHsc;/utf-8>"
)
target_compile_definitions(BettboxInstallerLauncher PRIVATE
  UNICODE
  _UNICODE
  NOMINMAX
  "BETTBOX_VERSION_MAJOR=${BETTBOX_VERSION_MAJOR}"
  "BETTBOX_VERSION_MINOR=${BETTBOX_VERSION_MINOR}"
  "BETTBOX_VERSION_PATCH=${BETTBOX_VERSION_PATCH}"
  "BETTBOX_VERSION_STRING=\"${BETTBOX_LAUNCHER_VERSION}\""
)
if(MSVC)
  target_compile_options(BettboxInstallerLauncher PRIVATE
    "$<$<CONFIG:Release>:/MT>"
  )
endif()
target_link_libraries(BettboxInstallerLauncher PRIVATE shell32.lib)

set_target_properties(BettboxInstallerLauncher PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${BETTBOX_LAUNCHER_OUTPUT_DIR}"
  RUNTIME_OUTPUT_DIRECTORY_RELEASE "${BETTBOX_LAUNCHER_OUTPUT_DIR}"
)
