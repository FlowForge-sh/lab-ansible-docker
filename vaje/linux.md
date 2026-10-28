Kje sem, kaj je tu:

pwd                 # trenutna mapa
ls -la              # seznam datotek, tudi skritih, z pravicami
cd /kurs            # pojdi v mapo; cd .. nazaj, cd ~ domov, cd - prejšnja
tree -L 2           # drevo map (če je nameščen)


Datoteke in mape:

cat datoteka.yml           # izpiši vsebino
less datoteka.log          # listaj (q za izhod, / za iskanje)
head -20 x; tail -f x.log  # začetek; spremljaj konec v živo
mkdir -p a/b/c             # ustvari mape, tudi vmesne
cp -r izvor cilj           # kopiraj (rekurzivno)
mv staro novo              # premakni ali preimenuj
rm -rf mapa                # izbriši brez vprašanj (previdno!)
touch prazna.txt           # ustvari prazno datoteko
nano x.yml                 # urejevalnik (Ctrl+O shrani, Ctrl+X izhod)


Iskanje in filtriranje:

grep -rn "docker" .        # išči niz po datotekah, z vrsticami
find . -name "*.yml"       # najdi datoteke po imenu
ukaz | grep napaka         # cev: izhod enega ukaza v drugi
ukaz > out.txt             # preusmeri izhod v datoteko (>> dodaj)
wc -l datoteka             # štetje vrstic


Pravice in uporabniki:

whoami; id                 # kdo sem, v katerih skupinah
sudo ukaz                  # zaženi kot root
chmod +x skripta.sh        # dovoli izvajanje
chown lab:lab datoteka     # spremeni lastnika
ls -l                      # rwx r-x r-- = lastnik, skupina, ostali


Procesi in sistem:

ps aux | grep nginx        # tekoči procesi
top  (ali htop)            # poraba v živo, q za izhod
kill ; kill -9   # ustavi proces (nežno; na silo)
systemctl status docker    # stanje storitve; start, stop, restart, enable
journalctl -u docker -f    # dnevnik storitve v živo
df -h; free -h             # disk; pomnilnik
uptime; uname -a           # čas delovanja; jedro
Paketi in omrežje:

sudo apt update && sudo apt install -y paket
apt list --installed | grep python
ip a                       # omrežni vmesniki in IP
ss -tlnp                   # kdo posluša na katerih vratih
curl -I [http://localhost:8080](http://localhost:8080)   # preveri HTTP odgovor
ping -c 3 8.8.8.8
SSH in prenos:

ssh lab@                      # povezava
scp datoteka lab@:/kurs/      # kopiraj na strežnik
ssh-keygen; ssh-copy-id lab@  # ključ namesto gesla


Okolje in bližnjice:

echo $HOME; export VAR=vrednost   # spremenljivke okolja
history | grep ssh                # zgodovina ukazov
man ls  /  ls --help              # pomoč