#!/usr/bin/env bash

function header_info {
  clear
  cat <<"EOF"
   ___  __  ___  _   ___________        ____
  / _ )/  |/  / | | / / __/ ___/ ____  / __/__ _____  _____ ____
 / _  / /|_/ /  | |/ /\ \/ /__  /___/ _\ \/ -_) __/ |/ / -_) __/
/____/_/  /_/   |___/___/\___/       /___/\__/_/  |___/\__/_/   


EOF
}
header_info

PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
if ! id "vscode" &>/dev/null; then
  echo -e "\033[33mCreating 'vscode' user...\033[0m"
  useradd -m -s /bin/bash vscode
  echo "vscode:$PASSWORD" | chpasswd
fi

echo -e "\033[33mInstalling pre-reqs...\033[0m"
apt install -y dbus-user-session dbus-x11

echo -e "\033[33mChanging to directory /opt...\033[0m"
cd /opt

echo -e "\033[33mCreating VSC-Server Directory...\033[0m"
mkdir vsc-server
cd /opt/vsc-server

echo -e "\033[33mDownloading VSC Server...\033[0m"
curl -Ls 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz

echo -e "\033[33mDecompressing Package...\033[0m"
tar -xf vscode_cli.tar.gz

# Fix ownership
chown -R vscode:vscode /opt/vsc-server
chown -R vscode:vscode /home/vscode

# Ensure vscode user's home directory is correct
export HOME=/home/vscode
HOSTNAME=$(hostname)

echo -e "\033[33mStarting code tunnel service installation as vscode user...\033[0m"

# Run the code tunnel command with disabled buffering and capture the output line by line
stdbuf -o0 sudo -u vscode -i /opt/vsc-server/code tunnel user login --provider github --name "$HOSTNAME" | while read -r line; do
  echo "$line"
  
  # Check for the URL in the output
  if [[ "$line" =~ "Open this link in your browser https://vscode.dev/tunnel/$HOSTNAME" ]]; then
    echo -e "\033[32mURL detected: https://vscode.dev/tunnel/$HOSTNAME\033[0m"
    
    # Kill the code tunnel process once the URL is detected
    pkill -f "/opt/vsc-server/code tunnel"
    break
  fi
done

# Continue with systemd service setup after killing the process
echo -e "\033[33mSetting up systemd service...\033[0m"

# Set up the systemd service for the VSC server
cat <<EOF > /etc/systemd/system/vsc-server.service
[Unit]
Description=Visual Studio Code Server
After=network.target
 
[Service]
User=vscode
ExecStart=/opt/vsc-server/code tunnel
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable vsc-server.service
systemctl start vsc-server.service

# Check if the service is active
if systemctl is-active --quiet vsc-server.service; then
  echo -e "\033[32mSystemd process created and running. Installation complete.\033[0m"
else
  echo -e "\033[31mFailed to start the vsc-server service. Please check the logs.\033[0m"
fi
