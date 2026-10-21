import QtQuick
import qs.Commons as Commons
import Quickshell.Io

FocusScope {
    id: root
    property alias text: input.text
    property bool busy: false
    property bool errorState: false
    property bool responseVisible: false
    property bool revealed: false
    property bool capsOn: false
    function applyKeyboardState(raw) {
        var data;
        try {
            data = JSON.parse(raw);
        } catch (error) {
            return;
        }
        if (!data || !Array.isArray(data.keyboards))
            return;
        // Any real keyboard with Caps Lock set merits a warning; synthetic main
        // keyboards may not reflect the physical Surface keyboard's lock LEDs.
        capsOn = data.keyboards.some(function (k) {
            return k.capsLock === true;
        });
    }
    Process {
        id: capsProbe
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.applyKeyboardState(text)
        }
    }
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!capsProbe.running)
            capsProbe.running = true
    }
    property string prompt: ""
    signal submitted(string password)
    signal editing
    implicitHeight: capsOn ? 88 : 62
    implicitWidth: 360
    function focusInput() {
        input.forceActiveFocus();
    }
    function clear() {
        input.text = "";
        revealed = false;
    }
    AuthStrings {
        id: strings
    }
    Rectangle {
        width: parent.width
        height: 54
        radius: 10
        color: Qt.alpha(Commons.Color.foreground, 0.05)
        border.width: input.activeFocus ? 2 : 1
        border.color: root.errorState ? Commons.Color.urgent : (input.activeFocus ? Commons.Color.accent : Qt.alpha(Commons.Color.foreground, 0.3))
        TextInput {
            id: input
            objectName: "passwordInput"
            anchors {
                left: parent.left
                right: eye.left
                verticalCenter: parent.verticalCenter
                leftMargin: 16
                rightMargin: 10
            }
            color: Commons.Color.foreground
            font.family: Commons.Style.font.family
            font.pixelSize: 20
            echoMode: root.responseVisible || root.revealed ? TextInput.Normal : TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            clip: true
            readOnly: root.busy
            activeFocusOnPress: true
            selectByMouse: true
            onTextEdited: root.editing()
            onAccepted: if (text.length > 0 && !root.busy)
                root.submitted(text)
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_CapsLock)
                    root.capsOn = !root.capsOn;
                if (event.key === Qt.Key_Escape)
                    root.clear();
            }
        }
        Label {
            anchors.fill: input
            text: root.busy ? strings.t("password.checking") : (root.prompt || strings.t("password.placeholder"))
            visible: input.text.length === 0
            opacity: 0.65
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 17
        }
        Item {
            id: eye
            anchors.right: parent.right
            width: 50
            height: parent.height
            activeFocusOnTab: visible
            visible: !root.responseVisible
            Accessible.role: Accessible.Button
            Accessible.name: root.revealed ? strings.t("action.hidePassword") : strings.t("action.showPassword")
            Accessible.onPressAction: root.revealed = !root.revealed
            Icon {
                anchors.centerIn: parent
                name: root.revealed ? "eyeOff" : "eye"
                ink: Commons.Color.foreground
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: parent.activeFocus ? 2 : 0
                border.color: Commons.Color.accent
                radius: 8
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.revealed = !root.revealed;
                    input.forceActiveFocus();
                }
            }
            Keys.onSpacePressed: root.revealed = !root.revealed
            Keys.onReturnPressed: root.revealed = !root.revealed
        }
    }
    Label {
        anchors.top: parent.top
        anchors.topMargin: 64
        visible: root.capsOn
        text: strings.t("password.caps")
        color: Commons.Color.urgent
        font.pixelSize: 14
    }
    onVisibleChanged: if (!visible)
        clear()
}
