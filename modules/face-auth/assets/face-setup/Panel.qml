import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "SetupModel.js" as SetupModel

Panel {
  id: root
  moduleName: "surface.face-setup"
  ipcTarget: "surface.face-setup"

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginRoot: home + "/.config/omarchy/plugins/surface.face-setup"
  readonly property string statusScript: pluginRoot + "/modules/face-auth/scripts/face-setup-status.py"
  readonly property string setupScript: pluginRoot + "/modules/face-auth/scripts/run-face-setup.sh"
  readonly property string titleText: strings.t("setup.title")

  property bool lockSelected: true
  property bool sudoSelected: false
  property bool polkitSelected: false
  property bool checking: false
  property bool launching: false
  property bool setupPending: false
  property string errorMessage: ""
  property var status: null

  SetupStrings { id: strings }

  function refreshStatus(userConfirmedComplete) {
    if (statusProc.running) return
    checking = true
    errorMessage = ""
    if (userConfirmedComplete === true) setupPending = false
    statusProc.command = ["python3", statusScript, "--json"]
    statusProc.running = true
  }

  function startSetup() {
    var options = SetupModel.selectedOptions({ lock: lockSelected, sudo: sudoSelected, polkit: polkitSelected })
    if (options.length === 0 || setupProc.running) {
      errorMessage = strings.t("error.noSelection")
      return
    }
    errorMessage = ""
    launching = true
    setupProc.command = ["omarchy", "launch", "terminal", "bash", setupScript].concat(options)
    setupProc.running = true
  }

  function statusEntries() {
    if (!status) return []
    return [
      { label: strings.t("status.camera"), ready: status.camera && status.camera.available && status.camera.accessible },
      { label: strings.t("status.howdy"), ready: status.howdy && status.howdy.ready },
      { label: strings.t("status.lockPam"), ready: status.lock && status.lock.ready },
      { label: strings.t("status.passwordFallback"), ready: status.lock && status.lock.passwordFallback },
      { label: strings.t("status.sudo"), ready: status.sudo && status.sudo.ready },
      { label: strings.t("status.polkit"), ready: status.polkit && status.polkit.ready },
    ]
  }

  onOpenedChanged: if (opened) refreshStatus()

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = SetupModel.parseStatus(text)
        if (parsed) root.status = parsed
        else root.errorMessage = strings.t("status.failed")
      }
    }
    onExited: function(exitCode) {
      root.checking = false
      if (exitCode !== 0 && root.errorMessage === "") root.errorMessage = strings.t("status.failed")
    }
  }

  Process {
    id: setupProc
    onExited: function(exitCode) {
      root.launching = false
      if (exitCode !== 0) root.errorMessage = strings.t("error.launch")
      else root.setupPending = true
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "◎"
    tooltipText: strings.t("setup.title")
    active: root.opened
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(620))

    content: PanelKeyCatcher {
      id: keyCatcher
      implicitHeight: contentColumn.implicitHeight
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: {}

      ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: Style.space(12)

        Text {
          Layout.fillWidth: true
          text: strings.t("setup.title")
          color: root.bar ? root.bar.foreground : Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          wrapMode: Text.WordWrap
        }

        Text {
          Layout.fillWidth: true
          text: strings.t("setup.subtitle")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        RowLayout {
          Layout.fillWidth: true
          Button {
            text: root.checking ? strings.t("status.checking") : strings.t("setup.check")
            enabled: !root.checking
            onClicked: root.refreshStatus(true)
          }
          Item { Layout.fillWidth: true }
          Text {
            visible: root.status !== null && root.status.platform
            text: root.status && root.status.platform ? root.status.platform.version : ""
            color: Commons.Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: statusColumn.implicitHeight + Style.space(16)
          radius: Style.cornerRadius
          color: Qt.alpha(Commons.Color.foreground, 0.05)

          ColumnLayout {
            id: statusColumn
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(4)

            Repeater {
              model: root.statusEntries()
              delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Text {
                  text: modelData.ready ? "●" : "○"
                  color: modelData.ready ? Commons.Color.accent : Commons.Color.urgent
                  font.family: Style.font.family
                }
                Text {
                  Layout.fillWidth: true
                  text: modelData.label
                  color: Commons.Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }
                Text {
                  text: modelData.ready ? strings.t("status.ready") : strings.t("status.missing")
                  color: modelData.ready ? Commons.Color.accent : Commons.Color.urgent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Text {
              Layout.fillWidth: true
              visible: root.status && root.status.lock && root.status.lock.conflict
              text: strings.t("status.conflict")
              color: Commons.Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        CheckBox {
          Layout.fillWidth: true
          text: strings.t("setup.lock")
          checked: root.lockSelected
          onToggled: root.lockSelected = checked
        }
        CheckBox {
          Layout.fillWidth: true
          text: strings.t("setup.sudo")
          checked: root.sudoSelected
          onToggled: root.sudoSelected = checked
        }
        CheckBox {
          Layout.fillWidth: true
          text: strings.t("setup.polkit")
          checked: root.polkitSelected
          onToggled: root.polkitSelected = checked
        }

        Text {
          Layout.fillWidth: true
          text: strings.t("setup.passwordFallback")
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }
        Text {
          Layout.fillWidth: true
          text: strings.t("setup.installNotice")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
        Text {
          Layout.fillWidth: true
          visible: root.setupPending
          text: strings.t("setup.afterTerminal")
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
        Text {
          Layout.fillWidth: true
          text: strings.t("setup.unverified")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
        Text {
          Layout.fillWidth: true
          visible: root.errorMessage !== ""
          text: root.errorMessage
          color: Commons.Color.urgent
          font.family: Style.font.family
          wrapMode: Text.WordWrap
        }

        RowLayout {
          Layout.fillWidth: true
          Button {
            Layout.fillWidth: true
            text: root.launching ? strings.t("status.checking") : strings.t("setup.configure")
            enabled: !root.launching && !root.setupPending && (root.lockSelected || root.sudoSelected || root.polkitSelected)
            onClicked: root.startSetup()
          }
          Button {
            text: strings.t("action.dismiss")
            onClicked: root.close()
          }
        }
      }
    }
  }
}
