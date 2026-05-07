#!/bin/bash

# =========================================
# ownCloud Auto Installer für Debian 11/12
# =========================================

echo "========================================="
echo " ownCloud Installation startet..."
echo "========================================="

sleep 2

# Root prüfen
if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root ausführen:"
  echo "sudo bash installer.sh"
  exit
fi

# Daten abfragen
read -p "ownCloud Datenbank Name [owncloud]: " DB_NAME
DB_NAME=${DB_NAME:-owncloud}

read -p "Datenbank Benutzer [ownclouduser]: " DB_USER
DB_USER=${DB_USER:-ownclouduser}

read -s -p "Datenbank Passwort: " DB_PASS
echo ""

# System updaten
echo "System wird aktualisiert..."
apt update && apt upgrade -y

# Pakete installieren
echo "Installiere benötigte Pakete..."

apt install -y apache2 mariadb-server libapache2-mod-php \
php php-gd php-json php-mysql php-curl php-mbstring \
php-intl php-imagick php-xml php-zip unzip wget curl \
apt-transport-https software-properties-common ca-certificates

# Dienste starten
systemctl enable apache2
systemctl start apache2

systemctl enable mariadb
systemctl start mariadb

# Debian Version erkennen
DEBIAN_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2 | cut -d '.' -f1)

echo "Debian Version erkannt: $DEBIAN_VERSION"

# ownCloud Key herunterladen
wget -nv https://download.owncloud.com/download/repositories/production/Debian_${DEBIAN_VERSION}/Release.key -O Release.key

# GPG Key hinzufügen
gpg --dearmor -o /etc/apt/trusted.gpg.d/owncloud.gpg Release.key

# Repository hinzufügen
echo "deb http://download.owncloud.com/download/repositories/production/Debian_${DEBIAN_VERSION}/ /" > /etc/apt/sources.list.d/owncloud.list

# Repository aktualisieren
apt update

# ownCloud installieren
echo "Installiere ownCloud..."
apt install -y owncloud-complete-files

# Datenbank erstellen
echo "Erstelle Datenbank..."

mysql -u root <<EOF
CREATE DATABASE ${DB_NAME};
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Apache Module aktivieren
a2enmod rewrite headers env dir mime ssl

# Rechte setzen
chown -R www-data:www-data /var/www/owncloud
chmod -R 755 /var/www/owncloud

# Firewall freigeben
if command -v ufw >/dev/null 2>&1; then
    ufw allow 80
    ufw allow 443
fi

# Apache neustarten
systemctl restart apache2

# IP Adresse holen
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "========================================="
echo " ownCloud wurde erfolgreich installiert!"
echo "========================================="
echo ""
echo "Öffne jetzt im Browser:"
echo "http://$IP/owncloud"
echo ""
echo "Datenbank:"
echo "DB Name: $DB_NAME"
echo "DB User: $DB_USER"
echo ""
echo "Installation abgeschlossen."
