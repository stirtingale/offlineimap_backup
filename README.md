# Email Backup Script

A self-contained Bash script for backing up multiple IMAP email accounts to local Maildir format using `offlineimap`. Everything is stored locally in the script directory, making it easy to manage and automate.

## Features

- **Multi-account support**. Back up multiple email accounts with a single script.
- **Self-contained**. All configuration and data stored in the script directory. No reliance on global config directories.
- **One-time backups**. Create tar.gz archives without persistent storage, perfect for one-off exports.
- **Persistent backups**. Store backups in the `data/` directory for incremental syncs.
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
cd /path/to/backup/directory
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

- Account name (e.g., `myaccount`, `gmail`, `work`)
- IMAP server (e.g., `imap.gmail.com`, `outlook.office365.com`)
- Email address
- Password (typed but not shown)

After entering credentials, you'll be asked: **"Run one-time backup now? (y/n)"**

- **Say `y`** to immediately create a tar.gz backup file: `myaccount_backup_TIMESTAMP.tar.gz`
- **Say `n`** to skip and set up persistent backups later with `sync`

### Backup your account

**Option 1: One-time backup (create tar file, no persistent storage)**

```bash
./offlineimap_backup.sh onetime myaccount
```

Creates a compressed tar.gz file and cleans up temporary files. Perfect for one-off exports or transfers.

**Option 2: Persistent backup (store in data/ directory)**

```bash
./offlineimap_backup.sh sync myaccount
```

Backs up to the `data/myaccount/` directory. Subsequent syncs are incremental and fast.

**Option 3: Backup all configured accounts**

```bash
./offlineimap_backup.sh sync
```

### Check what's backed up

```bash
./offlineimap_backup.sh list      # Show all accounts and sizes
./offlineimap_backup.sh usage     # Show disk usage breakdown
```

## Commands

### `setup`

Interactively add a new email account. After entering credentials, optionally creates a one-time backup.

```bash
./offlineimap_backup.sh setup
```

### `onetime [account]`

Create a one-time tar.gz backup of an account. No persistent directory storage, cleans up temp files automatically.

```bash
./offlineimap_backup.sh onetime myaccount
# Output: myaccount_backup_2026-01-14_17-15-24.tar.gz
```

### `sync` or `sync [account]`

Backup accounts to persistent storage in `data/` directory. Supports incremental updates.

```bash
./offlineimap_backup.sh sync              # All accounts
./offlineimap_backup.sh sync myaccount    # Single account
```

### `list`

Show all configured accounts and their backup sizes.

```bash
./offlineimap_backup.sh list
```

### `usage`

Display disk usage of all persistent backups.

```bash
./offlineimap_backup.sh usage
```

### `init`

Initialize the directory structure (run once).

```bash
./offlineimap_backup.sh init
```

## Backup Types Explained

### One-Time Backup (`onetime` command)

- **Storage**: Creates a single `.tar.gz` file
- **Cleanup**: Temporary files are automatically deleted after archiving
- **Use cases**:
  - Exporting email to share with others
  - Creating a snapshot without persistent storage
  - Quick backups for archive/transfer
  - Testing IMAP connectivity
- **File location**: `script_directory/account_backup_TIMESTAMP.tar.gz`
- **Incremental**: No, each run is a fresh backup

**Example:**

```bash
./offlineimap_backup.sh onetime gmail
# Creates: gmail_backup_2026-01-14_17-15-24.tar.gz (50MB)
```

### Persistent Backup (`sync` command)

- **Storage**: Stores in `data/account/` directory structure
- **Cleanup**: Data persists between runs
- **Use cases**:
  - Regular automated backups
  - Email archival
  - Incremental syncing to avoid re-downloading
  - Long-term backup strategy
- **Directory location**: `script_directory/data/account/`
- **Incremental**: Yes, only new/changed emails downloaded on subsequent runs

**Example:**

```bash
./offlineimap_backup.sh sync gmail
# Creates: data/gmail/ with Maildir structure
```

## Directory Structure

```
/path/to/backup/directory/
├── offlineimap_backup.sh          # This script
├── accounts/
│   ├── accounts.conf              # List of email accounts
│   ├── passwords/
│   │   ├── myaccount.pass         # Password for myaccount
│   │   ├── gmail.pass             # Password for gmail
│   │   └── ...
│   └── offlineimaprc              # Auto-generated offlineimap config
├── data/
│   ├── myaccount/                 # Persistent Maildir backup for myaccount
│   │   ├── INBOX/
│   │   ├── Sent/
│   │   └── ...
│   ├── gmail/                      # Persistent Maildir backup for gmail
│   └── ...
├── logs/
│   ├── backup_2026-01-14_10-30-45.log
│   ├── backup_2026-01-14_14-15-22.log
│   └── ...
├── myaccount_backup_2026-01-14_17-15-24.tar.gz  # One-time backups
├── gmail_backup_2026-01-14_16-00-00.tar.gz
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
myaccount|exchange.example.com|user@example.com|passwords/myaccount.pass|myaccount
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

### First-time setup with immediate backup

```bash
./offlineimap_backup.sh init
./offlineimap_backup.sh setup
# Choose "y" to run one-time backup immediately
```

### Add multiple accounts

```bash
./offlineimap_backup.sh setup   # Add myaccount, backup to tar
./offlineimap_backup.sh setup   # Add work email, backup to tar
./offlineimap_backup.sh setup   # Add gmail, backup to tar
```

### Create one-time backups

```bash
# Immediately after setup
./offlineimap_backup.sh setup

