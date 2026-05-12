This is a Work In Progress!!!
Things may break here and there..
As I find them myself, I will work to fix them.

Attempted to install CachyOS kernel onto a Fedora 44 VM under Proxmox.

Using ClaudAI to help make adjustments and see where things went wrong
I/we found out my Proxmox CPU isn't capable of running the non lts 
version of CachyOS

So here are a few scripts to set up CachyOS on Fedora 44 after a fresh
install, and set things up to use Sunshine with an Nvidia GPU

Make sure the EFI disk in Proxmox does NOT have pregen keys

These scripts assume you are using KDE Plasma - Wayland

Sunshine is installed as a service and does not need to be added to
the autostart list, although you will need to add Steam to it.

The script also checks for compatible cpu and installs the appropriate 
kernel.

Added to script3 and master: Power management settings
You should no longer get 503 errors.
So only only need the seperate script if something else happens.
    Let me know if you encounter any errors
