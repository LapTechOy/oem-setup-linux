import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

WizardFrame {
    eyebrow: qsTr("Viimeistellään")
    title: qsTr("Hetki vielä")
    subtitle: qsTr("Luodaan käyttäjätiliä ja valmistellaan seuraavaa käynnistystä.")
    illustration: "../assets/welcome.svg"

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        Item { Layout.fillHeight: true }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Tämä kestää yleensä alle minuutin.")
            color: "#34403f"
            font.pixelSize: 17
        }

        // Progressipalkki.
        Item {
            id: bar
            Layout.fillWidth: true
            Layout.topMargin: 6
            height: 6
            property real fillProgress: 0

            // Feikkiprogressi: nopea alku, sitten odotellaan oikeaa valmistumista.
            SequentialAnimation on fillProgress {
                running: true
                NumberAnimation { to: 0.42; duration: 1100; easing.type: Easing.OutCubic }
                NumberAnimation { to: 0.70; duration: 2600; easing.type: Easing.OutCubic }
                NumberAnimation { to: 0.88; duration: 4500; easing.type: Easing.OutCubic }
            }

            // Tausta.
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "#dce8e2"
            }

            // Täyttö.
            Rectangle {
                id: fill
                height: parent.height
                width: parent.width * bar.fillProgress
                radius: 3
                color: "#44896a"
                clip: true

                // Pieni kiilto.
                Rectangle {
                    id: shimmer
                    width: 72; height: parent.height; radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: "#30ffffff" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: bar.fillProgress > 0.02
                        NumberAnimation { from: -72; to: fill.width; duration: 1300; easing.type: Easing.InOutSine }
                        PauseAnimation  { duration: 500 }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
