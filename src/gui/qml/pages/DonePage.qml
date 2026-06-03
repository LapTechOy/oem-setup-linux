import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

WizardFrame {
    id: root
    eyebrow: qsTr("Valmis")
    title: qsTr("Tietokone on valmis")
    subtitle: qsTr("Seuraavaksi tietokone käynnistyy uudelleen.")
    illustration: "../assets/done.svg"

    property int secondsLeft: 15

    onSecondsLeftChanged: arc.requestPaint()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.secondsLeft--
            if (root.secondsLeft <= 0) {
                stop()
                oemSetup.reboot()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        Label {
            Layout.fillWidth: true
            text: qsTr("Kun kone käynnistyy uudelleen, kirjaudu sisään juuri luomallasi käyttäjällä.")
            wrapMode: Text.WordWrap
            color: "#34403f"
            font.pixelSize: 19
            lineHeight: 1.18
        }

        Item { Layout.fillHeight: true }

        // Lähtölaskennan rengas.
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 80; height: 80

                Canvas {
                    id: arc
                    anchors.fill: parent

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width / 2, cy = height / 2, r = 32

                        // Taustarengas.
                        ctx.strokeStyle = "#dce8e2"
                        ctx.lineWidth = 5
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, Math.PI * 2)
                        ctx.stroke()

                        // Jäljellä oleva aika.
                        var progress = root.secondsLeft / 15.0
                        ctx.strokeStyle = "#44896a"
                        ctx.lineWidth = 5
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2,
                                -Math.PI / 2 + Math.PI * 2 * progress, false)
                        ctx.stroke()
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: root.secondsLeft
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    color: "#44896a"
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Käynnistyy automaattisesti")
                font.pixelSize: 13
                color: "#63706f"
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PrimaryButton {
                text: qsTr("Käynnistä nyt")
                onClicked: oemSetup.reboot()
            }
        }
    }
}
