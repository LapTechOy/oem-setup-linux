import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

WizardFrame {
    eyebrow: qsTr("Virhe")
    title: oemSetup.errorTitle.length > 0 ? oemSetup.errorTitle : qsTr("Käyttöönotto ei onnistunut")
    subtitle: qsTr("Mitään keskeneräistä käyttäjätiliä ei jätetä käyttöön.")
    illustration: "../assets/error.svg"

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        Label {
            Layout.fillWidth: true
            text: oemSetup.errorMessage.length > 0 ? oemSetup.errorMessage : qsTr("Kokeile uudelleen. Jos ongelma jatkuu, ota yhteyttä laitteen toimittajaan.")
            wrapMode: Text.WordWrap
            color: "#34403f"
            font.pixelSize: 18
            lineHeight: 1.18
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PrimaryButton { text: qsTr("Takaisin"); onClicked: back() }
        }
    }
}
