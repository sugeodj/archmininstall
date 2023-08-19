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
    while true; do
        read -sp "Enter password for $1: " password1
        echo
        validate_input "$password1"

        read -sp "Confirm password for $1: " password2
        echo
        validate_input "$password2"

        if [ "$password1" != "$password2" ]; then
            echo "Error: Passwords do not match. Please try again."
        else
            eval "$2=$password1"
            break
        fi
    done
}

# Function to print error messages in red
print_error() {
    echo -e "\033[31mError: $1\033[0m"
}

# Function to print success messages in green
print_success() {
    echo -e "\033[32mSuccess: $1\033[0m"
}

# Check internet connection
echo "Checking internet connection..."
if ping -c 1 archlinux.org &> /dev/null; then
    print_success "Internet connection established."
else
    print_error "Unable to establish internet connection."
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

read -p "Enter your desired hostname: " hostname
validate_input "$hostname"

read -p "Enter desired keyboard layout (e.g., us, pt-latin1): " keyboard_layout
validate_input "$keyboard_layout"

read -p "Enter language/location (e.g., en_US.UTF-8): " locale
validate_input "$locale"

read -p "Enter location for timezone (e.g., Australia/Adelaide): " timezone
validate_input "$timezone"

read -p "Enter the target drive (e.g., sda): " target_drive
validate_input "$target_drive"

# Update keys for install to prevent errors
echo "Updating keys for install"
pacman -Syy --noconfirm
pacman-key --init
pacman-key --populate
pacman -S archlinux-keyring --noconfirm

# Load selected keyboard layout
echo "Step 1: Loading selected keyboard layout..."
loadkeys $keyboard_layout
echo "Keyboard layout loaded."

# Update system clock
echo "Step 2: Updating system clock..."
timedatectl set-ntp true
echo "System clock updated."

# Partitioning using fdisk
echo "Step 3: Partitioning disk..."
echo -e "g\nn\n1\n\n+512M\nt\n1\nn\n2\n\n+8G\nt\n2\nn\n3\n\n\nw" | fdisk /dev/$target_drive <<< "y"

# Formatting
echo "Step 4: Formatting partitions..."
mkfs.fat -F 32 /dev/${target_drive}1
mkswap /dev/${target_drive}2
mkfs.ext4 /dev/${target_drive}3
mount /dev/${target_drive}3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/${target_drive}1 /mnt/boot/efi
swapon /dev/${target_drive}2

# Install base system and extras
echo "Step 5: Installing base system and extras... (may take from 5-15 minutes depending on network speeds)"
pacstrap /mnt base linux linux-firmware sof-firmware nano networkmanager grub efibootmgr base-devel git neovim --noconfirm
echo "Base system installed succesfully!"

# Generate fstab
echo "Step 6: Generating fstab..."
genfstab /mnt >> /mnt/etc/fstab

echo "Step 7: Entering chroot environment..."
# Chroot into the new system and execute commands inside chroot environment
arch-chroot /mnt /bin/bash -c "
    echo 'Step 8: Setting time zone and generating locale...';
    timedatectl set-timezone $timezone;
    hwclock --systohc;
    sed -i '/$locale/s/^#//' /etc/locale.gen;
    locale-gen;
    echo 'Step 9: Setting keyboard layout..';
    echo 'LANG=$locale' >> /etc/locale.conf;
    echo 'KEYMAP=$keyboard_layout' >> /etc/vconsole.conf;
    echo 'Step 10: Setting hostname...';
    echo $hostname >> /etc/hostname;
    echo 'Step 11: Setting up grub boot loader...';
    grub-install /dev/${target_drive};
    grub-mkconfig -o /boot/grub/grub.cfg;
    echo 'Step 12: Setting root password...';
    echo 'root:$root_password' | chpasswd;
    echo 'Step 13: Adding user and setting password...';
    useradd -m -G wheel $username;
    echo '$username:$user_password' | chpasswd;
    echo 'Step 14: Allowing superusers to use sudo...';
    sed -i '/%wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers
"

# Exit chroot
echo "Installation complete! Exiting chroot environment..."
exit

# Unmount drives
echo "Unmounting partitions..."
umount -a 

# Rebooting system
echo "Rebooting the system in..."
echo "5"
sleep 1
echo "4"
sleep 1
echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1
echo "Enjoy arch linux!"
