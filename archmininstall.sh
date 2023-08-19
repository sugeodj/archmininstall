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

prompt_password "$username" user_password
echo
validate_input "$user_password"

prompt_password "root" root_password
echo
validate_input "$root_password"

# Set default values for hostname, keyboard layout, locale, and timezone
default_hostname="archlinux"
default_keyboard_layout="us"
default_locale="en_US.UTF-8"

# Prompt for hostname
read -p "Enter your desired hostname [$default_hostname]: " hostname
hostname="${hostname:-$default_hostname}"
validate_input "$hostname"

# Prompt for keyboard layout
read -p "Enter desired keyboard layout (e.g., us, pt-latin1) [$default_keyboard_layout]: " keyboard_layout
keyboard_layout="${keyboard_layout:-$default_keyboard_layout}"
validate_input "$keyboard_layout"

# Prompt for locale
read -p "Enter language/location (e.g., en_US.UTF-8) [$default_locale]: " locale
locale="${locale:-$default_locale}"
validate_input "$locale"

read -p "Enter the target drive (e.g., sda): " target_drive
validate_input "$target_drive"

# Update keys for install to prevent errors
echo "Updating keys for install..."
if pacman -Syy --noconfirm && pacman-key --init && pacman-key --populate && pacman -S archlinux-keyring --noconfirm; then
    print_success "Keys updated successfully."
else
    print_error "Failed to update keys."
    exit 1
fi

# Load selected keyboard layout
echo "Step 1: Loading selected keyboard layout..."
if loadkeys $keyboard_layout; then
    print_success "Keyboard layout loaded successfully."
else
    print_error "Failed to load keyboard layout."
    exit 1
fi

# Update system clock
echo "Step 2: Updating system clock..."
if timedatectl set-ntp true; then
    print_success "System clock updated successfully."
else
    print_error "Failed to update system clock."
    exit 1
fi

# Partitioning using fdisk
echo "Step 3: Partitioning disk..."
if fdisk /dev/$target_drive << EOF
g # Create a new GPT partition table
n # Create a new partition
1 # Partition number
   # Default: First sector
+512M # Size
n # Create a new partition
2 # Partition number
   # Default: First sector
+4G # Size
n # Create a new partition
3 # Partition number
   # Default: First sector
   # Default: Last sector (remaining space)
w # Write changes
EOF
then
    print_success "Disk partitioned successfully."
else
    print_error "Failed to partition disk."
    exit 1
fi

# Formatting
echo "Step 4: Formatting partitions..."
if mkfs.fat -F 32 /dev/${target_drive}1 && mkswap /dev/${target_drive}2 && mkfs.ext4 /dev/${target_drive}3 && mount /dev/${target_drive}3 /mnt && mkdir -p /mnt/boot/efi && mount /dev/${target_drive}1 /mnt/boot/efi && swapon /dev/${target_drive}2 -f; then
    print_success "Partitions formatted and mounted successfully."
else
    print_error "Failed to format partitions."
    exit 1
fi

# Install base system and extras
echo "Step 5: Installing base system and extras... (may take from 5-15 minutes depending on network speeds)"
if pacstrap /mnt base linux linux-firmware sof-firmware nano networkmanager grub efibootmgr base-devel git neovim --noconfirm; then
    print_success "Base system and extras installed successfully."
else
    print_error "Failed to install base system and extras."
    exit 1
fi

# Generate fstab
echo "Step 6: Generating fstab..."
if genfstab /mnt >> /mnt/etc/fstab; then
    print_success "fstab generated successfully."
else
    print_error "Failed to generate fstab."
    exit 1
fi

echo "Step 7: Entering chroot environment..."
# Chroot into the new system and execute commands inside chroot environment
if arch-chroot /mnt /bin/bash -c "
    echo 'Step 8: Setting time zone and generating locale...';
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
"; then
    print_success "Chroot environment set up successfully."
else
    print_error "Failed to set up chroot environment."
    exit 1
fi

# Exit chroot
print_success "Installation complete! Exiting chroot, umounting drives, and rebooting..."
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
exit && umount -a && reboot

