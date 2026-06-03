import QtQuick
import QtQuick.Controls

Button {
    id: button
    implicitHeight: 44
    padding: 20
    font.pixelSize: 15

    background: Rectangle {
        radius: 6
        color: button.pressed ? "#dde4e1"
             : button.hovered ? "#edf2f0"
             :                  "transparent"
        border.color: "#c8d0cd"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }
    }

    contentItem: Text {
        text: button.text
        font: button.font
        color: "#4a5568"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
