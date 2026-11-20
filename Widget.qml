import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "io.github.douglas.omarchy-ekvm"
  property bool popupOpen: false
  property string current: ""
  property string error: ""
  property bool busy: false
  readonly property string model: setting("model", "P40WD-40")
  readonly property var inputs: setting("inputs", [
    { "label": "HDMI", "value": "0x11" },
    { "label": "DisplayPort", "value": "0x0f" },
    { "label": "Thunderbolt", "value": "0x31" }
  ])
  readonly property var currentInput: inputFor(current)
  readonly property string tooltip: error !== ""
    ? "Monitor · " + error
    : "Monitor · " + (currentInput ? currentInput.label : "Unknown input")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function normalize(value) {
    return Number(value).toString(16)
  }

  function inputFor(value) {
    for (var i = 0; i < inputs.length; i++)
      if (normalize(inputs[i].value) === normalize(value))
        return inputs[i]
    return null
  }

  function nextInput() {
    for (var i = 0; i < inputs.length; i++)
      if (normalize(inputs[i].value) === normalize(current))
        return inputs[(i + 1) % inputs.length]
    return inputs[0]
  }

  function refresh() {
    if (busy)
      return
    readProcess.running = false
    readProcess.running = true
  }

  function switchTo(input) {
    if (!input || busy)
      return
    busy = true
    switchProcess.command = ["ddcutil", "--model", model, "setvcp", "60", String(input.value)]
    switchProcess.running = true
  }

  Process {
    id: readProcess
    command: ["ddcutil", "--model", root.model, "getvcp", "60", "--brief"]
    running: true
    stdout: SplitParser {
      property string buffer: ""
      onRead: function(data) { buffer += data + "\n" }
    }
    onExited: function(exitCode) {
      var raw = stdout.buffer.trim()
      stdout.buffer = ""
      var match = /VCP 60 SNC x([0-9a-fA-F]+)/.exec(raw)
      if (exitCode === 0 && match) {
        root.current = "0x" + match[1]
        root.error = ""
      } else {
        root.error = exitCode === 127 ? "ddcutil not installed" : root.model + " not found"
      }
    }
  }

  Process {
    id: switchProcess
    command: ["true"]
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0)
        root.error = "Switch failed"
      root.refresh()
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.currentInput && root.currentInput.icon ? root.currentInput.icon : "󰹑"
    tooltipText: root.tooltip
    foreground: Color.foreground
    dimmed: root.error !== ""
    useActiveColor: false
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton)
        root.switchTo(root.nextInput())
      else {
        root.popupOpen = !root.popupOpen
        if (root.popupOpen)
          root.refresh()
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(260))
    contentHeight: popup.fittedContentHeight(panelColumn.implicitHeight)

    Column {
      id: panelColumn
      anchors.fill: parent
      spacing: Style.space(10)

      Column {
        width: parent.width
        spacing: Style.space(2)

        Text {
          text: "ThinkVision " + root.model
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          elide: Text.ElideRight
          width: parent.width
        }
        Text {
          text: root.busy ? "Switching…" : root.tooltip.replace("Monitor · ", "")
          color: Qt.darker(root.bar.foreground, 1.45)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      Repeater {
        model: root.inputs
        delegate: Button {
          required property var modelData
          width: panelColumn.width
          iconText: modelData.icon || "󰇄"
          text: modelData.label
          foreground: root.bar.foreground
          selected: root.currentInput === modelData
          bordered: true
          enabled: root.error === "" && !root.busy
          onClicked: root.switchTo(modelData)
        }
      }
    }
  }
}
