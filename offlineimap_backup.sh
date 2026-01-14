#!/bin/bash

# Offlineimap IMAP to Mbox Backup Script (Self-Contained)
# All configuration and backups stored in script directory
# Works from anywhere, stores everything locally

set -e

# Get script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration Paths (all relative to script directory)
CONFIG_DIR="${SCRIPT_DIR}/accounts"
BACKUP_DIR="${SCRIPT_DIR}/data"
LOG_DIR="${SCRIPT_DIR}/logs"
ACCOUNTS_CONFIG="${CONFIG_DIR}/accounts.conf"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# Color output (disabled if not a TTY, useful for cron)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging Functions
log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${msg}" >> "${LOG_FILE}"
    [ -t 1 ] && echo -e "${msg}"
}

error() {
    local msg="${RED}[ERROR]${NC} $1"
    echo -e "${msg}" >> "${LOG_FILE}"
    echo -e "${msg}" >&2
    exit 1
}

success() {
    local msg="${GREEN}[SUCCESS]${NC} $1"
    echo -e "${msg}" >> "${LOG_FILE}"
    [ -t 1 ] && echo -e "${msg}"
}

warning() {
    local msg="${YELLOW}[WARNING]${NC} $1"
    echo -e "${msg}" >> "${LOG_FILE}"
    [ -t 1 ] && echo -e "${msg}"
}

info() {
    local msg="${BLUE}[INFO]${NC} $1"
    echo -e "${msg}" >> "${LOG_FILE}"
    [ -t 1 ] && echo -e "${msg}"
}

# Check if offlineimap is installed
check_offlineimap() {
    if ! command -v offlineimap &> /dev/null; then
        error "offlineimap is not installed. Install it with: pip install offlineimap3"
    fi
    log "offlineimap found: $(offlineimap --version 2>&1 | head -n1)"
}

# Create necessary directories
setup_directories() {
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "${LOG_DIR}"
    mkdir -p "${CONFIG_DIR}/passwords"
    log "Script directory: ${SCRIPT_DIR}"
    log "Config directory: ${CONFIG_DIR}"
    log "Backup directory: ${BACKUP_DIR}"
    log "Log directory: ${LOG_DIR}"
}

# Check if accounts config exists
check_accounts_config() {
    if [ ! -f "${ACCOUNTS_CONFIG}" ]; then
        return 1
    fi
    return 0
}

# Create template accounts config
create_accounts_template() {
    cat > "${ACCOUNTS_CONFIG}" << 'EOF'
# Offlineimap Accounts Configuration
# Format: account_name|imap_server|email|password_file|local_folder
# Lines starting with # are comments
# Do not commit password files to version control!

# Example for Gmail:
# gmail|imap.gmail.com|your-email@gmail.com|passwords/gmail.pass|gmail

# Example for Outlook:
# outlook|outlook.office365.com|your-email@outlook.com|passwords/outlook.pass|outlook

# Example for Exchange:
# exchange|exchange2019.livemail.co.uk|user@example.com|passwords/exchange.pass|exchange
EOF
    log "Template accounts config created at ${ACCOUNTS_CONFIG}"
}

# Interactive account setup
setup_new_account() {
    info "=== Setting up new email account ==="
    
    read -p "Account name (e.g., sophiegerrard, gmail, work): " account_name
    [ -z "${account_name}" ] && error "Account name cannot be empty"
    
    # Check if account already exists
    if grep -q "^${account_name}|" "${ACCOUNTS_CONFIG}" 2>/dev/null; then
        warning "Account '${account_name}' already exists. Updating it..."
        # Remove existing account
        sed -i.bak "/^${account_name}|/d" "${ACCOUNTS_CONFIG}"
    fi
    
    read -p "IMAP server (e.g., imap.gmail.com, exchange2019.livemail.co.uk): " imap_server
    [ -z "${imap_server}" ] && error "IMAP server cannot be empty"
    
    read -p "Email address: " email
    [ -z "${email}" ] && error "Email address cannot be empty"
    
    read -sp "IMAP password: " password
    echo
    read -sp "Confirm password: " password_confirm
    echo
    
    if [ "${password}" != "${password_confirm}" ]; then
        error "Passwords do not match"
    fi
    
    # Create password file
    local password_file="passwords/${account_name}.pass"
    echo "${password}" > "${CONFIG_DIR}/${password_file}"
    chmod 600 "${CONFIG_DIR}/${password_file}"
    log "Password file created: ${CONFIG_DIR}/${password_file}"
    
    # Add to accounts config
    echo "${account_name}|${imap_server}|${email}|${password_file}|${account_name}" >> "${ACCOUNTS_CONFIG}"
    success "Account '${account_name}' added to configuration"
    
    return 0
}

