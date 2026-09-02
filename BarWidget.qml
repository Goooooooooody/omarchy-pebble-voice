import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.goooooooooody.omarchy-pebble-voice"

  readonly property string pluginId: moduleName
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍬"
    tooltipText: "Pebble Voice"
    onPressed: {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell call " + root.pluginId + " activate '{}'")
    }
  }
}
