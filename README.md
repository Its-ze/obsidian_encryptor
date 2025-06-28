
# obsidian_encryptor

## Overview

`Obsidian_Encrypt.sh` is a Bash script that helps you securely back up and synchronize your Obsidian vault using encryption and Git. It provides a simple text-based menu to encrypt your vault, push it to a private GitHub repository, and pull/decrypt it when needed.

## Features

- Encrypts your entire Obsidian vault using GPG (AES256)
- Stores the encrypted archive in a Git repository
- Pushes/pulls the encrypted archive to/from a private GitHub repo
- Simple interactive menu for all operations
- Remembers your vault and repo paths for convenience
- Checks for required dependencies and helps install them

## Requirements

- Bash (Linux/macOS)
- git
- gpg
- nano
- tar
- pigz
- gh (GitHub CLI)

## Setup & Usage

1. **Clone or download this repository.**
2. **Run the script:**
   ```bash
   bash Obsidian_Encrypt.sh
   ```
3. **Follow the prompts:**
   - Set your Obsidian vault path (only once, or when reconfiguring)
   - Set up a new or existing GitHub repository (private recommended)
   - Configure Git if not already done
   - Choose to encrypt/push or pull/decrypt your vault

## Menu Options

1. **Encrypt and push to Git**: Compresses and encrypts your vault, then commits and pushes to your GitHub repo.
2. **Pull from Git and decrypt**: Pulls the latest encrypted archive from GitHub and decrypts it into your vault folder.
3. **Reconfigure settings**: Change your vault or repository paths.
4. **Exit**

## Security Notes

- Your encryption key is never stored. Remember it!
- The script uses symmetric GPG encryption (AES256).
- Always use a private repository for your encrypted vault.

## Troubleshooting

- If a required program is missing, the script will prompt to install it (using `pacman`).
- If you forget your encryption key, you cannot decrypt your vault backup.

## License

MIT License. See `LICENSE` if present.