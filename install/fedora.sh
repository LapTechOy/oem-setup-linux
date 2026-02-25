#!/bin/bash
# install-fedora.sh — Fedora-porttaus
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [ "$(id -u)" -ne 0 ]; then
    echo "Virhe: Tämä skripti täytyy ajaa rootina (sudo)." >&2
    exit 1
fi

# Tarkista riippuvuudet (ja yritä asentaa)
MISSING=""
for cmd in zenity sudo visudo systemctl chpasswd usermod; do
    command -v "$cmd" &>/dev/null || MISSING="$MISSING $cmd"
done
if ! command -v useradd &>/dev/null; then
    MISSING="$MISSING useradd"
fi

PKGS=""
if [ -n "$MISSING" ] && command -v dnf &>/dev/null; then
    case " $MISSING " in *" zenity "*) PKGS="$PKGS zenity" ;; esac
    case " $MISSING " in *" sudo "*|*" visudo "*) PKGS="$PKGS sudo" ;; esac
    case " $MISSING " in *" systemctl "*) PKGS="$PKGS systemd" ;; esac
    case " $MISSING " in *" chpasswd "*|*" usermod "*|*" useradd "*) PKGS="$PKGS shadow-utils" ;; esac
    PKGS="$PKGS polkit"
    echo "[*] Asennetaan puuttuvia paketteja: $PKGS"
    dnf install -y $PKGS >/dev/null 2>&1 || true
fi

# Uusi tarkistus
MISSING=""
for cmd in zenity sudo visudo systemctl chpasswd usermod; do
    command -v "$cmd" &>/dev/null || MISSING="$MISSING $cmd"
done
if ! command -v useradd &>/dev/null; then
    MISSING="$MISSING useradd"
fi
if [ -n "$MISSING" ]; then
    echo "Virhe: Seuraavat komennot puuttuvat:$MISSING" >&2
    if [ -n "$PKGS" ]; then
        echo "Yritettiin asentaa paketit:$PKGS" >&2
    fi
    echo "Asenna puuttuvat paketit ennen asennusta." >&2
    echo "Esim. Fedora: dnf install zenity sudo polkit systemd shadow-utils" >&2
    exit 1
fi

echo "============================================"
echo "  OEM Setup — ensikäyttöönoton asennus (Fedora)"
echo "============================================"
echo ""
echo "Tämä skripti asentaa käyttöönottoavustimen,"
echo "joka käynnistyy automaattisesti seuraavalla"
echo "käynnistyskerralla ja ohjaa loppukäyttäjän"
echo "luomaan oman käyttäjätilinsä."
echo ""
echo "[*] Asennetaan..."

# Binäärit
install -m 700 usr/local/sbin/oem-setup-apply.sh /usr/local/sbin/
install -m 755 usr/local/bin/oem-setup.sh         /usr/local/bin/

# PolicyKit
mkdir -p /etc/polkit-1/actions
install -m 644 etc/polkit-1/actions/fi.local.oem-setup.policy \
    /etc/polkit-1/actions/

# Sudoers — sallii setup-käyttäjän ajaa apply-skriptin sudolla
# ilman salasanaa (setup-tilillä ei ole salasanaa)
mkdir -p /etc/sudoers.d
install -m 440 etc/sudoers.d/oem-setup /etc/sudoers.d/
visudo -cf /etc/sudoers.d/oem-setup

# Luo setup-käyttäjä
if ! id setup &>/dev/null; then
    useradd -m -c "OEM Setup" -s /bin/bash setup
fi

# Autostart
SETUP_HOME=/home/setup
mkdir -p "$SETUP_HOME/.config/autostart"
install -m 644 home/setup/.config/autostart/oem-setup.desktop \
    "$SETUP_HOME/.config/autostart/"
chown -R setup:setup "$SETUP_HOME/.config"

# Display manager autologin (Fedora käyttää oletuksena GDM)
if [ -d /etc/gdm ] || [ -f /etc/gdm/custom.conf ]; then
    GDM_CONF="/etc/gdm/custom.conf"
    if [ ! -f "$GDM_CONF" ]; then
        mkdir -p "$(dirname "$GDM_CONF")"
        cat > "$GDM_CONF" << 'GDMEOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=setup
