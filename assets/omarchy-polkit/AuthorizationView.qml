import QtQuick
import qs.Commons as Commons
import "FaceUi" as FaceUi

FocusScope {
    id: root
    property string userName: ""
    property string displayName: ""
    property string avatarPath: ""
    property string message: ""
    property bool consentMode: false
    property bool scanning: false
    property bool fingerprintMode: false
    property bool passwordMode: false
    property bool busy: false
    property bool passwordError: false
    property bool faceFailed: false
    property bool canChangeIdentity: false
    property bool responseVisible: false
    property string responsePrompt: ""
    property bool externalDisplay: false
    property bool reducedMotion: Commons.Style.reduceMotion
    property alias passwordText: card.passwordText
    readonly property string faceLabel: card.faceLabel
    signal faceConsent(bool useFace)
    signal submitted
    signal cancelled
    signal changeIdentity
    signal editing
    implicitWidth: 480
    implicitHeight: card.implicitHeight + 64
    function focusInput() {
        if (passwordMode)
            card.focusPassword();
        else
            root.forceActiveFocus();
    }
    function clearPassword() {
        card.clearPassword();
    }
    Keys.onEscapePressed: root.cancelled()
    // Enter in the method picker always chooses password, never implicit face consent.
    Keys.onReturnPressed: if (consentMode && !scanning)
        root.faceConsent(false)
    Keys.onEnterPressed: if (consentMode && !scanning)
        root.faceConsent(false)
    Rectangle {
        anchors.fill: parent
        color: Commons.Color.polkit.background
        radius: 18
        border.width: 1
        border.color: Qt.alpha(Commons.Color.foreground, 0.25)
    }
    FaceUi.AuthCard {
        id: card
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 32
        }
        administrative: true
        passwordSwitchAvailable: root.consentMode && !root.scanning && !root.fingerprintMode
        userName: root.userName
        displayName: root.displayName
        avatarPath: root.avatarPath
        message: root.message
        phase: root.scanning ? "scanning" : root.faceFailed ? "failed" : "locked_idle"
        faceAvailable: root.consentMode && !root.scanning
        passwordMode: root.passwordMode
        passwordBusy: root.busy
        passwordError: root.passwordError
        fingerprintMode: root.fingerprintMode
        responseVisible: root.responseVisible
        responsePrompt: root.responsePrompt
        canChangeIdentity: root.canChangeIdentity
        externalDisplay: root.externalDisplay
        reducedMotion: root.reducedMotion
        onFaceRequested: root.faceConsent(true)
        onPasswordRequested: root.faceConsent(false)
        onSubmitted: function (value) {
            root.submitted();
        }
        onCancelled: root.cancelled()
        onChangeIdentity: root.changeIdentity()
        onEditing: root.editing()
    }
}