# Or anytime later
./offlineimap_backup.sh onetime myaccount
./offlineimap_backup.sh onetime work
```

### Setup persistent incremental backups

```bash
# Initial backup
./offlineimap_backup.sh sync myaccount

# Later, faster incremental sync
./offlineimap_backup.sh sync myaccount
```

### Backup all accounts (persistent)

```bash
./offlineimap_backup.sh sync
```

### See all backups and sizes

```bash
./offlineimap_backup.sh list
```

## Cron Jobs

The script is designed to work perfectly with cron. Colors are automatically disabled and all output is logged to files.

### Daily persistent backup at 2 AM

Edit your crontab:

```bash
crontab -e
```

Add this line:

```bash
0 2 * * * cd /path/to/backup/directory && ./offlineimap_backup.sh sync >> logs/cron.log 2>&1
```

### Weekly one-time backup

```bash
# Every Sunday at 3 AM, create a one-time tar backup
0 3 * * 0 cd /path/to/backup/directory && ./offlineimap_backup.sh onetime myaccount >> logs/cron.log 2>&1
```

### Multiple daily backups

```bash
# 2 AM - persistent backup of all accounts
0 2 * * * cd /path/to/backup/directory && ./offlineimap_backup.sh sync >> logs/cron.log 2>&1

# 2 PM - one-time backup of critical account
0 14 * * * cd /path/to/backup/directory && ./offlineimap_backup.sh onetime myaccount >> logs/cron.log 2>&1

# Weekly archive on Sunday at 3 AM
0 3 * * 0 cd /path/to/backup/directory && ./offlineimap_backup.sh onetime myaccount >> logs/cron.log 2>&1
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
   gpg -c accounts/passwords/myaccount.pass
   ```

5. **Backup your backups** to external storage or cloud:
   ```bash
   rsync -av data/ /mnt/external/email_backup/
   rsync -av *_backup_*.tar.gz /mnt/external/email_backup/
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
  offlineimap -c accounts/offlineimaprc -a myaccount -d IMAP
  ```

### Backup is slow

- First sync of a large mailbox can take hours
- One-time backups may also take time on first run
- Persistent syncs are incremental and much faster on subsequent runs
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
./offlineimap_backup.sh sync myaccount
```

## FAQ

**Q: What's the difference between one-time and persistent backups?**
A: One-time creates a tar.gz file and deletes temp files. Persistent stores in `data/` for incremental updates. Use one-time for exports, persistent for regular archival.

**Q: Can I restore emails from these backups?**
A: Yes. Files are in standard Maildir format, compatible with Thunderbird, Evolution, Mutt, and most mail clients. You can import them back into any IMAP server.

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
A: No. Offlineimap uses a state file (metadata) to track which emails have been synced. Subsequent persistent syncs only download new/modified emails.

**Q: Can I use this on macOS?**
A: Yes. Install offlineimap via Homebrew:

```bash
brew install offlineimap
```

**Q: Can I schedule multiple accounts at different times?**
A: Yes. Create separate cron jobs for each account or use at different times.

**Q: What format are the backups in?**
A: Maildir format, the modern standard for email storage. Each folder is a directory with cur/, new/, and tmp/ subdirectories containing individual email files.

**Q: Can I use one-time backups with cron?**
A: Yes. Perfect for creating weekly snapshots:

```bash
0 3 * * 0 cd /path/to/script && ./offlineimap_backup.sh onetime myaccount
```

## Support

For issues with:

- **This script**: Check logs in `logs/` directory or file an issue
- **offlineimap**: See https://www.offlineimap.org/
- **IMAP configuration**: Contact your email provider

## License

This script is provided as-is. Feel free to modify and use freely.

## Changelog

### v2.0

- Added one-time backup feature (creates tar.gz files)
- Added `onetime` command for single-file backups
- Setup command now offers one-time backup option
- Updated to Maildir format (Mbox no longer supported in offlineimap 8.0+)
- Improved temporary file cleanup

### v1.0

- Initial release
- Self-contained directory structure
- Multi-account support
- Single account sync capability
- Cron-friendly logging
