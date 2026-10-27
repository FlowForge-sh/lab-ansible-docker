# Vaja A03 · Samo Docker: site.yml in rola docker (obvezna, ~20 min)

## Cilj

Na prazen strežnik z enim ukazom postaviti **samo Docker Engine**:
`ansible-playbook site.yml` požene rolo `docker` (uradni repozitorij,
točna verzija 29.8.2, `daemon.json` z live-restore) na vseh hostih iz
`docker_hosts` (vaš strežnik `control`).
Aplikacij še ne postavljate (to je A04). Nato z `docker` ukazi preverite,
da Engine res teče, in z drugim zagonom pokažete idempotenco
(`changed=0`).

Rola je pripravljena v `~/projekt/roles/docker`; v tej vaji jo poženete,
pogledate in preverite, ne pišete je od začetka.

## Predpogoji

- A01: ste v `~/projekt`, `ansible all -m ansible.builtin.ping` vrne pong,
  `docker ps` javi `command not found` (`lab status`: docker še ni nameščen).
- Teorija: [`../teorija/05-ansible-projekt.md`](../teorija/05-ansible-projekt.md) §1 in §2.
- Neobvezno ozadje: [`../teorija/01-ozadje-docker-engine.md`](../teorija/01-ozadje-docker-engine.md)
  §2 in §3 (kateri ročni korak pokrije kateri task).

## Koraki

### A. Pred zagonom: kaj bo naredil (5 min)

1. ```bash
   cat site.yml                          # en play: docker_hosts, become, rola docker s tagom docker
   ls roles/docker/*                     # defaults, handlers, tasks (main.yml, prep.yml), templates, vars
   less roles/docker/tasks/main.yml      # ključ, repozitorij, verzija, paketi, daemon.json, skupina docker
   ansible-playbook site.yml --syntax-check
   ansible-playbook site.yml --list-tasks   # vsi taski role, TAGS: [docker]
   ansible-playbook site.yml --list-tags    # TASK TAGS: [docker]
   ```

### B. Zagon (5 min)

2. Inventory je privzet v `ansible.cfg`, enako lahko napišete izrecno z `-i`:
   ```bash
   ansible-playbook -i inventories/aws/hosts.yml site.yml
   ```
   Prvi zagon traja ~2 min. Med izpisom poiščite taske
   `Namesti Docker Engine`, `Datoteka daemon.json`, `Uporabniki v skupini
   docker` in handler `Restart docker`.
3. Drugi zagon, tokrat s tagom (samo taski z oznako `docker`; v tem playu
   so to vsi):
   ```bash
   ansible-playbook site.yml --tags docker      # changed=0
   ```
   Idempotenca: nič ni treba spremeniti, zato Ansible nič ne spremeni.

### C. Nova prijava: skupina docker (2 min)

4. ```bash
   docker ps          # permission denied while trying to connect to the docker API ...
   sudo docker ps     # deluje: prazen seznam
   id                 # skupine docker še ni
   ```
   Ansible je uporabnika `lab` dodal v skupino `docker`, vaša trenutna seja
   pa je nastala prej. Odjavite se in prijavite znova:
   ```bash
   exit
   ssh lab-control    # ali ssh lab@<IP>; prijava začne v ~/projekt
   id                 # ... docker
   docker ps          # CONTAINER ID   IMAGE   ...   (prazno, brez napake)
   ```

### Preverba na strežniku (5 min)

5. Na strežniku (ste že na njem):
   ```bash
   docker version --format '{{.Client.Version}} / {{.Server.Version}}'   # 29.8.2 / 29.8.2
   docker info --format '{{.ServerVersion}} {{.LiveRestoreEnabled}} {{.LoggingDriver}}'
   docker info | grep -E 'Server Version|Live Restore|Cgroup|Storage Driver'
   systemctl is-active docker            # active
   cat /etc/docker/daemon.json           # to je zapisal Ansible (predloga)
   docker run --rm hello-world | head -2 # Engine potegne sliko in zažene kontejner
   docker images                         # hello-world
   docker ps -a                          # prazno: --rm je kontejner že odstranil
   docker compose version                # plugin compose (za A04)
   lab status                            # docker 29.8.2
   ```