# Generate offlineimap config from accounts file
generate_offlineimap_config() {
    local accounts_list=()
    local account_count=0
    
    # Read accounts file and build list
    while IFS='|' read -r account imap_server email password_file local_folder; do
        [[ "${account}" =~ ^#.*$ || -z "${account}" ]] && continue
        
        accounts_list+=("${account}")
        ((account_count++))
    done < "${ACCOUNTS_CONFIG}"
    
    if [ ${account_count} -eq 0 ]; then
        error "No valid accounts found in ${ACCOUNTS_CONFIG}"
    fi
    
    local accounts_string=$(IFS=,; echo "${accounts_list[*]}")
    local offlineimap_config="${CONFIG_DIR}/offlineimaprc"
    
    # Create main offlineimap config
    cat > "${offlineimap_config}" << EOF
# Auto-generated Offlineimap Configuration
# Generated: $(date)
# Do not edit manually. Update accounts.conf instead.

[general]
accounts = ${accounts_string}
maxsyncaccounts = 1
metadata = ${CONFIG_DIR}/.metadata
ui = Noninteractive.Basic

EOF

    # Add account and repository sections
    while IFS='|' read -r account imap_server email password_file local_folder; do
        [[ "${account}" =~ ^#.*$ || -z "${account}" ]] && continue
        
        local local_path="${BACKUP_DIR}/${local_folder}"
        
        cat >> "${offlineimap_config}" << EOF
[Account ${account}]
localrepository = ${account}_local
remoterepository = ${account}_remote
autorefresh = 0
quick = 10

[Repository ${account}_local]
type = Mbox
localfolders = ${local_path}
createmissingfolders = yes

[Repository ${account}_remote]
type = IMAP
remotehost = ${imap_server}
remoteuser = ${email}
remotepassfile = ${CONFIG_DIR}/${password_file}
ssl = yes
sslcacertfile = /etc/ssl/certs/ca-certificates.crt

EOF
    done < "${ACCOUNTS_CONFIG}"
    
    log "Generated offlineimap config: ${offlineimap_config}"
}

# Run backup for all accounts
run_backup_all() {
    local offlineimap_config="${CONFIG_DIR}/offlineimaprc"
    
    if [ ! -f "${offlineimap_config}" ]; then
        error "Offlineimap config not found. Run setup first."
    fi
    
    log "Starting backup for all accounts..."
    log "Config: ${offlineimap_config}"
    
    if offlineimap -c "${offlineimap_config}" -u Noninteractive.Basic >> "${LOG_FILE}" 2>&1; then
        success "Backup completed successfully"
        return 0
    else
        error "Backup failed. Check ${LOG_FILE} for details"
        return 1
    fi
}

# Run backup for a single account
run_backup_account() {
    local account_name="$1"
    
    if [ -z "${account_name}" ]; then
        error "Account name required"
    fi
    
    # Check if account exists
    if ! grep -q "^${account_name}|" "${ACCOUNTS_CONFIG}" 2>/dev/null; then
        error "Account '${account_name}' not found in configuration"
    fi
    
    local offlineimap_config="${CONFIG_DIR}/offlineimaprc"
    
    if [ ! -f "${offlineimap_config}" ]; then
        error "Offlineimap config not found. Run setup first."
    fi
    
    log "Starting backup for account: ${account_name}"
    log "Config: ${offlineimap_config}"
    
    if offlineimap -c "${offlineimap_config}" -a "${account_name}" -u Noninteractive.Basic >> "${LOG_FILE}" 2>&1; then
        success "Backup completed successfully for ${account_name}"
        return 0
    else
        error "Backup failed for ${account_name}. Check ${LOG_FILE} for details"
        return 1
    fi
}

# Create archive of backup
create_archive() {
    local archive_name="mail_backup_${TIMESTAMP}.tar.gz"
    log "Creating archive: ${archive_name}"
    
    if [ ! -d "${BACKUP_DIR}" ] || [ -z "$(ls -A "${BACKUP_DIR}")" ]; then
        warning "No data to archive"
        return 1
    fi
    
    if tar -czf "${SCRIPT_DIR}/${archive_name}" -C "${BACKUP_DIR}" . 2>> "${LOG_FILE}"; then
        success "Archive created: ${SCRIPT_DIR}/${archive_name}"
        local size=$(du -h "${SCRIPT_DIR}/${archive_name}" | cut -f1)
        log "Archive size: ${size}"
        return 0
    else
        warning "Failed to create archive"
        return 1
    fi
}

# List configured accounts
list_accounts() {
    if [ ! -f "${ACCOUNTS_CONFIG}" ]; then
        warning "No accounts configured yet"
        return 1
    fi
    
    info "Configured accounts:"
    echo
    local count=0
    while IFS='|' read -r account imap_server email password_file local_folder; do
        [[ "${account}" =~ ^#.*$ || -z "${account}" ]] && continue
        ((count++))
        local backup_path="${BACKUP_DIR}/${local_folder}"
        local size="(no data)"
        if [ -d "${backup_path}" ]; then
            size=$(du -sh "${backup_path}" 2>/dev/null | cut -f1)
        fi
        echo "  ${count}. ${account} (${email} @ ${imap_server}) - ${size}"
    done < "${ACCOUNTS_CONFIG}"
    
    if [ ${count} -eq 0 ]; then
        warning "No accounts configured"
        return 1
    fi
    echo
    return 0
}

# Show disk usage
show_usage() {
    info "Disk usage:"
    echo
    if [ -d "${BACKUP_DIR}" ] && [ -n "$(ls -A "${BACKUP_DIR}")" ]; then
        du -sh "${BACKUP_DIR}"/*
    else
        echo "  (no data)"
    fi
    echo
}

# Show usage
usage() {
    cat << EOF
${BLUE}Offlineimap IMAP to Mbox Backup Script${NC}

${GREEN}USAGE:${NC}
    $0 [COMMAND] [OPTIONS]

${GREEN}COMMANDS:${NC}
    setup               Interactive setup for a new account
    list                List all configured accounts
    sync                Backup all configured accounts
    sync [account]      Backup a single account (e.g., sophiegerrard)
    archive             Create compressed tar.gz archive
    usage               Show disk usage of backups
    init                Initialize directory structure

${GREEN}EXAMPLES:${NC}
    # First-time setup
    $0 init
    
    # Add a new account
    $0 setup
    
    # List accounts
    $0 list
    
    # Backup all accounts
    $0 sync
    
    # Backup just sophiegerrard
    $0 sync sophiegerrard
    
    # Check backup sizes
    $0 usage
    
    # Cron job (daily at 2 AM)
    0 2 * * * cd /home/backupserver/backup/email && ./offlineimap_backup.sh sync

${GREEN}DIRECTORY STRUCTURE:${NC}
    ${SCRIPT_DIR}/
    ├── offlineimap_backup.sh          (this script)
    ├── accounts/
    │   ├── accounts.conf              (account list)
    │   ├── passwords/
    │   │   ├── sophiegerrard.pass
    │   │   └── ...
    │   └── offlineimaprc              (auto-generated config)
    ├── data/
    │   ├── sophiegerrard/             (mbox data for sophiegerrard)
    │   └── ...
    └── logs/
        └── backup_*.log

EOF
}

# Main execution
main() {
    local command="${1:-sync}"
    local account_arg="${2:-}"
    
    # Ensure log directory exists before any logging
    mkdir -p "${LOG_DIR}"
    
    case "${command}" in
        setup)
            setup_directories
            check_offlineimap
            if ! check_accounts_config; then
                create_accounts_template
            fi
            setup_new_account
            generate_offlineimap_config
            ;;
        list)
            setup_directories
            list_accounts
            ;;
        sync)
            setup_directories
            check_offlineimap
            if ! check_accounts_config; then
                error "No accounts configured. Run '$0 setup' first"
            fi
            generate_offlineimap_config
            log "=== Starting Backup Sync ==="
            
            if [ -z "${account_arg}" ]; then
                # Backup all accounts
                run_backup_all
            else
                # Backup single account
                run_backup_account "${account_arg}"
            fi
            success "Backup process complete"
            ;;
        archive)
            setup_directories
            log "=== Creating Archive ==="
            create_archive
            ;;
        usage)
            setup_directories
            show_usage
            ;;
        init)
            setup_directories
            check_offlineimap
            if ! check_accounts_config; then
                create_accounts_template
            fi
            success "Configuration structure initialized"
            info "Next step: Run '$0 setup' to add your first account"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: ${command}" >&2
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"