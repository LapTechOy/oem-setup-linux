#!/bin/bash
# /usr/local/sbin/oem-setup-apply.sh
# Ajetaan rootina sudon kautta. Saa argumentit oem-setup.sh:lta.
# Käyttö: oem-setup-apply.sh <username> <locale>

set -euo pipefail

USERNAME="$1"
LOCALE="$2"
SETUP_USER="setup"
CLEANUP_SERVICE="oem-cleanup"

# --- Validointi ---
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo "Virheellinen käyttäjänimi: $USERNAME" >&2
    exit 1
fi
if id "$USERNAME" &>/dev/null; then
    echo "Käyttäjä on jo olemassa: $USERNAME" >&2
    exit 1
fi
case "$LOCALE" in
    fi_FI.UTF-8|sv_SE.UTF-8|en_US.UTF-8) ;;
    *) echo "Virheellinen locale: $LOCALE" >&2; exit 1 ;;
esac

#  Lue salasana stdinistä 
IFS= read -r PASSWORD

# --- Luo käyttäjä ---
if command -v adduser &>/dev/null && adduser --help 2>&1 | grep -q -- "--gecos"; then
    adduser --gecos "" --disabled-password "$USERNAME"
else
    useradd -m -c "" -s /bin/bash "$USERNAME"
fi
echo "$USERNAME:$PASSWORD" | chpasswd
unset PASSWORD
# sudo-ryhmä Debianissa, wheel Fedorassa/Archissa
if getent group sudo &>/dev/null; then
    usermod -aG sudo "$USERNAME"
elif getent group wheel &>/dev/null; then
    usermod -aG wheel "$USERNAME"
fi

#  Aseta kieli 
# Yritä generoida locale, jos mahdollista
if command -v locale-gen &>/dev/null; then
    locale-gen "$LOCALE" || echo "Varoitus: locale-gen epäonnistui, jatketaan." >&2
elif command -v localedef &>/dev/null; then
    LOCALE_BASE="${LOCALE%%.*}"
    LOCALE_CHARSET="${LOCALE##*.}"
    localedef -i "$LOCALE_BASE" -f "$LOCALE_CHARSET" "$LOCALE" \
        || echo "Varoitus: localedef epäonnistui, jatketaan." >&2
fi
if command -v update-locale &>/dev/null; then
    update-locale LANG="$LOCALE"
elif command -v localectl &>/dev/null; then
    localectl set-locale LANG="$LOCALE"
fi

#  Poista autologin 
if [ -f /etc/lightdm/lightdm.conf ]; then
    # LightDM
    sed -i 's/^autologin-user=.*/#autologin-user=/' /etc/lightdm/lightdm.conf
    sed -i 's/^autologin-user-timeout=.*/#autologin-user-timeout=/' /etc/lightdm/lightdm.conf
fi
for GDM_CONF in /etc/gdm3/custom.conf /etc/gdm/custom.conf; do
    if [ -f "$GDM_CONF" ]; then
        # GDM
        sed -i '/^\[daemon\]/,/^\[/ {
            s/^AutomaticLoginEnable=.*/AutomaticLoginEnable=false/
            s/^AutomaticLogin=.*/#AutomaticLogin=/
        }' "$GDM_CONF"
        # Varmista että [daemon]-osioon jäi selkeät arvot
        if ! sed -n '/^\[daemon\]/,/^\[/{/^[^#]*AutomaticLoginEnable=/p}' "$GDM_CONF" | grep -q .; then
            sed -i '/^\[daemon\]/a AutomaticLoginEnable=false' "$GDM_CONF"
        fi
    fi
done
if [ -f /etc/sddm.conf.d/oem-autologin.conf ]; then
    # SDDM
    rm -f /etc/sddm.conf.d/oem-autologin.conf
fi

# --- Luo cleanup-service joka poistaa setup-käyttäjän seuraavalla bootilla ---
cat > "/etc/systemd/system/${CLEANUP_SERVICE}.service" << EOF
[Unit]
Description=OEM setup cleanup
After=local-fs.target
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/oem-cleanup.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

# Cleanup-skripti
cat > /usr/local/sbin/oem-cleanup.sh << 'CLEANEOF'
#!/bin/bash
# Ei set -e: siivouksen täytyy jatkaa loppuun vaikka jokin vaihe epäonnistuu

SETUP_USER="setup"

# Poista setup-käyttäjä jos vielä on
if id "$SETUP_USER" &>/dev/null; then
    deluser --remove-home "$SETUP_USER" 2>/dev/null \
        || userdel -r "$SETUP_USER" 2>/dev/null \
        || true
fi

# Poista sudoers-poikkeus
rm -f /etc/sudoers.d/oem-setup

# Poista oem-setup binäärit
rm -f /usr/local/sbin/oem-setup-apply.sh
rm -f /usr/local/bin/oem-setup.sh

# Poista polkit-policy
rm -f /etc/polkit-1/actions/fi.local.oem-setup.policy

# Poista lockfile
rm -f /home/setup/.oem-setup.lock

# Poista itsensä (service + skripti)
systemctl disable oem-cleanup.service
rm -f /etc/systemd/system/oem-cleanup.service
systemctl daemon-reload
rm -f /usr/local/sbin/oem-cleanup.sh
CLEANEOF

chmod 700 /usr/local/sbin/oem-cleanup.sh

# SELinux-kontekstien palautus (Fedora ym.)
if command -v restorecon &>/dev/null; then
    restorecon "/etc/systemd/system/${CLEANUP_SERVICE}.service" 2>/dev/null || true
    restorecon /usr/local/sbin/oem-cleanup.sh 2>/dev/null || true
fi

systemctl enable "${CLEANUP_SERVICE}.service"

exit 0
