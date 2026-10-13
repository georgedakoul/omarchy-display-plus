import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Extra display tools next to Omarchy's own Display panel: a screen map to
// arrange and rotate screens, and Miracast casting to a TV.
Panel {
  id: root
  moduleName: "ghostl9.display-plus"
  ipcTarget: "ghostl9.display-plus"

  // Display map: positions, physical sizes and rotation come from the tv-displays script.
  readonly property string tvScript: String(Qt.resolvedUrl("tv-displays")).replace(/^file:\/\//, "")
  property string mapStateText: ""
  property var mapDisplays: []

  // Miracast: TVs found nearby, and the cast in progress (null when idle).
  readonly property string castScript: String(Qt.resolvedUrl("cast")).replace(/^file:\/\//, "")
  property var castTvs: []
  property var cast: null
  property bool castTools: true

  function castTo(mac, mode) {
    Quickshell.execDetached([root.castScript, "start", mac, mode])
    root.cast = { name: "", mode: mode, state: "connecting" }
  }
  property string mapSelectedName: ""
  property bool mapDragging: false
  readonly property var mapSelected: {
    for (var i = 0; i < mapDisplays.length; i++) if (mapDisplays[i].enabled && mapDisplays[i].name === mapSelectedName) return mapDisplays[i]
    for (var j = 0; j < mapDisplays.length; j++) if (mapDisplays[j].enabled && mapDisplays[j].focused) return mapDisplays[j]
    return mapDisplays.length ? mapDisplays[0] : null
  }
  readonly property var rotations: [
    { value: "0", label: "0°" },
    { value: "1", label: "90°" },
    { value: "2", label: "180°" },
    { value: "3", label: "270°" }
  ]

  function runMap(args) {
    if (mapActionProc.running) return
    mapActionProc.command = [root.tvScript].concat(args)
    mapActionProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: mapStateProc
    command: [root.tvScript, "state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Unchanged state keeps the map delegates (and any drag) alive.
        if (root.mapDragging || text === root.mapStateText) return
        try {
          var st = JSON.parse(String(text || "{}"))
          root.mapDisplays = st.displays || []
          root.cast = st.cast || null
          root.castTools = st.castTools !== false
          root.mapStateText = text
        } catch (e) {
          console.warn("display map: bad state", e)
        }
      }
    }
  }

  Process {
    id: castScanProc
    command: [root.castScript, "scan"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.castTvs = JSON.parse(String(text || "[]"))
        } catch (e) {
          root.castTvs = []
        }
      }
    }
  }

  // Poll only while open: TVs come and go, and the cast runs in its own unit.
  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.castTools && !root.cast && !castScanProc.running) castScanProc.running = true
      if (!mapStateProc.running) mapStateProc.running = true
    }
  }

  Process {
    id: mapActionProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running && !mapStateProc.running) mapStateProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰨇"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "DISPLAYS · DRAG TO ARRANGE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          DisplayMap {
            width: parent.width
            height: Style.space(190)
            displays: root.mapDisplays
            selectedName: root.mapSelected ? root.mapSelected.name : ""
            foreground: root.bar.foreground
            accent: Style.selectedStateColor(root.bar.foreground, Color.accent)
            selectedFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
            hoverFill: Style.hoverFillFor(root.bar.foreground, Color.accent)
            fontFamily: root.bar.fontFamily
            captionSize: Style.font.caption
            numberSize: Style.font.display
            onDraggingChanged: root.mapDragging = dragging
            onPicked: function(name) { root.mapSelectedName = name }
            onArranged: function(args) { root.runMap(args) }
          }

          Item {
            width: parent.width
            visible: !!root.mapSelected
            implicitHeight: rotateGroup.implicitHeight

            Text {
              textFormat: Text.PlainText
              text: root.mapSelected ? root.mapSelected.name : ""
              color: Style.selectedStateColor(root.bar.foreground, Color.accent)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }

            ButtonGroup {
              id: rotateGroup
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              options: root.rotations
              value: root.mapSelected ? String(root.mapSelected.transform) : ""
              foreground: root.bar.foreground
              accent: Color.accent
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) { root.runMap(["rotate", root.mapSelected.name, v]) }
            }
          }

          // ---------- Cast to TV (Miracast) ----------
          PanelSectionHeader {
            text: "CAST TO TV"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Item {
            width: parent.width
            visible: !!root.cast
            implicitHeight: Math.max(stopCast.implicitHeight, castState.implicitHeight)

            Text {
              id: castState
              anchors.left: parent.left
              anchors.right: stopCast.left
              anchors.verticalCenter: parent.verticalCenter
              leftPadding: Style.space(6)
              textFormat: Text.PlainText
              text: !root.cast ? "" : root.cast.state === "failed"
                ? "Cast failed: " + root.cast.error
                : root.cast.state === "casting"
                ? (root.cast.mode === "extend" ? "Extending to " : "Mirroring to ") + root.cast.name
                : "Connecting" + (root.cast.name ? " to " + root.cast.name : "") + " · accept on the TV"
              wrapMode: root.cast && root.cast.state === "failed" ? Text.WordWrap : Text.NoWrap
              color: root.cast && root.cast.state === "failed" ? Color.urgent : Style.selectedStateColor(root.bar.foreground, Color.accent)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            Button {
              id: stopCast
              anchors.right: parent.right
              text: root.cast && root.cast.state === "failed" ? "Dismiss" : "Stop"
              iconText: "󰓛"
              bordered: true
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.caption
              onClicked: {
                Quickshell.execDetached([root.castScript, "stop"])
                root.cast = null
              }
            }
          }

          // Casting needs two packages Omarchy does not ship; one click installs them.
          Item {
            width: parent.width
            visible: !root.castTools
            implicitHeight: installCast.implicitHeight

            Text {
              anchors.left: parent.left
              anchors.right: installCast.left
              anchors.verticalCenter: parent.verticalCenter
              leftPadding: Style.space(6)
              textFormat: Text.PlainText
              text: "Casting needs wf-recorder and dnsmasq"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Button {
              id: installCast
              anchors.right: parent.right
              text: "Install"
              iconText: "󰏗"
              bordered: true
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.caption
              onClicked: {
                root.bar.run("omarchy-launch-floating-terminal-with-presentation omarchy-pkg-add wf-recorder dnsmasq")
                root.close()
              }
            }
          }

          Text {
            visible: root.castTools && !root.cast && root.castTvs.length === 0
            leftPadding: Style.space(6)
            textFormat: Text.PlainText
            text: "Searching for Miracast TVs nearby…"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: root.cast ? [] : root.castTvs

            Item {
              required property var modelData

              width: panelColumn.width
              implicitHeight: castButtons.implicitHeight

              Text {
                anchors.left: parent.left
                anchors.right: castButtons.left
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Style.space(6)
                textFormat: Text.PlainText
                text: modelData.name
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              Row {
                id: castButtons
                anchors.right: parent.right
                spacing: Style.spacing.xs

                Button {
                  text: "Mirror"
                  iconText: "󰍺"
                  bordered: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.caption
                  onClicked: root.castTo(modelData.mac, "mirror")
                }

                Button {
                  text: "Extend"
                  iconText: "󰍹"
                  bordered: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.caption
                  onClicked: root.castTo(modelData.mac, "extend")
                }
              }
            }
          }

          Item {
            width: parent.width
            height: Style.space(4)
          }
        }
      }
    }
  }
}
