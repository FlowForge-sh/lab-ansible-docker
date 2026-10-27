# Rešitev · Vaja A01

Skripta in datoteke so v [`../ansible-projekt/`](../ansible-projekt/)
(`setup-ansible.sh`, `requirements.txt`, `requirements.yml`, `ansible.cfg`,
`inventories/aws/hosts.yml`). Izhodišče vaje je
`vaje/A01-projekt-zacetek/`: cel delujoč projekt (role `docker` in `app`,
`site.yml`, `deploy.yml`, app1), brez app2 (vaja A05) in `upgrade.yml` (dodatno gradivo).

Na AWS labu isto (venv, pip in galaxy iz istih `requirements.*`) ob
postavitvi naredi `lab-bootstrap-control` (cloud-init), zato je zagon
skripte že ponovni: nič novega se ne namesti. Projekt `~/projekt` tam
vsebuje samo inventory `inventories/aws` (`ansible.cfg` kaže nanj).
Dockerja in aplikacij priprava ne postavi: ob prijavi `docker ps` javi
`command not found`, `lab status` pa "docker še ni nameščen". Docker
postavi udeleženec v A03 (`site.yml`), app1 v A04, app2 v A05.

Na AWS je v inventoryju en host `control` z `ansible_connection: local`:
`ansible all -m ping` vrne en `control | SUCCESS ... pong`. Korak s pravim
SSH (`-e ansible_connection=ssh -e ansible_host=127.0.0.1`) doda v
`known_hosts` eno vrstico.

Preverjeno (Ubuntu 24.04, Python 3.12):

```
$ ./setup-ansible.sh
[1/5] Python 3.12 ... ok
...
ansible [core 2.21.5]
community.docker 5.4.0 / ansible.posix 2.2.2 / community.general 13.5.0
ansible-lint 26.10.1 using ansible-core:2.21.5 ...
$ ansible all -m ansible.builtin.ping
control | SUCCESS => { "changed": false, "ping": "pong" }
```

Drugi zagon skripte ne namesti ničesar novega (pip: "Requirement already
satisfied", galaxy: "Nothing to do. All requested collections are already
installed.").

`known_hosts`: `StrictHostKeyChecking=accept-new` (v `ansible.cfg`) nov host
ključ sprejme in shrani, spremenjenega pa zavrne.

## Odgovori

- venv in pin: enaka verzija za vse in v CI, nadgradnja je zavestna
  sprememba v gitu; `apt` da verzijo distribucije (Ubuntu 24.04: ansible-core
  2.16), ki je stara in ne podpira novih kolekcij.
- Različni `community.docker`: drugačni argumenti, privzete vrednosti ali
  napake; isti playbook se obnaša različno. Zato `requirements.yml` s
  točnimi verzijami.
- `./collections`: projekt je samozadosten, verzije so vezane na projekt, ne
  na uporabnika; v `.gitignore`, ker jih skripta vedno namesti znova.
- V CI: brez koraka z SSH ključem (ključ pride iz CI spremenljivke), venv v
  predpomnilniku ali v sliki; ostane `pip install` + `ansible-galaxy` + lint.
