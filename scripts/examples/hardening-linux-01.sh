#!/bin/bash

# Update the system
sudo apt update
sudo apt upgrade -y

# Install firewall (ufw)
sudo apt install ufw -y
sudo ufw enable

# Configure firewall rules
# Example: Allow SSH
sudo ufw allow 22

# Install Fail2Ban
sudo apt install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl restart fail2ban

# Configure SSH secure mode
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config_backup
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/#ClientAliveInterval 0/#ClientAliveInterval 120/' /etc/ssh/sshd_config
sudo sed -i 's/#MaxAuthTries 6/#MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sed -i 's/#LoginGraceTime 2m/#LoginGraceTime 20/' /etc/ssh/sshd_config

sudo systemctl restart ssh

# Install and configure rkhunter for monitoring system integrity
sudo apt install rkhunter -y
sudo rkhunter --update
sudo rkhunter --propupd

# Install and configure logwatch for logs resume
sudo apt install logwatch -y

# Configure system audit tool
sudo apt install auditd -y

# Congigure resource limits
echo -e "root hard core 0\n* hard core 0" | sudo tee -a /etc/security/limits.conf

# Install and configure AppArmor
sudo apt install apparmor -y
sudo aa-enforce /etc/apparmor.d/*

# Disable unused services
sudo systemctl disable bluetooth

# Install AIDE to control system integrity
sudo apt install aide -y
sudo aideinit
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Configure kernel security
# Example: Disable sysrq
echo "kernel.sysrq = 0" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Debug
echo "Security setup configuration completed."

# Reboot system to apply changes
sudo reboot
