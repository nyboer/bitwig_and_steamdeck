# run the command `passwd` to create a password in steamdeck konsole
First things first - setup your SteamOS desktop user with a password
```
passwd
```
# update to wireplumber 0.5.10
Now you can update wireplumber so Bitwig can access audio devices.

```
sudo steamos-readonly disable
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -U https://archive.archlinux.org/packages/l/libwireplumber/libwireplumber-0.5.10-1-x86_64.pkg.tar.zst https://archive.archlinux.org/packages/w/wireplumber/wireplumber-0.5.10-1-x86_64.pkg.tar.zst && systemctl --user restart wireplumber
sudo steamos-readonly enable
```
