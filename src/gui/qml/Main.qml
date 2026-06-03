import QtQuick
import QtQuick.Controls
import OemSetup
import "pages"

ApplicationWindow {
    id: window
    width: 980
    height: 680
    minimumWidth: 740
    minimumHeight: 540
    visible: true
    title: qsTr("OEM Setup")
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    onVisibilityChanged: {
        if (visibility === Window.Minimized)
            showNormal()
    }

    // Ikkunaa voi raahata tyhjistä kohdista.
    Item {
        anchors.fill: parent
        z: -1
        DragHandler {
            onActiveChanged: if (active) window.startSystemMove()
        }
    }

    Connections {
        target: oemSetup
        function onApplySucceeded() {
            stack.replace(null, doneComp)
        }
        function onApplyRuntimeFailed() {
            stack.pop()
            stack.push(errorComp)
        }
    }

    StackView {
        id: stack
        anchors.fill: parent
        clip: true

        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "scale"
                    from: 0.95; to: 1.0
                    duration: 400; easing.type: Easing.OutQuart
                }
                NumberAnimation {
                    property: "opacity"
                    from: 0; to: 1
                    duration: 340; easing.type: Easing.OutCubic
                }
            }
        }
        pushExit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "scale"
                    from: 1.0; to: 1.04
                    duration: 300; easing.type: Easing.OutCubic
                }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 240 }
            }
        }
        popEnter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "scale"
                    from: 1.04; to: 1.0
                    duration: 400; easing.type: Easing.OutQuart
                }
                NumberAnimation {
                    property: "opacity"
                    from: 0; to: 1
                    duration: 340; easing.type: Easing.OutCubic
                }
            }
        }
        popExit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "scale"
                    from: 1.0; to: 0.95
                    duration: 300; easing.type: Easing.OutCubic
                }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 240 }
            }
        }
        replaceEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 420; easing.type: Easing.OutQuart }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }
            }
        }
        replaceExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 280 }
        }

        initialItem: welcomeComp
    }

    Component {
        id: welcomeComp
        WelcomePage {
            onNext: stack.push(nameComp)
        }
    }

    Component {
        id: nameComp
        NamePage {
            onBack: stack.pop()
            onNext: { if (oemSetup.validateNamePage()) stack.push(languageComp) }
        }
    }

    Component {
        id: languageComp
        LanguagePage {
            onBack: stack.pop()
            onNext: { if (oemSetup.validateLanguagePage()) stack.push(passwordComp) }
        }
    }

    Component {
        id: passwordComp
        PasswordPage {
            onBack: stack.pop()
            onNext: { if (oemSetup.validatePasswordPage()) stack.push(confirmComp) }
        }
    }

    Component {
        id: confirmComp
        ConfirmPage {
            onBack: {
                oemSetup.clearError()
                stack.pop()
            }
            onApply: {
                if (oemSetup.apply()) {
                    stack.push(progressComp)
                }
            }
        }
    }

    Component {
        id: progressComp
        ProgressPage {}
    }

    Component {
        id: doneComp
        DonePage {}
    }

    Component {
        id: errorComp
        ErrorPage {
            onBack: {
                oemSetup.clearError()
                stack.pop()
            }
        }
    }
}
