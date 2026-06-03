cmake_minimum_required(VERSION 3.27)

project(oem-setup-linux
    VERSION 1.0.0
    DESCRIPTION "First-boot OEM setup wizard for Linux"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(GNUInstallDirs)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Svg)

qt_standard_project_setup(REQUIRES 6.4)

enable_testing()

add_subdirectory(src/common)
add_subdirectory(src/gui)
add_subdirectory(tests)

install(FILES data/desktop/oem-setup.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

install(FILES src/gui/qml/assets/welcome.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
    RENAME oem-setup.svg
)

install(FILES data/polkit/fi.local.oem-setup.policy
    DESTINATION ${CMAKE_INSTALL_DATADIR}/polkit-1/actions
)

install(FILES data/systemd/oem-cleanup.service
    DESTINATION lib/systemd/system
)

install(PROGRAMS
    data/scripts/oem-apply.sh
    data/scripts/oem-cleanup.sh
    DESTINATION ${CMAKE_INSTALL_LIBEXECDIR}/oem-setup
)
