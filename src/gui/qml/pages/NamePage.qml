import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../animations"

WizardFrame {
    eyebrow: qsTr("Käyttäjätiedot")
    title: qsTr("Kuka käyttää tätä tietokonetta?")
    subtitle: qsTr("Nimi näkyy kirjautumisruudussa ja käyttäjäasetuksissa.")
    illustrationComponent: Component { NameAnimation {} }
    step: 0

    property bool syncingUsername: false

    StackView.onStatusChanged: {
        if (StackView.status === StackView.Activating) {
            filterHint.opacity = 0
            hintTimer.stop()
        }
    }

    // Kun controller johtaa tunnuksen nimestä, pidetään kenttä mukana.
    Connections {
        target: oemSetup
        function onUsernameChanged() {
            if (!syncingUsername && usernameCard.text !== oemSetup.username) {
                syncingUsername = true
                usernameCard.text = oemSetup.username
                syncingUsername = false
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        TextFieldCard {
            Layout.fillWidth: true
            label: qsTr("Nimi")
            placeholderText: qsTr("Esimerkiksi Matti Meikäläinen")
            supportingText: qsTr("Voit kirjoittaa koko nimen tai pelkän etunimen.")
            text: oemSetup.displayName
            onTextChanged: oemSetup.displayName = text
            onAccepted: next()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: qsTr("Käyttäjätunnus")
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: "#4a5568"
                }

                Rectangle {
                    visible: !oemSetup.usernameManuallyEdited
                    width: autoBadge.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: "#dff0e8"

                    Label {
                        id: autoBadge
                        anchors.centerIn: parent
                        text: qsTr("auto")
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                        color: "#44896a"
                    }
                }
            }

            TextFieldCard {
                id: usernameCard
                Layout.fillWidth: true
                placeholderText: qsTr("muodostetaan nimestä")
                text: oemSetup.username
                onTextChanged: {
                    if (syncingUsername) return
                    // Suodatetaan tässä, niin käyttäjä näkee heti mitä poistui.
                    const raw = text
                    const filtered = raw.toLowerCase().replace(/[^a-z0-9_-]/g, "").substring(0, 32)
                    if (filtered !== raw) {
                        syncingUsername = true
                        usernameCard.text = filtered  // vahti estää onTextChanged-kierteen
                        syncingUsername = false
                        usernameCard.flash()
                        filterHint.show()
                    }
                    oemSetup.username = filtered
                }
                onAccepted: next()
            }

            // Pikku huomautus jos merkkejä suodatettiin pois.
            Label {
                id: filterHint
                Layout.fillWidth: true
                text: qsTr("Vain merkit a-z, 0-9, _ ja - sallittu")
                font.pixelSize: 12
                color: "#b45309"
                opacity: 0
                wrapMode: Text.WordWrap

                Behavior on opacity { NumberAnimation { duration: 180 } }

                function show() { opacity = 1; hintTimer.restart() }

                Timer {
                    id: hintTimer
                    interval: 2400
                    onTriggered: filterHint.opacity = 0
                }
            }

            Text {
                visible: oemSetup.usernameManuallyEdited
                text: "↺ " + qsTr("Palauta automaattinen")
                font.pixelSize: 12
                color: "#44896a"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: oemSetup.resetUsernameToAutomatic()
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
            PrimaryButton { text: qsTr("Jatka"); onClicked: next() }
        }
    }
}
