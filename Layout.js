// Display map math. Hyprland arranges displays in logical pixels, the map
// draws them at their physical size in millimetres, so every drag converts
// between the two along the edge the screens share.

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

// Logical rect (x, y, w, h) plus physical size in mm (pw, ph) and diagonal inches.
function rectOf(d) {
  var portrait = d.transform % 2 === 1
  var s = d.scale || 1
  var pw = d.physicalWidth, ph = d.physicalHeight
  if (!(pw > 0 && ph > 0)) {
    // Virtual TVs report no size: use the inches picked for them, else 96 dpi.
    var diag = d.inches > 0 ? d.inches * 25.4 : Math.sqrt(d.width * d.width + d.height * d.height) / 96 * 25.4
    var px = Math.sqrt(d.width * d.width + d.height * d.height)
    pw = diag * d.width / px
    ph = diag * d.height / px
  }
  return {
    name: d.name,
    x: d.x,
    y: d.y,
    w: Math.round((portrait ? d.height : d.width) / s),
    h: Math.round((portrait ? d.width : d.height) / s),
    pw: portrait ? ph : pw,
    ph: portrait ? pw : ph,
    inches: Math.round(Math.sqrt(pw * pw + ph * ph) / 25.4)
  }
}

// Which side of p the rect m sits on, when they share part of an edge.
function touching(p, m) {
  var overlapY = m.y < p.y + p.h && p.y < m.y + m.h
  var overlapX = m.x < p.x + p.w && p.x < m.x + m.w
  if (overlapY && m.x === p.x + p.w) return "right"
  if (overlapY && m.x + m.w === p.x) return "left"
  if (overlapX && m.y === p.y + p.h) return "below"
  if (overlapX && m.y + m.h === p.y) return "above"
  return ""
}

// Physical position (px, py in mm) for each rect, walking shared edges from
// the top-left display so neighbours stay flush however dense each screen is.
function physicalLayout(rects) {
  var out = rects.map(function(r) { return Object.assign({}, r, { px: null, py: null }) })
  if (!out.length) return out
  var anchor = out.slice().sort(function(a, b) { return a.x - b.x || a.y - b.y })[0]
  anchor.px = 0
  anchor.py = 0
  var queue = [anchor]
  while (queue.length) {
    var p = queue.shift()
    for (var i = 0; i < out.length; i++) {
      var m = out[i]
      if (m.px !== null) continue
      var side = touching(p, m)
      if (!side) continue
      if (side === "right" || side === "left") {
        m.px = side === "right" ? p.px + p.pw : p.px - m.pw
        m.py = p.py + (m.y - p.y) * p.ph / p.h
      } else {
        m.py = side === "below" ? p.py + p.ph : p.py - m.ph
        m.px = p.px + (m.x - p.x) * p.pw / p.w
      }
      queue.push(m)
    }
  }
  // Displays with a gap to the rest: scale their offset by the anchor's density.
  for (var j = 0; j < out.length; j++) {
    if (out[j].px !== null) continue
    out[j].px = (out[j].x - anchor.x) * anchor.pw / anchor.w
    out[j].py = (out[j].y - anchor.y) * anchor.ph / anchor.h
  }
  return out
}

function bounds(rects) {
  if (!rects.length) return { x: 0, y: 0, w: 1, h: 1 }
  var x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity
  for (var i = 0; i < rects.length; i++) {
    var r = rects[i]
    x1 = Math.min(x1, r.px); y1 = Math.min(y1, r.py)
    x2 = Math.max(x2, r.px + r.pw); y2 = Math.max(y2, r.py + r.ph)
  }
  return { x: x1, y: y1, w: x2 - x1, h: y2 - y1 }
}

function overlaps(a, b) {
  var e = 0.01
  return a.px < b.px + b.pw - e && b.px < a.px + a.pw - e && a.py < b.py + b.ph - e && b.py < a.py + a.ph - e
}

// Pull v onto an aligned edge (start or end) when it lands within reach.
function align(v, start, end, reach) {
  if (Math.abs(v - start) <= reach) return start
  if (Math.abs(v - end) <= reach) return end
  return v
}

// Snap the dropped display m (physical px, py) flush against the nearest edge
// of another display without covering any, like Windows' display settings.
// Returns the physical spot plus the neighbour and side it attached to.
function snap(m, others) {
  var best = null
  for (var i = 0; i < others.length; i++) {
    var o = others[i]
    var y = align(clamp(m.py, o.py - m.ph * 0.9, o.py + o.ph - m.ph * 0.1), o.py, o.py + o.ph - m.ph, m.ph / 8)
    var x = align(clamp(m.px, o.px - m.pw * 0.9, o.px + o.pw - m.pw * 0.1), o.px, o.px + o.pw - m.pw, m.pw / 8)
    var candidates = [
      { side: "right", px: o.px + o.pw, py: y },
      { side: "left", px: o.px - m.pw, py: y },
      { side: "below", px: x, py: o.py + o.ph },
      { side: "above", px: x, py: o.py - m.ph }
    ]
    for (var j = 0; j < candidates.length; j++) {
      var c = candidates[j]
      var placed = { px: c.px, py: c.py, pw: m.pw, ph: m.ph }
      var blocked = false
      for (var k = 0; k < others.length; k++)
        if (overlaps(placed, others[k])) blocked = true
      if (blocked) continue
      var d = (c.px - m.px) * (c.px - m.px) + (c.py - m.py) * (c.py - m.py)
      if (!best || d < best.d) best = { px: c.px, py: c.py, side: c.side, neighbour: o, d: d }
    }
  }
  return best
}

// Hyprland position (logical x, y) for a display snapped onto neighbour n.
function toLogical(m, spot) {
  var n = spot.neighbour
  var x, y
  if (spot.side === "right" || spot.side === "left") {
    x = spot.side === "right" ? n.x + n.w : n.x - m.w
    if (Math.abs(spot.py - n.py) < 0.5) y = n.y
    else if (Math.abs(spot.py - (n.py + n.ph - m.ph)) < 0.5) y = n.y + n.h - m.h
    else y = clamp(Math.round(n.y + (spot.py - n.py) * n.h / n.ph), n.y - m.h + 1, n.y + n.h - 1)
  } else {
    y = spot.side === "below" ? n.y + n.h : n.y - m.h
    if (Math.abs(spot.px - n.px) < 0.5) x = n.x
    else if (Math.abs(spot.px - (n.px + n.pw - m.pw)) < 0.5) x = n.x + n.w - m.w
    else x = clamp(Math.round(n.x + (spot.px - n.px) * n.w / n.pw), n.x - m.w + 1, n.x + n.w - 1)
  }
  // shortcut: logical overlap with a third display is not checked, only the physical map is; fine for 2-4 screens.
  return { x: x, y: y }
}

if (typeof module !== "undefined") {
  module.exports = {
    rectOf: rectOf, physicalLayout: physicalLayout, bounds: bounds, snap: snap, toLogical: toLogical
  }
}
