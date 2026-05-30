#!/bin/bash
# /usr/local/sbin/oem-setup-apply.sh
# Ajetaan rootina sudon kautta. Saa argumentit oem-setup.sh:lta.
# Käyttö: oem-setup-apply.sh <username> <locale>

set -euo pipefail

USERNAME="$1"
LOCALE="$2"
OEM_CONFIG="/etc/default/oem-setup"
SETUP_USER="setup"
CLEANUP_SERVICE="oem-cleanup"
CREATED_USER=0
APPLY_DONE=0

if [ -r "$OEM_CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$OEM_CONFIG"
fi

if [[ ! "$SETUP_USER" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
    echo "Virheellinen väliaikainen käyttäjänimi: $SETUP_USER" >&2
    exit 1
fi

rollback_created_user() {
    if [ "$CREATED_USER" -eq 1 ] && [ "$APPLY_DONE" -eq 0 ]; then
        echo "Virhe: käyttöönotto epäonnistui, poistetaan keskeneräinen käyttäjä $USERNAME" >&2
        pkill -u "$USERNAME" 2>/dev/null || true
        loginctl terminate-user "$USERNAME" 2>/dev/null || true
        userdel -r "$USERNAME" 2>/dev/null || true
        groupdel "$USERNAME" 2>/dev/null || true
        rm -rf "/home/$USERNAME"
    fi
}

trap rollback_created_user ERR

# --- Validointi ---
if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
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
CREATED_USER=1
# printf '%s' (ei %s\n) jotta salasanan loppuun ei lisätä rivinvaihtoa,
# ja chpasswd ei pidä viimeistä riviä omana tietueenaan
printf '%s:%s\n' "$USERNAME" "$PASSWORD" | chpasswd
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

# --- Luo cleanup-service joka poistaa setup-käyttäjän seuraavalla bootilla ---
cat > "/etc/systemd/system/${CLEANUP_SERVICE}.service" << EOF
[Unit]
Description=OEM setup cleanup
After=local-fs.target
Before=display-manager.service gdm.service gdm3.service lightdm.service sddm.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/oem-cleanup.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

# Cleanup-skripti
cat > /usr/local/sbin/oem-cleanup.sh << CLEANHEAD
#!/bin/bash
# Ei set -e: siivouksen täytyy jatkaa loppuun vaikka jokin vaihe epäonnistuu

SETUP_USER="$SETUP_USER"
OEM_CONFIG="$OEM_CONFIG"
CLEANHEAD
cat >> /usr/local/sbin/oem-cleanup.sh << 'CLEANEOF'
FAILED=0

mark_failed() {
    echo "oem-cleanup: $*" >&2
    FAILED=1
}

# === VAIHE 1: Poista autologin-konfiguraatiot ENSIN ===
# Kriittinen järjestys: jos tämä vaihe epäonnistuu, käyttäjä jätetään
# tallelle ja yritetään uudelleen — parempi kuin login-loop ilman käyttäjää.

# LightDM pääkonfiguraatio
if [ -f /etc/lightdm/lightdm.conf ]; then
    # Whitespace-tolerantti poisto (välilyönti avaimen ympärillä)
    sed -i '/^[[:space:]]*autologin-user[[:space:]]*=/d' \
        /etc/lightdm/lightdm.conf 2>/dev/null || true
    sed -i '/^[[:space:]]*autologin-user-timeout[[:space:]]*=/d' \
        /etc/lightdm/lightdm.conf 2>/dev/null || true
    # Eksplisiittinen tarkistus: varmistetaan ettei autologin jäänyt voimaan
    if grep -Eq '^[[:space:]]*autologin-user[[:space:]]*=' \
            /etc/lightdm/lightdm.conf 2>/dev/null; then
        mark_failed "LightDM autologin-user jäi voimaan: /etc/lightdm/lightdm.conf"
    fi
fi

# LightDM drop-in
rm -f /etc/lightdm/lightdm.conf.d/50-oem-autologin.conf
if [ -f /etc/lightdm/lightdm.conf.d/50-oem-autologin.conf ]; then
    mark_failed "LightDM drop-in ei poistunut"
fi

# GDM — poista autologin-rivit kokonaan, whitespace-tolerantti match
for GDM_CONF in /etc/gdm3/custom.conf /etc/gdm/custom.conf; do
    if [ -f "$GDM_CONF" ]; then
        sed -i '/^[[:space:]]*AutomaticLoginEnable[[:space:]]*=/d' \
            "$GDM_CONF" 2>/dev/null || true
        sed -i '/^[[:space:]]*AutomaticLogin[[:space:]]*=/d' \
            "$GDM_CONF" 2>/dev/null || true
        # Tarkistus 1: AutomaticLoginEnable ei saa olla true/True
        if grep -Eq \
            '^[[:space:]]*AutomaticLoginEnable[[:space:]]*=[[:space:]]*[Tt]rue' \
            "$GDM_CONF" 2>/dev/null; then
            mark_failed "GDM AutomaticLoginEnable jäi aktiiviseksi: $GDM_CONF"
        fi
        # Tarkistus 2: AutomaticLogin-rivi ei saa enää olla olemassa
        if grep -Eq \
            '^[[:space:]]*AutomaticLogin[[:space:]]*=' \
            "$GDM_CONF" 2>/dev/null; then
            mark_failed "GDM AutomaticLogin jäi voimaan: $GDM_CONF"
        fi
    fi
done

# SDDM
rm -f /etc/sddm.conf.d/oem-autologin.conf
if [ -f /etc/sddm.conf.d/oem-autologin.conf ]; then
    mark_failed "SDDM autologin-konfiguraatio ei poistunut"
fi

# Jos mikään autologin-tarkistus epäonnistui: poistu nyt, jätä käyttäjä tallelle
if [ "$FAILED" -ne 0 ]; then
    echo "oem-cleanup: autologin-konfiguraatioiden poisto epäonnistui — yritetään uudelleen seuraavalla bootilla" >&2
    exit 1
fi

# === VAIHE 2: Poista setup-käyttäjä (vasta autologin on siivottu) ===
pkill -u "$SETUP_USER" 2>/dev/null || true
loginctl terminate-user "$SETUP_USER" 2>/dev/null || true
sleep 1
deluser --remove-home "$SETUP_USER" 2>/dev/null \
    || userdel -r "$SETUP_USER" 2>/dev/null \
    || true
groupdel "$SETUP_USER" 2>/dev/null || true
rm -rf "/home/$SETUP_USER"
if id "$SETUP_USER" &>/dev/null; then
    mark_failed "setup-käyttäjän poisto epäonnistui"
fi
if [ -d "/home/$SETUP_USER" ]; then
    mark_failed "setup-kotikansion poisto epäonnistui"
fi

# === VAIHE 3: Poista jäljelle jääneet OEM-tiedostot ===
rm -f "/var/lib/AccountsService/users/$SETUP_USER"
if [ -f "/var/lib/AccountsService/users/$SETUP_USER" ]; then
    mark_failed "AccountsService-käyttäjätiedon poisto epäonnistui"
fi

# Poista sudoers-poikkeus
rm -f /etc/sudoers.d/oem-setup
if [ -f /etc/sudoers.d/oem-setup ]; then
    mark_failed "sudoers-poikkeuksen poisto epäonnistui"
fi

# Poista OEM-konfiguraatio
rm -f "$OEM_CONFIG"
if [ -f "$OEM_CONFIG" ]; then
    mark_failed "OEM-konfiguraation poisto epäonnistui"
fi

# Poista oem-setup binäärit
rm -f /usr/local/sbin/oem-setup-apply.sh
rm -f /usr/local/bin/oem-setup.sh
if [ -f /usr/local/sbin/oem-setup-apply.sh ] || [ -f /usr/local/bin/oem-setup.sh ]; then
    mark_failed "OEM-skriptien poisto epäonnistui"
fi

# Poista polkit-policy
rm -f /etc/polkit-1/actions/fi.local.oem-setup.policy
if [ -f /etc/polkit-1/actions/fi.local.oem-setup.policy ]; then
    mark_failed "polkit-policyn poisto epäonnistui"
fi

if [ "$FAILED" -ne 0 ]; then
    echo "oem-cleanup: kriittinen siivous epäonnistui, service jätetään uutta yritystä varten" >&2
    exit 1
fi

# Poista itsensä (service + skripti)
systemctl disable oem-cleanup.service
rm -f /etc/systemd/system/oem-cleanup.service
systemctl daemon-reload
rm -f /usr/local/sbin/oem-cleanup.sh
CLEANEOF

chmod 700 /usr/local/sbin/oem-cleanup.sh

# Validoi syntaksi ennen aktivointia — syntaksivirhe bootissa olisi kriittinen
if ! bash -n /usr/local/sbin/oem-cleanup.sh; then
    echo "VIRHE: oem-cleanup.sh sisältää syntaksivirheen, keskeytytään!" >&2
    rm -f /usr/local/sbin/oem-cleanup.sh
    exit 1
fi

# SELinux-kontekstien palautus (Fedora ym.)
if command -v restorecon &>/dev/null; then
    restorecon "/etc/systemd/system/${CLEANUP_SERVICE}.service" 2>/dev/null || true
    restorecon /usr/local/sbin/oem-cleanup.sh 2>/dev/null || true
fi

systemctl enable "${CLEANUP_SERVICE}.service"
APPLY_DONE=1

#  Poista autologin vasta kun cleanup-service on varmasti käytössä.
if [ -f /etc/lightdm/lightdm.conf ]; then
    # LightDM
    sed -i "/autologin-user=$SETUP_USER/d" /etc/lightdm/lightdm.conf 2>/dev/null || true
    sed -i '/autologin-user-timeout=0/d' /etc/lightdm/lightdm.conf 2>/dev/null || true
fi
rm -f /etc/lightdm/lightdm.conf.d/50-oem-autologin.conf || true
for GDM_CONF in /etc/gdm3/custom.conf /etc/gdm/custom.conf; do
    if [ -f "$GDM_CONF" ]; then
        # GDM — poista autologin-rivit kokonaan (yhdenmukainen cleanup.sh:n kanssa)
        sed -i '/^AutomaticLoginEnable=/d' "$GDM_CONF" || true
        sed -i '/^AutomaticLogin=/d' "$GDM_CONF" || true
    fi
done
rm -f /etc/sddm.conf.d/oem-autologin.conf || true

exit 0
