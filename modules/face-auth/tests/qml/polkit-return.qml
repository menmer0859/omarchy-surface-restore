import QtQuick
import QtQuick.Window
import Quickshell
import "assets/omarchy-polkit" as Admin

ShellRoot {
 id: suite
 property int returns: 0
 property int consents: 0
 function findItem(item, name) { if (item.objectName === name) return item; for (var i = 0; i < item.children.length; i++) { var found = findItem(item.children[i], name); if (found) return found } return null }
 function check(condition, message) { if (!condition) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message) } }
 Window {
  width: 800; height: 900; visible: true
  Admin.AuthorizationView {
   id: admin; anchors.centerIn: parent; width: 480; height: implicitHeight
   userName: "Administrator"; passwordMode: true; consentMode: false
  }
 }
 Connections {
  target: admin
  ignoreUnknownSignals: true
  function onReturnToFace() { suite.returns++ }
  function onFaceConsent(value) { suite.consents++ }
 }
 Timer {
  interval: 250; running: true; repeat: false
  onTriggered: {
   try {
    suite.check(typeof admin.canReturnToFace === "boolean", "password view supports a return capability");
    admin.canReturnToFace = true;
    var face = suite.findItem(admin, "faceAction");
    suite.check(face && face.visible && face.enabled, "password view visibly offers Return to face");
    suite.check(face.label === "Return to face", "return action describes returning to the picker");
    face.clicked();
    suite.check(suite.returns === 1 && suite.consents === 0, "return event never directly consents to camera");
    admin.busy = true;
    suite.check(!face.enabled, "submitted password disables return");
    admin.busy = false; admin.canReturnToFace = false;
    suite.check(!face.visible, "unsupported backend does not offer a fake return");
    admin.passwordMode = false; admin.consentMode = true;
    suite.check(face.visible && face.enabled, "picker offers explicit face consent");
    face.clicked();
    suite.check(suite.returns === 1 && suite.consents === 1, "picker face event is separate explicit consent");
    admin.scanning = true;
    suite.check(!face.visible, "busy face scan has no unsupported restart");
    console.log("POLKIT_RETURN_QML_PASS"); Qt.quit();
   } catch (error) { console.error("FAIL: " + error); Qt.exit(1) }
  }
 }
}
