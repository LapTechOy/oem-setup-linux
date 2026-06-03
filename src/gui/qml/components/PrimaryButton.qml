import QtQuick
import QtQuick.Controls

Button {
    id: button
    implicitHeight: 44
    padding: 20
    font.pixelSize: 15
    font.weight: Font.DemiBold

    background: Rectangle {
        radius: 6
        color: button.pressed ? "#2d5e48"
             : button.hovered ? "#3d7a5f"
             :                  "#44896a"
        Behavior on color { ColorAnimation { duration: 80 } }
    }

    contentItem: Text {
        text: button.text
        font: button.font
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
