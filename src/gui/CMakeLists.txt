qt_add_executable(oem-setup-gui
    main.cpp
    Installer.cpp
    Installer.h
    OemSetupController.cpp
    OemSetupController.h
)

if(COMMAND qt_policy)
    qt_policy(SET QTP0004 NEW)
endif()

qt_add_qml_module(oem-setup-gui
    URI OemSetup
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/animations/WelcomeAnimation.qml
        qml/animations/NameAnimation.qml
        qml/animations/LanguageAnimation.qml
        qml/animations/PasswordAnimation.qml
        qml/components/WizardFrame.qml
        qml/components/PrimaryButton.qml
        qml/components/SecondaryButton.qml
        qml/components/StepIndicator.qml
        qml/components/TextFieldCard.qml
        qml/pages/WelcomePage.qml
        qml/pages/NamePage.qml
        qml/pages/LanguagePage.qml
        qml/pages/PasswordPage.qml
        qml/pages/ConfirmPage.qml
        qml/pages/ProgressPage.qml
        qml/pages/DonePage.qml
        qml/pages/ErrorPage.qml
    RESOURCES
        qml/animations/qmldir
        qml/components/qmldir
        qml/pages/qmldir
        qml/assets/welcome.svg
        qml/assets/done.svg
        qml/assets/error.svg
)

find_package(Qt6 REQUIRED COMPONENTS LinguistTools)

qt_add_translations(oem-setup-gui
    TS_FILES "${CMAKE_SOURCE_DIR}/translations/oem-setup_en.ts"
    RESOURCE_PREFIX "/i18n"
)

target_link_libraries(oem-setup-gui
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Svg
        oem_setup_common
)

install(TARGETS oem-setup-gui
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