GDMEOF
    elif ! grep -q '^\[daemon\]' "$GDM_CONF"; then
        cat >> "$GDM_CONF" << 'GDMEOF'

[daemon]
AutomaticLoginEnable=true
AutomaticLogin=setup
GDMEOF
    else
        sed -i '/^\[daemon\]/,/^\[/ {
            s/^#\?AutomaticLoginEnable=.*/AutomaticLoginEnable=true/
            s/^#\?AutomaticLogin=.*/AutomaticLogin=setup/
        }' "$GDM_CONF"
        # Jos avaimia ei ollut lainkaan, lisää ne [daemon]-osion alle
        if ! sed -n '/^\[daemon\]/,/^\[/{/^[^#]*AutomaticLoginEnable=/p}' "$GDM_CONF" | grep -q .; then
            sed -i '/^\[daemon\]/a AutomaticLoginEnable=true' "$GDM_CONF"
        fi
        if ! sed -n '/^\[daemon\]/,/^\[/{/^[^#]*AutomaticLogin=/p}' "$GDM_CONF" | grep -q .; then
            sed -i '/^\[daemon\]/a AutomaticLogin=setup' "$GDM_CONF"
        fi
    fi
elif [ -f /etc/lightdm/lightdm.conf ]; then
    # LightDM (jos käytössä)
    sed -i 's/^#\?autologin-user=.*/autologin-user=setup/' /etc/lightdm/lightdm.conf
    sed -i 's/^#\?autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
    if ! grep -q '^autologin-user=' /etc/lightdm/lightdm.conf; then
        echo "autologin-user=setup" >> /etc/lightdm/lightdm.conf
    fi
    if ! grep -q '^autologin-user-timeout=' /etc/lightdm/lightdm.conf; then
        echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf
    fi
elif command -v sddm &>/dev/null; then
    # SDDM (jos käytössä)
    mkdir -p /etc/sddm.conf.d
    SDDM_SESSION=""
    if [ -d /usr/share/xsessions ] || [ -d /usr/share/wayland-sessions ]; then
        SESSION_COUNT=$(
            { ls -1 /usr/share/xsessions/*.desktop 2>/dev/null; ls -1 /usr/share/wayland-sessions/*.desktop 2>/dev/null; } \
            | wc -l
        )
        if [ "$SESSION_COUNT" -eq 1 ]; then
            SDDM_SESSION=$(
                { ls -1 /usr/share/xsessions/*.desktop 2>/dev/null; ls -1 /usr/share/wayland-sessions/*.desktop 2>/dev/null; } \
                | sed -n '1p' | xargs -n1 basename | sed 's/\.desktop$//'
            )
        fi
    fi

    cat > /etc/sddm.conf.d/oem-autologin.conf << SDDMEOF
[Autologin]
User=setup
SDDMEOF
    if [ -n "$SDDM_SESSION" ]; then
        echo "Session=$SDDM_SESSION" >> /etc/sddm.conf.d/oem-autologin.conf
    fi
fi

# SELinux-kontekstien palautus (Fedora enforcing oletuksena)
if command -v restorecon &>/dev/null; then
    restorecon /etc/sudoers.d/oem-setup 2>/dev/null || true
    restorecon /etc/polkit-1/actions/fi.local.oem-setup.policy 2>/dev/null || true
    restorecon /usr/local/sbin/oem-setup-apply.sh 2>/dev/null || true
    restorecon /usr/local/bin/oem-setup.sh 2>/dev/null || true
fi

echo ""
echo "[OK] Asennus valmis."
echo ""
echo "Seuraavat vaiheet:"
echo "  1. Sulje tämä terminaali / chroot-ympäristö"
echo "  2. Käynnistä tietokone"
echo "  3. Käyttöönottoavustin käynnistyy automaattisesti"
echo "     ja ohjaa käyttäjää luomaan oman tilinsä"
echo ""
echo "Tilapäinen 'setup'-käyttäjä ja kaikki OEM-tiedostot"
echo "poistetaan automaattisesti käyttöönoton jälkeen."
