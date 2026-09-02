import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string phase: "idle"
  property string transcript: ""
  property string resultTitle: ""
  property string resultLabel: ""
  property string resultGlyph: "󰍬"
  property string resultDetail: ""
  property string errorText: ""
  property bool voxtypeReady: false
  property bool indexReady: false
  property bool daemonReady: false
  property string lastStatusClass: ""
  property int recordRestarts: 0
  property bool sawRecording: false

  readonly property string pluginId: "io.github.goooooooooody.omarchy-pebble-voice"
  readonly property string pluginHome: (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/" + pluginId
  readonly property string cli: pluginHome + "/bin/pebble-voice"
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-pebble-voice"
  readonly property string transcriptPath: runtimeDir + "/transcript.txt"
  readonly property color background: Color.popups.background
  readonly property color foreground: Color.popups.text
  readonly property color border: Color.popups.border
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property var borderSpec: Border.surfaceSpec("popups", "border", border, Math.max(1, Style.space(2)))
  readonly property string fontFamily: Style.font.family
  readonly property int pad: Style.space(16)
  readonly property int chipWidth: Math.min(Style.space(240), Math.max(Style.space(168), panel.width > 0 ? panel.width - Style.gapsOut * 2 : Style.space(240)))
  readonly property bool busy: phase === "snapshot" || phase === "listening" || phase === "transcribing" || phase === "dispatching"
  readonly property bool listening: phase === "listening"
  readonly property string statusLine: {
    if (phase === "missing") return errorText || "Voice is not ready"
    if (phase === "snapshot") return "Looking at the window"
    if (phase === "listening") return transcript === "" ? "Listening" : "Listening"
    if (phase === "transcribing") return "Transcribing"
    if (phase === "dispatching") return "Working it out"
    if (phase === "done") return resultLabel || "Done"
    if (phase === "error") return errorText || "Failed"
    return "Pebble Voice"
  }
  readonly property string detailLine: {
    if (phase === "done") return resultTitle || transcript
    if (phase === "error") return resultDetail
    if (transcript !== "") return transcript
    if (phase === "listening") return "Speak…"
    return ""
  }
  readonly property string orbGlyph: {
    if (phase === "done") return resultGlyph || "󰀎"
    if (phase === "error" || phase === "missing") return "󰅚"
    if (phase === "dispatching") return resultGlyph || "󰔟"
    if (phase === "transcribing") return "󰔟"
    return "󰍬"
  }

  function open(payloadJson) {
    if (root.opened && root.busy) return
    if (root.opened && root.phase === "done") {
      root.dismiss()
      return
    }
    root.errorText = ""
    root.transcript = ""
    root.resultTitle = ""
    root.resultLabel = ""
    root.resultGlyph = "󰍬"
    root.resultDetail = ""
    root.lastStatusClass = ""
    root.recordRestarts = 0
    root.sawRecording = false
    root.phase = "snapshot"
    dismissTimer.stop()
    snapshotProcess.running = true
  }

  function close() {
    root.cancelRecording()
    root.opened = false
    root.phase = "idle"
    dismissTimer.stop()
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || root.pluginId)
  }

  function activate() {
    if (!root.opened || root.phase === "idle") {
      root.open("{}")
      return "listening"
    }
    if (root.phase === "listening") {
      root.stopListening()
      return "stopping"
    }
    if (root.phase === "snapshot") return "snapshot"
    if (root.phase === "transcribing") {
      if (root.transcript !== "") {
        root.runCapture()
        return "dispatching"
      }
      return "transcribing"
    }
    if (root.busy) return root.phase
    root.dismiss()
    return "closed"
  }

  function cancelRecording() {
    if (root.phase === "listening" || root.phase === "transcribing" || root.phase === "snapshot")
      cancelProcess.running = true
  }

  function startListening() {
    root.opened = true
    root.phase = "listening"
    startProcess.running = true
    Qt.callLater(function() { if (card) card.forceActiveFocus() })
  }

  function stopListening() {
    if (root.phase !== "listening") return
    root.phase = "transcribing"
    stopProcess.running = true
  }

  function runCapture() {
    if (root.phase === "dispatching" || root.phase === "done") return
    root.phase = "dispatching"
    captureProcess.running = true
  }

  function applyLiveTranscript(raw) {
    var spoken = String(raw || "").replace(/^\s+|\s+$/g, "")
    if (spoken !== "") root.transcript = spoken
    if (root.phase === "transcribing" && spoken !== "") root.runCapture()
  }

  function finishTranscription() {
    if (root.phase !== "transcribing") return
    if (root.transcript !== "") {
      root.runCapture()
      return
    }
    root.phase = "error"
    root.errorText = "No speech heard"
  }

  function recoverRecording() {
    if (root.phase !== "listening" || startProcess.running || !root.sawRecording) return
    if (root.recordRestarts < 1) {
      root.recordRestarts += 1
      root.sawRecording = false
      startProcess.running = true
      return
    }
    root.phase = "error"
    root.errorText = "Recording was cancelled"
  }

  function parseReady(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      root.voxtypeReady = parsed.voxtype === true
      root.daemonReady = parsed.daemon === true
      root.indexReady = parsed.index === true
    } catch (e) {
      root.voxtypeReady = false
      root.daemonReady = false
      root.indexReady = false
    }
  }

  function parseStatus(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      var klass = String(parsed.class || parsed.alt || "")
      root.lastStatusClass = klass
      if (klass === "recording") root.sawRecording = true
      var preview = String(parsed.preview || parsed.partial || parsed.transcript || "")
      if (preview !== "" && (root.phase === "listening" || root.phase === "transcribing"))
        root.applyLiveTranscript(preview)
      if (root.phase === "listening" && klass === "idle")
        root.recoverRecording()
      if (root.phase === "transcribing" && (klass === "idle" || klass === "stopped" || klass === "")) {
        if (!transcriptProcess.running) transcriptProcess.running = true
      }
    } catch (e) {}
  }

  function parseCapture(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (parsed.status === "error") {
        root.phase = "error"
        root.errorText = parsed.detail || "Dispatch failed"
        return
      }
      root.resultLabel = parsed.label || parsed.action || "Done"
      root.resultGlyph = parsed.glyph || "󰀎"
      root.resultTitle = parsed.preview || parsed.title || parsed.transcription || ""
      root.resultDetail = parsed.actionResult || parsed.result || ""
      if (parsed.transcription) root.transcript = parsed.transcription
      root.phase = parsed.status === "failed" ? "error" : "done"
      if (parsed.status === "failed") root.errorText = parsed.error || "Dispatch failed"
      else dismissTimer.restart()
    } catch (e) {
      root.phase = "error"
      root.errorText = "Could not read the Index result"
    }
  }

  FileView {
    id: liveTranscript
    path: root.transcriptPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyLiveTranscript(text())
  }

  Process {
    id: readyProcess
    command: [root.cli, "ready"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseReady(text)
    }
    onExited: function(code) {
      if (!root.voxtypeReady || !root.daemonReady || !root.indexReady) {
        root.opened = true
        root.phase = "missing"
        if (!root.voxtypeReady) root.errorText = "VoxType is not installed"
        else if (!root.daemonReady) root.errorText = "Start the VoxType daemon"
        else root.errorText = "Pebble Index is not installed"
        Qt.callLater(function() { if (card) card.forceActiveFocus() })
        return
      }
      root.startListening()
    }
  }

  Process {
    id: snapshotProcess
    command: [root.cli, "snapshot"]
    running: false
    onExited: readyProcess.running = true
  }

  Process {
    id: startProcess
    command: [root.cli, "start"]
    running: false
  }

  Process {
    id: stopProcess
    command: [root.cli, "stop"]
    running: false
    onExited: function() {
      if (!statusProcess.running) statusProcess.running = true
      if (!transcriptProcess.running) transcriptProcess.running = true
    }
  }

  Process {
    id: cancelProcess
    command: [root.cli, "cancel"]
    running: false
  }

  Process {
    id: statusProcess
    command: [root.cli, "status"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Process {
    id: transcriptProcess
    command: [root.cli, "transcript"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.applyLiveTranscript(text)
        if (root.phase === "transcribing" && (root.lastStatusClass === "idle" || root.lastStatusClass === "stopped" || root.lastStatusClass === ""))
          root.finishTranscription()
      }
    }
  }

  Process {
    id: captureProcess
    command: [root.cli, "capture"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseCapture(text)
    }
    onExited: function(code) {
      if (code !== 0 && root.phase === "dispatching") {
        root.phase = "error"
        root.errorText = "Index capture failed"
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 250
    repeat: true
    running: root.opened && (root.phase === "listening" || root.phase === "transcribing")
    onTriggered: {
      if (!statusProcess.running) statusProcess.running = true
      if (!transcriptProcess.running) transcriptProcess.running = true
      liveTranscript.reload()
    }
  }

  IpcHandler {
    target: "io.github.goooooooooody.omarchy-pebble-voice"
    function activate(): string { return root.activate() }
    function open(payloadJson: string): string { root.open(payloadJson || "{}"); return "ok" }
    function close(): string { root.close(); return "ok" }
  }

  Timer {
    id: transcribeTimeout
    interval: 20000
    running: root.phase === "transcribing"
    onTriggered: {
      if (root.transcript !== "") root.runCapture()
      else {
        root.phase = "error"
        root.errorText = "No speech heard"
      }
    }
  }

  Timer {
    id: dismissTimer
    interval: 2800
    onTriggered: root.dismiss()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-pebble-voice"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: card }

    BorderSurface {
      id: card
      width: root.chipWidth
      height: content.implicitHeight + root.pad * 2
      radius: Style.cornerRadius
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: Style.gapsOut
      anchors.bottomMargin: Style.space(67)
      color: Util.alpha(root.background, 0.97)
      borderSpec: root.borderSpec
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.dismiss()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          if (root.phase === "listening") root.stopListening()
          else if (root.phase === "done" || root.phase === "error" || root.phase === "missing") root.dismiss()
          event.accepted = true
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.phase === "listening") root.stopListening()
          else if (root.phase === "done" || root.phase === "error" || root.phase === "missing") root.dismiss()
        }
      }

      RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: card.borderLeft + root.pad
        anchors.rightMargin: card.borderRight + root.pad
        spacing: Style.space(12)

        Item {
          Layout.preferredWidth: Style.space(28)
          Layout.preferredHeight: Style.space(28)
          Layout.alignment: Qt.AlignTop

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.orbGlyph
            color: root.phase === "error" || root.phase === "missing" ? root.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.listening ? pulse.opacity : 1
          }

          Rectangle {
            visible: root.listening
            width: Style.space(7)
            height: Style.space(7)
            radius: width / 2
            anchors.right: parent.right
            anchors.top: parent.top
            color: root.accent
            opacity: pulse.opacity
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: Style.space(4)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.statusLine
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            visible: root.detailLine !== ""
            textFormat: Text.PlainText
            text: root.detailLine
            color: root.foreground
            opacity: 0.72
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
        }
      }

      SequentialAnimation {
        id: pulse
        property real opacity: 0.55
        running: root.listening
        loops: Animation.Infinite
        NumberAnimation { target: pulse; property: "opacity"; from: 0.4; to: 1; duration: 700; easing.type: Easing.InOutQuad }
        NumberAnimation { target: pulse; property: "opacity"; from: 1; to: 0.4; duration: 700; easing.type: Easing.InOutQuad }
      }
    }
  }
}
