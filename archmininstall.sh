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

# Function to prompt for drive type
function get_drive_type() {
  while true; do
    read -p "Enter the type of system you are on (e.g UEFI or BIOS): " drive_type
    case $drive_type in
      UEFI|BIOS)
        echo "Drive type is $drive_type"
        break
        ;;
      *)
        echo "Invalid input. Please enter either UEFI or BIOS."
        ;;
    esac
  done
}

# Function to print error messages in red
print_error() {
    echo -e "\033[31mError: $1\033[0m"
}

# Function to print success messages in green with two greater than symbols
print_success() {
    echo -e "\033[32m>> Step $1: $2\033[0m"
}

# Check internet connection
print_success 1 "Checking internet connection..."
if ping -c 1 archlinux.org &> /dev/null; then
    print_success 2 "Internet connection established."
else
    print_error "Unable to establish internet connection."
    exit 1
fi

# Prompt for user input
read -p "Enter your desired username: " username
validate_input "$username"
echo 

prompt_password "$username" user_password
echo


prompt_password "root" root_password
echo

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
read -p "Enter language/location (e.g., en_US.UTF-8)[$default_locale]: " locale
locale="${locale:-$default_locale}"
validate_input "$locale"

# Prompt for drive
read -p "Enter the target drive (e.g., sda): " target_drive
validate_input "$target_drive"

# Prompt for drive type
get_drive_type

# Update keys for install to prevent errors
print_success 3 "Updating keys for install..."
if pacman -Syy --noconfirm && pacman-key --init && pacman-key --populate && pacman -S archlinux-keyring --noconfirm; then
    print_success 4 "Keys updated successfully."
else
    print_error "Failed to update keys."
    exit 1
fi

# Load selected keyboard layout
print_success 5 "Loading selected keyboard layout..."
if loadkeys $keyboard_layout; then
    print_success 6 "Keyboard layout loaded successfully."
else
    print_error "Failed to load keyboard layout."
    exit 1
fi

# Update system clock
print_success 7 "Updating system clock..."
if timedatectl set-ntp true; then
    print_success 8 "System clock updated successfully."
else
    print_error "Failed to update system clock."
    exit 1
fi


# Partitioning and format using fdisk
print_success 9 "Partitioning disk and formatting partitions..."
if [ "$drive_type" = "BIOS" ]; then
  if echo -e "o\nn\n \n \n \n+512M\nn\nn\n \n \n \n+8G\nn\nn\n \n \n \n \nw\n" | fdisk /dev/$target_drive; then
    print_success 10 "Disk partitioned successfully."
  else
    print_error "Failed to partition disk."
    exit 1
  fi
elif [ "$drive_type" = "UEFI" ]; then
  if echo -e "g\nn\n \n \n+512M\nn\nn\n \n \n+8G\nn\nn\n \n \n \nw\n" | fdisk /dev/$target_drive; then
    print_success 10 "Disk partitioned successfully."
  else
    print_error "Failed to partition disk."
    exit 1
  fi
else
  print_error "Invalid drive type. Please enter either UEFI or BIOS."
  exit 1
fi

# Formatting drive
mkfs.fat -F 32 /dev/${target_drive}1
mkfs.ext4 /dev/${target_drive}3
mkswap /dev/${target_drive}2


sleep 5

# Mount the drives
print_success 11 "Mounting drives..."
if mount /dev/${target_drive}3 /mnt; then
  print_success 12 "Root partition mounted successfully."
else
  print_error "Failed to mount root partition."
  exit 1
fi

if mkdir -p /mnt/boot/efi && mount /dev/${target_drive}1 /mnt/boot/efi; then
  print_success 13 "EFI partition mounted successfully."
else
  print_error "Failed to mount EFI partition."
  exit 1
fi

if swapon /dev/${target_drive}2; then
  print_success 14 "Swap partition activated successfully."
else
  print_error "Failed to activate swap partition."
  exit 1
fi

# Install base system and extras
print_success 15 "Installing base system and extras... (may take from 5-15 minutes depending on network speeds)"
if pacstrap /mnt base linux linux-firmware sof-firmware nano networkmanager grub efibootmgr base-devel git neovim --noconfirm; then
    print_success 16 "Base system and extras installed successfully."
else
    print_error "Failed to install base system and extras."
    exit 1
fi

# Generate fstab
print_success 17 "Generating fstab..."
if genfstab /mnt >> /mnt/etc/fstab; then
    print_success 18 "fstab generated successfully."
else
    print_error "Failed to generate fstab."
    exit 1
fi

print_success 19 "Entering chroot environment..."
# Chroot into the new system and execute commands inside chroot environment
if arch-chroot /mnt /bin/bash -c "
    echo 'Step 20: Setting time zone and generating locale...';
    hwclock --systohc;
    sed -i '/$locale/s/^#//' /etc/locale.gen;
    locale-gen;
    echo 'Step 21: Setting keyboard layout..';
    echo 'LANG=$locale' >> /etc/locale.conf;
    echo 'KEYMAP=$keyboard_layout' >> /etc/vconsole.conf;
    echo 'Step 22: Setting hostname...';
    echo $hostname >> /etc/hostname;
    echo 'Step 23: Setting up grub boot loader...';
    grub-install /dev/${target_drive};
    grub-mkconfig -o /boot/grub/grub.cfg;
    echo 'Step 24: Setting root password...';
    echo 'root:$root_password' | chpasswd;
    echo 'Step 25: Adding user and setting password...';
    useradd -m -G wheel $username;
    echo '$username:$user_password' | chpasswd;
    echo 'Step 26: Allowing superusers to use sudo...';
    sed -i 's|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' /etc/sudoers;
    exit
"; then
    print_success 27 "Chroot environment set up successfully."
else
    print_error "Failed to set up chroot environment."
    exit 1
fi

# Exit chroot
print_success 28 "Installation complete! Exiting chroot, umounting drives, and rebooting..."

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
umount -a
reboot
