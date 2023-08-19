#!/bin/bash

# Function to validate input not empty
validate_input() {
    if [ -z "$1" ]; then
        echo "Error: Input cannot be empty."
        exit 1
    fi
}

# Function to prompt for and confirm passwords
prompt_password() {
    read -sp "Enter password for $1: " password1
    echo
    validate_input "$password1"

    read -sp "Confirm password for $1: " password2
    echo
    validate_input "$password2"

    if [ "$password1" != "$password2" ]; then
        echo "Error: Passwords do not match."
        exit 1
    fi

    eval "$2=$password1"
}

# Check internet connection
if ping -c 1 archlinux.org &> /dev/null; then
    echo "Internet connection established."
else
    echo "Error: Unable to establish internet connection."
    exit 1
fi

# Prompt for user input
read -p "Enter your desired username: " username
validate_input "$username"

read -sp "Enter password for $username: " user_password
echo
validate_input "$user_password"

read -sp "Enter root password: " root_password
echo
validate_input "$root_password"

read -p "Enter desired keyboard layout (e.g., us, pt-latin1): " keyboard_layout
validate_input "$keyboard_layout"

read -p "Enter language/location (e.g., en_US.UTF-8): " locale
validate_input "$locale"

read -p "Enter location for timezone (e.g., Australia/Adelaide): " timezone
validate_input "$timezone"

read -p "Enter the target drive (e.g., sda): " target_drive
validate_input "$target_drive"

# Load selected keyboard layout
loadkeys $keyboard_layout

# Update system clock
timedatectl set-ntp true

# Partitioning using fdisk
fdisk /dev/$target_drive << EOF
g # Create a new GPT partition table
n # Create a new partition
1 # Partition number
   # Default: First sector
+512M # Size
n # Create a new partition
2 # Partition number
   # Default: First sector
+8G # Size
n # Create a new partition
3 # Partition number
   # Default: First sector
   # Default: Last sector (remaining space)
w # Write changes
EOF

# Formatting
mkfs.fat -F 32 /dev/${target_drive}1
mkswap /dev/${target_drive}2
mkfs.ext4 /dev/${target_drive}3
mount /dev/${target_drive}3 /mnt
mkdir /mnt/boot/efi
mount /dev/${target_drive}1 /mnt/boot/efi
swapon /dev/${target_drive}2

# Install base system and extras
pacstrap /mnt base linux linux-firmware sof-firmware nano networkmanager grub efibootmgr base-devel git neovim

# Generate fstab
genfstab /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt

# Set time zone
timedatectl set-timezone $timezone
hwclock --systohc

# Uncomment desired locale using sed
sed -i "/$locale/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=$locale" >> /etc/locale.conf

# Set keyboard layout
echo "KEYMAP=$keyboard_layout" >> /etc/vconsole.conf

# Set hostname
echo "archmini" >> /etc/hostname

# Configure /etc/hosts
#echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\tarchx64.localdomain\tarchx64" >> /etc/hosts

# Enable NetworkManager
systemctl enable NetworkManager.service

# Configure GRUB bootloader
grub-install /dev/${target_drive}
grub-mkconfig -o /boot/grub/grub.cfg

# Set root password
echo "root:$root_password" | chpasswd

# Create new user and set password
useradd -m -G wheel $username
echo "$username:$user_password" | chpasswd

# Uncomment sudo access for users in visudo
sed -i '/%wheel ALL=(ALL) ALL/s/^# //' /etc/sudoer

# Exit chroot and reboot
exit && reboot

