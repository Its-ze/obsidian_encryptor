


#!/bin/bash

# =========================
# Obsidian Encryptor Script
# =========================
#
# This script securely backs up and syncs your Obsidian vault using encryption and Git.
#
# Supported Environments:
#   - Linux
#   - macOS
#   - Windows (via WSL or Git Bash)
#
# Not Supported:
#   - Windows PowerShell or Command Prompt (cmd.exe)
#
# Windows Setup:
#   - Install Git Bash: https://gitforwindows.org/
#   - Or use WSL: https://docs.microsoft.com/en-us/windows/wsl/
#   - Install dependencies with Chocolatey (https://chocolatey.org/) or Scoop (https://scoop.sh/):
#       choco install git gnupg nano tar pigz gh
#       or
#       scoop install git gpg nano tar pigz gh
#
# The script will check your environment and dependencies before running.

# Detect if running in Git Bash, WSL, or Unix-like shell
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" && "$OSTYPE" != "linux-gnu"* && "$OSTYPE" != "darwin"* ]]; then
  echo "This script must be run in Git Bash, WSL, or a Unix-like shell. Exiting."
  exit 1
fi


# Define paths
CONFIG_DIR="$HOME/.obsidian_vault_manager"  # Directory to store configuration
CONFIG_FILE="$CONFIG_DIR/vault_path.txt"  # File to store the vault path
GIT_CONFIG_FILE="$CONFIG_DIR/git_repo_path.txt"  # File to store the Git repository path
ENCRYPTED_ARCHIVE="vault.tar.gz.gpg"  # Name of the encrypted archive file

# Function to check for required programs
check_required_programs() {
  REQUIRED_PROGRAMS=("git" "gpg" "nano" "tar" "pigz" "gh")
  for program in "${REQUIRED_PROGRAMS[@]}"; do
    if ! command -v "$program" &> /dev/null; then
      echo "Error: $program is not installed. Please install it manually."
      if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "On Windows, you can use Chocolatey (https://chocolatey.org/) or Scoop (https://scoop.sh/) to install missing tools."
        echo "Example: choco install $program   or   scoop install $program"
      fi
      MISSING=1
    fi
  done
  if [ "$MISSING" = "1" ]; then
    echo "One or more required programs are missing. Exiting."
    exit 1
  fi
}

# Function to get or set the vault path
get_or_set_vault_path() {
  if [ -f "$CONFIG_FILE" ]; then
    VAULT_PATH=$(<"$CONFIG_FILE")
    echo "Previous vault path found: $VAULT_PATH"
    read -rp "Would you like to use this path? (y/n): " use_previous
    if [[ "$use_previous" == "y" || "$use_previous" == "Y" ]]; then
      echo "Using previously saved vault path."
    else
      read -rp "Enter the path to your Obsidian vault: " VAULT_PATH
      while [ ! -d "$VAULT_PATH" ]; do
        echo "Invalid path. Please enter a valid directory."
        read -rp "Enter the path to your Obsidian vault: " VAULT_PATH
      done
      mkdir -p "$CONFIG_DIR"
      echo "$VAULT_PATH" > "$CONFIG_FILE"
      echo "Vault path saved."
    fi
  else
    read -rp "Enter the path to your Obsidian vault: " VAULT_PATH
    while [ ! -d "$VAULT_PATH" ]; do
      echo "Invalid path. Please enter a valid directory."
      read -rp "Enter the path to your Obsidian vault: " VAULT_PATH
    done
    mkdir -p "$CONFIG_DIR"
    echo "$VAULT_PATH" > "$CONFIG_FILE"
    echo "Vault path saved."
  fi

  # Ask to set Git repository path
  if [ ! -f "$GIT_CONFIG_FILE" ]; then
    GIT_REPO_PATH="$HOME/new_git_repo"
    mkdir -p "$GIT_REPO_PATH"
    cd "$GIT_REPO_PATH" || exit
    git init
    echo "Initialized new Git repository at $GIT_REPO_PATH."
    mkdir -p "$CONFIG_DIR"
    echo "$GIT_REPO_PATH" > "$GIT_CONFIG_FILE"
    echo "Git repository path saved."
    # Create a new private repository on GitHub using the GitHub CLI
    read -rp "Enter the name for the GitHub repository: " REPO_NAME
    gh repo create "$REPO_NAME" --private --source="$GIT_REPO_PATH" --remote=origin
    echo "Created new private repository on GitHub: $REPO_NAME"
  else
    GIT_REPO_PATH=$(<"$GIT_CONFIG_FILE")
    echo "Previous Git repository path found: $GIT_REPO_PATH"
    read -rp "Would you like to use this path? (y/n): " use_previous_repo
    if [[ "$use_previous_repo" != "y" && "$use_previous_repo" != "Y" ]]; then
      GIT_REPO_PATH="$HOME/new_git_repo"
      mkdir -p "$GIT_REPO_PATH"
      cd "$GIT_REPO_PATH" || exit
      git init
      echo "Initialized new Git repository at $GIT_REPO_PATH."
      mkdir -p "$CONFIG_DIR"
      echo "$GIT_REPO_PATH" > "$GIT_CONFIG_FILE"
      echo "Git repository path saved."
      # Create a new private repository on GitHub using the GitHub CLI
      read -rp "Enter the name for the GitHub repository: " REPO_NAME
      gh repo create "$REPO_NAME" --private --source="$GIT_REPO_PATH" --remote=origin
      echo "Created new private repository on GitHub: $REPO_NAME"
    fi
  fi
}

