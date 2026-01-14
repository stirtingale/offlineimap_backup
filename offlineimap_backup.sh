#!/bin/bash

# Offlineimap IMAP to Mbox Backup Script (Self-Contained)
# All configuration and backups stored in script directory

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration Paths
CONFIG_DIR="${SCRIPT_DIR}/accounts"
BACKUP_DIR="${SCRIPT_DIR}/data"
LOG_DIR="${SCRIPT_DIR}/logs"
ACCOUNTS_CONFIG="${CONFIG_DIR}/accounts.conf"
OFFLINEIMAP_CONFIG="${CONFIG_DIR}/offlineimaprc"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# Color output
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

# Logging
log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    mkdir -p "${LOG_DIR}"
    echo -e "${msg}" >> "${LOG_FILE}"
    [ -t 1 ] && echo -e "${msg}"
}

error() {
    local msg="${RED}[ERROR]${NC} $1"
    mkdir -p "${LOG_DIR}"
    echo -e "${msg}" >> "${LOG_FILE}" 2>&1
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

# Setup
setup() {
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "${LOG_DIR}"
    mkdir -p "${CONFIG_DIR}/passwords"
    log "Directories initialized"
}

# Check offlineimap
check_offlineimap() {
    if ! command -v offlineimap &> /dev/null; then
        error "offlineimap not installed. Run: pip install offlineimap3"
    fi
}

# Create template
create_template() {
    if [ -f "${ACCOUNTS_CONFIG}" ]; then
        return
    fi
    
    cat > "${ACCOUNTS_CONFIG}" << 'EOF'
# Offlineimap Accounts Configuration
# Format: account_name|imap_server|email|password_file|local_folder

# Examples:
# myaccount|imap.gmail.com|user@gmail.com|passwords/myaccount.pass|myaccount
# work|mail.company.com|user@company.com|passwords/work.pass|work
EOF
    log "Created template: ${ACCOUNTS_CONFIG}"
}

# Setup new account
setup_account() {
    log "Setting up new account..."
    
    read -p "Account name: " account_name
    [ -z "${account_name}" ] && error "Account name required"
    
    read -p "IMAP server: " imap_server
    [ -z "${imap_server}" ] && error "IMAP server required"
    
    read -p "Email address: " email
    [ -z "${email}" ] && error "Email required"
    
    read -sp "Password: " password
    echo
    read -sp "Confirm: " password_confirm
    echo
    
    [ "${password}" != "${password_confirm}" ] && error "Passwords don't match"
    
    # Save password
    local pass_file="${CONFIG_DIR}/passwords/${account_name}.pass"
    echo "${password}" > "${pass_file}"
    chmod 600 "${pass_file}"
    log "Password saved: ${pass_file}"
    
    # Add to config
    echo "${account_name}|${imap_server}|${email}|passwords/${account_name}.pass|${account_name}" >> "${ACCOUNTS_CONFIG}"
    success "Account '${account_name}' added"
    
    # Ask if they want to do a one-time backup now
    read -p "Run one-time backup now? (y/n): " run_backup
    if [[ $run_backup =~ ^[Yy]$ ]]; then
        generate_config
        run_onetime_backup "${account_name}"
    fi
}

# Generate offlineimap config
generate_config() {
    log "Generating offlineimap config..."
    
    if [ ! -f "${ACCOUNTS_CONFIG}" ]; then
        error "No accounts configured"
    fi
    
    # Build account list
    local accounts=""
    local first=1
    while IFS='|' read -r account imap_server email pass_file folder; do
        # Skip comments and empty lines
        [[ "$account" =~ ^#.*$ ]] && continue
        [ -z "$account" ] && continue
        
        if [ $first -eq 1 ]; then
            accounts="$account"
            first=0
        else
            accounts="$accounts,$account"
        fi
    done < "${ACCOUNTS_CONFIG}"
    
    if [ -z "$accounts" ]; then
        error "No valid accounts found in ${ACCOUNTS_CONFIG}"
    fi
    
    log "Found accounts: $accounts"
    
    # Generate config
    cat > "${OFFLINEIMAP_CONFIG}" << EOF
[general]
accounts = ${accounts}
maxsyncaccounts = 1
metadata = ${CONFIG_DIR}/.metadata
ui = Noninteractive.Basic

EOF

    # Add each account
    while IFS='|' read -r account imap_server email pass_file folder; do
        # Skip comments and empty lines
        [[ "$account" =~ ^#.*$ ]] && continue
        [ -z "$account" ] && continue
        
        local local_path="${BACKUP_DIR}/${folder}"
        local full_pass_file="${CONFIG_DIR}/${pass_file}"
        
        cat >> "${OFFLINEIMAP_CONFIG}" << EOF
[Account ${account}]
localrepository = ${account}_local
remoterepository = ${account}_remote
autorefresh = 0
quick = 10

[Repository ${account}_local]
type = Maildir
localfolders = ${local_path}
createmissingfolders = yes

[Repository ${account}_remote]
type = IMAP
remotehost = ${imap_server}
remoteuser = ${email}
remotepassfile = ${full_pass_file}
ssl = yes
sslcacertfile = /etc/ssl/certs/ca-certificates.crt

EOF
    done < "${ACCOUNTS_CONFIG}"
    
    success "Config generated: ${OFFLINEIMAP_CONFIG}"
}

# Run backup (all accounts)
run_backup_all() {
    log "Starting backup (all accounts)..."
    
    if [ ! -f "${OFFLINEIMAP_CONFIG}" ]; then
        error "Config file missing"
    fi
    
    if offlineimap -c "${OFFLINEIMAP_CONFIG}" -u Noninteractive.Basic >> "${LOG_FILE}" 2>&1; then
        success "Backup complete"
    else
        error "Backup failed - check log: ${LOG_FILE}"
    fi
}

# Run backup (single account)
run_backup_single() {
    local account="$1"
    log "Starting backup for account: ${account}"
    
    if [ ! -f "${OFFLINEIMAP_CONFIG}" ]; then
        error "Config file missing"
    fi
    
    # Verify account exists
    if ! grep -q "^${account}|" "${ACCOUNTS_CONFIG}"; then
        error "Account '${account}' not found"
    fi
    
    if offlineimap -c "${OFFLINEIMAP_CONFIG}" -a "${account}" -u Noninteractive.Basic >> "${LOG_FILE}" 2>&1; then
        success "Backup complete for ${account}"
    else
        error "Backup failed for ${account} - check log: ${LOG_FILE}"
    fi
}

# Run one-time backup (no persistent storage, just tar)
run_onetime_backup() {
    local account="$1"
    log "Starting one-time backup for account: ${account}"
    
    if [ ! -f "${ACCOUNTS_CONFIG}" ]; then
        error "No accounts configured"
    fi
    
    # Verify account exists
    if ! grep -q "^${account}|" "${ACCOUNTS_CONFIG}"; then
        error "Account '${account}' not found"
    fi
    
    # Create temporary directory for this backup
    local temp_backup_dir="${BACKUP_DIR}/.temp_${account}_${TIMESTAMP}"
    local temp_config="${SCRIPT_DIR}/.temp_offlineimaprc_${TIMESTAMP}"
    
    mkdir -p "${temp_backup_dir}"
    
    log "Using temporary directory: ${temp_backup_dir}"
    
    # Get account details
    while IFS='|' read -r acc imap_server email pass_file folder; do
        [[ "$acc" =~ ^#.*$ ]] && continue
        [ -z "$acc" ] && continue
        [ "$acc" != "$account" ] && continue
        
        local full_pass_file="${CONFIG_DIR}/${pass_file}"
        
        # Generate temporary config
        cat > "${temp_config}" << EOF
[general]
accounts = ${account}
maxsyncaccounts = 1
metadata = ${BACKUP_DIR}/.metadata_temp_${TIMESTAMP}
ui = Noninteractive.Basic

[Account ${account}]
localrepository = ${account}_local
remoterepository = ${account}_remote
autorefresh = 0
quick = 10

[Repository ${account}_local]
type = Maildir
localfolders = ${temp_backup_dir}
createmissingfolders = yes

[Repository ${account}_remote]
type = IMAP
remotehost = ${imap_server}
remoteuser = ${email}
remotepassfile = ${full_pass_file}
ssl = yes
sslcacertfile = /etc/ssl/certs/ca-certificates.crt

EOF
    done < "${ACCOUNTS_CONFIG}"
    
    # Run backup to temp location
    if offlineimap -c "${temp_config}" -a "${account}" -u Noninteractive.Basic >> "${LOG_FILE}" 2>&1; then
        # Create tar file
        local tar_file="${SCRIPT_DIR}/${account}_backup_${TIMESTAMP}.tar.gz"
        log "Creating archive: ${tar_file}"
        
        if tar -czf "${tar_file}" -C "${temp_backup_dir}" . 2>> "${LOG_FILE}"; then
            local size=$(du -h "${tar_file}" | cut -f1)
            success "One-time backup complete: ${tar_file} (${size})"
            log "Archive location: ${tar_file}"
            
            # Cleanup temp files
            rm -rf "${temp_backup_dir}"
            rm -f "${temp_config}"
            rm -rf "${BACKUP_DIR}/.metadata_temp_${TIMESTAMP}"
            
            return 0
        else
            error "Failed to create archive"
        fi
    else
        error "Backup failed for ${account} - check log: ${LOG_FILE}"
    fi
    
    # Cleanup on failure
    rm -rf "${temp_backup_dir}"
    rm -f "${temp_config}"
    rm -rf "${BACKUP_DIR}/.metadata_temp_${TIMESTAMP}"
}

# List accounts
list() {
    if [ ! -f "${ACCOUNTS_CONFIG}" ]; then
        warning "No accounts configured"
        return
    fi
    
    info "Configured accounts:"
    echo
    local n=0
    while IFS='|' read -r account imap_server email pass_file folder; do
        [[ "$account" =~ ^#.*$ ]] && continue
        [ -z "$account" ] && continue
        ((n++))
        
        local data_path="${BACKUP_DIR}/${folder}"
        local size="(empty)"
        [ -d "$data_path" ] && size=$(du -sh "$data_path" 2>/dev/null | cut -f1)
        
        echo "  $n. $account ($email @ $imap_server) - $size"
    done < "${ACCOUNTS_CONFIG}"
    echo
}

# Show usage
show_usage() {
    if [ ! -d "${BACKUP_DIR}" ] || [ -z "$(ls -A "${BACKUP_DIR}")" ]; then
        info "No backups yet"
        return
    fi
    
    info "Backup usage:"
    echo
    du -sh "${BACKUP_DIR}"/*
    echo
}

# Help
help() {
    cat << EOF
${BLUE}Email Backup Script${NC}

${GREEN}Commands:${NC}
  init                  Initialize directories
  setup                 Add new account (with optional one-time backup)
  list                  List all accounts
  sync                  Backup all accounts (persistent storage)
  sync ACCOUNT          Backup single account (persistent storage)
  onetime ACCOUNT       One-time backup to tar file (no persistent storage)
  usage                 Show disk usage
  help                  Show this help

${GREEN}Examples:${NC}
  ./offlineimap_backup.sh init
  ./offlineimap_backup.sh setup              # Will ask for one-time backup
  ./offlineimap_backup.sh sync               # Backup all to data/
  ./offlineimap_backup.sh sync myaccount     # Backup one to data/
  ./offlineimap_backup.sh onetime myaccount  # One-time backup to tar file

${GREEN}Persistent vs One-Time:${NC}
  - 'sync': Stores backups in data/account/ directory for incremental updates
  - 'onetime': Creates a tar.gz file in script directory, cleans up temp files

EOF
}

# Main
main() {
    local cmd="${1:-sync}"
    local arg="${2:-}"
    
    setup
    
    case "$cmd" in
        init)
            check_offlineimap
            create_template
            success "Initialized. Run: $0 setup"
            ;;
        setup)
            create_template
            setup_account
            ;;
        list)
            list
            ;;
        sync)
            check_offlineimap
            create_template
            generate_config
            if [ -z "$arg" ]; then
                run_backup_all
            else
                run_backup_single "$arg"
            fi
            ;;
        onetime)
            [ -z "$arg" ] && error "Account name required: $0 onetime ACCOUNT"
            check_offlineimap
            create_template
            run_onetime_backup "$arg"
            ;;
        usage)
            show_usage
            ;;
        help|--help|-h)
            help
            ;;
        *)
            echo "Unknown command: $cmd"
            help
            exit 1
            ;;
    esac
}

main "$@"