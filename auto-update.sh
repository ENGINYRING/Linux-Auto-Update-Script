#!/bin/bash
#===============================================================================
# Script Name: auto-update.sh
# Description: Automatically updates Linux systems (Debian/Ubuntu, RedHat/CentOS/Fedora)
#              and handles situations requiring manual intervention by notifying
#              system administrators via email.
#
# Features:    - Cross-distribution compatibility (apt and yum/dnf)
#              - Safe updates (no package removal without approval)  
#              - Configuration preservation (always keeps existing config files)
#              - Non-interactive operation (handles all prompts automatically)
#              - Email notifications for issues requiring manual intervention
#              - Detailed logging
#
# Author:      ENGINYRING (https://github.com/ENGINYRING)
# Repository:  https://github.com/ENGINYRING/Linux-Auto-Update-Script
# License:     MIT
#
# Usage:       ./auto-update.sh
#
# Recommended: Set up as a cron job or systemd timer for regular execution
#              (see README.md for details)
#===============================================================================

# Configuration - Change these values
ADMIN_EMAIL="admin@example.com"
SMTP_SERVER="smtp.example.com"
SMTP_PORT="587"
SMTP_USER="notifications@example.com"
SMTP_PASS="your_password_here"
HOSTNAME=$(hostname)

# Log file
LOG_FILE="/var/log/auto-update.log"

# Function to send email
send_email() {
  local subject="$1"
  local body="$2"
  
  echo "Subject: $subject
From: System Update <$SMTP_USER>
To: Admin <$ADMIN_EMAIL>

$body" | curl --url "smtps://$SMTP_SERVER:$SMTP_PORT" \
              --ssl-reqd \
              --mail-from "$SMTP_USER" \
              --mail-rcpt "$ADMIN_EMAIL" \
              --user "$SMTP_USER:$SMTP_PASS" \
              --upload-file - \
              --silent \
              --show-error \
              --connect-timeout 30
  
  if [ $? -eq 0 ]; then
    echo "Email sent to $ADMIN_EMAIL" >> "$LOG_FILE"
  else
    echo "Failed to send email to $ADMIN_EMAIL" >> "$LOG_FILE"
  fi
}

# Function to log and potentially email errors
log_error() {
  local message="$1"
  local send_mail=${2:-true}
  
  echo "ERROR: $message" >> "$LOG_FILE"
  
  if [ "$send_mail" = true ]; then
    send_email "[$HOSTNAME] Error during system update" "An error occurred during the system update process on $HOSTNAME:\n\n$message\n\nPlease check /var/log/auto-update.log for details."
  fi
}

# Start log
echo "=== Auto-update script started at $(date) ===" >> "$LOG_FILE"

# Detect package manager
if command -v apt &> /dev/null; then
  PKG_MANAGER="apt"
  echo "Detected apt package manager" >> "$LOG_FILE"
elif command -v dnf &> /dev/null; then
  PKG_MANAGER="dnf"
  echo "Detected dnf package manager" >> "$LOG_FILE"
elif command -v yum &> /dev/null; then
  PKG_MANAGER="yum"
  echo "Detected yum package manager" >> "$LOG_FILE"
else
  log_error "No supported package manager found"
  exit 1
fi

# Update package lists
echo "Updating package lists with $PKG_MANAGER" >> "$LOG_FILE"

