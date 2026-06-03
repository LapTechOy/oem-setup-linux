import QtQuick

// Käyttäjäkortti piirtyy sisään. Ei mitään kovin vakavaa.
Item {
    id: root

    readonly property real lineFullW:  44   // sopiva leveys ekalle riville
    readonly property real lineShortW: 28   // toinen rivi on lyhyempi

    // Kortti.
    Rectangle {
        id: card
        width: 112; height: 76
        anchors.centerIn: parent
        radius: 10
        color: "#1a2e2e"
        border.color: "#44896a"; border.width: 1.5
        opacity: 0

        // Avatar.
        Rectangle {
            id: avatar
            width: 32; height: 32; radius: 16
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            color: "#44896a"
            scale: 0

            // Pää.
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 4
                color: "#7ecba0"
            }
            // Hartiat.
            Rectangle {
                width: 20; height: 8; radius: 4
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                color: "#7ecba0"
            }
        }

        // Feikkitekstirivit.
        Column {
            anchors.left: avatar.right; anchors.leftMargin: 10
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle { id: line1; width: 0; height: 8; radius: 4; color: "#5aab86" }
            Rectangle { id: line2; width: 0; height: 6; radius: 3; color: "#3a5e4e" }
        }
    }

    SequentialAnimation {
        id: anim
        running: false
        NumberAnimation { target: card;   property: "opacity"; to: 1;              duration: 280; easing.type: Easing.OutCubic }
        PauseAnimation  { duration: 80 }
        NumberAnimation { target: avatar; property: "scale";   to: 1;              duration: 360; easing.type: Easing.OutBack }
        PauseAnimation  { duration: 80 }
        NumberAnimation { target: line1;  property: "width";   to: root.lineFullW;  duration: 280; easing.type: Easing.OutCubic }
        PauseAnimation  { duration: 90 }
        NumberAnimation { target: line2;  property: "width";   to: root.lineShortW; duration: 240; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: anim.start()
}
