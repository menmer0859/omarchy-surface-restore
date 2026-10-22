import QtQuick
import qs.Commons as Commons

Item {
    id: root
    property bool scanning: false
    property bool externalDisplay: false
    property bool reducedMotion: Commons.Style.reduceMotion
    implicitHeight: 88
    implicitWidth: 360
    AuthStrings {
        id: strings
    }
    Rectangle {
        id: laptop
        width: 68
        height: 43
        anchors.horizontalCenter: parent.horizontalCenter
        color: "transparent"
        border.color: Qt.alpha(Commons.Color.foreground, 0.45)
        border.width: 1
        radius: 4
        Rectangle {
            id: cameraDot
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: 5
            height: 5
            radius: 3
            color: root.scanning ? Commons.Color.accent : Commons.Color.muted
            SequentialAnimation on opacity {
                running: root.scanning && root.visible && !root.reducedMotion
                loops: 3
                NumberAnimation {
                    to: 0.3
                    duration: 420
                }
                NumberAnimation {
                    to: 1
                    duration: 420
                }
                onStopped: cameraDot.opacity = 1
            }
        }
        Rectangle {
            height: 2
            width: 78
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            color: Qt.alpha(Commons.Color.foreground, 0.45)
        }
    }
    Label {
        width: parent.width
        anchors.top: laptop.bottom
        anchors.topMargin: 13
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 13
        opacity: 0.75
        text: root.externalDisplay ? strings.t("face.externalHint") : strings.t("camera.label")
    }
}
