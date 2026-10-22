import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons as Commons
import "assets/omarchy-lock" as Lock
import "assets/omarchy-polkit" as Admin

ShellRoot {
 id: suite
 property int step: 0
 property bool faceChosen: false
 property bool passwordChosen: false
 property string lastMode: ""
 property int wakeCalls: 0
 function findItem(item, name) { if (item.objectName === name) return item; for (var i = 0; i < item.children.length; i++) { var found = findItem(item.children[i], name); if (found) return found } return null }
 function check(condition, message) { if (!condition) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message) } }
 Window {
  id: window; width: 1024; height: 768; visible: true
  Lock.LockView { id: lock; anchors.fill: parent; faceConfigured: true; unlockMode: "face"; avatarPath: ""; userName: "eclipse" }
  Admin.AuthorizationView { id: admin; width: 480; height: 620; visible: false; userName: "eclipse"; consentMode: true }
 }
 Connections { target: admin; function onFaceConsent(value) { if (value) suite.faceChosen = true; else suite.passwordChosen = true } }
 Connections { target: lock; function onWakeRequested(deliberate) { suite.wakeCalls++; } function onUnlockModeRequested(mode) { suite.lastMode = mode; if (suite.step === 2) { suite.check(mode === "password", "password signal"); suite.step++ } } }
 Timer {
  interval: 250; running: true; repeat: true
  onTriggered: {
   try {
    if (suite.step === 0) {
     suite.check(lock.stateTitle === "Ready when you are", "English lock title");
     suite.check(admin.faceLabel === "Use face", "English admin consent");
     var face = suite.findItem(admin, "faceAction"); suite.check(!!face, "face action exists"); face.clicked(); suite.check(suite.faceChosen, "explicit face consent");
     suite.findItem(admin, "passwordAction").clicked(); suite.check(suite.passwordChosen, "password fallback choice");
     admin.visible = true; admin.scanning = true;
     suite.check(!suite.findItem(admin, "passwordAction").visible, "busy Polkit cannot offer unsupported password switch");
     admin.scanning = false; admin.consentMode = false; admin.fingerprintMode = true;
     suite.check(!suite.findItem(admin, "passwordAction").visible, "fingerprint busy cannot offer unsupported password switch");
     admin.fingerprintMode = false; admin.consentMode = true; admin.visible = false;
     Commons.I18n.setLanguage("zh-CN"); suite.step = 1;
    } else if (suite.step === 1) {
     suite.check(lock.stateTitle === "等待你的操作", "live Chinese lock title");
     suite.check(admin.faceLabel === "使用人脸", "live Chinese admin choice");
     lock.facePhase = "failed"; suite.check(lock.stateTitle === "未能识别", "translated error binding");
     lock.userName = '<img src="https://invalid.example/x">';
     suite.check(lock.identityLabel === lock.userName, "identity kept literally");
     suite.check(lock.identityVertical === false, "default horizontal identity");
     lock.avatarPath = "/nonexistent-avatar.png";
     Commons.I18n.setLanguage("fr"); suite.step = 2;
    } else if (suite.step === 2) {
     suite.check(lock.stateTitle === "Not recognized", "English fallback for unsupported locale");
     suite.check(!lock.identityVertical, "broken avatar falls back to Omarchy identity");
     lock.unlockModeRequested("password");
    } else if (suite.step === 3) {
     var folder = Quickshell.env("SURFACE_TEST_SCREENSHOTS")
     if (folder) window.contentItem.grabToImage(function(result) { result.saveToFile(folder + "/lock-en.png") }); suite.step = 30; return
    } else if (suite.step === 30) {
     admin.visible = true; admin.x = (window.width-admin.width)/2; admin.y = (window.height-admin.height)/2
     admin.height = admin.implicitHeight
     Commons.I18n.setLanguage("zh-CN"); suite.step = 4;
    } else if (suite.step === 4) {
     var folder = Quickshell.env("SURFACE_TEST_SCREENSHOTS")
     if (folder) window.contentItem.grabToImage(function(result) { result.saveToFile(folder + "/admin-zh.png") }); suite.step = 40; return
    } else if (suite.step === 40) {
     admin.visible = false; lock.avatarPath = "/usr/share/omarchy/icon.png"; suite.step = 5;
    } else if (suite.step === 5) {
     suite.check(lock.identityVertical, "custom avatar uses large vertical identity");
     var label = suite.findItem(lock, "identityName"); suite.check(label.height > 0 && label.width > 0, "username remains visible after avatar layout changes");
     var folder = Quickshell.env("SURFACE_TEST_SCREENSHOTS")
     if (folder) window.contentItem.grabToImage(function(result) { result.saveToFile(folder + "/avatar-zh.png") })
     suite.step = 6;
    } else if (suite.step === 6) {
     lock.unlockMode = "password"; lock.facePhase = "password"; suite.lastMode = ""; suite.step = 7;
    } else if (suite.step === 7) {
     var face = suite.findItem(lock, "faceAction");
     suite.check(face.visible && face.enabled, "password screen has accessible face return action");
     suite.check(face.mapToItem(lock, 0, face.height).y <= lock.height - 86, "face return must be inside viewport without scrolling at 1024x768");
     suite.check(suite.lastMode === "", "password mode must not switch automatically");
     face.clicked(); suite.check(suite.lastMode === "face", "return action requests face explicitly");
     var input = suite.findItem(lock, "passwordInput");
     var field = input.parent.parent;
     field.text = "not-a-real-password"; field.revealed = true; suite.wakeCalls = 0; field.text = "";
     suite.check(suite.wakeCalls === 0, "programmatic password clearing never wakes a blanked display");
     suite.check(!field.revealed, "clearing an editing session also resets password reveal");
     field.text = "example"; suite.step = 8;
    } else if (suite.step === 8) {
     var folder = Quickshell.env("SURFACE_TEST_SCREENSHOTS"); suite.step = 80;
     if (folder) window.contentItem.grabToImage(function(result) { result.saveToFile(folder + "/password-return-en.png"); suite.step = 9; }); else suite.step = 9;
    } else if (suite.step === 9) {
     console.log("SURFACE_QML_TESTS_PASS"); Qt.quit();
    }
   } catch (error) { console.error("FAIL: " + error); Qt.exit(1) }
  }
 }
}