6. Isto brez prijave, za vse Docker hoste naenkrat (z Ansiblom):
   ```bash
   ansible docker_hosts -m ansible.builtin.shell -a 'docker info | grep -E "Server Version|Live Restore"'
   ansible docker_hosts -m ansible.builtin.command -a 'docker ps -a'
   ```
   (Prazen seznam: Engine je, aplikacij še ni.)

### D. Neobvezno: sprememba konfiguracije

7. V `inventories/aws/group_vars/all.yml` dodajte `docker_log_max_size: 20m`
   in poglejte, kaj bi se spremenilo, brez spremembe:
   ```bash
   ansible-playbook site.yml --check --diff     # daemon.json: "max-size": "10m" -> "20m"
   ansible-playbook site.yml --diff             # zares, handler Restart docker
   grep max-size /etc/docker/daemon.json
   ```
   Vrstico odstranite in poženite znova (nazaj na `10m`). Koliko hostov je
   restartalo Docker?
8. `ansible-lint site.yml roles/docker`: brez napak.
9. Od začetka: `lab reset` odstrani Docker (kontejnerje, slike,
   `/opt/apps`), `lab status` spet kaže "še ni nameščen"; ponovite B in C.

> **Alternativa v Swarmu** (samo za informacijo, v labu tega ne poganjamo)
>
> Swarm bi dodal drugo rolo za `site.yml`, ki teče za rolo docker:
>
> | Ansible za samostojni Docker | Ansible za Swarm |
> | --- | --- |
> | skupina `docker_hosts` | skupini `managers` in `workers` |
> | rola docker | rola docker + rola swarm (`--tags swarm`) |
> | (ni) | `community.docker.docker_swarm` (`state: present` na prvem managerju, `state: join` na ostalih, `throttle: 1`) |
> | (ni) | `community.docker.docker_node` za vloge in labele nodov |
> | `docker_live_restore: true` | `docker_live_restore: false` (v Swarm načinu ni dovoljen) |
>
> Primer (`~/vaje/swarm-primer/swarm.yml`, inventory `hosts-swarm.yml` s skupinama `managers` in `workers`):
>
> ```yaml
> - name: Swarm init na prvem managerju
>   hosts: managers[0]
>   become: true
>   tasks:
>     - community.docker.docker_swarm:
>         state: present
>         advertise_addr: "{{ ansible_facts['default_ipv4']['address'] }}"
>       register: swarm_init          # swarm_facts.JoinTokens.Manager / .Worker
>
> - name: Workerji se pridružijo
>   hosts: workers
>   become: true
>   throttle: 1
>   tasks:
>     - community.docker.docker_swarm:
>         state: join
>         join_token: "{{ hostvars[groups['managers'][0]]['swarm_init']['swarm_facts']['JoinTokens']['Worker'] }}"
>         remote_addrs: ["{{ hostvars[groups['managers'][0]]['ansible_facts']['default_ipv4']['address'] }}:2377"]
> ```
>
> Preverba na managerju: `docker node ls` (vsi `Ready`, managerji `Leader`/`Reachable`).

## Pričakovan izpis

```
$ ansible-playbook -i inventories/aws/hosts.yml site.yml
...
TASK [docker : Namesti Docker Engine] ****
changed: [control]
...
RUNNING HANDLER [docker : Restart docker] ****
changed: [control]
...
PLAY RECAP
control : ok=...  changed=...  unreachable=0  failed=0   (prvi zagon, ~2 min)

$ ansible-playbook site.yml --tags docker
control : ok=...  changed=0  unreachable=0  failed=0

po novi prijavi:
$ id
uid=1000(lab) gid=1000(lab) groups=...,docker

korak 5:
29.8.2 / 29.8.2
29.8.2 true json-file
active
Hello from Docker!
```

## Vprašanja za razmislek

- Zakaj validacija `daemon.json` (`dockerd --validate`) pred zamenjavo
  datoteke in ne po njej?
- Kaj naredi `site.yml` na strežniku, kjer je nekdo Docker že namestil
  ročno (`lab reset`, nato `lab install-docker`, nato `site.yml`)?
- Tag `docker` izbere taske, `--limit` izbere hoste. Kdaj rabite enega in
  kdaj drugega?
- Skupina `docker` je enakovredna root dostopu. Kdo jo sme imeti v produkciji?

Rešitev: [`../resitve/A03-projekt-rola-docker/`](../resitve/A03-projekt-rola-docker/README.md).
