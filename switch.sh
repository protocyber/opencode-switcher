#!/bin/bash

# ============================================
# OpenCode Multi-Account Switcher
# ============================================
# Version: 1.0.0
# Description: Switch between multiple OpenCode provider accounts
# Author: OpenCode Community
# License: MIT

# ============================================
# Configuration
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_RETENTION=5
AUTH_FILE="$HOME/.local/share/opencode/auth.json"
ACCOUNTS_FILE="$SCRIPT_DIR/accounts.json"
BACKUP_DIR="$SCRIPT_DIR/backups"
EDITOR_PREFERENCE="vim"

# ============================================
# Color Codes
# ============================================
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' RED='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

# ============================================
# Helper Functions
# ============================================

check_dependencies() {
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}✗${RESET} Error: jq is not installed"
    echo "  Please install jq: sudo apt install jq (Ubuntu/Debian) or brew install jq (macOS)"
    exit 1
  fi
}

check_files() {
  if [[ ! -f "$ACCOUNTS_FILE" ]]; then
    echo -e "${RED}✗${RESET} Error: accounts.json not found at $ACCOUNTS_FILE"
    exit 1
  fi
  
  if [[ ! -f "$AUTH_FILE" ]]; then
    echo -e "${YELLOW}!${RESET} Warning: auth.json not found at $AUTH_FILE"
    echo "  OpenCode may not be configured yet."
  fi
}

enforce_permissions() {
  chmod 600 "$ACCOUNTS_FILE" 2>/dev/null
  if [[ -f "$AUTH_FILE" ]]; then
    chmod 600 "$AUTH_FILE" 2>/dev/null
  fi
}

validate_json() {
  local file=$1
  if ! jq empty "$file" 2>/dev/null; then
    echo -e "${RED}✗${RESET} Error: Invalid JSON in $file"
    return 1
  fi
  return 0
}

# ============================================
# Backup Management
# ============================================

backup_auth() {
  if [[ ! -f "$AUTH_FILE" ]]; then
    echo -e "${YELLOW}!${RESET} No auth.json to backup"
    return 0
  fi
  
  mkdir -p "$BACKUP_DIR"
  local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
  local backup_file="$BACKUP_DIR/auth.json.backup.$timestamp"
  
  # Create backup
  if cp "$AUTH_FILE" "$backup_file" 2>/dev/null; then
    echo -e "${GREEN}✓${RESET} Backup created: $(basename "$backup_file")"
  else
    echo -e "${RED}✗${RESET} Failed to create backup"
    return 1
  fi
  
  # Keep only last N backups
  local backup_count=$(ls -t "$BACKUP_DIR"/auth.json.backup.* 2>/dev/null | wc -l)
  if [[ $backup_count -gt $BACKUP_RETENTION ]]; then
    ls -t "$BACKUP_DIR"/auth.json.backup.* 2>/dev/null | \
      tail -n +$((BACKUP_RETENTION + 1)) | \
      xargs rm -f 2>/dev/null
    echo -e "${CYAN}ℹ${RESET} Cleaned old backups (keeping last $BACKUP_RETENTION)"
  fi
  
  return 0
}

# ============================================
# Account Management Functions
# ============================================

get_providers() {
  jq -r 'keys[]' "$ACCOUNTS_FILE" 2>/dev/null
}

get_account_count() {
  local provider=$1
  jq -r ".\"$provider\".accounts | length" "$ACCOUNTS_FILE" 2>/dev/null
}

get_active_index() {
  local provider=$1
  jq -r ".\"$provider\".active // 0" "$ACCOUNTS_FILE" 2>/dev/null
}

set_active_index() {
  local provider=$1
  local index=$2
  
  local temp_file=$(mktemp)
  jq ".\"$provider\".active = $index" "$ACCOUNTS_FILE" > "$temp_file"
  
  if validate_json "$temp_file"; then
    mv "$temp_file" "$ACCOUNTS_FILE"
    enforce_permissions
    return 0
  else
    rm -f "$temp_file"
    return 1
  fi
}

get_account_data() {
  local provider=$1
  local index=$2
  
  jq -r ".\"$provider\".accounts[$index]" "$ACCOUNTS_FILE" 2>/dev/null
}

