#!/bin/bash
# /usr/local/bin/oem-setup.sh
# Ajetaan setup-käyttäjän autostartista. Näyttää GUI:n zenitylla,
# kutsuu sitten root-skriptiä sudon kautta.

set -uo pipefail

# Tarkista riippuvuudet
if ! command -v zenity &>/dev/null; then
    echo "oem-setup: zenity puuttuu, ei voida jatkaa." >&2
    notify-send "OEM Setup" "Käyttöönotto vaatii zenity-paketin." 2>/dev/null
    exit 1
fi

LOCKDIR="$HOME/.oem-setup.lock"
APPLY_SCRIPT="/usr/local/sbin/oem-setup-apply.sh"
SETUP_COMPLETE=0

cleanup_lock() {
    if [ "$SETUP_COMPLETE" -eq 0 ]; then
        rm -rf "$LOCKDIR"
    fi
}

acquire_lock() {
    if mkdir "$LOCKDIR" 2>/dev/null; then
        echo "$$" > "$LOCKDIR/pid"
        trap cleanup_lock EXIT
        trap 'cleanup_lock; exit 130' HUP INT TERM
        return 0
    fi

    if [ -r "$LOCKDIR/pid" ]; then
        local old_pid
        old_pid="$(cat "$LOCKDIR/pid" 2>/dev/null || true)"
        if [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
            exit 0
        fi
    fi

    rm -rf "$LOCKDIR"
    if mkdir "$LOCKDIR" 2>/dev/null; then
        echo "$$" > "$LOCKDIR/pid"
        trap cleanup_lock EXIT
        trap 'cleanup_lock; exit 130' HUP INT TERM
        return 0
    fi

    exit 0
}

# Estä useampi ajo, mutta älä jätä rikkinäistä lockia pysyvästi.
acquire_lock

if [ ! -x "$APPLY_SCRIPT" ]; then
    zenity --error \
        --title="Virhe" \
        --text="\nKäyttöönoton järjestelmäkomponentti puuttuu.\n\nOta yhteys laitteen valmistelijaan." \
        --width=500
    exit 1
fi

# Odota työpöytää
sleep 2

#  Ikkunakoko 
W=500
H=350

get_screen_size() {
    local size=""
    if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
        if command -v kscreen-doctor &>/dev/null; then
            size=$(kscreen-doctor -o 2>/dev/null | awk '/Geometry:/{print $2; exit}')
        fi
        if [ -z "$size" ] && command -v gdbus &>/dev/null; then
            size=$(
                gdbus call --session \
                    --dest org.gnome.Mutter.DisplayConfig \
                    --object-path /org/gnome/Mutter/DisplayConfig \
                    --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null \
                | awk -F'[(), ]+' '
                    {
                        for (i=1; i<=NF; i++) {
                            if ($i ~ /^[0-9]+x[0-9]+$/) { print $i; exit }
                        }
                    }'
            )
        fi
    fi
    if command -v xdpyinfo &>/dev/null; then
        size=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2; exit}')
    fi
    if [ -z "$size" ] && command -v xrandr &>/dev/null; then
        size=$(xrandr --current 2>/dev/null | awk '/\*/{print $1; exit}')
    fi
    if [[ "$size" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "$size"
    fi
}

SIZE="$(get_screen_size)"
if [[ "$SIZE" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    SW="${BASH_REMATCH[1]}"
    SH="${BASH_REMATCH[2]}"

    W=$((SW * 35 / 100))
    H=$((SH * 35 / 100))

    # Minimit ja maksimit
    if [ "$W" -lt 500 ]; then W=500; fi
    if [ "$H" -lt 350 ]; then H=350; fi
    if [ "$W" -gt 1100 ]; then W=1100; fi
    if [ "$H" -gt 800 ]; then H=800; fi

    # Varmista että mahtuu ruudulle
    if [ "$W" -gt $((SW - 80)) ]; then W=$((SW - 80)); fi
    if [ "$H" -gt $((SH - 80)) ]; then H=$((SH - 80)); fi
    if [ "$W" -lt 300 ]; then W=300; fi
    if [ "$H" -lt 250 ]; then H=250; fi
fi

#  Sulkemisen vahvistus
# 0 = jatka käyttöönottoa, 1 = sulkeminen
confirm_exit() {
    zenity --question \
        --title="Keskeytä käyttöönotto?" \
        --text="\nTietokoneen käyttöönotto on kesken.\n\nJos suljet nyt, käyttöönotto käynnistyy\nuudelleen seuraavalla käynnistyskerralla.\n\nHaluatko keskeyttää?" \
        --ok-label="Keskeytä" \
        --cancel-label="Jatka käyttöönottoa" \
        --width=$W
    return $?
}

#  Tervetuloviesti / ohjeet
while true; do
    zenity --info \
        --title="Tervetuloa — tietokoneen käyttöönotto" \
        --text="\nTämä tietokone on esiasennettu, mutta sitä ei ole vielä\notettu käyttöön.\n\nSeuraavissa vaiheissa:\n\n  1.  Luot itsellesi käyttäjätilin\n  2.  Valitset järjestelmän kielen\n  3.  Asetat salasanan\n\nSen jälkeen tietokone käynnistyy uudelleen\nja on valmis käytettäväksi." \
        --ok-label="Aloita käyttöönotto" \
        --width=$W --height=$H && break
    confirm_exit && exit 0
done

#   Käyttäjänimi 
while true; do
    USERNAME=$(zenity --entry \
        --title="Vaihe 1/3 — Käyttäjätili" \
        --text='\nAnna itsellesi käyttäjänimi.\n\nTämä on tilisi tunnus, jolla kirjaudut sisään.\nEsimerkiksi etunimesi pienillä kirjaimilla, esim. matti' \
        --entry-text="" \
        --width=$W --height=$H)

    if [ $? -ne 0 ]; then
        confirm_exit && exit 0
        continue
    fi

    if [[ -z "$USERNAME" ]]; then
        zenity --warning --text="Käyttäjänimi ei voi olla tyhjä." --width=$W
        continue
    fi

    if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        zenity --warning \
            --text="Virheellinen käyttäjänimi.\n\nKäytä vain pieniä kirjaimia (a-z), numeroita (0-9),\nviivaa (-) tai alaviivaa (_).\nEnsimmäisen merkin on oltava kirjain." \
            --width=$W
        continue
    fi

    break
done

#  Kieli 
while true; do
    LANGSEL=$(zenity --list \
        --title="Vaihe 2/3 — Järjestelmän kieli" \
        --text="\nValitse kieli, jota käytetään valikoissa ja järjestelmässä:" \
        --column="Koodi" --column="Kieli" \
        --hide-column=1 \
        --width=$W --height=$H \
        fi_FI.UTF-8 "Suomi" \
        sv_SE.UTF-8 "Svenska" \
        en_US.UTF-8 "English (US)")

    if [ $? -ne 0 ]; then
        confirm_exit && exit 0
        continue
    fi

    if [[ -n "$LANGSEL" ]]; then
        break
    fi
done

#  Salasana 
while true; do
    PASSWORD=$(zenity --password \
        --title="Vaihe 3/3 — Salasana" \
        --width=$W)

    if [ $? -ne 0 ]; then
        confirm_exit && exit 0
        continue
    fi

    if [[ -z "$PASSWORD" ]]; then
        zenity --warning --text="Salasana ei voi olla tyhjä." --width=$W
        continue
    fi

    PASSWORD2=$(zenity --password \
        --title="Vaihe 3/3 — Vahvista salasana" \
        --width=$W)

    if [ $? -ne 0 ]; then
        confirm_exit && exit 0
        continue
    fi

    if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
        zenity --warning --text="Salasanat eivät täsmää. Yritä uudelleen." --width=$W
        continue
    fi

    break
done

# Vahvistus 
while true; do
    zenity --question \
        --title="Vahvista käyttöönotto" \
        --text="\nTarkista tiedot:\n\nKäyttäjätunnus:  <b>${USERNAME}</b>\nKieli:  <b>${LANGSEL}</b>\n\nTietokone käynnistyy uudelleen käyttöönoton jälkeen." \
        --ok-label="Ota käyttöön" \
        --cancel-label="Peruuta" \
        --width=$W --height=$H && break
    confirm_exit && exit 0
done

# --- Aja root-toiminnot sudolla ---
# pkexec ei välitä stdiniä, joten käytetään sudoa (jätetty pkexec, jos joskus tarvitsee....)
RESULT_FILE="$(mktemp)"
LOG_FILE="$(mktemp)"
(
    printf '%s\n' "$PASSWORD" | sudo -n "$APPLY_SCRIPT" "$USERNAME" "$LANGSEL" 2>"$LOG_FILE"
    echo $? > "$RESULT_FILE"
) | zenity --progress \
    --title="Viimeistellään käyttöönottoa" \
    --text="\nLuodaan käyttäjätiliä ja viimeistellään asetuksia..." \
    --pulsate \
    --no-cancel \
    --auto-close \
    --width=$W
if [ -s "$RESULT_FILE" ]; then
    RESULT="$(cat "$RESULT_FILE")"
else
    RESULT=1
fi
rm -f "$RESULT_FILE"
unset PASSWORD PASSWORD2

if [ $RESULT -ne 0 ]; then
    # Kerää viimeiset 5 riviä apply.sh:n virheviesteistä käyttäjälle
    # Pango-escape: &, <, > -> &amp; &lt; &gt;
    ERR_DETAIL=""
    if [ -s "$LOG_FILE" ]; then
        ERR_DETAIL="$(tail -n 5 "$LOG_FILE" 2>/dev/null \
            | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
    fi
    rm -f "$LOG_FILE"

    if [ -n "$ERR_DETAIL" ]; then
        zenity --error \
            --title="Virhe" \
            --text="\nKäyttöönotossa tapahtui virhe (koodi: $RESULT).\n\n<tt>$ERR_DETAIL</tt>\n\nVoit yrittää uudelleen käynnistämällä tietokoneen uudelleen." \
            --width=$W --height=$H
    else
        zenity --error \
            --title="Virhe" \
            --text="\nKäyttöönotossa tapahtui virhe (koodi: $RESULT).\n\nVoit yrittää uudelleen käynnistämällä tietokoneen uudelleen." \
            --width=$W --height=$H
    fi
    exit 1
fi
rm -f "$LOG_FILE"

SETUP_COMPLETE=1

zenity --info \
    --title="Käyttöönotto valmis" \
    --text="\nTietokone on otettu käyttöön.\n\nKirjaudu seuraavaksi sisään tunnuksella\n<b>${USERNAME}</b>\nja aiemmin asettamallasi salasanalla.\n\nTietokone käynnistyy nyt uudelleen." \
    --width=$W --height=$H

systemctl reboot
