import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Panel {
  id: root
  moduleName: "io.github.douglas.omarchy-ekvm"
  ipcTarget: "io.github.douglas.omarchy-ekvm"

  property string current: ""
  property string error: ""
  property string switchingTo: ""
  property bool cursorActive: false
  property int selectedIndex: 0

  readonly property string model: setting("model", "P40WD-40")
  readonly property var inputs: setting("inputs", [
    { "label": "HDMI", "value": "0x11" },
    { "label": "DisplayPort", "value": "0x0f" },
    { "label": "Thunderbolt", "value": "0x31" }
  ])
  readonly property var currentInput: inputFor(current)
  readonly property string statusText: {
    if (error !== "") return error
    if (switchingTo !== "") return "Switching to " + switchingTo
    return currentInput ? "Showing " + currentInput.label : "Unknown input"
  }
  readonly property color hoverFill: bar
    ? Style.hoverFillFor(bar.foreground, Commons.Color.accent)
    : Commons.Color.accent
  readonly property color selectedFill: bar
    ? Style.selectedFillFor(bar.foreground, Commons.Color.accent)
    : Commons.Color.accent

  // Turns the target machine's display back on (DPMS) so it isn't black after
  // idle. SSH sessions lack the Hyprland environment, so recover it first.
  readonly property string wakeScript: "export XDG_RUNTIME_DIR=/run/user/$(id -u); "
    + "export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t $XDG_RUNTIME_DIR/hypr | head -1); "
    + "omarchy-brightness-display on"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function normalize(value) {
    return Number(value).toString(16)
  }

  function inputFor(value) {
    for (var i = 0; i < inputs.length; i++)
      if (normalize(inputs[i].value) === normalize(value)) return inputs[i]
    return null
  }

  // Compare by value: QML hands delegates copies of the settings objects.
  function isCurrent(input) {
    return !!input && current !== "" && normalize(input.value) === normalize(current)
  }

  function portName(value) {
    var names = { "11": "HDMI", "12": "HDMI 2", "f": "DisplayPort", "10": "DisplayPort 2", "31": "Thunderbolt" }
    return names[normalize(value)] || ("Input " + value)
  }

  function nextInput() {
    for (var i = 0; i < inputs.length; i++)
      if (isCurrent(inputs[i])) return inputs[(i + 1) % inputs.length]
    return inputs[0]
  }

  function refresh() {
    if (switchingTo !== "") return
    readProcess.running = false
    readProcess.running = true
  }

  function switchTo(input) {
    if (!input || switchingTo !== "" || isCurrent(input)) return
    switchingTo = input.label
    if (input.host) {
      wakeProcess.command = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=3", String(input.host), wakeScript]
      wakeProcess.running = true
    }
    switchProcess.command = ["ddcutil", "--model", model, "setvcp", "60", String(input.value)]
    switchProcess.running = true
  }

  function moveCursor(delta) {
    if (inputs.length === 0) return
    selectedIndex = (selectedIndex + delta + inputs.length) % inputs.length
  }

  onOpenedChanged: if (opened) {
    refresh()
    cursorActive = false
    selectedIndex = Math.max(0, inputs.findIndex(isCurrent))
  }

  Process {
    id: readProcess
    command: ["ddcutil", "--model", root.model, "getvcp", "60", "--brief"]
    running: true
    stdout: StdioCollector { id: readOutput }
    onExited: function(exitCode) {
      var match = /VCP 60 SNC x([0-9a-fA-F]+)/.exec(readOutput.text)
      if (exitCode === 0 && match) {
        root.current = "0x" + match[1]
        root.error = ""
      } else {
        root.error = exitCode === 127 ? "ddcutil is not installed" : root.model + " not found"
      }
    }
  }

  Process {
    id: wakeProcess
    command: ["true"]
  }

  Process {
    id: switchProcess
    command: ["true"]
    onExited: function(exitCode) {
      root.switchingTo = ""
      root.error = exitCode === 0 ? "" : "Switch failed"
      root.refresh()
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  ShellIpc {
    target: root.ipcTarget + ".input"
    function next(): void { root.switchTo(root.nextInput()) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰹑"
    tooltipText: "Monitor · " + root.statusText
    dimmed: root.error !== ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.switchTo(root.nextInput())
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.switchTo(root.inputs[root.selectedIndex])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(14)

        // ---------- Hero: monitor icon · model · current input ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰹑"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.error === "" ? 1.0 : 0.5
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "ThinkVision " + root.model
              textFormat: Text.PlainText
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.statusText.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          id: inputList
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "Inputs"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Repeater {
            model: root.inputs
            InputRow {
              required property var modelData
              required property int index
              width: inputList.width
              input: modelData
              rowIndex: index
            }
          }
        }
      }
    }
  }

  // Two-line input row: machine name over its monitor port.
  component InputRow: CursorSurface {
    id: row
    required property var input
    required property int rowIndex

    readonly property bool isActive: root.isCurrent(input)
    readonly property bool isSwitching: root.switchingTo === input.label
    readonly property bool usable: root.error === "" && root.switchingTo === ""

    hasCursor: root.cursorActive && root.selectedIndex === rowIndex
    current: isActive
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: row.usable && !row.isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.selectedIndex = row.rowIndex
      }
      onClicked: if (row.usable) root.switchTo(row.input)
    }

    PanelToolTip {
      visible: rowMouse.containsMouse && !row.isActive && row.usable
      text: "Switch to " + row.input.label
      fontFamily: root.bar.fontFamily
    }

    Item {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      implicitHeight: Math.max(rowIcon.implicitHeight, info.implicitHeight)

      Text {
        id: rowIcon
        textFormat: Text.PlainText
        text: row.input.icon || "󰇄"
        color: row.isActive ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.heading
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: info
        spacing: Style.space(1)
        anchors.left: rowIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Text {
          textFormat: Text.PlainText
          text: row.input.label
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          width: parent.width
        }
        Text {
          textFormat: Text.PlainText
          text: row.isSwitching ? "Switching…"
            : root.portName(row.input.value) + (row.isActive ? " · On screen" : "")
          color: row.isActive ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }
    }
  }
}
