# OEM Setup

Pieni OEM‑käyttöönottoavustin distroille, joista puuttuu valmis OEM‑asennus.  

Ideana on, että käyttäjä luo ensimmäisellä bootilla oman tilinsä ja kielen, ilman ylimääräistä säätöä.

## Käyttö
1. Kopioi `oem-setup` asennettuun järjestelmään.
2. Siirry kansioon:

   ```bash
   cd oem-setup
   ```
3. Aja asennus:

   ```bash
   sudo ./install.sh
   ```
4. Käynnistä kone uudelleen.

Ensimmäisellä bootilla:

* `setup`-käyttäjä kirjautuu automaattisesti
* käyttöönottoavustin käynnistyy
* käyttäjä luo oman tilinsä
* kone käynnistyy uudelleen
* `setup`-tili ja OEM-tiedostot poistuvat automaattisesti

## Tuetut distrot
- Fedora‑pohjaiset (Fedora, Nobara tms.)
- Arch‑pohjaiset (EndeavourOS, CachyOS, Manjaro, Garuda)
- Muut → generinen polku (Debian/Ubuntu‑tyyliset)


Jos puuttuvia paketteja löytyy, asennus yrittää asentaa ne ja kertoo lopuksi mikä jäi puuttumaan.