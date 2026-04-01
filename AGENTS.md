# Agent Instructions for OpenCode Multi-Account Switcher

This document provides coding guidelines and project conventions for AI coding agents working in this repository.

## Project Overview

**Type:** Bash shell utility script  
**Purpose:** Multi-account credential switcher for OpenCode providers  
**Language:** Bash 4.0+  
**Dependencies:** `jq` (JSON processor)

## Running Commands

### Execution
```bash
# Run the script
./switch.sh                          # Interactive menu
./switch.sh list                     # List accounts
./switch.sh switch github-copilot 1  # Switch account
./switch.sh help                     # Show help

# Via alias (if configured)
oc-switch
```

### Testing
**No formal test framework.** Test manually by:
```bash
# Test basic functionality
./switch.sh list                     # Should show accounts
./switch.sh active                   # Should show active account
./switch.sh switch github-copilot 0  # Should switch successfully

# Test error handling
./switch.sh switch invalid-provider 0   # Should fail gracefully
./switch.sh switch github-copilot 999   # Should fail with clear error
```

### Validation
```bash
# Check for syntax errors
bash -n switch.sh

# Validate JSON files
jq empty accounts.json
jq empty ~/.local/share/opencode/auth.json

# Check dependencies
command -v jq >/dev/null || echo "jq missing"

# Verify permissions
ls -l accounts.json    # Should be 600 (rw-------)
```

### Development Workflow
```bash
# Make script executable
chmod +x switch.sh

# Edit safely
cp switch.sh switch.sh.backup
vim switch.sh

# Test changes
./switch.sh list

# Restore if needed
mv switch.sh.backup switch.sh
```

## Code Style Guidelines

### File Organization

Structure scripts with clear section headers:
```bash
# ============================================
# Section Name
# ============================================
```

Standard sections (in order):
1. Configuration (constants, file paths)
2. Color Codes (with TTY detection)
3. Helper Functions (validation, checks)
4. Core Functions (business logic)
5. Interactive Menu
6. Help/Usage
7. Main Entry Point

### Naming Conventions

**Functions:** `snake_case`
```bash
check_dependencies()
get_account_count()
switch_account()
```

**Variables:**
- Constants: `UPPER_CASE` (e.g., `AUTH_FILE`, `BACKUP_RETENTION`)
- Local variables: `snake_case` (e.g., `account_name`, `temp_file`)
- Always use `local` for function variables

**Files:**
- Scripts: `kebab-case.sh` (e.g., `switch.sh`)
- Data files: `lowercase.json` (e.g., `accounts.json`)

### Formatting

**Indentation:** 2 spaces (no tabs)

**Conditionals:**
```bash
# Good
if [[ -f "$file" ]]; then
  echo "Found"
fi

# Also acceptable for simple checks
[[ -f "$file" ]] && echo "Found"
```

**Loops:**
```bash
# Prefer while read for processing lines
while IFS= read -r line; do
  process "$line"
done <<< "$output"
```

**Functions:**
```bash
function_name() {
  local param=$1
  
  # Early validation/returns
  if [[ -z "$param" ]]; then
    echo "Error: param required"
    return 1
  fi
  
  # Main logic
  do_work "$param"
  
  return 0  # Explicit return codes
}
```

### Error Handling

**Always validate inputs:**
```bash
# Check required parameters
if [[ -z "$provider" ]] || [[ -z "$index" ]]; then
  echo -e "${RED}✗${RESET} Error: provider and index required"
  return 1
fi

# Validate bounds
local count=$(get_account_count "$provider")
if [[ $index -lt 0 ]] || [[ $index -ge $count ]]; then
  echo -e "${RED}✗${RESET} Error: Invalid index $index (valid: 0-$((count-1)))"
  return 1
fi
```

**Use return codes consistently:**
- `0` = success
- `1` = error
- Always check return codes for critical operations

**Atomic file operations:**
```bash
# ALWAYS write to temp file first, validate, then move
local temp_file=$(mktemp)
jq '.' "$ACCOUNTS_FILE" > "$temp_file"

if validate_json "$temp_file"; then
  mv "$temp_file" "$ACCOUNTS_FILE"
  chmod 600 "$ACCOUNTS_FILE"
else
  rm -f "$temp_file"
  return 1
fi
```

### Security Best Practices

**File permissions:**
```bash
# Enforce 600 on credential files
chmod 600 "$ACCOUNTS_FILE"
chmod 600 "$AUTH_FILE"
```

**Secure JSON validation:**
```bash
validate_json() {
  local file=$1
  if ! jq empty "$file" 2>/dev/null; then
    echo -e "${RED}✗${RESET} Error: Invalid JSON in $file"
    return 1
  fi
  return 0
}
```

**Never commit credentials:**
- All credential files are in `.gitignore`
- Backups directory is gitignored
- Always verify `.gitignore` when adding new credential storage

### User Interaction

**Visual feedback with symbols:**
- ✓ Success (`${GREEN}✓${RESET}`)
- ✗ Error (`${RED}✗${RESET}`)
- ! Warning (`${YELLOW}!${RESET}`)
- ℹ Info (`${CYAN}ℹ${RESET}`)

**Color usage:**
```bash
# Detect TTY for color support
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  # ...
else
  GREEN='' RED=''  # No colors for pipes
fi
```

**Confirmations for destructive operations:**
```bash
read -p "Delete account '$name'? This cannot be undone. (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  echo "Cancelled."
  return 0
fi
```

### JSON Manipulation

**Always use `jq` for JSON operations:**
```bash
# Read
local value=$(jq -r '.provider.field' "$file")

# Check existence
if jq -e ".\"$provider\"" "$file" &>/dev/null; then
  echo "Provider exists"
fi

# Build JSON
local new_json=$(jq -n \
  --arg name "$account_name" \
  --argjson data "$account_data" \
  '{provider: {name: $name, data: $data}}')

# Modify
jq ".\"$provider\".active = $index" "$file" > "$temp_file"
```

## Important Notes

- **Backups:** Always call `backup_auth()` before modifying `auth.json`
- **Validation:** Always validate JSON before moving temp files to final location
- **Dependencies:** Check `jq` is installed at script start
- **Permissions:** Enforce 600 on all credential files
- **Idempotency:** Operations should be safe to run multiple times
- **Atomic writes:** Use temp files + validate + move pattern
- **Error messages:** Include context and suggest fixes
- **Documentation:** Update README.md for user-facing changes

## Common Pitfalls to Avoid

❌ Don't use `cat` to pipe to `jq` - use `jq` directly on file  
❌ Don't modify files in place - always use temp file + atomic move  
❌ Don't skip JSON validation after generating new content  
❌ Don't forget to enforce file permissions after creating/modifying credential files  
❌ Don't use single brackets `[ ]` - prefer double brackets `[[ ]]` for conditionals  
❌ Don't forget to handle missing files gracefully  
❌ Don't commit any credential files or backups  

## Version

Current version: 1.0.0 (see `switch.sh` header)