get_account_name() {
  local provider=$1
  local index=$2
  
  jq -r ".\"$provider\".accounts[$index].name // \"Account $index\"" "$ACCOUNTS_FILE" 2>/dev/null
}

check_duplicate_credential() {
  local provider=$1
  local access_token=$2
  
  # Get all access tokens for this provider
  local existing_tokens=$(jq -r ".\"$provider\".accounts[].access" "$ACCOUNTS_FILE" 2>/dev/null)
  
  # Check if access token already exists
  if echo "$existing_tokens" | grep -qFx "$access_token"; then
    return 0  # Duplicate found
  fi
  return 1  # No duplicate
}

# ============================================
# Core Functions
# ============================================

list_accounts() {
  echo -e "${BOLD}╔═══════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║   OpenCode Account Switcher               ║${RESET}"
  echo -e "${BOLD}╚═══════════════════════════════════════════╝${RESET}"
  echo ""
  
  local providers=$(get_providers)
  
  if [[ -z "$providers" ]]; then
    echo -e "${YELLOW}!${RESET} No providers configured in accounts.json"
    return 1
  fi
  
  while IFS= read -r provider; do
    echo -e "${CYAN}${provider}${RESET} accounts:"
    
    local count=$(get_account_count "$provider")
    local active=$(get_active_index "$provider")
    
    for ((i=0; i<count; i++)); do
      local name=$(get_account_name "$provider" "$i")
      
      if [[ $i -eq $active ]]; then
        echo -e "  ${GREEN}[${i}] ✓ ${name} - ACTIVE${RESET}"
      else
        echo -e "  [${i}]   ${name}"
      fi
    done
    echo ""
  done <<< "$providers"
}

show_active() {
  local provider=$1
  
  if [[ -n "$provider" ]]; then
    # Show active for specific provider
    local active=$(get_active_index "$provider")
    local name=$(get_account_name "$provider" "$active")
    echo -e "${CYAN}${provider}${RESET}: ${GREEN}${name}${RESET}"
  else
    # Show active for all providers
    echo -e "${BOLD}Active accounts:${RESET}"
    local providers=$(get_providers)
    
    while IFS= read -r prov; do
      local active=$(get_active_index "$prov")
      local name=$(get_account_name "$prov" "$active")
      echo -e "  ${CYAN}${prov}${RESET}: ${name}"
    done <<< "$providers"
  fi
}

switch_account() {
  local provider=$1
  local index=$2
  
  # Validate provider
  if ! jq -e ".\"$provider\"" "$ACCOUNTS_FILE" &>/dev/null; then
    echo -e "${RED}✗${RESET} Error: Provider '$provider' not found"
    echo "  Available providers: $(get_providers | tr '\n' ' ')"
    return 1
  fi
  
  # Validate index
  local count=$(get_account_count "$provider")
  if [[ $index -lt 0 ]] || [[ $index -ge $count ]]; then
    echo -e "${RED}✗${RESET} Error: Invalid account index $index"
    echo "  Valid range: 0-$((count-1))"
    return 1
  fi
  
  # Get account data
  local account_data=$(get_account_data "$provider" "$index")
  local account_name=$(get_account_name "$provider" "$index")
  
  # Check if account has credentials
  local access=$(echo "$account_data" | jq -r '.access // ""')
  if [[ -z "$access" ]]; then
    echo -e "${YELLOW}!${RESET} Warning: Account '$account_name' has no credentials configured"
    echo "  Edit accounts.json to add credentials for this account"
    read -p "  Continue anyway? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
      echo "  Cancelled."
      return 1
    fi
  fi
  
  # Backup current auth.json
  backup_auth || return 1
  
  # Create new auth.json content
  local new_auth=$(jq -n \
    --argjson account "$account_data" \
    "{\"$provider\": \$account}")
  
  # Write to temp file first
  local temp_file=$(mktemp)
  echo "$new_auth" > "$temp_file"
  
  if ! validate_json "$temp_file"; then
    rm -f "$temp_file"
    echo -e "${RED}✗${RESET} Error: Failed to generate valid auth.json"
    return 1
  fi
  
  # Atomic move
  mkdir -p "$(dirname "$AUTH_FILE")"
  mv "$temp_file" "$AUTH_FILE"
  chmod 600 "$AUTH_FILE"
  
  # Update active index
  set_active_index "$provider" "$index"
  
  echo -e "${GREEN}✓${RESET} Switched to: ${BOLD}${account_name}${RESET}"
  echo -e "${GREEN}✓${RESET} OpenCode will use this account on next request"
  
  return 0
}

