#Reset your password

If for some reason you don't know your password for the desktop user, you'll need to reset.
Below are the steps on how to reset a forgotten sudo password.
You will need a keyboard attached to the Steam Deck to enter the commands easily.

While the Steam Deck is powered off, hold the 3dots (QAM) and turn on the Steam Deck.

The recovery menu will appear. On your keyboard highlight the 3rd option - CURRENT (OS Boot Menu) then press enter.

The GRUB menu will appear. Highlight the 1st option - SteamOS then on your keyboard press "e" to edit the boot options.

Press down cursor on the keyboard until steamenv_boot is highlighted. Press "end" to go to the end of the line.

Enter the command - systemd.debug_shell

Press CTRL-X to boot!

Once SteamOS loads, press CTL-ALT-F9 on the keyboard to access the root debug shell.

Enter the command - passwd deck

Enter new password and retype the new password.

Once done, press CTL-ALT-F1 on the keyboard to go back to game mode.
