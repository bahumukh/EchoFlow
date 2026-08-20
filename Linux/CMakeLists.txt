cmake_minimum_required(VERSION 3.10)
project(EchoflowLinux)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find GTK3
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK3 REQUIRED gtk+-3.0)

# Find ALSA
find_package(ALSA REQUIRED)

# Find X11 and XTest
find_package(X11 REQUIRED)

include_directories(
    ${GTK3_INCLUDE_DIRS}
    ${ALSA_INCLUDE_DIRS}
    ${X11_INCLUDE_DIR}
    include
)

link_directories(
    ${GTK3_LIBRARY_DIRS}
)

add_executable(echoflow
    src/main.cpp
    src/GlobalHotkeyService.cpp
    src/AudioRecorderService.cpp
    src/WhisperService.cpp
    src/TextInserterService.cpp
    src/HUDWindow.cpp
)

target_link_libraries(echoflow
    ${GTK3_LIBRARIES}
    ${ALSA_LIBRARIES}
    ${X11_LIBRARIES}
    Xtst
    pthread
)
