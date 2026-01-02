# bitwig_and_steamdeck
Scripts and documentation for working with Bitwig Studio on a Valve Steamdeck. These were successful using Bitwig Studio 5.3.13 installed from flatpak. Below is basic summaries of each document.

## how to update pipewire
In short, you'll need to update wireplumber on SteamOS so Bitwig will recognize audio i/o.

## how to reset password steamdeck
If you bought a steamdeck used or got it from a friend, there may be a password on it already, and you don't know it. Here's how to reset it. 

## Making Bitwig Connect Useful on A Steamdeck
If you want to use the Bitwig Connect interface, you'll need to use the included script, systemd, and udev rules files ("linux things for BItwig Connect Interface/") so the interface shows up with all its inputs and outputs. 

This process was extracted using a GPT AI, so it may not be ideal. I have gotten consistent results from this solution, so I'm good with it!

## how to Install Bitwig Connect Control Panel
Once you have the Connect interface working, you'll probably want to use the Control Panel to configure it. This doc details how to install it.

## Appendix
I'm appending some additional findings as I've used this system a lot. 

### Lost input 1
At some point, input 1 decided to not show up in Bitwig. Meters on the Connect showed audio activity, but no audio came through Bitwig when I selected input 1 as a source. Troubleshooting with ChatGPT help, I found that PipeWire was not to blame, as it wasn't even showing up in ALSA. A quick test to monitor all audio input in the terminal with `arecord -D hw:2,0 -f S24_3LE -r 48000 -c 6 -V mono /dev/null` showed activity if audio came into ins 2,3,4, but not input 1. This was fixed by forcing USB audio re-enumeration - i.e. unplugging the USB cable, and replugging the cable. To troubleshoot, I did the following:

Stop PipeWire:
```
systemctl --user stop pipewire pipewire-pulse wireplumber
```

Then unplug the Bitwig Connect from USB, wait 10 seconds, then reconnect it to a different USB port (if possible).
Then re-test ALSA by monitoring audio, before restarting PipeWire:
```
arecord -D hw:2,0 -f S24_3LE -r 48000 -c 6 -V mono /dev/null
```
If channel 1 comes back, this indicates a bad enumeration state.

If this turns out to be a regular issue, I'll explore adding some lines to the udev script that initializes the Connect to de-authorize and re-authorize the USB device once at login, which is essentially the same as un/plugging.

