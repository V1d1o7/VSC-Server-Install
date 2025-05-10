#!/usr/bin/env bash

function header_info {
  clear
  cat <<"EOF"

 _    _______ ______            _____                          
| |  / / ___// ____/           / ___/___  ______   _____  _____
| | / /\__ \/ /      ______    \__ \/ _ \/ ___/ | / / _ \/ ___/
| |/ /___/ / /___   /_____/   ___/ /  __/ /   | |/ /  __/ /    
|___//____/\____/            /____/\___/_/    |___/\___/_/     
                                                                 


EOF
}
header_info

PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
if ! id "vscode" &>/dev/null; then
  echo -e "\033[33mCreating 'vscode' user...\033[0m"
  useradd -m -s /bin/bash vscode
  usermod -aG www-data vscode
  echo "vscode:$PASSWORD" | chpasswd
fi

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
# Run the installation as vscode user and allow interaction via CLI
sudo -u vscode -i sh -c 'stdbuf -o0 /opt/vsc-server/code tunnel --name $HOSTNAME' user login --provider github | while read line; do
  echo "$line"
  
  # Check for the URL in the output
  if [[ "$line" =~ "Open this link in your browser https://vscode.dev/tunnel/$HOSTNAME" ]]; then
    # Once URL is detected, terminate the process
    echo -e "\033[32mTerminating code tunnel process to proceed...\033[0m"
    pkill -f "/opt/vsc-server/code tunnel"
    
    break
  fi
done

echo -e "\033[33mSetting up systemd file...\033[0m"
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