add_current_account() {
  local provider=$1
  
  if [[ ! -f "$AUTH_FILE" ]]; then
    echo -e "${RED}✗${RESET} Error: auth.json not found at $AUTH_FILE"
    return 1
  fi
  
  # Check if provider exists in auth.json
  if ! jq -e ".\"$provider\"" "$AUTH_FILE" &>/dev/null; then
    echo -e "${RED}✗${RESET} Error: Provider '$provider' not found in auth.json"
    return 1
  fi
  
  # Get current credential
  local current_cred=$(jq ".\"$provider\"" "$AUTH_FILE")
  local access_token=$(echo "$current_cred" | jq -r '.access // ""')
  
  # Check for empty access token
  if [[ -z "$access_token" ]]; then
    echo -e "${RED}✗${RESET} Error: No access token found in auth.json"
    return 1
  fi
  
  # Check for duplicate
  if check_duplicate_credential "$provider" "$access_token"; then
    # Find which account has this credential
    local existing_name=$(jq -r ".\"$provider\".accounts[] | select(.access == \"$access_token\") | .name" "$ACCOUNTS_FILE" 2>/dev/null | head -1)
    echo -e "${RED}✗${RESET} Error: This credential already exists"
    echo -e "  Existing account: ${BOLD}${existing_name}${RESET}"
    echo -e "  Use 'oc-switch switch $provider <index>' to switch to it"
    return 1
  fi
  
  echo -e "${CYAN}Current credential in auth.json:${RESET}"
  echo "$current_cred" | jq .
  echo ""
  
  read -p "Add this as a new account? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "Cancelled."
    return 0
  fi
  
  read -p "Enter account name: " account_name
  if [[ -z "$account_name" ]]; then
    echo -e "${RED}✗${RESET} Error: Account name cannot be empty"
    return 1
  fi
  
  # Get current active account name (before we change it)
  local current_active_index=$(get_active_index "$provider")
  local previous_active=$(get_account_name "$provider" "$current_active_index")
  
  # Add name to credential
  local new_account=$(echo "$current_cred" | jq --arg name "$account_name" '. + {name: $name}')
  
  # Calculate the new index (will be at the end)
  local new_index=$(get_account_count "$provider")
  
  # Append to accounts array AND set as active
  local temp_file=$(mktemp)
  jq ".\"$provider\".accounts += [$new_account] | .\"$provider\".active = $new_index" "$ACCOUNTS_FILE" > "$temp_file"
  
  if validate_json "$temp_file"; then
    mv "$temp_file" "$ACCOUNTS_FILE"
    enforce_permissions
    
    local new_count=$(get_account_count "$provider")
    echo -e "${GREEN}✓${RESET} Added '${account_name}' to ${provider} accounts"
    echo -e "${GREEN}✓${RESET} Set as active account ${CYAN}(was: ${previous_active})${RESET}"
    echo -e "${GREEN}✓${RESET} Total accounts: ${new_count}"
  else
    rm -f "$temp_file"
    echo -e "${RED}✗${RESET} Error: Failed to add account"
    return 1
  fi
}

