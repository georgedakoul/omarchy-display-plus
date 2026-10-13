import QtQuick
import "Layout.js" as Layout

// Windows-style display map: every enabled display drawn at its physical
// size, dragged against another display's edge to rearrange. Plain QtQuick so
// both the TV panel and the Display panel can host it.
Item {
  id: map

  property var displays: []
  property string selectedName: ""
  property color foreground: "white"
  property color accent: "deepskyblue"
  property color selectedFill: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
  property color hoverFill: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  property string fontFamily: "monospace"
  property real captionSize: 11
  property real numberSize: 28
  property bool dragging: false

  signal picked(string name)
  signal arranged(var args)


  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property var rects: Layout.physicalLayout(displays.filter(function(d) { return d.enabled }).map(Layout.rectOf))
  readonly property var box: Layout.bounds(rects)
  readonly property real pad: 12
  readonly property real k: Math.min((width - 2 * pad) / box.w, (height - 2 * pad) / box.h)
  readonly property real offX: (width - box.w * k) / 2
  readonly property real offY: (height - box.h * k) / 2

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.color: Qt.darker(map.foreground, 2.4)
    border.width: 1
    radius: 4
  }

  Repeater {
    model: map.rects

    Rectangle {
      id: screen
      required property var modelData
      required property int index

      readonly property bool isSelected: map.selectedName === modelData.name

      function rebind() {
        screen.x = Qt.binding(function() { return map.offX + (screen.modelData.px - map.box.x) * map.k })
        screen.y = Qt.binding(function() { return map.offY + (screen.modelData.py - map.box.y) * map.k })
      }

      Component.onCompleted: rebind()
      width: modelData.pw * map.k
      height: modelData.ph * map.k
      z: mouse.drag.active ? 2 : (isSelected ? 1 : 0)
      radius: 3
      color: isSelected ? map.selectedFill : (mouse.containsMouse ? map.hoverFill : "transparent")
      border.color: isSelected ? map.accent : map.dim
      border.width: isSelected ? 2 : 1

      Column {
        anchors.centerIn: parent

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: String(screen.index + 1)
          color: screen.isSelected ? map.accent : map.foreground
          font.family: map.fontFamily
          font.pixelSize: Math.max(map.captionSize, Math.min(map.numberSize, screen.height * 0.35))
          font.bold: true
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: screen.height > 46 && implicitWidth < screen.width - 6
          textFormat: Text.PlainText
          text: screen.modelData.name + " · " + screen.modelData.inches + "″"
          color: map.dim
          font.family: map.fontFamily
          font.pixelSize: map.captionSize
        }
      }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: screen
        drag.threshold: 4
        onPressed: {
          map.picked(screen.modelData.name)
          map.dragging = true
        }
        onReleased: {
          map.dragging = false
          var mx = map.box.x + (screen.x - map.offX) / map.k
          var my = map.box.y + (screen.y - map.offY) / map.k
          screen.rebind()
          if (Math.abs(mx - screen.modelData.px) < 1 && Math.abs(my - screen.modelData.py) < 1) return

          var me = screen.modelData
          var others = map.rects.filter(function(r) { return r.name !== me.name })
          var spot = Layout.snap(Object.assign({}, me, { px: mx, py: my }), others)
          if (!spot) return
          var pos = Layout.toLogical(me, spot)
          var args = ["arrange"]
          for (var i = 0; i < map.rects.length; i++) {
            var r = map.rects[i]
            var p = r.name === me.name ? pos : r
            args.push(r.name + "=" + p.x + "x" + p.y)
          }
          map.arranged(args)
        }
        onCanceled: { map.dragging = false; screen.rebind() }
      }
    }
  }
}
