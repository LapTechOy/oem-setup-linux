# oem-setup-linux

Qt6/QML-pohjainen käyttöönottoavustin Linuxille. Tarkoitettu tilanteisiin joissa laitteeseen pitää tehdä OEM-tyylinen ensikirjautuminen: käyttäjä luo tilinsä, valitsee kielen ja salasanan, kone käynnistyy uudelleen ja setup-tili katoaa.

Toimii ainakin Ubuntulla ja Fedoralla. Todennäköisesti muuallakin.

## Miten tämä toimii

1. OEM-vaiheessa ajetaan `oem-setup-gui --install setup` rootina. Se kopioi binäärin, skriptit ja polkit-policyn oikeisiin paikkoihin, ja kirjoittaa autostart-tiedoston setup-käyttäjälle.
2. Järjestelmä käynnistetään. Setup-käyttäjä kirjautuu automaattisesti ja wizard aukeaa.
3. Käyttäjä täyttää nimen, kielen ja salasanan. "Ota käyttöön" ajaa `pkexec oem-apply.sh`:n, joka luo tilin rootina.
4. Kone käynnistyy uudelleen. `oem-cleanup.service` poistaa setup-tilin ja kaikki OEM-tiedostot.

## Rakenne

```
src/gui/       Qt6/QML wizard + Installer.cpp
src/common/    validointi (jaettu GUI:n ja testien välillä)
data/scripts/  oem-apply.sh, oem-cleanup.sh
data/polkit/   pkexec-policy
data/systemd/  oem-cleanup.service
```

## Kehitys

Nix-ympäristö, mutta toimii myös ilman:

```bash
nix develop
just build
just run
```

Tai suoraan CMakella jos Qt6 on asennettuna:

```bash
cmake -B build -G Ninja && cmake --build build
./build/src/gui/oem-setup-gui --mock
```

`--mock` skippaa oikeat root-toiminnot, hyvä UI-testaukseen.

## Asennus kohdelaitteeseen

```bash
sudo ./build/src/gui/oem-setup-gui --install setup
```

Sen jälkeen ota image ja levitä. Tai käynnistä suoraan uudelleen.

## Release

Release syntyy `v*`-tagista GitHub Actionsissa.

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

## Tuetut distrot

Ubuntu, Fedora, Arch-pohjaiset. Kielipaketti kannattaa asentaa etukäteen jos haluaa lokalisoidut XDG-kansiot (Lataukset jne.). Wizard asettaa localen mutta ei asenna kielipaketteja.
