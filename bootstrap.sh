#!/usr/bin/env bash
# Первичная настройка чистого Ubuntu 24.04 / Debian 12 VPS под beg-deals.
# Запуск от root:  bash bootstrap.sh <username> "<ssh-публичный-ключ>"
set -euo pipefail

USER_NAME="${1:?usage: bootstrap.sh <username> \"<ssh-ed25519 ...>\"}"
PUBKEY="${2:?нужен публичный SSH-ключ}"

export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get -y upgrade
apt-get -y install ca-certificates curl ufw fail2ban unattended-upgrades

# пользователь с sudo и ключом
id "$USER_NAME" &>/dev/null || adduser --disabled-password --gecos "" "$USER_NAME"
usermod -aG sudo "$USER_NAME"
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$USER_NAME"
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
echo "$PUBKEY" > "/home/$USER_NAME/.ssh/authorized_keys"
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"

# SSH: только ключи, без root. Имя 00-*, т.к. sshd берёт ПЕРВОЕ значение,
# а cloud-init у хостеров кладёт 50-cloud-init.conf с PasswordAuthentication yes
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
sshd -t && (systemctl reload ssh || systemctl reload sshd)

# firewall: наружу нужен только SSH (бот сам ходит в API, входящих портов не надо)
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw --force enable

# автообновления безопасности
dpkg-reconfigure -f noninteractive unattended-upgrades

# Docker из официального репозитория
install -m 0755 -d /etc/apt/keyrings
. /etc/os-release
curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker "$USER_NAME"

# swap 2 ГБ — на маленьких VPS спасает от OOM при сборке образа
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

timedatectl set-timezone Europe/Belgrade
echo "Готово. Проверь вход:  ssh $USER_NAME@<ip>  — и только потом закрывай root-сессию."
