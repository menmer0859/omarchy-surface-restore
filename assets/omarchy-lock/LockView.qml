import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons as Commons
import "FaceUi" as FaceUi

Item {
    id: root
    property string backgroundPath: ""
    property int backgroundVersion: 0
    property bool fingerprintConfigured: false
    property bool faceConfigured: false
    property bool faceAuthenticating: false
    property string facePhase: "inactive"
    property string unlockMode: "password"
    property bool authenticatingPassword: false
    property string failureMessage: ""
    property int failedAttempts: 0
    property bool inputEnabled: true
    property bool loadBackground: true
    property string passwordText: ""
    property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME")
    property string avatarPath: Quickshell.env("HOME") + "/.face"
    property bool externalDisplay: false
    property bool reducedMotion: Commons.Style.reduceMotion
    readonly property bool passwordMode: !faceConfigured || facePhase === "password" || unlockMode === "password"
    readonly property string stateTitle: auth.stateTitle
    readonly property string identityLabel: auth.identityLabel
    readonly property bool identityVertical: auth.identityVertical
    signal submitPassword(string password)
    signal passwordTextEdited(string password)
    signal clearFailureRequested
    signal wakeRequested
    signal faceIntentRequested
    signal faceRetryRequested
    signal unlockModeRequested(string mode)
    signal blankRequested
    FaceUi.AuthStrings {
        id: strings
    }
    function forcePasswordFocus() {
        if (inputEnabled && passwordMode)
            auth.focusPassword();
        else
            root.forceActiveFocus();
    }
    function requestFaceIntent() {
        if (inputEnabled) {
            wakeRequested();
            faceIntentRequested();
        }
    }
    function fileUrl(path) {
        return path ? "file://" + String(path).split("/").map(encodeURIComponent).join("/") + "?v=" + backgroundVersion : "";
    }
    function syncPasswordText() {
        if (auth.passwordText !== passwordText)
            auth.passwordText = passwordText;
    }
    onPasswordTextChanged: syncPasswordText()
    onPasswordModeChanged: Qt.callLater(forcePasswordFocus)
    onInputEnabledChanged: if (inputEnabled)
        Qt.callLater(forcePasswordFocus)
    Component.onCompleted: {
        syncPasswordText();
        Qt.callLater(forcePasswordFocus);
    }
    focus: inputEnabled && !passwordMode
    LayoutMirroring.enabled: Commons.I18n.rightToLeft
    LayoutMirroring.childrenInherit: true
    Keys.onPressed: function (event) {
        if (!inputEnabled || event.isAutoRepeat || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            return;
        if (!passwordMode)
            root.requestFaceIntent();
        else
            root.wakeRequested();
        event.accepted = true;
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Column {
        id: clockGroup
        visible: root.height >= 650
        anchors.top: parent.top
        anchors.topMargin: 55
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 3
        FaceUi.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.date.toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale), "HH:mm")
            font.pixelSize: 62
            font.weight: Font.Light
        }
        FaceUi.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.date.toLocaleDateString(Qt.locale(Commons.I18n.formatLocale), Locale.LongFormat)
            font.pixelSize: 15
            opacity: 0.75
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Commons.Color.background
        z: -3
    }
    Image {
        id: wallpaper
        z: -2
        anchors.fill: parent
        source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        cache: false
        sourceSize.width: width
        sourceSize.height: height
    }
    MultiEffect {
        z: -2
        anchors.fill: parent
        source: wallpaper
        blurEnabled: wallpaper.status === Image.Ready
        blur: 1
        blurMax: 48
        autoPaddingEnabled: false
    }
    Rectangle {
        z: -1
        anchors.fill: parent
        color: Qt.alpha(Commons.Color.background, 0.72)
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPressed: root.requestFaceIntent()
        onPositionChanged: root.wakeRequested()
    }
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 28
        spacing: 10
        FaceUi.Icon {
            name: "lock"
            ink: Commons.Color.foreground
            width: 16
            height: 16
        }
        FaceUi.Label {
            text: strings.t("status.locked")
            font.pixelSize: 12
            opacity: 0.7
        }
        FaceUi.Label {
            text: strings.t(root.faceAuthenticating ? "status.scanning" : "status.noScan")
            font.pixelSize: 12
            opacity: 0.7
        }
    }
    Flickable {
        anchors {
            fill: parent
            topMargin: clockGroup.visible ? 180 : 74
            bottomMargin: 86
        }
        contentWidth: width
        contentHeight: Math.max(height, auth.implicitHeight + 40)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        FaceUi.AuthCard {
            id: auth
            transform: Translate {
                x: root.shake
            }
            objectName: "authenticationCard"
            width: Math.min(410, parent.width - 48)
            x: (parent.width - width) / 2
            y: Math.max(20, (parent.height - implicitHeight) / 2)
            height: implicitHeight
            enabled: root.inputEnabled
            userName: root.userName
            avatarPath: root.avatarPath
            phase: root.facePhase
            faceAvailable: root.faceConfigured
            passwordMode: root.passwordMode
            passwordBusy: root.authenticatingPassword
            passwordError: root.failureMessage !== ""
            externalDisplay: root.externalDisplay
            reducedMotion: root.reducedMotion
            onFaceRequested: root.unlockModeRequested("face")
            onPasswordRequested: root.unlockModeRequested("password")
            onSubmitted: function (value) {
                root.submitPassword(value);
                root.passwordTextEdited("");
            }
            onPasswordTextChanged: if (passwordText !== root.passwordText)
                root.passwordTextEdited(passwordText)
            onEditing: {
                root.wakeRequested();
                root.clearFailureRequested();
            }
        }
    }
    FaceUi.Action {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        label: strings.t("action.screenOff")
        iconName: "screen"
        enabled: root.inputEnabled
        onClicked: root.blankRequested()
    }
    property real shake: 0
    Connections {
        target: root
        function onFailedAttemptsChanged() {
            if (root.failedAttempts > 0 && !root.reducedMotion)
                shakeAnimation.restart();
        }
    }
    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation {
            target: root
            property: "shake"
            to: -7
            duration: 50
        }
        NumberAnimation {
            target: root
            property: "shake"
            to: 6
            duration: 70
        }
        NumberAnimation {
            target: root
            property: "shake"
            to: -3
            duration: 80
        }
        NumberAnimation {
            target: root
            property: "shake"
            to: 0
            duration: 140
        }
        // Translate only the card; the secure session surface never moves.
    }
}
