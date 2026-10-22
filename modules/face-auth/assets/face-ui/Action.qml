import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons

Rectangle {
    id: root
    property string label: ""
    property string iconName: ""
    property bool primary: false
    property color ink: Commons.Color.foreground
    property color accent: Commons.Color.accent
    signal clicked
    implicitWidth: Math.max(124, content.implicitWidth + 32)
    implicitHeight: 48
    radius: 10
    color: primary ? Qt.alpha(accent, 0.18) : (pointer.containsMouse ? Qt.alpha(ink, 0.12) : Qt.alpha(ink, 0.05))
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus || primary ? accent : Qt.alpha(ink, 0.3)
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: visible && enabled
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if (enabled)
        root.clicked()
    Keys.onReturnPressed: if (enabled)
        root.clicked()
    Keys.onEnterPressed: if (enabled)
        root.clicked()
    Keys.onSpacePressed: if (enabled)
        root.clicked()
    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 9
        Icon {
            visible: root.iconName !== ""
            name: root.iconName
            ink: root.ink
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
        }
        Label {
            text: root.label
            color: root.ink
            font.pixelSize: 15
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
