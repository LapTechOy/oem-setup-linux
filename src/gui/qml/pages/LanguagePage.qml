import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../animations"

WizardFrame {
    eyebrow: qsTr("Kieliasetukset")
    title: qsTr("Valitse kieli")
    subtitle: qsTr("Kieli asetetaan järjestelmän oletukseksi.")
    illustrationComponent: Component { LanguageAnimation {} }
    step: 1

    ListModel {
        id: languages
        ListElement { code: "fi_FI.UTF-8"; label: "Suomi";        detail: "Suomi" }
        ListElement { code: "sv_SE.UTF-8"; label: "Svenska";      detail: "Sverige" }
        ListElement { code: "en_GB.UTF-8"; label: "English (UK)"; detail: "United Kingdom" }
        ListElement { code: "en_US.UTF-8"; label: "English (US)"; detail: "United States" }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: languages
            delegate: RadioDelegate {
                id: delegate
                Layout.fillWidth: true
                implicitHeight: 62
                checked: oemSetup.locale === code
                onClicked: oemSetup.locale = code

                background: Rectangle {
                    radius: 8
                    color: delegate.pressed ? "#d8e8e0"
                         : delegate.checked ? "#eaf4ef"
                         : delegate.hovered ? "#edf2f0"
                         :                    "#f1f4f2"
                    border.color: delegate.checked ? "#44896a" : "#dce3df"
                    border.width: delegate.checked ? 2 : 1
                    Behavior on color       { ColorAnimation { duration: 80 } }
                    Behavior on border.color { ColorAnimation { duration: 80 } }
                }

                indicator: Rectangle {
                    x: delegate.width - width - 16
                    y: (delegate.height - height) / 2
                    width: 20
                    height: 20
                    radius: 10
                    color: "transparent"
                    border.color: delegate.checked ? "#44896a" : "#b0bcb8"
                    border.width: 2
                    Behavior on border.color { ColorAnimation { duration: 80 } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        color: "#44896a"
                        visible: delegate.checked
                    }
                }

                contentItem: Column {
                    leftPadding: 16
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        text: label
                        font.pixelSize: 17
                        font.weight: Font.Medium
                        color: "#263238"
                    }
                    Label {
                        text: detail
                        font.pixelSize: 12
                        color: "#63706f"
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            SecondaryButton { text: qsTr("Takaisin"); onClicked: back() }
            Item { Layout.fillWidth: true }
            PrimaryButton { text: qsTr("Jatka"); onClicked: next() }
        }
    }
}
