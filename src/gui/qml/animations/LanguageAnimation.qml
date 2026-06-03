import QtQuick

// Puhekuplat liukuvat sisään pienellä viiveellä.
Item {
    id: root

    // Ylempi kupla.
    Rectangle {
        id: bubble1
        width: 90; height: 46; radius: 14
        anchors.left: parent.left; anchors.leftMargin: 4
        anchors.top: parent.top; anchors.topMargin: 18
        color: "#2c5040"
        border.color: "#5aab86"; border.width: 1.5
        opacity: 0
        transform: Translate { id: b1slide; x: -20 }

        Column {
            anchors.centerIn: parent
            spacing: 7
            Rectangle { width: 56; height: 7; radius: 3.5; color: "#7ecba0" }
            Rectangle { width: 38; height: 7; radius: 3.5; color: "#5aab86" }
        }
    }

    // Alempi kupla.
    Rectangle {
        id: bubble2
        width: 80; height: 40; radius: 12
        anchors.right: parent.right; anchors.rightMargin: 4
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        color: "#44896a"
        opacity: 0
        transform: Translate { id: b2slide; x: 20 }

        Column {
            anchors.centerIn: parent
            spacing: 6
            Rectangle { width: 46; height: 6; radius: 3; color: "#9ecbb8" }
            Rectangle { width: 30; height: 6; radius: 3; color: "#7ecba0" }
        }
    }

    SequentialAnimation {
        id: anim
        running: false
        ParallelAnimation {
            NumberAnimation { target: bubble1; property: "opacity"; to: 1; duration: 360; easing.type: Easing.OutCubic }
            NumberAnimation { target: b1slide; property: "x";       to: 0; duration: 360; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 160 }
        ParallelAnimation {
            NumberAnimation { target: bubble2; property: "opacity"; to: 1; duration: 360; easing.type: Easing.OutCubic }
            NumberAnimation { target: b2slide; property: "x";       to: 0; duration: 360; easing.type: Easing.OutCubic }
        }
    }

    Component.onCompleted: anim.start()
}
