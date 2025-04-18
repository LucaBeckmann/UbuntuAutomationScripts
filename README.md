1.  Erstelle Ubuntu Server mit Systemaccount
2.  Kopiere das Script auf den Server
3.  Ausführbar machen mit chmod +x startup.sh
4.  Das Script führt folgendes aus:
    4.1   timedatectl auf "Europe/Berlin"
    4.2  erstelle einen Benutzer und füge ihn sudo hinzu
    4.3  lade den public ssh key von einem GitHub Profil
    4.5  ändere die ssh config so, dass nur public key aktzeptiert wird
    4.6  starte ssh neu
