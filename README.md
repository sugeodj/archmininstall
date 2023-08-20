# Arch Minimal Install Script

This script automates the process of manually installing and setting up a minimal Arch Linux installation. It only installs the base system and required packages, without any desktop environment or additional software.

## Background

I wrote this script because the `archinstall` command baked into the Arch Linux ISO didn't work on all three machines I tested it on (my main desktop, a laptop, and a second laptop). However, manually configuring and installing Arch Linux worked on all three. This script is intended to simplify the installation process for a minimal Arch Linux system.

## Requirements

- An internet connection (either Ethernet or Wi-Fi)
- A live USB with the Arch Linux ISO

## Wi-Fi Setup

If you're using Wi-Fi, you need to connect to your network before running the script. Here are the steps:

1. Open a terminal and run `iwctl`.
   
3. Run `device list` to list your network devices.
   
5. Run `station {device} scan` to scan for available networks (replace `{device}` with the name of your Wi-Fi device).
   
7. Run `station {device} connect {SSID}` to connect to your network (replace `{device}` with the name of your Wi-Fi device and `{SSID}` with your network name).
   
9. Run `quit` to exit `iwctl`.

## Installation Steps

1. Boot from the live USB with the Arch Linux ISO.
   
3. Open a terminal and run `pacman -Syy` to update the package database.
   
5. Run `pacman-key --init` to initialize the keyring.
   
7. Run `pacman-key --populate` to populate the keyring.
   
9. Run `pacman -S archlinux-keyring` to install the Arch Linux keyring.
    
11. Run `pacman -Sy git` to install Git.
    
13. Run `git clone https://github.com/sugeodj/archmininstall` to clone the script repository.
    
15. Run `cd archmininstall` to change to the script directory.
    
17. Run `chmod a+x archmininstall.sh` to make the script executable.
    
19. Run `./archmininstall.sh` to start the installation process.
    
21. Follow the prompts to configure your system.

- Note: I configured the script to install `neovim` as the base editor instead of `nano`, `nano` is not installed.

## Disclaimer

GitHub Copilot: Certainly! Here's a revised disclaimer section that's less hostile:

## Contributing

GitHub Copilot: Certainly! Here's a possible section on contributing to your Arch Minimal Install Script:

## Contributing

If you'd like to contribute to this script, feel free to fork the repository and submit a pull request with your changes. Before making any changes, please review the code and make sure that your changes align with the goals of the script (i.e., automating the process of manually installing and setting up a minimal Arch Linux installation).

When submitting a pull request, please provide a clear description of your changes and any relevant information about why you made them. I'll review your changes as soon as possible and provide feedback if necessary.

Please note that this script is provided as-is, without any warranty or guarantee of support. While I'm happy to review and merge pull requests, I cannot guarantee that I will be able to provide support for any issues that arise from using this script. Use it at your own risk and make sure to review the code before running it on your system.

## Disclaimer

This script is provided as-is, without any warranty or guarantee of support. While I have tested it on multiple machines, there may be bugs or issues that I haven't encountered. If you encounter any problems while using this script, feel free to reach out to me for assistance. However, I cannot guarantee that I will be able to provide a solution or fix any issues. Use this script at your own risk and make sure to review the code before running it on your system.
