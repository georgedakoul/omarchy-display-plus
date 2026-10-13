// node Layout.test.js
const assert = require("assert")
const L = require("./Layout.js")

const laptop = L.rectOf({ name: "eDP-1", x: 0, y: 0, width: 1920, height: 1080, scale: 1.25, transform: 0, physicalWidth: 310, physicalHeight: 170 })
const dell = L.rectOf({ name: "HDMI-A-2", x: 1536, y: 0, width: 1920, height: 1080, scale: 1.25, transform: 0, physicalWidth: 600, physicalHeight: 340 })
assert.deepStrictEqual([laptop.w, laptop.h, laptop.inches, dell.inches], [1536, 864, 14, 27])

const tv = L.rectOf({ name: "TV-1", x: 3072, y: 0, width: 1920, height: 1080, scale: 1, transform: 0, physicalWidth: 0, physicalHeight: 0, inches: 55 })
assert.strictEqual(tv.inches, 55)
const portraitTv = L.rectOf({ name: "TV-2", x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 1, inches: 55 })
assert.ok(portraitTv.ph > portraitTv.pw && portraitTv.h === 1920)

// Physical map: Dell sits flush right of the laptop, the TV flush right of the Dell.
const phys = L.physicalLayout([laptop, dell, tv])
const byName = Object.fromEntries(phys.map(r => [r.name, r]))
assert.strictEqual(byName["HDMI-A-2"].px, 310)
assert.strictEqual(byName["TV-1"].px, 910)
assert.strictEqual(byName["HDMI-A-2"].py, 0)

// Drag the TV under the Dell, roughly left-aligned: snaps below it, flush left.
// (Under the 14" laptop it would collide with the taller Dell.)
const moving = Object.assign({}, byName["TV-1"], { px: 330, py: 400 })
const spot = L.snap(moving, [byName["eDP-1"], byName["HDMI-A-2"]])
assert.strictEqual(spot.side, "below")
assert.deepStrictEqual(L.toLogical(byName["TV-1"], spot), { x: 1536, y: 864 })

// Never covers another display, and the result always touches its neighbour.
const s2 = L.snap(Object.assign({}, byName["TV-1"], { px: 320, py: 5 }), [byName["eDP-1"], byName["HDMI-A-2"]])
const overlapDell = s2.px < 910 && 310 < s2.px + moving.pw && s2.py < 340 && 0 < s2.py + moving.ph
assert.ok(!overlapDell)

// Bottom-aligned next to the Dell maps to bottom-aligned logical pixels.
const lap2 = Object.assign({}, byName["eDP-1"], { px: 920, py: 170 })
const s3 = L.snap(lap2, [byName["HDMI-A-2"]])
assert.strictEqual(s3.side, "right")
assert.deepStrictEqual(L.toLogical(laptop, s3), { x: 3072, y: 0 })

console.log("Layout ok")
