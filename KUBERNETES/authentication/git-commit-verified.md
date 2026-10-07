```bash
# =============================
# 1) Install GPG + Tools
# =============================
sudo apt update
sudo apt install gnupg pinentry-curses -y

# =============================
# 2) Generate a GPG Key (4096-bit RSA)
# =============================
gpg --full-generate-key
# Choose:
#   1) RSA and RSA
#   Keysize: 4096
#   Expiry: Optional (or never)
#   Name + email = GitHub email
#   Create a passphrase

# =============================
# 3) List the Secret Keys
# =============================
gpg --list-secret-keys --keyid-format=long
# Copy the KEYID after the slash e.g. ABCDEF1234567890

# =============================
# 4) Export Public Key & Add to GitHub
# =============================
gpg --armor --export <KEYID>
# Copy output:
# -----BEGIN PGP PUBLIC KEY BLOCK-----
# ...
# -----END PGP PUBLIC KEY BLOCK-----

# GitHub → Settings → SSH & GPG keys → New GPG key → Paste → Save

# =============================
# 5) Configure Git to Sign Commits
# =============================
git config --global user.signingkey <KEYID>
git config --global commit.gpgsign true
git config --global tag.gpgsign true

git config --global user.name "YOUR NAME"
git config --global user.email "your-github-email@example.com"

# =============================
# 6) Fix Pinentry Error (Terminal Passphrase Prompt)
# =============================
echo 'pinentry-program /usr/bin/pinentry-curses' >> ~/.gnupg/gpg-agent.conf

# Restart agent
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

# Export TTY so GPG knows where to prompt
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
source ~/.bashrc

# =============================
# 7) Test GPG Signing
# =============================
echo "hello" | gpg --clearsign
# If works, commit signing will work

# =============================
# 8) Create or Edit a File
# =============================
touch file1
git add .

# =============================
# 9) Make a Signed Commit
# =============================
git commit -S -m "working signed commit"

# =============================
# 10) Push to GitHub
# =============================
git push
# GitHub will show: ✔ Verified
```