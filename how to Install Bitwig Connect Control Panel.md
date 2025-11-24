# Installing `bitwig-control-panel` AUR Package on Steam Deck

This guide explains how to install the `bitwig-control-panel` AUR package on a Steam Deck in Desktop mode.

---

## 1. Switch to Desktop Mode
1. Press the **Steam** button → *Power* → *Switch to Desktop*.  
2. Open a terminal (e.g., Konsole).

---

## 2. Disable Read-Only Mode
SteamOS is read-only by default. Run:

```bash
sudo steamos-readonly disable
```

## 3. Initialize the Keyring (if not already)

```
sudo pacman-key --init
sudo pacman-key --populate archlinux holo
```

## 4. Install Build Tools

Install necessary development tools:
```
sudo pacman -S --needed base-devel git
```

## 5. Install an AUR Helper (yay)
```
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si
```
After installation, clean up:
```
cd ..
rm -rf yay-bin
```

## 6. Install the bitwig-control-panel Package
Use yay to build and install the package:
```
yay -S bitwig-control-panel
```

##7. Re-Enable Read-Only Mode (Optional)

After installation, you can make the system read-only again:
```
sudo steamos-readonly enable
```
