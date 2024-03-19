#!/bin/bash

# Exit if not run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

# Loop through arguments
for arg in "$@"
do
  # Split argument into name and value
  key=$(echo $arg | cut -f1 -d= | sed 's/--//')
  value=$(echo $arg | cut -f2 -d=)

  # Convert key to uppercase and remove dashes
  varname=$(echo $key | tr '[:lower:]' '[:upper:]' | tr '-' '_')

  # Declare a dynamic variable with the name and value
  declare "$varname=$value"
done

if [ -z "$USERNAME" ]; then
    echo "Error: USERNAME is not set."
    exit 1
fi

if [ -z "$GIT" ]; then
    echo "Error: GIT is not set."
    exit 1
fi


if [ -z "$SERVER_NAME" ]; then
    echo "Error: SERVER_NAME is not set."
    exit 1
fi

DEST_FOLDERNAME="${DEST:-www}";
DEST_FOLDER="/home/$USERNAME/$DEST_FOLDERNAME"

###########################################################################
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
###########################################################################
echo "###### ###### Apache"
#!/bin/bash

# Check if Apache is installed (apache2 for Debian/Ubuntu, httpd for Red Hat/CentOS)
if ! command -v apache2 >/dev/null 2>&1 && ! command -v httpd >/dev/null 2>&1; then
    echo "Apache is not installed. Installing..."

    # Detect the package management system and install Apache
    if [ -f /etc/debian_version ]; then
        # Debian-based distributions (Debian, Ubuntu, etc.)
        sudo apt update
        sudo apt install apache2 -y
    elif [ -f /etc/redhat-release ]; then
        # Red Hat-based distributions (RHEL, CentOS, Fedora, etc.)
        sudo yum update
        sudo yum install httpd -y
    else
        echo "Unsupported Linux distribution."
        exit 1
    fi

    ufw allow 'Apache'
    ufw allow OpenSSH
    ufw enable
    echo "Apache has been installed successfully."
else
    echo "Apache is already installed."
    systemctl status apache2    
fi


###########################################################################
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
###########################################################################
echo "###### ###### Durée de sessions"

read -r -d '' TEXT << 'EOF'
ClientAliveInterval 120
ClientAliveCountMax 720
EOF
UNIQUE_IDENTIFIER="ClientAliveCountMax 720"

# File to check and append to
FILE="/etc/ssh/sshd_config"

# Check if the text is already in the file
if ! grep -qF "$UNIQUE_IDENTIFIER" "$FILE"; then
    # If not, append the text
    echo "$TEXT" >> "$FILE"
    echo "OK"
fi

###########################################################################
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
###########################################################################

echo "###### ###### Hostname $SERVER_NAME"
sudo hostnamectl set-hostname $SERVER_NAME



###########################################################################
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
###########################################################################
echo "###### ###### User $USERNAME"
adduser $USERNAME

usermod -aG sudo $USERNAME

# Temporary file
TMP_FILE=$(mktemp)

# Sudoers file location
SUDOERS_FILE="/etc/sudoers"

# Backup original sudoers file
cp $SUDOERS_FILE "$SUDOERS_FILE.bak"

# Replace the specified line
sed 's/ALL=(ALL:ALL) ALL/ALL=(ALL:ALL) NOPASSWD:ALL/' "$SUDOERS_FILE.bak" > $TMP_FILE

# Check syntax of the new sudoers file
visudo -c -f $TMP_FILE
if [ $? -eq 0 ]; then
    # Syntax is okay, replace the original file
    cp $TMP_FILE $SUDOERS_FILE
    echo "Sudoers file updated successfully."
else
    echo "Error: Syntax check failed. Changes not applied."
fi

# Clean up temporary file
rm $TMP_FILE


###########################################################################
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
###########################################################################
echo "###### ###### Clé SSH"
KEY_PATH="/home/$USERNAME/.ssh/id_ed25519";
if [ ! -f "$KEY_PATH" ]; then
  ssh-keygen -t ed25519 -C "$SERVER_NAME" -f "$KEY_PATH" -N ''
fi
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/authorized_keys
cp /home/ubuntu/.ssh/authorized_keys /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys



###########################################################################
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
###########################################################################
echo "###### ###### VHOST"
read -r -d '' VHOST << EOF
<VirtualHost *:80>
        ServerName $SERVER_NAME
        ServerAdmin contact@lorraine.fun
        DocumentRoot $DEST_FOLDER

        <Directory $DEST_FOLDER>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>

        ErrorLog \${APACHE_LOG_DIR}/$SERVER_NAME-error.log
        CustomLog \${APACHE_LOG_DIR}/$SERVER_NAME-access.log combined

</VirtualHost>
EOF

VHOST_FILE="/etc/apache2/sites-available/$SERVER_NAME.conf"
echo "$VHOST" > $VHOST_FILE
a2ensite $SERVER_NAME
systemctl reload apache2

###########################################################################
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
###########################################################################
echo "###### ###### GIT"
if [ ! -f "$DEST_FOLDER" ]; then
  echo "Depot already cloned"
else
  sudo -u "$USERNAME" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone "$GIT" "$DEST_FOLDER"
fi
