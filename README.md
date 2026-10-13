# Omarchy Display+

A drop-in replacement for Omarchy's Display panel that adds a Windows-style screen map and Miracast casting to any smart TV.

Windows has had Win+K since 2013: pick a TV, and your screen is on it. Linux never got the same, because the pieces belong to different projects (the Wi-Fi driver, NetworkManager, the compositor, the encoder) and nobody joined them up for Hyprland. This plugin does, inside Omarchy's bar. Click the Display icon, pick your TV, press Mirror or Extend.

<img src="docs/panel.png" alt="The Display panel extending to a 50 inch TV: the map shows the TV above the 14 inch laptop screen, at their real sizes" width="380">

- **Screen map.** Every screen is drawn at its real size in inches. Drag one to move it, and it snaps to the edges of the others. Click a screen to select it, then rotate it from the buttons under the map.
- **Cast to TV.** Lists Miracast TVs nearby. Pick Mirror to show the screen you are on, or Extend to get a new screen on the map at the TV's size.
- Brightness, text size, scale and turning screens on or off work as in the stock panel.

## Install

```sh
git clone https://github.com/georgedakoul/omarchy-display-plus ~/.config/omarchy/plugins/ghostl9.monitor
```

1. In `~/.config/omarchy/shell.json`, replace `omarchy.monitor` with `ghostl9.monitor` in `bar.layout`.
2. Append to `~/.config/hypr/monitors.lua`:
   ```lua
   require("default.hypr.require_optional").module("hypr.displays")
   ```
3. Run `omarchy restart shell`.

## Needs

- Omarchy with Hyprland's Lua config.
- Casting: NetworkManager with a Wi-Fi card that supports Wi-Fi Direct (`iw list` shows `P2P-GO`), a GPU with VA-API H.264 encoding, `dnsmasq`, `ffmpeg` and `wf-recorder` (`sudo pacman -S wf-recorder`).

## How it works

- `tv-displays` keeps positions and rotation in `~/.config/omarchy/tv-displays.json` and writes them to `~/.config/hypr/displays.lua`.
- `cast` finds TVs through NetworkManager, connects over Wi-Fi Direct, runs the Miracast session itself and streams with `wf-recorder`, hardware-encoded through VA-API. It sends the stream exactly as the Wi-Fi Display spec asks (the H.264 level the TV can decode, the fixed MPEG-TS PIDs), because TVs tested only against Windows show a black screen for anything else.

## Tested on

| TV | Mirror | Extend |
|---|---|---|
| Samsung UE50TU7172 (2020, Tizen) | 1080p60 with sound | 1080p60 with sound |

Sender: Intel UHD 620 laptop on Omarchy. If your TV works or does not, open an issue with its model and the line `cast: TV offers ...` from the log below, so it can go in this table.

## Troubleshooting

- **No TVs listed.** Turn the TV on and open its Screen Mirroring source. Check that `nmcli device` shows a `wifi-p2p` device.
- **Cast failed.** The panel shows the reason. The full log is in `journalctl --user -u omarchy-cast`.
- **Black screen on the TV.** Open an issue with the `cast: TV offers ...` line from that log.

## Tests

```sh
node Layout.test.js   # Layout ok
python3 cast_test.py  # cast ok
```
