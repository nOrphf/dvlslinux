#!/bin/bash
###################################
# Prerequisites

# Update the list of packages
apt-get update

# Install pre-requisite packages.
apt-get install -y wget

# Download the PowerShell package file
wget https://github.com/PowerShell/PowerShell/releases/download/v7.5.4/powershell_7.5.4-1.deb_amd64.deb
wget http://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu74_74.2-1ubuntu3.1_amd64.deb

###################################
# Install the PowerShell package
dpkg -i libicu74_74.2-1ubuntu3.1_amd64.deb
dpkg -i powershell_7.5.4-1.deb_amd64.deb

# Resolve missing dependencies and finish the install (if necessary)
apt-get install -f

# Delete the downloaded package file
rm libicu74_74.2-1ubuntu3.1_amd64.deb
rm powershell_7.5.4-1.deb_amd64.deb

# Start PowerShell
pwsh