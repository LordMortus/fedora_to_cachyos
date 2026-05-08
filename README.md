Attempted to install CachyOS kernel onto a Fedora 44 VM under Proxmox.

Using ClaudAI to help make adjustments and see where things went wrong
I/we found out it my Proxmox CPU isn't capable of running the non lts 
version of CachyOS

So here are a few scripts to set up CachyOS on Fedora 44 after a fresh
install, and set things up to use Sunshine with an Nvidia GPU

The script also checks for compatible cpu and installs the appropriate 
kernel.

One thing to note:
    At least for my setup, make sure the EFI disk in Proxmox does
    NOT have pregen keys
