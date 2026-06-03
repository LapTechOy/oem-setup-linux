import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""
    property url illustration
    property Component illustrationComponent: null
    property int step: -1
    default property alias content: body.data
    signal back()
    signal next()

    // Kortin ulompi varjo.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 6
        width: card.width + 4
        height: card.height + 4
        radius: card.radius + 2
        color: "#18000000"
        z: card.z - 1
    }
    // Pehmeämpi varjo.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 14
        width: card.width - 20
        height: card.height
        radius: card.radius
        color: "#0c000000"
        z: card.z - 2
    }

    Rectangle {
        id: card
        width: Math.min(parent.width - 64, 920)
        height: Math.min(parent.height - 64, 580)
        anchors.centerIn: parent
        radius: 12
        color: "#fbfaf7"
        border.color: "#e0dbd2"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Vasen tumma laita.
            Rectangle {
                id: sidebar
                Layout.fillHeight: true
                Layout.preferredWidth: Math.max(252, card.width * 0.36)
                radius: 12
                color: "#1e2c32"
                clip: true

                // Maskataan oikea reuna, pyöristys jää vain vasemmalle.
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.radius
                    color: parent.color
                }

                // Kevyt ylävalo.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height * 0.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#22384060" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Alareunan hehku.
                Rectangle {
                    id: glowBlob
                    width: 220; height: 220; radius: 110
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -70
                    color: "#44896a"
                    opacity: 0.11
                }

                // Pieni taustapiste.
                Rectangle {
                    id: accentDot
                    width: 88; height: 88; radius: 44
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 30
                    anchors.rightMargin: 8
                    color: "#7ecba0"
                    opacity: 0.07

                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.14; duration: 3400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.05; duration: 3400; easing.type: Easing.InOutSine }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 36
                    spacing: 0

                    Label {
                        id: eyebrowLabel
                        Layout.fillWidth: true
                        Layout.bottomMargin: 14
                        text: root.eyebrow
                        color: "#7ecba0"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                        opacity: 0
                        transform: Translate { id: eyebrowT; y: 10 }
                    }

                    Label {
                        id: titleLabel
                        Layout.fillWidth: true
                        Layout.bottomMargin: 16
                        text: root.title
                        color: "#f0f4f2"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                        opacity: 0
                        transform: Translate { id: titleT; y: 12 }
                    }

                    Label {
                        id: subtitleLabel
                        Layout.fillWidth: true
                        text: root.subtitle
                        color: "#9ab8b0"
                        font.pixelSize: 14
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                        opacity: 0
                        transform: Translate { id: subtitleT; y: 14 }
                    }

                    Item { Layout.fillHeight: true }

                    // Kuvan paikka pysyy samana vaikka animaatio vähän kelluu.
                    // illustrationComponent on animaatiolle, illustration staattiselle SVG:lle.
                    Item {
                        Layout.preferredHeight: 148
                        Layout.fillWidth: true

                        Item {
                            anchors.centerIn: parent
                            width: 142; height: 142
                            opacity: 0.88
                            transform: Translate { id: floatT }

                            Image {
                                anchors.fill: parent
                                source: root.illustration
                                fillMode: Image.PreserveAspectFit
                                visible: root.illustrationComponent === null
                            }

                            Loader {
                                anchors.fill: parent
                                sourceComponent: root.illustrationComponent
                            }
                        }
                    }
                }
            }

            // Oikean puolen sisältö.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 44
                Layout.rightMargin: 44
                Layout.topMargin: 32
                Layout.bottomMargin: 36
                spacing: 0

                StepIndicator {
                    visible: root.step >= 0
                    currentStep: root.step
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 28
                }

                Item {
                    id: body
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    // Kielenvaihdossa ajetaan tekstit sisään uudestaan.
    Connections {
        target: oemSetup
        function onUiLanguageChanged() {
            if (eyebrowLabel.opacity < 0.5) return  // alkuanimaatio vielä kesken
            eyebrowLabel.opacity  = 0; eyebrowT.y  = 10
            titleLabel.opacity    = 0; titleT.y    = 12
            subtitleLabel.opacity = 0; subtitleT.y = 14
            eyebrowAppear.restart()
            titleAppear.restart()
            subtitleAppear.restart()
        }
    }

    // Sivupalkin tekstit sisään pienellä porrastuksella.
    Component.onCompleted: {
        eyebrowAppear.start()
        titleAppear.start()
        subtitleAppear.start()
    }

    SequentialAnimation {
        id: eyebrowAppear
        ParallelAnimation {
            NumberAnimation { target: eyebrowLabel; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: eyebrowT;     property: "y";       to: 0; duration: 280; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: titleAppear
        PauseAnimation { duration: 65 }
        ParallelAnimation {
            NumberAnimation { target: titleLabel; property: "opacity"; to: 1; duration: 340; easing.type: Easing.OutCubic }
            NumberAnimation { target: titleT;     property: "y";       to: 0; duration: 300; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: subtitleAppear
        PauseAnimation { duration: 135 }
        ParallelAnimation {
            NumberAnimation { target: subtitleLabel; property: "opacity"; to: 1; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: subtitleT;     property: "y";       to: 0; duration: 340; easing.type: Easing.OutCubic }
        }
    }

    // Kuva kelluu vähän, ettei ruutu tunnu ihan jäykältä.
    SequentialAnimation {
        running: true
        loops: Animation.Infinite
        NumberAnimation { target: floatT; property: "y"; to: -10; duration: 2700; easing.type: Easing.InOutSine }
        NumberAnimation { target: floatT; property: "y"; to: 0;   duration: 2700; easing.type: Easing.InOutSine }
    }
}
