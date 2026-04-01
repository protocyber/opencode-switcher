# OpenCode Multi-Account Switcher

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)
[![OpenCode](https://img.shields.io/badge/OpenCode-Compatible-green.svg)](https://opencode.ai)

🚀 Quick account switching for OpenCode without re-authentication

Switch between multiple GitHub Copilot Pro accounts (or other providers) seamlessly without needing to run `/connect` each time.

---

## 📦 Requirements

- **Bash** 4.0 or higher
- **jq** - Command-line JSON processor
- **OpenCode** - Installed and configured

### Installing jq

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# Fedora
sudo dnf install jq

# Arch Linux
sudo pacman -S jq
```

---

## 📋 Features

- ✅ **Instant Account Switching** - Switch between accounts in seconds
- ✅ **Account Management** - Add and delete accounts easily
- ✅ **Multiple Providers** - Support for GitHub Copilot (extensible to Anthropic, OpenAI, etc.)
- ✅ **Automatic Backups** - Creates backups before each switch (keeps last 5)
- ✅ **Interactive Menu** - User-friendly visual interface
- ✅ **Command-Line Interface** - Scriptable for automation
- ✅ **Security First** - File permissions enforced (600)
- ✅ **Safe Operations** - Atomic file writes with validation
- ✅ **Color Output** - Easy-to-read visual feedback

---

## 🚀 Quick Start

### Installation

> **Note:** Replace `YOUR-USERNAME` with your actual GitHub username after publishing the repository.

```bash
# Clone the repository
git clone https://github.com/YOUR-USERNAME/opencode-switcher.git
cd opencode-switcher

# Make the script executable
chmod +x switch.sh

# Create initial accounts.json
cat > accounts.json << 'EOF'
{
  "github-copilot": {
    "accounts": [],
    "active": 0
  }
}
EOF

chmod 600 accounts.json

# Optional: Create an alias for easy access
echo "alias oc-switch='$(pwd)/switch.sh'" >> ~/.bashrc  # for bash
echo "alias oc-switch='$(pwd)/switch.sh'" >> ~/.zshrc   # for zsh
source ~/.bashrc  # or source ~/.zshrc
```

### Usage

```bash
# Interactive menu (easiest way)
oc-switch

# Or use command-line
oc-switch list                      # List all accounts
oc-switch switch github-copilot 1   # Switch to account 1
oc-switch active                    # Show active account
```

---

## 📖 Commands

### Interactive Menu
```bash
oc-switch
```

Opens an interactive menu where you can:
- See all accounts with visual indicators
- Select an account by number
- View active account
- Edit accounts.json
- Access help

### List Accounts
```bash
oc-switch list
```

Shows all configured accounts:
```
GitHub Copilot accounts:
  [0] ✓ Account 1 - ACTIVE
  [1]   Account 2
  [2]   Account 3
```

### Switch Account
```bash
oc-switch switch github-copilot <index>
```

**Examples:**
```bash
# Switch to Account 2 (index 1)
oc-switch switch github-copilot 1

# Switch to Account 3 (index 2)
oc-switch switch github-copilot 2
```

**What happens:**
1. Creates a backup of current `auth.json`
2. Updates `~/.local/share/opencode/auth.json` with selected account
3. Updates active index in `accounts.json`
4. OpenCode will use the new account on next request

### Show Active Account
```bash
oc-switch active
```

Shows which account is currently active:
```
Active accounts:
  github-copilot: Account 1
```

### Add Current Account
```bash
oc-switch add github-copilot
```

Captures the current credential from `auth.json` and adds it to your account list. **The new account is automatically set as active.**

**Features:**
- ✅ **Auto-activates** - New account becomes active immediately
- ✅ **Duplicate prevention** - Won't add if credentials already exist
- ✅ **Shows previous active** - Clear feedback on what changed

**Workflow:**
1. Authenticate in OpenCode: `opencode` → `/connect`
2. Add to switcher: `oc-switch add github-copilot`
   - Automatically becomes active
   - Shows previous active account
3. **No need to switch manually!** Ready to use immediately.

**Example:**
```bash
$ oc-switch add github-copilot

Current credential in auth.json:
{
  "type": "oauth",
  "access": "gho_NEW...",
  ...
}

Add this as a new account? (y/n): y
Enter account name: Work Account
✓ Added 'Work Account' to github-copilot accounts
✓ Set as active account (was: Account 1)
✓ Total accounts: 4
```

**Duplicate Detection:**
```bash
$ oc-switch add github-copilot
✗ Error: This credential already exists
  Existing account: Work Account
  Use 'oc-switch switch github-copilot <index>' to switch to it
```

### Delete Account
```bash
oc-switch delete github-copilot <index>
```

Deletes an account from your account list. This is useful for removing accounts you no longer use.

**Examples:**
```bash
# Delete Account 3 (index 2)
oc-switch delete github-copilot 2

# Shorthand
oc-switch del github-copilot 2
oc-switch rm github-copilot 2
```

**Safety Features:**
- Requires confirmation before deletion
- Cannot delete the only account (must have at least one)
- If deleted account was active, automatically switches to first account
- If deleted account was before active, adjusts active index

**Example:**
```bash
$ oc-switch delete github-copilot 2
! About to delete: Account 3
  Provider: github-copilot
  Index: 2

Are you sure? This cannot be undone (y/n): y
✓ Deleted 'Account 3' from github-copilot accounts
✓ Remaining accounts: 2
```

### Edit Accounts
```bash
oc-switch edit
```

Opens `accounts.json` in your editor (vim by default) for manual editing.

### Help
```bash
oc-switch help
```

Shows usage information and examples.

---

## 🔧 Configuration

### File Structure

```
opencode-switcher/
├── accounts.json              # Your accounts (DO NOT COMMIT!)
├── switch.sh                  # Main script
├── backups/                   # Auto-managed backups
│   └── auth.json.backup.*     # Last 5 backups
├── .gitignore                 # Credential protection
└── README.md                  # This file
```

### accounts.json Format

```json
{
  "github-copilot": {
    "accounts": [
      {
        "name": "Account 1",
        "type": "oauth",
        "access": "gho_...",
        "refresh": "gho_...",
        "expires": 0
      },
      {
        "name": "Account 2",
        "type": "oauth",
        "access": "gho_...",
        "refresh": "gho_...",
        "expires": 0
      }
    ],
    "active": 0
  }
}
```

### Adding New Accounts

#### Method 1: Through OpenCode (Recommended)
```bash
# 1. Authenticate new account in OpenCode
opencode
> /connect
[Select GitHub Copilot and authenticate]

# 2. Add to switcher
oc-switch add github-copilot

# 3. Enter a name when prompted
Enter account name: Work Account

# 4. Done! Switch back to your previous account
oc-switch switch github-copilot 0
```

#### Method 2: Manual Editing
```bash
# 1. Open accounts.json
oc-switch edit

# 2. Add new account entry
{
  "name": "My New Account",
  "type": "oauth",
  "access": "gho_...",
  "refresh": "gho_...",
  "expires": 0
}

# 3. Save and exit
```

---

## 🔐 Security

### File Permissions

The script automatically enforces secure file permissions:
- `accounts.json` - **600** (owner read/write only)
- `~/.local/share/opencode/auth.json` - **600** (owner read/write only)

### .gitignore Protection

The `.gitignore` file prevents accidentally committing credentials:
```gitignore
accounts.json
backups/
*.backup
auth.json
```

**⚠️ IMPORTANT:** Never commit `accounts.json` to version control!

### Backup Strategy

- Backups created before each account switch
- Stored in `./backups/` (relative to installation directory)
- Automatically keeps last 5 backups
- Older backups auto-deleted to save space

**Restore a backup manually:**
```bash
# From your installation directory
cp ./backups/auth.json.backup.TIMESTAMP \
   ~/.local/share/opencode/auth.json
```

### Customizing Backup Retention

Edit `switch.sh` and change this line:
```bash
BACKUP_RETENTION=5  # Change to keep more/fewer backups
```

---

## 🔮 Future: Multi-Provider Support

The switcher is designed to support multiple providers. Here's how to add Anthropic as an example:

### Step 1: Update accounts.json

```json
{
  "github-copilot": { ... },
  "anthropic": {
    "accounts": [
      {
        "name": "Personal Claude",
        "type": "oauth",
        "access": "sk-ant-...",
        "refresh": "",
        "expires": 0
      },
      {
        "name": "Work Claude",
        "type": "oauth",
        "access": "sk-ant-...",
        "refresh": "",
        "expires": 0
      }
    ],
    "active": 0
  }
}
```

### Step 2: Use It

```bash
# List all providers
oc-switch list

GitHub Copilot accounts:
  [0] ✓ Account 1 - ACTIVE
  [1]   Account 2

Anthropic accounts:
  [0] ✓ Personal Claude - ACTIVE
  [1]   Work Claude

# Switch Anthropic account
oc-switch switch anthropic 1
```

**No script modifications needed!** The script automatically discovers providers.

---

## 🐛 Troubleshooting

### "jq is not installed"

**Solution:**
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# Fedora
sudo dnf install jq
```

### "accounts.json not found"

**Solution:**
```bash
# Check if file exists in your installation directory
ls accounts.json

# Recreate if missing
cat > accounts.json << 'EOF'
{
  "github-copilot": {
    "accounts": [],
    "active": 0
  }
}
EOF

chmod 600 accounts.json
```

### "Account has no credentials"

**Cause:** The account's `access` and `refresh` fields are empty.

**Solution:**
1. Authenticate the account in OpenCode first
2. Use `oc-switch add github-copilot` to capture credentials
3. Or manually edit `accounts.json` and add credentials

### "Invalid JSON in accounts.json"

**Solution:**
```bash
# Validate JSON syntax
jq empty accounts.json

# If errors, restore from backup (run from installation directory)
cp ./backups/auth.json.backup.LATEST ~/.local/share/opencode/auth.json

# Or fix manually
oc-switch edit
```

### "OpenCode not recognizing new account"

**Solution:**
1. Verify the switch was successful: `oc-switch active`
2. Check auth.json: `cat ~/.local/share/opencode/auth.json`
3. Restart OpenCode
4. Try re-authenticating with `/connect`

### Alias not working

**Solution:**
```bash
# Reload shell configuration
source ~/.bashrc  # for bash
source ~/.zshrc   # for zsh

# Or restart your terminal

# Check if alias exists
alias | grep oc-switch
```

---

## 📊 Examples

### Example 1: Daily Workflow

```bash
# Morning: Use personal account
oc-switch switch github-copilot 0

# Work hours: Switch to work account
oc-switch switch github-copilot 1

# Evening: Back to personal
oc-switch switch github-copilot 0
```

### Example 2: Adding a New Account

```bash
# Step 1: Check current accounts
oc-switch list

# Step 2: Authenticate new account in OpenCode
opencode
> /connect
[Authenticate with GitHub Copilot]

# Step 3: Add to switcher
oc-switch add github-copilot
Enter account name: Freelance Account

# Step 4: Verify
oc-switch list
GitHub Copilot accounts:
  [0]   Account 1
  [1]   Account 2
  [2]   Account 3
  [3] ✓ Freelance Account - ACTIVE

# Step 5: Switch back to your main account
oc-switch switch github-copilot 0
```

### Example 3: Backup Restoration

```bash
# List available backups (from installation directory)
ls -lh ./backups/

# Restore a specific backup
cp ./backups/auth.json.backup.2026-04-01_14-30-25 \
   ~/.local/share/opencode/auth.json

# Verify restoration
oc-switch active
```

---

## 📚 Advanced Usage

### Automation with Scripts

```bash
#!/bin/bash
# work-mode.sh - Switch to work environment

oc-switch switch github-copilot 1
cd ~/work-projects
opencode
```

### Checking Account Before Running

```bash
#!/bin/bash
# ensure-personal.sh - Make sure personal account is active

current=$(oc-switch active | grep "Account 1")
if [[ -z "$current" ]]; then
  echo "Switching to personal account..."
  oc-switch switch github-copilot 0
fi

opencode
```

---

## 💡 Tips

1. **Name your accounts clearly** - Use descriptive names like "Personal", "Work", "Client XYZ"
2. **Use interactive menu for visual feedback** - Just run `oc-switch` without arguments
3. **Check active account before starting work** - Run `oc-switch active` to verify
4. **Keep backup retention reasonable** - Default 5 is good for most users
5. **Don't edit accounts.json manually if unsure** - Use `oc-switch add` instead
6. **Test switches work** - After switching, verify in OpenCode with `/models`

---

## 🔄 Version History

### v1.0.0 (2026-04-01)
- Initial release
- GitHub Copilot support
- Interactive menu
- Automatic backups (keep last 5)
- Color output
- Command-line interface

---

## 📝 License

MIT License - Feel free to modify and share!

---

## 🤝 Contributing

Found a bug or have a feature request?

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Edit the script: `switch.sh`
4. Test your changes thoroughly
5. Commit your changes: `git commit -m "Add your feature"`
6. Push to the branch: `git push origin feature/your-feature`
7. Open a Pull Request

**Note:** Never commit `accounts.json` or backup files!

---

## 📞 Support

**Common Issues:**
- See [Troubleshooting](#-troubleshooting) section above
- Check OpenCode docs: https://opencode.ai/docs

**Questions:**
- OpenCode Discord: https://opencode.ai/discord
- OpenCode GitHub: https://github.com/anomalyco/opencode

---

## 🎯 Quick Reference

```bash
oc-switch                           # Interactive menu
oc-switch list                      # List accounts
oc-switch switch github-copilot 1   # Switch to account 1
oc-switch active                    # Show active account
oc-switch add github-copilot        # Add current credential
oc-switch delete github-copilot 2   # Delete account 2
oc-switch edit                      # Edit accounts.json
oc-switch help                      # Show help
```

**Files:**
- Config: `./accounts.json` (in installation directory)
- Auth: `~/.local/share/opencode/auth.json`
- Backups: `./backups/` (in installation directory)

**Happy switching! 🚀**