# Check if user is logged in to Git
check_git_login() {
  if ! git config --global user.name &> /dev/null || ! git config --global user.email &> /dev/null; then
    echo "Git is not fully configured. Please login to Git."
    read -rp "Enter your Git username: " GIT_USERNAME
    git config --global user.name "$GIT_USERNAME"
    read -rp "Enter your Git email: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
    echo "Git configuration complete."
  else
    echo "Git is already configured with the following details:"
    echo "Username: $(git config --global user.name)"
    echo "Email: $(git config --global user.email)"
  fi
}

# Function to initialize Git repository if not found
initialize_git_repo() {
  if [ ! -d "$GIT_REPO_PATH/.git" ]; then
    echo "The specified directory is not a Git repository."
    git init "$GIT_REPO_PATH"
    echo "Git repository initialized at $GIT_REPO_PATH."
    echo "$GIT_REPO_PATH" > "$GIT_CONFIG_FILE"
    echo "Git repository path updated in configuration."
  fi
}

# Function to encrypt and push to Git
encrypt_and_push() {
  while true; do
    # Use a cross-platform temp directory
    if [[ -n "$TMPDIR" ]]; then
      TEMP_FILE=$(mktemp "$TMPDIR/encryption_key.XXXXXX")
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
      TEMP_FILE=$(mktemp "/tmp/encryption_key.XXXXXX")
    else
      TEMP_FILE=$(mktemp "/tmp/encryption_key.XXXXXX")
    fi
    read -rsp "Enter encryption key: " ENCRYPTION_KEY
    echo
    read -rsp "Confirm encryption key: " ENCRYPTION_KEY_CONFIRM
    echo

    if [ "$ENCRYPTION_KEY" != "$ENCRYPTION_KEY_CONFIRM" ]; then
      echo "Encryption keys do not match. Please try again."
    else
      break
    fi
  done

  # Create a tar archive of the vault and encrypt it
  tar --use-compress-program=pigz -cf - "$VAULT_PATH" | gpg --yes --symmetric --cipher-algo AES256 --batch --passphrase "$ENCRYPTION_KEY" -o "$GIT_REPO_PATH/$ENCRYPTED_ARCHIVE"

  # Check if tar and encryption were successful
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create encrypted archive. Please check your inputs and try again."
    return
  fi

  # Move to the Git folder, add, commit, and push changes
  cd "$GIT_REPO_PATH" || exit
  git add -A
  if ! git diff-index --quiet HEAD --; then
    git commit -m "Update encrypted vault $(date)"
  else
    echo "No changes to commit."
  fi

  # Check if a remote is set up
  if ! git remote | grep -q "origin"; then
    read -rp "Enter the URL of the remote repository to push to (or press Enter to skip): " REMOTE_URL
    if [ -n "$REMOTE_URL" ]; then
      git remote add origin "$REMOTE_URL"
    else
      echo "No remote repository set. You will need to set this manually before pushing."
      return
    fi
  else
    echo "Remote repository already set."
  fi

  # Convert remote URL to SSH if it's using HTTPS
  CURRENT_URL=$(git remote get-url origin)
  if [[ "$CURRENT_URL" == https://* ]]; then
    SSH_URL=$(echo "$CURRENT_URL" | sed -e 's/https:\/\/github.com\//git@github.com:/')
    git remote set-url origin "$SSH_URL"
    echo "Converted remote URL to SSH: $SSH_URL"
  fi

  # Push to remote repository
  git push -u origin $(git rev-parse --abbrev-ref HEAD)
}

# Function to pull from Git and decrypt
decrypt_and_pull() {
  while true; do
    read -rsp "Enter decryption key: " DECRYPTION_KEY
    echo
    read -rsp "Confirm decryption key: " DECRYPTION_KEY_CONFIRM
    echo

    if [ "$DECRYPTION_KEY" != "$DECRYPTION_KEY_CONFIRM" ]; then
      echo "Decryption keys do not match. Please try again."
    else
      break
    fi
  done

  # Move to the Git folder and pull the latest changes
  cd "$GIT_REPO_PATH" || exit
  git pull origin $(git rev-parse --abbrev-ref HEAD)

  # Decrypt the archive and extract it
  gpg --decrypt --batch --passphrase "$DECRYPTION_KEY" "$GIT_REPO_PATH/$ENCRYPTED_ARCHIVE" | tar -xzf - -C "$VAULT_PATH"

  # Check if decryption was successful
  if [ $? -ne 0 ]; then
    echo "Error: Failed to decrypt the archive. Please check your decryption key and try again."
  fi
}

# Function to display a text-based GUI
display_menu() {
  while true; do
    echo "----------------------------------------"
    echo "|         Obsidian Vault Manager       |"
    echo "----------------------------------------"
    echo "Select an option:"
    echo "1) Encrypt and push to Git"
    echo "2) Pull from Git and decrypt"
    echo "3) Reconfigure settings"
    echo "4) Exit"
    echo "----------------------------------------"
    read -rp "Enter choice [1-4]: " choice

    case $choice in
      1)
        check_git_login
        initialize_git_repo
        encrypt_and_push
        ;;
      2)
        check_git_login
        initialize_git_repo
        decrypt_and_pull
        ;;
      3)
        get_or_set_vault_path
        ;;
      4)
        echo "Exiting."
        exit 0
        ;;
      *)
        echo "Invalid option. Please enter 1, 2, 3, or 4."
        ;;
    esac
  done
}

# Check for required programs
check_required_programs

# Get or set the vault path
get_or_set_vault_path

# Run the menu
display_menu
