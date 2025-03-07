[![ENGINYRING](https://cdn.enginyring.com/img/logo_dark.png)](https://www.enginyring.com)

# Auto System Update Script

A robust BASH script that automates system updates on Linux servers while intelligently handling scenarios that require manual intervention.

**Author:** ENGINYRING ([@ENGINYRING](https://github.com/ENGINYRING))

## Features

- **Cross-distribution compatibility**: Works with both apt-based (Debian/Ubuntu) and yum/dnf-based (RHEL/CentOS/Fedora) systems
- **Intelligent update handling**: Automatically detects when updates are safe to apply
- **Configuration preservation**: Always preserves existing configuration files
- **Non-interactive operation**: Handles all prompts automatically for true unattended operation
- **Admin notifications**: Sends email alerts when manual intervention is required
- **Detailed logging**: Maintains comprehensive logs of all update activities
- **Safe operation**: Never removes packages without admin approval

## Requirements

- Bash shell
- sudo/root access
- `curl` for sending emails
- SMTP server access for notifications
- Compatible with:
  - Debian-based systems (Debian, Ubuntu, etc.)
  - RedHat-based systems (RHEL, CentOS, Fedora, etc.)

## Installation

1. **Download the script**:

```bash
curl -O https://raw.githubusercontent.com/ENGINYRING/Linux-Auto-Update-Script/main/auto-update.sh
```

2. **Make it executable**:

```bash
chmod +x auto-update.sh
```

3. **Move to system path**:

```bash
sudo mv auto-update.sh /usr/local/bin/auto-update.sh
```

4. **Edit the configuration**:

```bash
sudo nano /usr/local/bin/auto-update.sh
```

Update the email configuration variables at the top of the script:

```bash
ADMIN_EMAIL="admin@example.com"
SMTP_SERVER="smtp.example.com"
SMTP_PORT="587"
SMTP_USER="notifications@example.com"
SMTP_PASS="your_password_here"
```

## Setting Up Automated Runs

### Using Cron

1. **Edit the crontab**:

```bash
sudo crontab -e
```

2. **Add a schedule** (example: run at 3 AM daily):

```
0 3 * * * /usr/local/bin/auto-update.sh
```

### Using Systemd Timer

1. **Create a service file** (`/etc/systemd/system/auto-update.service`):

```
[Unit]
Description=Automatic System Update
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto-update.sh
User=root

[Install]
WantedBy=multi-user.target
```

2. **Create a timer file** (`/etc/systemd/system/auto-update.timer`):

```
[Unit]
Description=Run auto-update.service weekly

[Timer]
OnCalendar=Mon *-*-* 03:00:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
```

3. **Enable and start the timer**:

```bash
sudo systemctl enable auto-update.timer
sudo systemctl start auto-update.timer
```

## How It Works

### For Debian/Ubuntu Systems:

1. Sets `DEBIAN_FRONTEND=noninteractive` to prevent interactive prompts
2. Updates package lists with `apt update`
3. Simulates an upgrade with `apt upgrade --simulate` to check for:
   - Packages that would be removed
   - Packages held back
   - Other conditions requiring manual intervention
4. If packages would be removed → Sends email notification
5. If packages are held back → Checks if `dist-upgrade` would remove packages
   - If yes → Sends email notification
   - If no → Performs `dist-upgrade` with `--force-confold` to preserve configs
6. If no issues → Performs regular upgrade with `--force-confold`

### For RHEL/CentOS/Fedora Systems:

1. Checks for updates with `yum/dnf check-update`
2. Simulates an upgrade with `yum/dnf upgrade --assumeno` to check for:
   - Packages that would be removed
   - Conflicts or errors
3. If issues found → Sends email notification
4. If no issues → Performs upgrade

## Configuration Options

The script has several configurable parameters at the top:

| Parameter | Description |
|-----------|-------------|
| `ADMIN_EMAIL` | Email address for notifications |
| `SMTP_SERVER` | SMTP server for sending emails |
| `SMTP_PORT` | SMTP port (usually 25, 465, or 587) |
| `SMTP_USER` | Username for SMTP authentication |
| `SMTP_PASS` | Password for SMTP authentication |
| `LOG_FILE` | Path to the log file (default: `/var/log/auto-update.log`) |

## Log File

The script logs all activities to `/var/log/auto-update.log` (by default). Each run is clearly marked with timestamps and detailed information about the update process.

## Email Notifications

When manual intervention is required, an email is sent with:

- Server hostname
- Reason for manual intervention
- Details of packages that would be removed or other issues
- Timestamp

## Troubleshooting

### No Emails Being Sent

1. Check SMTP configuration
2. Verify network connectivity to SMTP server
3. Check if `curl` is installed
4. Review logs for SMTP errors

### Script Not Running from Cron

1. Check cron logs: `grep CRON /var/log/syslog`
2. Ensure script has proper permissions
3. Check for PATH issues in the cron environment

### Updates Not Being Applied

1. Check `/var/log/auto-update.log` for errors
2. Verify the script is detecting the correct package manager
3. Check if the user running the script has sufficient permissions

## Security Considerations

- The script contains SMTP credentials in plaintext
- For improved security:
  - Restrict file permissions: `chmod 700 /usr/local/bin/auto-update.sh`
  - Consider using an external credentials file with restricted permissions
  - Use environment variables instead of hardcoded credentials

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature-name`
5. Submit a pull request

---

© 2025 ENGINYRING. All rights reserved.
