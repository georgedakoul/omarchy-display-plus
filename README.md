# Omarchy Display+

A drop-in replacement for Omarchy's Display panel that adds a Windows-style screen map, TV screens over the internet, and Miracast casting.

- **Screen map.** Every screen is drawn at its real size in inches. Drag one to move it, and it snaps to the edges of the others. Click a screen to select it, then rotate it from the buttons under the map.
- **TV screens over the internet.** Add a TV screen and pair Moonlight on the TV with the address shown. The TV gets its own Sunshine stream over Tailscale. It appears on the map only once a device has paired.
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
3. Append to `~/.config/hypr/autostart.lua`:
   ```lua
   o.launch_on_start(os.getenv("HOME") .. "/.config/omarchy/plugins/ghostl9.monitor/tv-displays restore")
   ```
4. Run `omarchy restart shell`.

## Needs

- Omarchy with Hyprland's Lua config.
- TV screens: Sunshine (the panel's Install streaming button runs `omarchy-install-service-sunshine`), Tailscale, and Moonlight on the TV. Ports are opened on `tailscale0` only.
- Casting: NetworkManager with a Wi-Fi card that supports Wi-Fi Direct, `dnsmasq`, and `wf-recorder`.

## How it works

- `tv-displays` keeps positions, rotation and TV screens in `~/.config/omarchy/tv-displays.json` and writes them to `~/.config/hypr/displays.lua`.
- `cast` finds TVs through NetworkManager, connects over Wi-Fi Direct, runs the Miracast session itself and streams with `wf-recorder`.

Casting is new. Finding TVs works, but it has not yet been tried on many TV brands.

## Tests

```sh
node Layout.test.js   # Layout ok
python3 cast_test.py  # cast ok
```
