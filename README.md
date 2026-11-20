# eKVM

Switch your monitor's input from the Omarchy bar, so its built-in KVM moves
your keyboard and mouse to the other computer. No monitor buttons needed.

It talks to the monitor over DDC/CI with `ddcutil` (VCP `0x60`, input source).
Tested with a Lenovo ThinkVision P40wd-40.

Left-click the bar icon to pick an input. Right-click switches to the next one.

## Requirements

- `ddcutil` (`sudo pacman -S ddcutil`)
- Access to `/dev/i2c-*`: add yourself to the `i2c` group and load `i2c-dev`.
- Install the plugin on every computer connected to the monitor, so you can
  switch back from whichever one is on screen.

## Settings

Set these on the widget's entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.douglas.omarchy-ekvm",
  "model": "P40WD-40",
  "inputs": [
    { "label": "Laptop", "value": "0x11" },
    { "label": "Desktop", "value": "0x31" }
  ]
}
```

`model` matches the name from `ddcutil detect`. Find your input values with
`ddcutil --model <model> capabilities` (look under `Feature: 60`). On the
P40wd-40, `0x11` is HDMI, `0x0f` is DisplayPort, and `0x31` is Thunderbolt.

## Install

```bash
omarchy plugin add https://github.com/douglas/omarchy-ekvm.git --enable
```

## Development

```bash
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I "$OMARCHY_PATH/shell" Widget.qml
```
