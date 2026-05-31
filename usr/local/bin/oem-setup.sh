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

# Johda käyttäjänimi käyttäjän antamasta näkyvästä nimestä:
#  - Ottaa ensimmäisen sanan (välilyöntiin asti)
#  - Translitteroi ASCII:ksi (Ääkä -> Aaka, René -> Rene)
#  - Pieneksi
#  - Strippaa pois kaikki paitsi a-z, 0-9, - ja _
# Esim:
#  "Matti Meikäläinen" -> "matti"
#  "Pekka Tähtinen"    -> "pekka"
#  "tv"                -> "tv"
#  "Ääkä Ölö"          -> "aaka"
derive_username() {
    local input="$1"
    local first_word="${input%% *}"
    local ascii
    ascii=$(printf '%s' "$first_word" \
        | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null \
        | tr -d "\"'\`")
    printf '%s' "$ascii" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-'
}

# Pango-escape: zenityn --text tukee markupia, joten käyttäjän
# antama merkkijono pitää escapeta ennen kuin se upotetaan markup-kontekstiin.
pango_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Käyttäjälle näytettävä kielinimi (ei locale-koodi)
locale_display_name() {
    case "$1" in
        fi_FI.UTF-8) echo "Suomi" ;;
        sv_SE.UTF-8) echo "Svenska" ;;
        en_GB.UTF-8) echo "English (UK)" ;;
        en_US.UTF-8) echo "English (US)" ;;
        *) echo "$1" ;;
    esac
}

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

if [ ! -e "$APPLY_SCRIPT" ]; then
    # Huom: -x ei toimi tässä, koska apply.sh on mode 700 owner root,
    # eikä setup-käyttäjä voi ajaa sitä suoraan. Sudo elevoi rootiksi.
    zenity --error \
        --title="Käyttöönottoa ei voi aloittaa" \
        --text="\nKäyttöönoton tarvitsema osa puuttuu tietokoneelta.\n\nOta yhteyttä laitteen toimittajaan." \
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
        --title="Lopetetaanko nyt?" \
        --text="\nKäyttöönotto on vielä kesken.\n\nVoit jatkaa milloin tahansa — käyttöönotto käynnistyy\nuudelleen seuraavalla kerralla kun tietokone\nkäynnistetään." \
        --ok-label="Lopeta nyt" \
        --cancel-label="Jatka" \
        --width=$W
    return $?
}

#  Tervetuloviesti / ohjeet
while true; do
    zenity --info \
        --title="Tervetuloa" \
        --text="\nOtetaan uusi tietokoneesi käyttöön.\n\nTämä kestää noin minuutin. Tarvitsen sinulta vain:\n\n  • Nimesi\n  • Kielen jota haluat käyttää\n  • Salasanan\n\nSen jälkeen tietokone käynnistyy uudelleen\nja on valmis." \
        --ok-label="Aloitetaan" \
        --width=$W --height=$H && break
    confirm_exit && exit 0
done

