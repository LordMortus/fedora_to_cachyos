#!/bin/sh
#MAC Address for VM to keep IP
#BC:24:11:C2:59:9C

#DO NOT SWITCH KERNELS UNTIL MENTIONED
#Stay on default kernel

#Add video card in Proxmox after initial install first

sudo dnf upgrade --refresh -y
sudo dnf upgrade -y

#RPM Fusion commands can be found searching "eneable rpm repositories"
sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm -y
sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
sudo dnf install copr-frontend-fedora.noarch -y
sudo dnf instal copr -y

# sudo setsebool -P domain_kernel_load_modules on

sudo dnf copr enable bieszczaders/kernel-cachyos -y
sudo dnf copr enable bieszczaders/kernel-cachyos-addons -y

sudo dnf install kernel-cachyos kernel-cachyos-devel-matched -y
sudo dnf in cachyos-settings scx-manager scx-scheds-git scx-tools-git --allowerasing -y
sudo dnf upgrade --refresh -y
sudo dnf upgrade -y

# dnf search kernel-cachyos
# sudo dnf install <modules>

sudo grub2-mkconfig -o /boot/grub2/grub.cfg -y

sudo dnf install kernel-devel kernel-headers gcc make dkms acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig libxcb egl-wayland -y

#Downlaod Nvidia drivers (.run)
#Make executable
#run as su
#Select NO to xconfig utility

#REBOOT NOW
reboot
