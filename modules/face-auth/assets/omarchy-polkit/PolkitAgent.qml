import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit as Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "PolkitModel.js" as PolkitModel
import "FaceUi" as FaceUi

Item {
  id: root

  property bool reducedMotion: Style.reduceMotion
  FaceUi.AuthStrings { id: strings }

  property string fontFamily: Style.font.menuFamily
  // Bound to the central [polkit] section in shell.toml via Color.qml.
  property color accent: Color.polkit.accent
  property color background: Color.polkit.background
  property color foreground: Color.polkit.text
  property color border: Color.polkit.border
  property color borderError: Color.polkit.borderError
  property var borderSpec: Border.surfaceSpec("polkit", errorFlash ? "border-error" : "border", errorFlash ? borderError : border, Math.max(1, Style.space(2)), "border-alpha")
  property color scrim: Color.polkit.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int fieldHeight: Math.max(Style.space(42), Style.spacing.controlHeight)

  property bool closing: false
  property bool submitted: false
  property string currentMessage: ""
  property string currentPrompt: ""
  property string currentSupplementary: ""
  property bool responseRequired: false
  property bool responseVisible: false
  property bool failed: false
  // Set only after the user explicitly chooses face authentication.
  property bool faceCheckPending: false
  property bool faceFallbackActive: false
  property var faceConsentFlow: null
  property var faceConsentIdentity: null
  property bool errorFlash: false
  // pam_fprintd appears in the polkit PAM stack (a sensor is enrolled).
  property bool fingerprintConfigured: false
  // Lid shut right now — the reader is physically unreachable, so we fall back
  // to the password even when a sensor is enrolled. Refreshed per request.
  property bool laptopClosed: false
  property int shakeOffset: 0

  readonly property bool dialogVisible: polkitAgent.isActive || closing
  readonly property bool faceConsentMode: dialogVisible && responseRequired && PolkitModel.isFaceConsentPrompt(currentPrompt)
  readonly property bool canReturnToFace: dialogVisible && !closing && PolkitModel.canReturnToFace(polkitAgent.flow, faceConsentFlow, faceConsentIdentity, submitted, faceCheckPending)
  readonly property var activeIdentity: polkitAgent.flow ? polkitAgent.flow.selectedIdentity : null
  readonly property var allowedIdentities: polkitAgent.flow ? polkitAgent.flow.identities : []
  // We show one method at a time. Fingerprint owns the dialog while PAM is
  // waiting on the reader (lid open, sensor enrolled); the moment PAM asks for
  // a password — including immediately when the lid is shut and the clamshell
  // gate skips pam_fprintd — we switch to the password field instead.
  readonly property bool fingerprintMode: fingerprintConfigured && !laptopClosed && dialogVisible && !responseRequired && !submitted && !errorFlash
  readonly property int cardHeight: panel.height > 0 ? Math.min(fieldHeight + contentMargin * 2, panel.height - Style.gapsOut * 2) : fieldHeight + contentMargin * 2
  // Password mode is a wide field; fingerprint mode collapses to a square that
  // just frames the centered sensor icon.
  readonly property int cardWidth: fingerprintMode ? cardHeight : Math.min(Style.space(312), Math.max(Style.space(260), panel.width - Style.gapsOut * 2))

  function authorizationLabel(message) {
    return PolkitModel.authorizationLabel(message)
  }

  function selectedIdentityLabel() {
    if (!activeIdentity) return strings.t("admin.unknown")
    if (activeIdentity.isGroup) return strings.t("admin.group").arg(activeIdentity.displayName || activeIdentity.name)
    return PolkitModel.identityLabel(activeIdentity)
  }

  function cycleIdentity() {
    var flow = polkitAgent.flow
    if (!flow || submitted || faceCheckPending) return
    var index = PolkitModel.nextIdentityIndex(flow.identities, flow.selectedIdentity)
    if (index < 0) return
    authView.passwordText = ""
    faceFallbackActive = false
    faceCheckPending = false
    faceConsentFlow = null
    faceConsentIdentity = null
    flow.selectedIdentity = flow.identities[index]
    Qt.callLater(syncFromFlow)
    Qt.callLater(refocus)
  }

  function loadPamConfig(raw) {
    fingerprintConfigured = PolkitModel.fingerprintConfiguredFromPamConfig(raw)
  }

  function refreshLidState() {
    if (!laptopClosedProc.running) laptopClosedProc.running = true
  }

  function resetSnapshot() {
    currentMessage = ""
    currentPrompt = ""
    currentSupplementary = ""
    responseRequired = false
    responseVisible = false
    failed = false
    errorFlash = false
    submitted = false
    faceCheckPending = false
    faceFallbackActive = false
    faceConsentFlow = null
    faceConsentIdentity = null
    authView.passwordText = ""
  }

  function syncFromFlow() {
    var flow = polkitAgent.flow
    if (!flow) return

    currentMessage = String(flow.message || "")
    currentPrompt = String(flow.inputPrompt || "")
    currentSupplementary = String(flow.supplementaryMessage || "")
    responseRequired = !!flow.isResponseRequired
    responseVisible = !!flow.responseVisible
    failed = !!flow.failed

    if (responseRequired && PolkitModel.isFaceConsentPrompt(currentPrompt)) {
      faceConsentFlow = flow
      faceConsentIdentity = flow.selectedIdentity
      faceFallbackActive = false
    }
    if (responseRequired && !PolkitModel.isFaceConsentPrompt(currentPrompt)) {
      if (faceCheckPending) faceFallbackActive = true
      faceCheckPending = false
      // Keep failure state for non-English PAM prompts as well.
    }
    if (responseRequired) submitted = false
  }

  function beginFlow() {
    closeTimer.stop()
    closing = false
    submitted = false
    faceFallbackActive = false
    faceCheckPending = false
    faceConsentFlow = null
    faceConsentIdentity = null
    authView.passwordText = ""
    refreshLidState()
    syncFromFlow()
    Qt.callLater(refocus)
  }

  function refocus() {
    if (!dialogVisible) return
    // In fingerprint mode there is no field to type into — park focus on the
    // key catcher so Escape still cancels; otherwise focus the password field.
    if (fingerprintMode || faceConsentMode || faceCheckPending) authView.forceActiveFocus()
    else authView.focusInput()
  }

  function submitFaceConsent(useFace) {
    var flow = polkitAgent.flow
    if (!flow || flow.isCompleted || flow.isCancelled || !flow.isResponseRequired || !PolkitModel.isFaceConsentPrompt(currentPrompt) || !PolkitModel.isFaceConsentPrompt(flow.inputPrompt)) return
    faceFallbackActive = false
    faceCheckPending = useFace
    submitted = true
    authView.passwordText = ""
    flow.submit(useFace ? "y" : "n")
    authView.forceActiveFocus()
  }

  function returnToFace() {
    var flow = polkitAgent.flow
    if (!canReturnToFace || !PolkitModel.canReturnToFace(flow, faceConsentFlow, faceConsentIdentity, submitted, faceCheckPending)) return
    authView.passwordText = ""
    faceFallbackActive = false
    faceCheckPending = false
    errorFlash = false
    submitted = true
    // Restart only the input-waiting conversation. The native method retains
    // the original protected request and identity and sends no PAM response.
    // A new consent prompt still requires a separate explicit face choice.
    if (!flow.restartAuthentication()) submitted = false
    syncFromFlow()
    Qt.callLater(refocus)
  }

  function submitResponse() {
    var flow = polkitAgent.flow
    if (!flow || !flow.isResponseRequired) return
    if (PolkitModel.isFaceConsentPrompt(currentPrompt)) {
      submitFaceConsent(false)
      return
    }
    submitted = true
    errorFlash = false
    faceFallbackActive = false
    flow.submit(authView.passwordText)
    authView.passwordText = ""
    authView.forceActiveFocus()
  }

  function cancelRequest() {
    var flow = polkitAgent.flow
    authView.passwordText = ""
    submitted = false
    closing = true
    closeTimer.restart()
    if (flow) flow.cancelAuthenticationRequest()
  }

  function triggerFailureFeedback() {
    submitted = false
    faceFallbackActive = faceFallbackActive || faceCheckPending
    faceCheckPending = false
    errorFlash = true
    authView.passwordText = ""
    errorTimer.restart()
    if (!reducedMotion && !faceFallbackActive) shakeAnimation.restart()
    Qt.callLater(refocus)
  }

  Timer {
    id: closeTimer
    interval: 300
    repeat: false
    onTriggered: {
      closing = false
      resetSnapshot()
    }
  }

  Timer {
    id: errorTimer
    interval: 1200
    repeat: false
    onTriggered: root.errorFlash = false
  }

  SequentialAnimation {
    id: shakeAnimation
    NumberAnimation { target: root; property: "shakeOffset"; to: -7; duration: 50 }
    NumberAnimation { target: root; property: "shakeOffset"; to: 6; duration: 70 }
    NumberAnimation { target: root; property: "shakeOffset"; to: -3; duration: 80 }
    NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 140 }
  }
  FileView {
    path: "/etc/pam.d/polkit-1"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadPamConfig(text())
    onLoadFailed: root.fingerprintConfigured = false
    onFileChanged: reload()
  }

  Process {
    id: laptopClosedProc
    command: ["bash", "-c", "omarchy-hw-laptop-closed && echo closed || echo open"]
    stdout: StdioCollector { id: laptopClosedOut; waitForEnd: true }
    onExited: root.laptopClosed = String(laptopClosedOut.text || "").trim() === "closed"
  }

  Polkit.PolkitAgent {
    id: polkitAgent
    path: "/org/omarchy/PolkitAgent"

    onAuthenticationRequestStarted: root.beginFlow()
    onIsActiveChanged: {
      if (isActive) root.syncFromFlow()
      else if (!root.closing) root.resetSnapshot()
    }
    onIsRegisteredChanged: {
      if (isRegistered) console.log("omarchy polkit agent registered")
      else console.warn("omarchy polkit agent is not registered; another agent may be running")
    }
  }

  Connections {
    target: polkitAgent.flow

    function onIsResponseRequiredChanged() {
      root.syncFromFlow()
      if (!polkitAgent.flow || !polkitAgent.flow.isResponseRequired) authView.passwordText = ""
      Qt.callLater(root.refocus)
    }

    function onSelectedIdentityChanged() {
      root.faceConsentFlow = null
      root.faceConsentIdentity = null
      root.faceFallbackActive = false
      root.faceCheckPending = false
      authView.passwordText = ""
    }

    function onInputPromptChanged() { root.syncFromFlow() }
    function onResponseVisibleChanged() { root.syncFromFlow() }
    function onSupplementaryMessageChanged() { root.syncFromFlow() }
    function onFailedChanged() { root.syncFromFlow() }

    function onAuthenticationFailed() {
      root.syncFromFlow()
      root.triggerFailureFeedback()
    }

    function onAuthenticationSucceeded() {
      root.closing = true
      closeTimer.restart()
    }

    function onAuthenticationRequestCancelled() {
      root.closing = true
      closeTimer.restart()
    }
  }

  PanelWindow {
    id: panel
    visible: root.dialogVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.refocus() }
    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: Math.max(height, authView.implicitHeight + 48)
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      AuthorizationView {
        id: authView
        width: Math.min(480, parent.width - 48)
        height: implicitHeight
        x: (parent.width - width) / 2 + root.shakeOffset
        y: Math.max(24, (parent.height - height) / 2)
        userName: root.selectedIdentityLabel()
        avatarPath: root.activeIdentity && !root.activeIdentity.isGroup && root.activeIdentity.name === (Quickshell.env("USER") || Quickshell.env("LOGNAME")) ? Quickshell.env("HOME") + "/.face" : ""
        message: root.currentMessage || strings.t("admin.message")
        consentMode: root.faceConsentMode
        canReturnToFace: root.canReturnToFace
        scanning: root.faceCheckPending
        fingerprintMode: root.fingerprintMode
        passwordMode: root.responseRequired && !root.faceConsentMode && !root.faceCheckPending
        busy: root.submitted
        passwordError: root.errorFlash && !root.faceFallbackActive
        faceFailed: root.faceFallbackActive
        responseVisible: root.responseVisible
        responsePrompt: root.currentPrompt
        externalDisplay: panel.screen && !/^(eDP|LVDS|DSI)/i.test(panel.screen.name)
        reducedMotion: root.reducedMotion
        canChangeIdentity: root.allowedIdentities.length > 1
        onFaceConsent: function(useFace) { if (root.faceConsentMode) root.submitFaceConsent(useFace) }
        onReturnToFace: root.returnToFace()
        onSubmitted: root.submitResponse()
        onCancelled: root.cancelRequest()
        onChangeIdentity: root.cycleIdentity()
        onEditing: root.errorFlash = false
      }
    }
  }
}