delete_account() {
  local provider=$1
  local index=$2
  
  # Validate provider
  if ! jq -e ".\"$provider\"" "$ACCOUNTS_FILE" &>/dev/null; then
    echo -e "${RED}✗${RESET} Error: Provider '$provider' not found"
    echo "  Available providers: $(get_providers | tr '\n' ' ')"
    return 1
  fi
  
  # Validate index
  local count=$(get_account_count "$provider")
  if [[ $index -lt 0 ]] || [[ $index -ge $count ]]; then
    echo -e "${RED}✗${RESET} Error: Invalid account index $index"
    echo "  Valid range: 0-$((count-1))"
    return 1
  fi
  
  # Check if trying to delete the only account
  if [[ $count -eq 1 ]]; then
    echo -e "${RED}✗${RESET} Error: Cannot delete the only account"
    echo "  Provider must have at least one account"
    return 1
  fi
  
  # Get account info
  local account_name=$(get_account_name "$provider" "$index")
  local active_index=$(get_active_index "$provider")
  
  # Confirm deletion
  echo -e "${YELLOW}!${RESET} About to delete: ${BOLD}${account_name}${RESET}"
  echo -e "  Provider: ${CYAN}${provider}${RESET}"
  echo -e "  Index: ${index}"
  echo ""
  read -p "Are you sure? This cannot be undone (y/n): " confirm
  
  if [[ "$confirm" != "y" ]]; then
    echo "Cancelled."
    return 0
  fi
  
  # Delete the account
  local temp_file=$(mktemp)
  jq "del(.\"$provider\".accounts[$index])" "$ACCOUNTS_FILE" > "$temp_file"
  
  if ! validate_json "$temp_file"; then
    rm -f "$temp_file"
    echo -e "${RED}✗${RESET} Error: Failed to delete account"
    return 1
  fi
  
  mv "$temp_file" "$ACCOUNTS_FILE"
  enforce_permissions
  
  # Update active index if needed
  if [[ $index -eq $active_index ]]; then
    # Deleted account was active, set to first account
    set_active_index "$provider" 0
    echo -e "${YELLOW}!${RESET} Deleted account was active, switched to first account"
  elif [[ $index -lt $active_index ]]; then
    # Deleted account was before active, decrement active index
    set_active_index "$provider" $((active_index - 1))
  fi
  
  local new_count=$(get_account_count "$provider")
  echo -e "${GREEN}✓${RESET} Deleted '${account_name}' from ${provider} accounts"
  echo -e "${GREEN}✓${RESET} Remaining accounts: ${new_count}"
  
  return 0
}

edit_accounts() {
  local editor="${EDITOR:-$EDITOR_PREFERENCE}"
  
  if ! command -v "$editor" &> /dev/null; then
    editor="nano"
  fi
  
  echo -e "${CYAN}Opening accounts.json in $editor...${RESET}"
  "$editor" "$ACCOUNTS_FILE"
  
  # Validate after editing
  if validate_json "$ACCOUNTS_FILE"; then
    echo -e "${GREEN}✓${RESET} accounts.json is valid"
    enforce_permissions
  else
    echo -e "${RED}✗${RESET} Error: accounts.json has invalid JSON"
    echo "  Please fix the syntax errors"
    return 1
  fi
}

# ============================================
# Interactive Menu
# ============================================

