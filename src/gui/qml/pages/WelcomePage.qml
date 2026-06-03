import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../animations"

WizardFrame {
    eyebrow: qsTr("Ensikäyttöönotto")
    title: qsTr("Tervetuloa")
    subtitle: qsTr("Otetaan tietokone käyttöösi muutamassa vaiheessa.")
    illustrationComponent: Component { WelcomeAnimation {} }

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        // Kielivalinta yläkulmassa.
        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            Row {
                spacing: 0

                Repeater {
                    model: [
                        { code: "fi", label: "FI" },
                        { code: "en", label: "EN" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: 38; height: 26
                        // Kaksiosainen pilleri, reunat pyöreiksi käsin.
                        radius: 6
                        Rectangle {
                            visible: index === 0
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.radius
                            color: parent.color
                        }
                        Rectangle {
                            visible: index === 1
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.radius
                            color: parent.color
                        }

                        readonly property bool active: oemSetup.uiLanguage === modelData.code
                        color: active ? "#44896a" : "#e8ede9"
                        border.color: active ? "#44896a" : "#c8d0cd"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: parent.active ? "#ffffff" : "#4a5568"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: oemSetup.uiLanguage = modelData.code
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("Valitse nimi, kieli ja salasana. Sen jälkeen tietokone viimeistelee asetukset ja käynnistyy uudelleen.")
            wrapMode: Text.WordWrap
            color: "#34403f"
            font.pixelSize: 19
            lineHeight: 1.18
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PrimaryButton {
                text: qsTr("Aloitetaan")
                onClicked: next()
            }
        }
    }
}
