#!/bin/bash
# install-arch.sh Arch-pohjaiset distrot (EndeavourOS, CachyOS, Manjaro, Garuda)
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
if [ -n "$MISSING" ] && command -v pacman &>/dev/null; then
    case " $MISSING " in *" zenity "*) PKGS="$PKGS zenity" ;; esac
    case " $MISSING " in *" sudo "*|*" visudo "*) PKGS="$PKGS sudo" ;; esac
    case " $MISSING " in *" systemctl "*) PKGS="$PKGS systemd" ;; esac
    case " $MISSING " in *" chpasswd "*|*" usermod "*|*" useradd "*) PKGS="$PKGS shadow" ;; esac
    PKGS="$PKGS polkit"
    echo "[*] Asennetaan puuttuvia paketteja: $PKGS"
    pacman -S --needed --noconfirm $PKGS >/dev/null 2>&1 || true
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
    echo "Esim. Arch-pohjainen: pacman -S zenity sudo polkit systemd shadow" >&2
    exit 1
fi

OEM_CONFIG="/etc/default/oem-setup"
if [ -z "${SETUP_USER+x}" ] && [ -r "$OEM_CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$OEM_CONFIG"
fi
SETUP_USER="${SETUP_USER:-setup}"
SETUP_HOME="/home/$SETUP_USER"
RUNNING_AS_SETUP=0

if [[ ! "$SETUP_USER" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
    echo "Virhe: virheellinen väliaikainen käyttäjänimi: $SETUP_USER" >&2
    exit 1
fi

if [ "${SUDO_USER:-}" = "$SETUP_USER" ] || [ "${USER:-}" = "$SETUP_USER" ]; then
    RUNNING_AS_SETUP=1
fi

cleanup_setup_user() {
    if [ "$RUNNING_AS_SETUP" -eq 1 ]; then
        echo "[*] Ajetaan $SETUP_USER-käyttäjän sessiosta, ei tapeta nykyistä sessiota."
        return 0
    fi
    pkill -u "$SETUP_USER" 2>/dev/null || true
    loginctl terminate-user "$SETUP_USER" 2>/dev/null || true
    sleep 1
    userdel -r "$SETUP_USER" 2>/dev/null || true
    groupdel "$SETUP_USER" 2>/dev/null || true
    rm -rf "$SETUP_HOME"
}

install_oem_config() {
    cat > "$OEM_CONFIG" << EOF
SETUP_USER="$SETUP_USER"
EOF
    chmod 644 "$OEM_CONFIG"
}

install_oem_sudoers() {
    cat > /etc/sudoers.d/oem-setup << EOF
# Sallii oem-setup-apply.sh:n ajon sudolla ilman salasanaa
# Poistetaan automaattisesti oem-cleanup.sh:n toimesta
$SETUP_USER ALL=(root) NOPASSWD: /usr/local/sbin/oem-setup-apply.sh
EOF
    chmod 440 /etc/sudoers.d/oem-setup
}

prepare_setup_user() {
    passwd -d "$SETUP_USER" 2>/dev/null || true
    usermod -s /bin/bash "$SETUP_USER" 2>/dev/null || true
    chage -E -1 "$SETUP_USER" 2>/dev/null || true
}

detect_display_manager() {
    local dm=""
    if [ -e /etc/systemd/system/display-manager.service ]; then
        dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    fi

    case "$dm" in
        lightdm|gdm|gdm3|sddm) echo "$dm"; return 0 ;;
    esac

    if [ -d /etc/lightdm ] || [ -f /etc/lightdm/lightdm.conf ]; then
        echo "lightdm"
    elif [ -d /etc/gdm ] || [ -f /etc/gdm/custom.conf ]; then
        echo "gdm"
    elif command -v sddm &>/dev/null; then
        echo "sddm"
    fi
}

detect_sddm_session() {
    local session_file session_name preferred
    for preferred in ubuntu ubuntu-xorg gnome plasma plasmawayland kde-plasma xfce cinnamon mate; do
        for session_file in \
            "/usr/share/xsessions/${preferred}.desktop" \
            "/usr/share/wayland-sessions/${preferred}.desktop"; do
            if [ -f "$session_file" ]; then
                basename "$session_file" .desktop
                return 0
            fi
        done
    done

    session_name=$(
        { ls -1 /usr/share/xsessions/*.desktop 2>/dev/null; ls -1 /usr/share/wayland-sessions/*.desktop 2>/dev/null; } \
        | sort \
        | sed -n '1p' \
        | xargs -r -n1 basename \
        | sed 's/\.desktop$//'
    )
    if [ -n "$session_name" ]; then
        echo "$session_name"
    fi
}

configure_lightdm_autologin() {
    if [ -f /etc/lightdm/lightdm.conf ]; then
        sed -i "/autologin-user=$SETUP_USER/d" /etc/lightdm/lightdm.conf 2>/dev/null || true
        sed -i '/autologin-user-timeout=0/d' /etc/lightdm/lightdm.conf 2>/dev/null || true
    fi
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/50-oem-autologin.conf << LIGHTDMEOF
[Seat:*]
autologin-user=$SETUP_USER
autologin-user-timeout=0
LIGHTDMEOF
}

echo "============================================"
echo "  OEM Setup — ensikäyttöönoton asennus (Arch-pohjaiset)"
echo "============================================"
echo ""
echo "Tämä skripti asentaa käyttöönottoavustimen,"
echo "joka käynnistyy automaattisesti seuraavalla"
echo "käynnistyskerralla ja ohjaa loppukäyttäjän"
echo "luomaan oman käyttäjätilinsä."
echo ""
echo "[*] Asennetaan..."

# Skriptipolut binäärikansioihin
install -m 700 usr/local/sbin/oem-setup-apply.sh /usr/local/sbin/
install -m 755 usr/local/bin/oem-setup.sh         /usr/local/bin/

# PolicyKit
mkdir -p /etc/polkit-1/actions
install -m 644 etc/polkit-1/actions/fi.local.oem-setup.policy \
    /etc/polkit-1/actions/

# Sudoers sallii setup-käyttäjän ajaa apply-skriptin sudolla
mkdir -p /etc/sudoers.d
install_oem_sudoers
visudo -cf /etc/sudoers.d/oem-setup

mkdir -p /etc/default
install_oem_config

# Siivoa vanha setup-käyttäjä ennen luontia, jos pitää ajaa uusiks
cleanup_setup_user

# Luo setup-käyttäjä
if ! id "$SETUP_USER" &>/dev/null; then
    useradd -m -c "OEM Setup" -s /bin/bash "$SETUP_USER"
fi
prepare_setup_user

# Autostart
mkdir -p "$SETUP_HOME/.config/autostart"
install -m 644 home/setup/.config/autostart/oem-setup.desktop \
    "$SETUP_HOME/.config/autostart/"
chown -R "$SETUP_USER:$SETUP_USER" "$SETUP_HOME/.config"

# Display manager autologin
DISPLAY_MANAGER="$(detect_display_manager)"
case "$DISPLAY_MANAGER" in
lightdm)
    # LightDM — poista mahdollinen vanha autologin pääkonfigista, käytä drop-inia
    configure_lightdm_autologin
    ;;
gdm|gdm3)
    # GDM
    GDM_CONF="/etc/gdm/custom.conf"
    GDM_SESSION="$(detect_sddm_session)"
    if [ ! -f "$GDM_CONF" ]; then
        mkdir -p "$(dirname "$GDM_CONF")"
        cat > "$GDM_CONF" << GDMEOF
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=$SETUP_USER
GDMEOF
    elif ! grep -q '^\[daemon\]' "$GDM_CONF"; then
        cat >> "$GDM_CONF" << GDMEOF

[daemon]
AutomaticLoginEnable=True
AutomaticLogin=$SETUP_USER
GDMEOF
    else
        sed -i "/^\[daemon\]/,/^\[/ {
            s/^#\?AutomaticLoginEnable=.*/AutomaticLoginEnable=True/
            s/^#\?AutomaticLogin=.*/AutomaticLogin=$SETUP_USER/
        }" "$GDM_CONF"
        # Jos avaimia ei ollut lainkaan, lisää ne [daemon]-osion alle
        if ! sed -n '/^\[daemon\]/,/^\[/{/^[^#]*AutomaticLoginEnable=/p}' "$GDM_CONF" | grep -q .; then
            sed -i '/^\[daemon\]/a AutomaticLoginEnable=True' "$GDM_CONF"
        fi
        if ! sed -n '/^\[daemon\]/,/^\[/{/^[^#]*AutomaticLogin=/p}' "$GDM_CONF" | grep -q .; then
            sed -i "/^\[daemon\]/a AutomaticLogin=$SETUP_USER" "$GDM_CONF"
        fi
    fi
    if [ -n "$GDM_SESSION" ]; then
        mkdir -p /var/lib/AccountsService/users
        cat > "/var/lib/AccountsService/users/$SETUP_USER" << EOF
[User]
Session=$GDM_SESSION
XSession=$GDM_SESSION
SystemAccount=false
EOF
        chmod 600 "/var/lib/AccountsService/users/$SETUP_USER"
    fi
    ;;
sddm)
    # SDDM
    mkdir -p /etc/sddm.conf.d
    SDDM_SESSION="$(detect_sddm_session)"

    cat > /etc/sddm.conf.d/oem-autologin.conf << SDDMEOF
[Autologin]
User=$SETUP_USER
SDDMEOF
    if [ -n "$SDDM_SESSION" ]; then
        echo "Session=$SDDM_SESSION" >> /etc/sddm.conf.d/oem-autologin.conf
    fi
    ;;
esac

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
