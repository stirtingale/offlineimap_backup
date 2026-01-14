# Email Backup Script

A self-contained Bash script for backing up multiple IMAP email accounts to local Mbox format using `offlineimap`. Everything is stored locally in the script directory, making it easy to manage and automate.

## Features

- **Multi-account support**. Back up multiple email accounts with a single script.
- **Self-contained**. All configuration and data stored in the script directory. No reliance on global config directories.
- **Single account sync**. Backup individual accounts on demand, perfect for cron scheduling.
- **Simple CLI**. Easy-to-use commands for setup, sync, listing, and archiving.
- **Cron-friendly**. Automatically disables colors in logs and supports background execution.
- **Secure password storage**. Passwords stored in individual files with restricted permissions (600).

## Requirements

- `bash` (4.0+)
- `offlineimap3` or `offlineimap`
- IMAP-enabled email account

## Installation

1. Download the script to your desired directory:

```bash
cd /home/backupserver/backup/email
wget https://example.com/offlineimap_backup.sh
# or copy manually
cp offlineimap_backup.sh .
chmod +x offlineimap_backup.sh
```

2. Install offlineimap:

```bash
pip install offlineimap3
# or on Debian/Ubuntu:
apt install offlineimap
```

3. Initialize the directory structure:

```bash
./offlineimap_backup.sh init
```

## Quick Start

### Add your first account

```bash
./offlineimap_backup.sh setup
```

Follow the interactive prompts:

- Account name (e.g., `emailaccountexample`)
- IMAP server (e.g., `exchange2019.livemail.co.uk`)
- Email address
- Password (typed but not shown)

### Backup that account

```bash
./offlineimap_backup.sh sync emailaccountexample
```

Or backup all accounts:

```bash
./offlineimap_backup.sh sync
```

### Check what's backed up

```bash
./offlineimap_backup.sh list
./offlineimap_backup.sh usage
```

## Commands

### `setup`

Interactively add a new email account.

```bash
./offlineimap_backup.sh setup
```

### `sync` or `sync [account]`

Backup all accounts or a specific account.

```bash
./offlineimap_backup.sh sync              # All accounts
./offlineimap_backup.sh sync emailaccountexample   # Just emailaccountexample
```

### `list`

Show all configured accounts and their backup sizes.

```bash
./offlineimap_backup.sh list
```

### `usage`

Display disk usage of all backups.

```bash
./offlineimap_backup.sh usage
```

### `archive`

Create a compressed tar.gz archive of all backups.

```bash
./offlineimap_backup.sh archive
```

### `init`

Initialize the directory structure (run once).

```bash
./offlineimap_backup.sh init
```

## Directory Structure

```
/home/backupserver/backup/email/
├── offlineimap_backup.sh          # This script
├── accounts/
│   ├── accounts.conf              # List of email accounts
│   ├── passwords/
│   │   ├── emailaccountexample.pass     # Password for emailaccountexample
│   │   ├── gmail.pass             # Password for gmail
│   │   └── ...
│   └── offlineimaprc              # Auto-generated offlineimap config
├── data/
│   ├── emailaccountexample/             # Mbox backup for emailaccountexample
│   │   ├── INBOX
│   │   ├── Sent
│   │   └── ...
│   ├── gmail/                      # Mbox backup for gmail
│   └── ...
├── logs/
│   ├── backup_2025-01-14_10-30-45.log
│   ├── backup_2025-01-14_14-15-22.log
│   └── ...
├── mail_backup_2025-01-14_10-30-45.tar.gz  # Optional archives
└── README.md
```

## Configuration

### accounts.conf

The `accounts/accounts.conf` file defines all your email accounts in pipe-delimited format:

```
account_name|imap_server|email_address|password_file|local_folder
```

Example:

```
emailaccountexample|exchange2019.livemail.co.uk|sophie@emailaccountexample.com|passwords/emailaccountexample.pass|emailaccountexample
gmail|imap.gmail.com|you@gmail.com|passwords/gmail.pass|gmail
work|mail.company.com|user@company.com|passwords/work.pass|work
```

Lines starting with `#` are comments and are ignored.

### Passwords

Passwords are stored in individual files under `accounts/passwords/`. Each file:

- Has restricted permissions (600, readable only by you)
- Contains a single line with the IMAP password
- Is automatically created by the `setup` command

Never commit these files to version control.

## Usage Examples

### First-time setup

```bash
./offlineimap_backup.sh init
./offlineimap_backup.sh setup
./offlineimap_backup.sh sync
```

### Add multiple accounts

```bash
./offlineimap_backup.sh setup   # Add gmail
./offlineimap_backup.sh setup   # Add work email
./offlineimap_backup.sh setup   # Add personal email
```

### Backup all accounts

```bash
./offlineimap_backup.sh sync
```

### Backup one account

```bash
./offlineimap_backup.sh sync emailaccountexample
```

### See all accounts and sizes

```bash
./offlineimap_backup.sh list
```

### Create an archive before transferring

```bash
./offlineimap_backup.sh sync
./offlineimap_backup.sh archive
ls -lh *.tar.gz
```

