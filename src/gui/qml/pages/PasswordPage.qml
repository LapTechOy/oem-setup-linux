import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../animations"

WizardFrame {
    eyebrow: qsTr("Suojaus")
    title: qsTr("Luo salasana")
    subtitle: qsTr("Valitse salasana, jolla kirjaudut sisään.")
    illustrationComponent: Component { PasswordAnimation {} }
    step: 2

    ColumnLayout {
        anchors.fill: parent
        spacing: 18

        TextFieldCard {
            Layout.fillWidth: true
            label: qsTr("Salasana")
            placeholderText: qsTr("Kirjoita salasana")
            showToggle: true
            text: oemSetup.password
            onTextChanged: oemSetup.password = text
            onAccepted: next()
        }

        TextFieldCard {
            Layout.fillWidth: true
            label: qsTr("Salasana uudelleen")
            placeholderText: qsTr("Kirjoita sama salasana")
            supportingText: qsTr("Valitse salasana, jonka muistat helposti.")
            showToggle: true
            text: oemSetup.passwordConfirmation
            onTextChanged: oemSetup.passwordConfirmation = text
            onAccepted: next()
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
            PrimaryButton { text: qsTr("Jatka"); onClicked: next() }
        }
    }
}