#   Nimi (näkyvä nimi + johdettu käyttäjänimi)
while true; do
    DISPLAY_NAME=$(zenity --entry \
        --title="Nimesi (1/3)" \
        --text='\nMikä on nimesi?\n\nVoit kirjoittaa koko nimesi (esim. Matti Meikäläinen)\ntai vain etunimesi (esim. Matti).' \
        --entry-text="" \
        --width=$W --height=$H)

    if [ $? -ne 0 ]; then
        confirm_exit && exit 0
        continue
    fi

    # Trimmaa whitespace alusta ja lopusta
    DISPLAY_NAME="$(printf '%s' "$DISPLAY_NAME" \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if [[ -z "$DISPLAY_NAME" ]]; then
        zenity --warning --text="Kirjoita jokin nimi, kiitos." --width=$W
        continue
    fi

    # Kaksoispiste rikkoisi /etc/passwd-formaatin
    if [[ "$DISPLAY_NAME" == *":"* ]]; then
        zenity --warning \
            --text="Nimessä ei voi olla kaksoispistettä (:).\n\nKokeile toista nimeä." \
            --width=$W
        continue
    fi

    # Johda käyttäjänimi
    USERNAME="$(derive_username "$DISPLAY_NAME")"

    if [[ -z "$USERNAME" ]] || [[ ! "$USERNAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        zenity --warning \
            --text="Tästä nimestä ei voi tehdä käyttäjätunnusta.\n\nKokeile nimeä joka alkaa kirjaimella, esim. \"Matti\"." \
            --width=$W
        continue
    fi

    # Aikainen collision-tarkistus: jos käyttäjänimi on jo varattu
    # (esim. järjestelmäkäyttäjä 'root', 'daemon', 'bin', 'nobody', tai
    # aiempi luonti), käyttäjä saa palautteen heti — ei vasta apply-vaiheessa.
    if id "$USERNAME" &>/dev/null; then
        zenity --warning \
            --text="Tunnus <b>${USERNAME}</b> on jo käytössä.\n\nKokeile toista nimeä." \
            --width=$W
        continue
    fi

    break
done

#  Kieli 
while true; do
    LANGSEL=$(zenity --list \
        --title="Kieli (2/3)" \
        --text="\nMillä kielellä haluat käyttää tietokonettasi?" \
        --column="Koodi" --column="Kieli" \
        --hide-column=1 \
        --width=$W --height=$H \
        fi_FI.UTF-8 "Suomi" \
        sv_SE.UTF-8 "Svenska" \
        en_GB.UTF-8 "English (UK)" \
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
        --title="Salasana (3/3)" \
        --width=$W)

    if [ $? -ne 0 ]; then
        confirm_exit && exit 0
        continue
    fi

    if [[ -z "$PASSWORD" ]]; then
        zenity --warning --text="Kirjoita jokin salasana, kiitos." --width=$W
        continue
    fi

    PASSWORD2=$(zenity --password \
        --title="Kirjoita salasana uudelleen (3/3)" \
        --width=$W)

    if [ $? -ne 0 ]; then
        confirm_exit && exit 0
        continue
    fi

    if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
        zenity --warning \
            --text="Salasanat eivät täsmänneet.\n\nKokeile uudelleen — kirjoita sama salasana molempiin kenttiin." \
            --width=$W
        continue
    fi

    break
done

# Vahvistus 
while true; do
    DISPLAY_NAME_ESC="$(pango_escape "$DISPLAY_NAME")"
    LANG_DISPLAY="$(pango_escape "$(locale_display_name "$LANGSEL")")"
    zenity --question \
        --title="Onko kaikki oikein?" \
        --text="\nTarkista tiedot:\n\nNimi:  <b>${DISPLAY_NAME_ESC}</b>\nKäyttäjätunnus:  <b>${USERNAME}</b>\nKotikansio:  <b>/home/${USERNAME}</b>\nKieli:  <b>${LANG_DISPLAY}</b>\n\nKun jatkat, tietokone käynnistyy uudelleen\nja olet valmis kirjautumaan sisään." \
        --ok-label="Jatka" \
        --cancel-label="Takaisin" \
        --width=$W --height=$H && break
    confirm_exit && exit 0
done

# --- Aja root-toiminnot sudolla ---
# pkexec ei välitä stdiniä, joten käytetään sudoa (jätetty pkexec, jos joskus tarvitsee....)
RESULT_FILE="$(mktemp)"
LOG_FILE="$(mktemp)"
(
    printf '%s\n' "$PASSWORD" | sudo -n "$APPLY_SCRIPT" "$USERNAME" "$LANGSEL" "$DISPLAY_NAME" 2>"$LOG_FILE"
    echo $? > "$RESULT_FILE"
) | zenity --progress \
    --title="Hetki..." \
    --text="\nLuodaan käyttäjätunnustasi ja viimeistellään tietokoneesi.\nTämä kestää vain hetken." \
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
            --title="Jokin meni vikaan" \
            --text="\nKäyttöönotto ei valitettavasti onnistunut.\n\n<tt>$ERR_DETAIL</tt>\n\nKokeile uudelleen käynnistämällä tietokone.\nJos ongelma jatkuu, ota yhteyttä laitteen toimittajaan.\n\n(Virhekoodi: $RESULT)" \
            --width=$W --height=$H
    else
        zenity --error \
            --title="Jokin meni vikaan" \
            --text="\nKäyttöönotto ei valitettavasti onnistunut.\n\nKokeile uudelleen käynnistämällä tietokone.\nJos ongelma jatkuu, ota yhteyttä laitteen toimittajaan.\n\n(Virhekoodi: $RESULT)" \
            --width=$W --height=$H
    fi
    exit 1
fi
rm -f "$LOG_FILE"

SETUP_COMPLETE=1

zenity --info \
    --title="Valmis!" \
    --text="\nTietokoneesi on nyt valmis.\n\nKun se käynnistyy uudelleen, kirjaudu sisään\nnimellä <b>$(pango_escape "$DISPLAY_NAME")</b>\nja äsken antamallasi salasanalla.\n\nMukavia hetkiä uuden koneen parissa!" \
    --width=$W --height=$H

systemctl reboot