## Cron Jobs

The script is designed to work perfectly with cron. Colors are automatically disabled and all output is logged to files.

### Daily backup at 2 AM

Edit your crontab:

```bash
crontab -e
```

Add this line:

```bash
0 2 * * * cd /home/backupserver/backup/email && ./offlineimap_backup.sh sync >> logs/cron.log 2>&1
```

### Multiple daily backups

```bash
# 2 AM - backup all accounts
0 2 * * * cd /home/backupserver/backup/email && ./offlineimap_backup.sh sync >> logs/cron.log 2>&1

# 2 PM - backup emailaccountexample only
0 14 * * * cd /home/backupserver/backup/email && ./offlineimap_backup.sh sync emailaccountexample >> logs/cron.log 2>&1

# Weekly archive on Sunday at 3 AM
0 3 * * 0 cd /home/backupserver/backup/email && ./offlineimap_backup.sh archive >> logs/cron.log 2>&1
```

### View cron logs

```bash
tail -f logs/cron.log
tail -f logs/backup_*.log
```

## IMAP Servers

Here are some common IMAP server addresses:

| Provider                | IMAP Server           |
| ----------------------- | --------------------- |
| Gmail                   | imap.gmail.com        |
| Outlook / Microsoft 365 | outlook.office365.com |
| Yahoo                   | imap.mail.yahoo.com   |
| Apple iCloud            | imap.mail.me.com      |
| ProtonMail              | imap.protonmail.com   |
| Exchange (On-Premise)   | mail.yourcompany.com  |
| Custom Domain           | mail.example.com      |

Contact your email provider if unsure.

## Security

### Best Practices

1. **Use app-specific passwords** for Gmail and Microsoft accounts instead of your main password:

   - Gmail: https://myaccount.google.com/apppasswords
   - Microsoft: https://account.microsoft.com/account/manage-my-microsoft-account

2. **Keep password files secure**. Check permissions:

   ```bash
   ls -l accounts/passwords/
   ```

   All files should show `600` permissions. Fix if needed:

   ```bash
   chmod 600 accounts/passwords/*
   ```

3. **Never commit password files to git**. Use the provided `.gitignore`.

4. **Consider encryption** if storing on shared systems:

   ```bash
   gpg -c accounts/passwords/emailaccountexample.pass
   ```

5. **Backup your backups** to external storage or cloud:
   ```bash
   rsync -av data/ /mnt/external/email_backup/
   ```

## Troubleshooting

### "offlineimap is not installed"

```bash
pip install offlineimap3
# or
apt install offlineimap
```

### "Account not found" error

Make sure the account is in `accounts/accounts.conf`:

```bash
cat accounts/accounts.conf
./offlineimap_backup.sh list
```

### "Authentication failed" or "Permission denied"

- Verify the IMAP server address is correct
- Check the email address is correct
- For Gmail/Outlook, use an app-specific password, not your account password
- Test manually:
  ```bash
  offlineimap -c accounts/offlineimaprc -a emailaccountexample -d IMAP
  ```

### Backup is slow

- First sync of a large mailbox can take hours
- Subsequent syncs are incremental and much faster
- You can safely interrupt (Ctrl+C) and restart

### Check logs for errors

```bash
tail -f logs/backup_*.log
```

### Reset a single account

Remove from `accounts/accounts.conf` and re-add:

```bash
nano accounts/accounts.conf  # Delete the account line
./offlineimap_backup.sh setup
./offlineimap_backup.sh sync emailaccountexample
```

## FAQ

**Q: Can I restore emails from these backups?**
A: Yes. The files are standard Mbox format, compatible with Thunderbird, Evolution, Mutt, and most mail clients. You can import them back into any IMAP server.

**Q: How much disk space will I need?**
A: Similar to your email provider's storage. Run `./offlineimap_backup.sh usage` to see current usage.

**Q: Is my password safe?**
A: Passwords are stored in files with 600 permissions (only you can read). For maximum security, use app-specific passwords instead of your main account password.

**Q: Can I back up to an external drive?**
A: Yes. Symlink the `data/` directory:

```bash
rm -rf data
ln -s /mnt/external/email_backup data
```

**Q: Can I share this repository on GitHub?**
A: Yes, but NEVER commit the `accounts/passwords/` directory. The `.gitignore` file handles this automatically.

**Q: Will incremental syncs miss any emails?**
A: No. Offlineimap uses a state file (metadata) to track which emails have been synced. Subsequent runs only download new/modified emails.

**Q: Can I use this on macOS?**
A: Yes. Install offlineimap via Homebrew:

```bash
brew install offlineimap
```

**Q: Can I schedule multiple accounts on different times?**
A: Yes. Create separate cron jobs for each account or use at different times.

## Support

For issues with:

- **This script**: Check logs in `logs/` directory or file an issue
- **offlineimap**: See https://www.offlineimap.org/
- **IMAP configuration**: Contact your email provider

## License

This script is provided as-is. Feel free to modify and use freely.

## Changelog

### v1.0

- Initial release
- Self-contained directory structure
- Multi-account support
- Single account sync capability
- Cron-friendly logging
