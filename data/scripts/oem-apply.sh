#!/bin/bash
# Ajetaan rootina pkexecillä. Tekee oikean käyttäjän ja vähän siivoaa perään.
# Käyttö: pkexec oem-apply.sh --username X --display-name Y --locale Z
# Salasana luetaan stdinistä, ei argv:stä.
set -euo pipefail

die() { echo "oem-apply: $*" >&2; exit 1; }

USERNAME=""
DISPLAY_NAME=""
LOCALE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            [[ $# -ge 2 ]] || die "--username vaatii arvon"
            USERNAME="$2"; shift 2 ;;
        --display-name)
            [[ $# -ge 2 ]] || die "--display-name vaatii arvon"
            DISPLAY_NAME="$2"; shift 2 ;;
        --locale)
            [[ $# -ge 2 ]] || die "--locale vaatii arvon"
            LOCALE="$2"; shift 2 ;;
        *) die "tuntematon argumentti: $1" ;;
    esac
done

[[ -n "$USERNAME" ]]     || die "puuttuva --username"
[[ -n "$DISPLAY_NAME" ]] || die "puuttuva --display-name"
[[ -n "$LOCALE" ]]       || die "puuttuva --locale"

[[ "$USERNAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] \
    || die "virheellinen käyttäjätunnus: '$USERNAME'"

case "$LOCALE" in
    fi_FI.UTF-8|sv_SE.UTF-8|en_GB.UTF-8|en_US.UTF-8) ;;
    *) die "tuntematon locale: '$LOCALE'" ;;
esac

# GECOS-kenttä ei tykkää näistä, ja passwd käyttää kaksoispistettä erotinmerkkinä.
[[ ${#DISPLAY_NAME} -le 128 ]] || die "nimi on liian pitkä"
case "$DISPLAY_NAME" in
    *:*|*$'\n'*|*$'\r'*) die "nimi sisältää kielletyn merkin" ;;
esac

IFS= read -r PASSWORD || true
[[ -n "$PASSWORD" ]] || die "salasana puuttuu"

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

rollback() {
    echo "oem-apply: käyttöönotto epäonnistui, poistetaan $USERNAME" >&2
    pkill -u "$USERNAME" 2>/dev/null || true
    loginctl terminate-user "$USERNAME" 2>/dev/null || true
    userdel --force -r "$USERNAME" 2>/dev/null || true
    groupdel "$USERNAME" 2>/dev/null || true
    rm -f "${INFLIGHT:-/etc/oem-setup/.apply-in-progress}"
}

# Ei yliajeta olemassa olevaa käyttäjää.
if id "$USERNAME" &>/dev/null; then
    die "käyttäjä on jo olemassa: $USERNAME"
fi

INFLIGHT=/etc/oem-setup/.apply-in-progress
if [[ -f "$INFLIGHT" ]]; then
    PREV=$(cat "$INFLIGHT" 2>/dev/null || true)
    [[ -n "$PREV" ]] && userdel --force -r "$PREV" 2>/dev/null || true
    rm -f "$INFLIGHT"
fi
echo "$USERNAME" > "$INFLIGHT"

# useradd on tylsä mutta kulkee distrosta toiseen.
# Debianin adduser ei käy, Fedorassa/Archissa se voi olla useradd-symlinkki
# eikä tue samoja optioita.
SHELL_PATH=$(command -v bash 2>/dev/null)
[[ -x "$SHELL_PATH" ]] || SHELL_PATH=/bin/sh
useradd -m -c "$DISPLAY_NAME" -s "$SHELL_PATH" "$USERNAME" \
    || die "käyttäjän luominen epäonnistui"

# Salasana chpasswdille stdinistä, ettei se näy prosessilistassa.
if ! printf '%s:%s\n' "$USERNAME" "$PASSWORD" | chpasswd; then
    rollback
    die "salasanan asettaminen epäonnistui"
fi

# Lisätään admin-ryhmään jos sellainen löytyy.
GROUP=""
if getent group sudo &>/dev/null; then
    GROUP=sudo
elif getent group wheel &>/dev/null; then
    GROUP=wheel
else
    echo "oem-apply: sudo/wheel-ryhmää ei löydy, ohitetaan" >&2
fi

if [[ -n "$GROUP" ]]; then
    if ! usermod -aG "$GROUP" "$USERNAME"; then
        rollback
        die "käyttäjän lisääminen sudo-ryhmään epäonnistui"
    fi
fi

# Locale paikalleen.
set_locale() {
    local locale="$1"
    command -v locale-gen &>/dev/null && locale-gen "$locale" || true
    if command -v localectl &>/dev/null; then
        localectl set-locale "LANG=$locale"; return $?
    fi
    if command -v update-locale &>/dev/null; then
        update-locale "LANG=$locale"; return $?
    fi
    echo "oem-apply: localectl/update-locale ei saatavilla" >&2
    return 1
}

if ! set_locale "$LOCALE"; then
    rollback
    die "kielen asettaminen epäonnistui"
fi

# Cleanup päälle ennen autologinin poistoa, niin seuraava boot voi yrittää uusiksi.
if ! systemctl enable oem-cleanup.service; then
    rollback
    die "cleanup-palvelun aktivointi epäonnistui"
fi

# Yritetään autologin pois heti. Ei kaadeta tähän, cleanup yrittää vielä bootissa.
remove_autologin && autologin_gone \
    || echo "oem-apply: varoitus: autologinin poisto epäonnistui osin, cleanup-palvelu yrittää uudelleen" >&2

rm -f "$INFLIGHT"
echo "ok"