if [ "$PKG_MANAGER" = "apt" ]; then
  # Set environment variables to handle interactive prompts
  export DEBIAN_FRONTEND=noninteractive
  
  # Update with specific options to avoid interactive prompts
  apt update -y >> "$LOG_FILE" 2>&1
  UPDATE_RESULT=$?
  
  if [ $UPDATE_RESULT -ne 0 ]; then
    log_error "Failed to update package lists (exit code: $UPDATE_RESULT)"
    exit 1
  fi
  
  # Check for packages that would be removed or held back
  echo "Checking for packages that would be removed or held back" >> "$LOG_FILE"
  APT_UPGRADE_SIMULATION=$(apt upgrade --simulate 2>&1)
  PKGS_TO_REMOVE=$(echo "$APT_UPGRADE_SIMULATION" | grep "The following packages will be REMOVED")
  PKGS_KEPT_BACK=$(echo "$APT_UPGRADE_SIMULATION" | grep "The following packages have been kept back")
  
  # Also check if there are any packages that need manual intervention
  MANUAL_INTERVENTION=$(echo "$APT_UPGRADE_SIMULATION" | grep -E "You should explicitly select|The following packages require|Need to get .* of archives")
  
  if [ -n "$PKGS_TO_REMOVE" ] || [ -n "$MANUAL_INTERVENTION" ]; then
    echo "Packages would be removed or require manual intervention. Sending email." >> "$LOG_FILE"
    UPGRADE_DETAILS=$(echo "$APT_UPGRADE_SIMULATION" | grep -A 100 "The following packages")
    send_email "[$HOSTNAME] Manual intervention required for system update" "The system update on $HOSTNAME requires manual intervention because packages would be removed or require manual handling.\n\nDetails:\n$UPGRADE_DETAILS"
  elif [ -n "$PKGS_KEPT_BACK" ]; then
    # Some packages kept back - check if dist-upgrade would remove packages
    echo "Some packages kept back. Checking if dist-upgrade would remove packages." >> "$LOG_FILE"
    APT_DISTUPGRADE_SIMULATION=$(apt dist-upgrade --simulate 2>&1)
    DISTUPGRADE_REMOVE=$(echo "$APT_DISTUPGRADE_SIMULATION" | grep "The following packages will be REMOVED")
    
    if [ -n "$DISTUPGRADE_REMOVE" ]; then
      echo "dist-upgrade would remove packages. Sending email." >> "$LOG_FILE"
      send_email "[$HOSTNAME] Manual intervention required for system update" "The system update on $HOSTNAME has packages kept back, and using dist-upgrade would remove packages.\n\nKept back:\n$PKGS_KEPT_BACK\n\ndist-upgrade details:\n$APT_DISTUPGRADE_SIMULATION"
    else
      # No packages would be removed with dist-upgrade, so we can proceed to fully upgrade all packages
      echo "dist-upgrade would not remove packages. Proceeding with dist-upgrade." >> "$LOG_FILE"
      
      # Set options to always keep existing config files
      # --force-confold: always keep the old config files
      apt dist-upgrade -y -o Dpkg::Options::="--force-confold" >> "$LOG_FILE" 2>&1
      UPGRADE_RESULT=$?
      
      if [ $UPGRADE_RESULT -eq 0 ]; then
        echo "dist-upgrade completed successfully" >> "$LOG_FILE"
      else
        log_error "dist-upgrade failed with exit code $UPGRADE_RESULT"
      fi
    fi
  else
    echo "No packages would be removed. Proceeding with automatic upgrade." >> "$LOG_FILE"
    apt upgrade -y -o Dpkg::Options::="--force-confold" >> "$LOG_FILE" 2>&1
    UPGRADE_RESULT=$?
    
    if [ $UPGRADE_RESULT -eq 0 ]; then
      echo "Upgrade completed successfully" >> "$LOG_FILE"
    else
      log_error "Upgrade failed with exit code $UPGRADE_RESULT"
    fi
  fi

elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
  # Both yum and dnf have similar interfaces
  $PKG_MANAGER check-update >> "$LOG_FILE" 2>&1
  # yum/dnf check-update returns 100 when updates are available, 0 when no updates are available
  CHECK_UPDATE_RESULT=$?
  if [ $CHECK_UPDATE_RESULT -ne 0 ] && [ $CHECK_UPDATE_RESULT -ne 100 ]; then
    log_error "Failed to check for updates (exit code: $CHECK_UPDATE_RESULT)"
    exit 1
  fi
  
  # Check if there are any updates available
  if [ $CHECK_UPDATE_RESULT -eq 0 ]; then
    echo "No updates available" >> "$LOG_FILE"
    exit 0
  fi
  
  # Check for packages that would be removed
  echo "Checking for packages that would be removed" >> "$LOG_FILE"
  UPGRADE_SIMULATION=$($PKG_MANAGER upgrade --assumeno 2>&1)
  PKGS_TO_REMOVE=$(echo "$UPGRADE_SIMULATION" | grep -i "removing")
  
  # Also check for other conditions requiring manual intervention
  MANUAL_INTERVENTION=$(echo "$UPGRADE_SIMULATION" | grep -i -E "error:|warning:|conflict|failed|is needed by")
  
  if [ -n "$PKGS_TO_REMOVE" ] || [ -n "$MANUAL_INTERVENTION" ]; then
    echo "Packages would be removed or require manual intervention. Sending email." >> "$LOG_FILE"
    send_email "[$HOSTNAME] Manual intervention required for system update" "The system update on $HOSTNAME requires manual intervention because packages would be removed or there are conflicts.\n\nDetails:\n$UPGRADE_SIMULATION"
  else
    echo "No packages would be removed. Proceeding with automatic upgrade." >> "$LOG_FILE"
    $PKG_MANAGER upgrade -y >> "$LOG_FILE" 2>&1
    UPGRADE_RESULT=$?
    
    if [ $UPGRADE_RESULT -eq 0 ]; then
      echo "Upgrade completed successfully" >> "$LOG_FILE"
    else
      log_error "Upgrade failed with exit code $UPGRADE_RESULT"
    fi
  fi
fi

echo "=== Auto-update script completed at $(date) ===" >> "$LOG_FILE"
