import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

WizardFrame {
    eyebrow: qsTr("Yhteenveto")
    title: qsTr("Tarkista asetukset")
    subtitle: qsTr("Kun jatkat, käyttäjä luodaan ja väliaikainen setup-tila poistetaan.")
    illustration: "../assets/done.svg"
    step: 3
    signal apply()

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Repeater {
            model: [
                { key: qsTr("Nimi"), value: oemSetup.displayName },
                { key: qsTr("Käyttäjätunnus"), value: oemSetup.username },
                { key: qsTr("Kotikansio"), value: "/home/" + oemSetup.username },
                { key: qsTr("Kieli"), value: oemSetup.localeLabel }
            ]
            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 58
                color: "#f1f4f2"
                radius: 8
                border.color: "#dce3df"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    Label { text: modelData.key; color: "#63706f"; font.pixelSize: 14 }
                    Item { Layout.fillWidth: true }
                    Label { text: modelData.value; color: "#263238"; font.pixelSize: 16; font.weight: Font.DemiBold }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: oemSetup.errorMessage.length > 0
            text: oemSetup.errorMessage
            color: "#9b2c2c"
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            SecondaryButton { text: qsTr("Takaisin"); onClicked: back() }
            Item { Layout.fillWidth: true }
            PrimaryButton { text: qsTr("Luo käyttäjä"); enabled: !oemSetup.busy; onClicked: apply() }
        }
    }
}
