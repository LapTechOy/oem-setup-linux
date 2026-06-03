#!/bin/bash
# Ajetaan rootina systemd-palveluna. Poistaa autologinin, setup-käyttäjän
# ja loput OEM-tiedostot. Jos autologin ei lähde, seuraava boot yrittää uusiksi.
set -euo pipefail

die() { echo "oem-cleanup: $*" >&2; exit 1; }

# Luetaan setup-käyttäjä konffista. Oletus on setup.
SETUP_USER="setup"
CONFIG=/etc/oem-setup/oem-setup.conf
if [[ -f "$CONFIG" ]]; then
    val=$(grep '^setup_user=' "$CONFIG" | cut -d= -f2- || true)
    [[ -n "$val" ]] && SETUP_USER="$val"
fi
[[ "$SETUP_USER" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] \
    || die "virheellinen setup-käyttäjänimi config-tiedostossa: '$SETUP_USER'"

# Poistaa INI-avaimia paikallaan. Välilyönnit =-merkin ympärillä sallitaan.
# Jos tiedostoa ei ole, kaikki hyvin. cat säilyttää SELinux-kontekstin.
filter_keys() {
    local file="$1"; shift
    [[ -f "$file" ]] || return 0
    local tmp sed_expr=""
    tmp=$(mktemp) || return 1
    for key in "$@"; do
        sed_expr="${sed_expr}/^[[:blank:]]*${key}[[:blank:]]*=/d;"
    done
    if ! sed "$sed_expr" "$file" > "$tmp"; then
        rm -f "$tmp"; return 1
    fi
    cat "$tmp" > "$file"; local rc=$?
    rm -f "$tmp"
    return $rc
}

# Palauttaa 0 kun autologin-rivejä ei enää näy DM-konffeissa.
# Ankkuroitu alkuun, ettei kommentoidut esimerkit osu.
autologin_gone() {
    local pattern='^[[:blank:]]*(autologin-user|autologin-guest|AutomaticLogin(Enable)?)[[:blank:]]*='
    for f in /etc/lightdm/lightdm.conf /etc/gdm3/custom.conf /etc/gdm/custom.conf; do
        [[ -f "$f" ]] || continue
        grep -qE "$pattern" "$f" && return 1
    done
    # Drop-in-tiedosto riittää jo itsessään autologiniin.
    for f in \
            /etc/lightdm/lightdm.conf.d/50-oem-autologin.conf \
            /etc/sddm.conf.d/oem-autologin.conf \
            /etc/plasmalogin.conf.d/oem-autologin.conf; do
        [[ -f "$f" ]] && return 1
    done
    return 0
}

remove_autologin() {
    filter_keys /etc/lightdm/lightdm.conf \
        autologin-user autologin-user-timeout autologin-session autologin-guest || return 1
    rm -f /etc/lightdm/lightdm.conf.d/50-oem-autologin.conf || return 1
    filter_keys /etc/gdm3/custom.conf AutomaticLoginEnable AutomaticLogin || return 1
    filter_keys /etc/gdm/custom.conf  AutomaticLoginEnable AutomaticLogin || return 1
    rm -f /etc/sddm.conf.d/oem-autologin.conf || return 1
    rm -f /etc/plasmalogin.conf.d/oem-autologin.conf || return 1
}

# Vaihe 1: autologin ensin pois. Muuten voisi jäädä looppi poistettuun käyttäjään.
remove_autologin && autologin_gone \
    || die "autologinin poisto epäonnistui, yritetään uudelleen seuraavalla bootilla"

# Vaihe 2: setup-käyttäjä pois, sessiot ensin nurin.
loginctl disable-linger  "$SETUP_USER" 2>/dev/null || true
loginctl kill-user        "$SETUP_USER" 2>/dev/null || true
loginctl terminate-user   "$SETUP_USER" 2>/dev/null || true
pkill -9 -u "$SETUP_USER" 2>/dev/null || true
userdel --force -r "$SETUP_USER" 2>/dev/null || true
groupdel "$SETUP_USER" 2>/dev/null || true

if id "$SETUP_USER" &>/dev/null; then
    die "setup-käyttäjän poisto epäonnistui"
fi

# Vaihe 3: loput OEM-tiedostot pois.
rm -f /etc/sudoers.d/oem-setup
rm -f /etc/oem-setup/oem-setup.conf
rmdir /etc/oem-setup 2>/dev/null || true
rm -f /etc/polkit-1/actions/fi.local.oem-setup.policy
rm -f "/var/lib/AccountsService/users/$SETUP_USER"
rm -f /usr/bin/oem-setup-gui
rm -f /usr/bin/oem-setup-run
rm -f /tmp/oem-setup-done /tmp/oem-setup-gui.lock
rm -f /etc/oem-setup/.apply-in-progress
rm -f /usr/libexec/oem-setup/oem-apply.sh
# Poistetaan tämä skripti vasta lopussa. Linux pitää ajossa olevan fd:n auki.
rm -f /usr/libexec/oem-setup/oem-cleanup.sh
rmdir /usr/libexec/oem-setup 2>/dev/null || true

# Vaihe 4: cleanup-palvelu pois käytöstä.
systemctl disable oem-cleanup.service 2>/dev/null || true
rm -f /usr/lib/systemd/system/oem-cleanup.service
systemctl daemon-reload
