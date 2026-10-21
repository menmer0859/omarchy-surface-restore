import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons

ColumnLayout {
    id: root
    property bool administrative: false
    property string userName: ""
    property string displayName: ""
    property string avatarPath: ""
    property string phase: "locked_idle"
    property bool passwordMode: false
    property bool passwordBusy: false
    property bool passwordError: false
    property bool responseVisible: false
    property string responsePrompt: ""
    property string message: ""
    property bool faceAvailable: true
    property bool canChangeIdentity: false
    property bool externalDisplay: false
    property bool reducedMotion: Commons.Style.reduceMotion
    property bool fingerprintMode: false
    property alias passwordText: password.text
    readonly property alias identityLabel: identity.label
    readonly property alias identityVertical: identity.vertical
    readonly property string faceLabel: strings.t("action.face")
    readonly property bool scanning: phase === "scanning"
    readonly property bool timedOut: phase === "timed_out"
    readonly property color stateColor: passwordError ? Commons.Color.urgent : (timedOut || phase === "failed" ? "#c49043" : Commons.Color.accent)
    readonly property string stateTitle: strings.t(passwordError ? "password.failed" : passwordBusy ? "password.checking" : fingerprintMode ? "admin.fingerprint" : passwordMode ? "password.title" : scanning ? "face.scanning" : phase === "wake_delay" ? "lock.settling" : timedOut ? "face.timeout" : phase === "failed" ? "face.failed" : !faceAvailable ? "face.unavailable" : administrative ? "admin.title" : "lock.ready")
    readonly property string stateHint: strings.t(passwordError ? "password.failedHint" : administrative && phase === "failed" ? "face.failedHint" : passwordMode ? "password.hint" : scanning || phase === "wake_delay" ? (externalDisplay ? "face.externalHint" : "face.hint") : timedOut ? "face.timeoutHint" : phase === "failed" ? "face.failedHint" : !faceAvailable ? "face.unavailableHint" : administrative ? "admin.hint" : "lock.readyHint")
    signal faceRequested
    signal passwordRequested
    signal submitted(string password)
    signal editing
    signal cancelled
    signal changeIdentity
    spacing: 16
    LayoutMirroring.enabled: Commons.I18n.rightToLeft
    LayoutMirroring.childrenInherit: true
    function focusPassword() {
        password.focusInput();
    }
    function clearPassword() {
        password.clear();
    }
    AuthStrings {
        id: strings
    }
    Identity {
        id: identity
        userName: root.userName
        displayName: root.displayName
        avatarPath: root.avatarPath
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: root.width
        Layout.preferredWidth: Math.min(implicitWidth, root.width)
    }
    Label {
        visible: root.administrative && root.message !== ""
        text: root.message
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 14
        maximumLineCount: 4
        elide: Text.ElideRight
    }
    Icon {
        name: root.passwordMode ? "password" : root.timedOut ? "clock" : "face"
        ink: root.stateColor
        Layout.preferredWidth: 44
        Layout.preferredHeight: 44
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 10
    }
    Label {
        text: root.stateTitle
        color: root.stateColor
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 27
        font.weight: Font.DemiBold
        Accessible.role: Accessible.AlertMessage
    }
    Label {
        text: root.stateHint
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.8
        font.pixelSize: 15
    }
    PasswordField {
        id: password
        visible: root.passwordMode
        Layout.fillWidth: true
        Layout.topMargin: 8
        busy: root.passwordBusy
        errorState: root.passwordError
        responseVisible: root.responseVisible
        prompt: root.responsePrompt
        onSubmitted: function (value) {
            root.submitted(value);
        }
        onEditing: root.editing()
    }
    Action {
        visible: root.passwordMode
        Layout.fillWidth: true
        label: strings.t(root.administrative ? "action.authorize" : "action.unlock")
        iconName: "arrow"
        primary: true
        enabled: root.enabled && !root.passwordBusy && password.text.length > 0
        onClicked: root.submitted(password.text)
    }
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        spacing: 12
        Action {
            objectName: "faceAction"
            visible: root.faceAvailable && !root.scanning && !root.fingerprintMode
            label: strings.t(root.phase === "failed" || root.timedOut ? "action.retry" : "action.face")
            iconName: "face"
            enabled: !root.passwordBusy
            primary: !root.passwordMode
            onClicked: root.faceRequested()
        }
        Action {
            objectName: "passwordAction"
            visible: !root.passwordMode
            label: strings.t("action.password")
            iconName: "password"
            onClicked: root.passwordRequested()
        }
    }
    Action {
        visible: root.canChangeIdentity
        label: strings.t("action.changeIdentity")
        Layout.alignment: Qt.AlignHCenter
        enabled: !root.scanning && !root.passwordBusy
        onClicked: root.changeIdentity()
    }
    CameraHint {
        visible: !root.passwordMode && (root.scanning || root.phase === "wake_delay")
        Layout.fillWidth: true
        Layout.topMargin: 12
        scanning: root.scanning
        externalDisplay: root.externalDisplay
        reducedMotion: root.reducedMotion
    }
    Action {
        visible: root.administrative
        label: strings.t("action.cancel")
        iconName: "cancel"
        Layout.alignment: Qt.AlignHCenter
        onClicked: root.cancelled()
    }
}
