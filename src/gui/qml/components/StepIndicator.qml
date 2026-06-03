import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property int currentStep: 0
    spacing: 0

    readonly property var stepLabels: [
        qsTr("Nimi"),
        qsTr("Kieli"),
        qsTr("Salasana"),
        qsTr("Vahvistus")
    ]

    Repeater {
        model: root.stepLabels.length

        delegate: RowLayout {
            spacing: 0

            ColumnLayout {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                // Vaiheen pallo.
                Rectangle {
                    id: dot
                    width: 32; height: 32; radius: 16
                    Layout.alignment: Qt.AlignHCenter

                    readonly property bool done:   index < root.currentStep
                    readonly property bool active: index === root.currentStep

                    color: done ? "#44896a" : "transparent"
                    border.color: (done || active) ? "#44896a" : "#c8d0cd"
                    border.width: active ? 2 : done ? 0 : 1
                    scale: 1.0

                    Behavior on color        { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    // Pieni pomppu aktiiviselle vaiheelle.
                    onActiveChanged: {
                        if (active) dotPop.start()
                        else dot.scale = 1.0
                    }

                    SequentialAnimation {
                        id: dotPop
                        NumberAnimation {
                            target: dot; property: "scale"
                            to: 1.30; duration: 140; easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: dot; property: "scale"
                            to: 1.0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3.0
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dot.done ? "✓" : (index + 1).toString()
                        color: dot.done ? "white" : dot.active ? "#44896a" : "#a0adb0"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                // Vaiheen nimi.
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.stepLabels[index]
                    font.pixelSize: 11
                    color: (index <= root.currentStep) ? "#44896a" : "#a0adb0"
                    font.weight: index === root.currentStep ? Font.DemiBold : Font.Normal
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // Väliviiva vaiheiden väliin.
            Rectangle {
                visible: index < root.stepLabels.length - 1
                Layout.preferredWidth: 44
                Layout.preferredHeight: 2
                Layout.alignment: Qt.AlignVCenter
                Layout.bottomMargin: 20
                color: index < root.currentStep ? "#44896a" : "#d8dfe0"
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