interactive_menu() {
  while true; do
    clear
    list_accounts
    
    echo -e "Select account to switch to, or:"
    echo -e "  ${CYAN}[a]${RESET} Add     ${CYAN}[s]${RESET} Show Active   ${CYAN}[d]${RESET} Delete"
    echo -e "  ${CYAN}[e]${RESET} Edit    ${CYAN}[h]${RESET} Help     ${CYAN}[q]${RESET} Quit"
    echo ""
    read -p "Your choice: " choice
    
    case "$choice" in
      [0-9]*)
        # Assume github-copilot for now (can enhance for multi-provider)
        local provider="github-copilot"
        switch_account "$provider" "$choice"
        echo ""
        read -p "Press Enter to continue..."
        ;;
      a|A)
        echo ""
        # Get available providers
        local providers=$(get_providers)
        local provider_array=()
        
        # Build provider array
        while IFS= read -r prov; do
          provider_array+=("$prov")
        done <<< "$providers"
        
        # Check if we have any providers
        if [[ ${#provider_array[@]} -eq 0 ]]; then
          echo -e "${RED}✗${RESET} No providers configured in accounts.json"
          read -p "Press Enter to continue..."
          continue
        fi
        
        # If only one provider, use it automatically
        if [[ ${#provider_array[@]} -eq 1 ]]; then
          local selected_provider="${provider_array[0]}"
          echo -e "${CYAN}Provider: ${selected_provider}${RESET}"
          echo ""
        else
          # Show available providers
          echo -e "${CYAN}Available providers:${RESET}"
          for i in "${!provider_array[@]}"; do
            echo -e "  [$i] ${provider_array[$i]}"
          done
          echo ""
          read -p "Select provider: " prov_choice
          
          # Validate provider choice
          if [[ "$prov_choice" =~ ^[0-9]+$ ]] && [[ $prov_choice -ge 0 ]] && [[ $prov_choice -lt ${#provider_array[@]} ]]; then
            local selected_provider="${provider_array[$prov_choice]}"
            echo ""
          else
            echo -e "${RED}✗${RESET} Invalid provider selection"
            read -p "Press Enter to continue..."
            continue
          fi
        fi
        
        # Call add_current_account with selected provider
        add_current_account "$selected_provider"
        echo ""
        read -p "Press Enter to continue..."
        ;;
      s|S)
        echo ""
        show_active
        echo ""
        read -p "Press Enter to continue..."
        ;;
      d|D)
        echo ""
        read -p "Enter account index to delete: " del_index
        if [[ "$del_index" =~ ^[0-9]+$ ]]; then
          local provider="github-copilot"
          delete_account "$provider" "$del_index"
        else
          echo -e "${RED}✗${RESET} Invalid index"
        fi
        echo ""
        read -p "Press Enter to continue..."
        ;;
      e|E)
        edit_accounts
        echo ""
        read -p "Press Enter to continue..."
        ;;
      h|H)
        show_help
        read -p "Press Enter to continue..."
        ;;
      q|Q)
        echo "Goodbye!"
        exit 0
        ;;
      *)
        echo -e "${RED}✗${RESET} Invalid choice"
        sleep 1
        ;;
    esac
  done
}

# ============================================
# Help
# ============================================

show_help() {
  echo -e "${BOLD}OpenCode Multi-Account Switcher${RESET}"
  echo ""
  echo -e "${BOLD}USAGE:${RESET}"
  echo "  oc-switch                           Interactive menu"
  echo "  oc-switch list                      List all accounts"
  echo "  oc-switch switch <provider> <index> Switch to account"
  echo "  oc-switch active [provider]         Show active account(s)"
  echo "  oc-switch add <provider>            Add current credential"
  echo "  oc-switch delete <provider> <index> Delete an account"
  echo "  oc-switch edit                      Edit accounts.json"
  echo "  oc-switch help                      Show this help"
  echo ""
  echo -e "${BOLD}EXAMPLES:${RESET}"
  echo "  oc-switch list"
  echo "  oc-switch switch github-copilot 1"
  echo "  oc-switch active"
  echo "  oc-switch add github-copilot"
  echo "  oc-switch delete github-copilot 2"
  echo ""
  echo -e "${BOLD}FILES:${RESET}"
  echo "  Config:  $ACCOUNTS_FILE"
  echo "  Auth:    $AUTH_FILE"
  echo "  Backups: $BACKUP_DIR"
  echo ""
  echo -e "${BOLD}BACKUP RETENTION:${RESET}"
  echo "  Keeps last $BACKUP_RETENTION backups automatically"
  echo ""
  echo "For more information, see: README.md"
}

# ============================================
# Main Entry Point
# ============================================

main() {
  check_dependencies
  check_files
  enforce_permissions
  
  if [[ $# -eq 0 ]]; then
    # Interactive mode
    interactive_menu
  else
    case "$1" in
      list|ls)
        list_accounts
        ;;
      switch|sw)
        if [[ $# -lt 3 ]]; then
          echo -e "${RED}✗${RESET} Error: Missing arguments"
          echo "  Usage: oc-switch switch <provider> <index>"
          exit 1
        fi
        switch_account "$2" "$3"
        ;;
      active)
        show_active "$2"
        ;;
      add)
        if [[ $# -lt 2 ]]; then
          echo -e "${RED}✗${RESET} Error: Missing provider"
          echo "  Usage: oc-switch add <provider>"
          exit 1
        fi
        add_current_account "$2"
        ;;
      delete|del|rm)
        if [[ $# -lt 3 ]]; then
          echo -e "${RED}✗${RESET} Error: Missing arguments"
          echo "  Usage: oc-switch delete <provider> <index>"
          exit 1
        fi
        delete_account "$2" "$3"
        ;;
      edit)
        edit_accounts
        ;;
      help|--help|-h)
        show_help
        ;;
      *)
        echo -e "${RED}✗${RESET} Error: Unknown command '$1'"
        echo ""
        show_help
        exit 1
        ;;
    esac
  fi
}

# Run main function
main "$@"
