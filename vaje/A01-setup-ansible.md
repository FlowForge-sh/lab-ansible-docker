# Vaja A01 · Prijava in pregled projekta (obvezna, ~10 min)

## Cilj

Ogrodje tečaja je narejeno vnaprej. Na vašem strežniku so ob postavitvi
pripravljeni:

- **Ansible** (venv `~/.venv` s pinanimi verzijami, kolekcije),
- **Ansible projekt** `~/projekt` z rolama `docker` in `app`, playbookoma
  `site.yml` in `deploy.yml`, inventoryjem `aws` in predlogami prve
  aplikacije **app1** (`files/apps/app1`).

**Dockerja in aplikacij še ni.** Postavite jih sami z Ansiblom, korak za
korakom:

| Vaja | Kaj | Ukaz |
| --- | --- | --- |
| [A03](A03-projekt-rola-docker.md) | samo Docker Engine | `ansible-playbook site.yml` |
| [A04](A04-rola-app-in-app1.md) | app1, nato nov pozdrav samo za app1 | `ansible-playbook deploy.yml --tags app1` |
| [A05](A05-druga-aplikacija-app2.md) | app2: kopija app1, drug pozdrav, port 8081 | `cp -r files/apps/app1 files/apps/app2` |

Na AWS ima vsak udeleženec **en strežnik**, ki je hkrati control node (tu
teče Ansible) in Docker host (tega Ansible upravlja): Ansible cilja sam
sebe z `ansible_connection: local`.

## Predpogoji

- Prijava na strežnik (AWS: `ssh lab-control`, glej
  [`../00-priprava-aws.md`](../00-priprava-aws.md)).
- Neobvezno: teorija [`../teorija/04-ansible-postavitev-in-arhitektura.md`](../teorija/04-ansible-postavitev-in-arhitektura.md) §1 do §5.

## Koraki

### A. Ansible je, Dockerja ni

1. ```bash
   pwd                                   # /home/lab/projekt (prijava začne tu)
   ansible --version | head -1           # ansible [core 2.21.5]
   ansible all -m ansible.builtin.ping   # control | SUCCESS, "ping": "pong"
   docker ps                             # docker: command not found
   lab status                            # docker: še ni nameščen (vaja A03)
   ```
   Če Ubuntu predlaga `sudo snap install docker` ali `apt install docker.io`:
   **ne**. Docker namesti Ansible (rola `docker`) v vaji A03, s točno
   verzijo iz uradnega repozitorija.

### B. Kaj je v projektu

2. ```bash
   tree -L 3 -I collections
   ```
   | Pot | Kaj |
   | --- | --- |
   | `ansible.cfg` | privzet inventory `inventories/aws`, kolekcije v `./collections` |
   | `inventories/aws/hosts.yml` | en host `control` v skupinah `docker_hosts`, `app_hosts`, `monitoring` |
   | `inventories/aws/group_vars/all.yml` | verzija Dockerja, `daemon.json`, seznam aplikacij `apps` (zdaj samo app1) |
   | `site.yml` + `roles/docker/` | A03: namestitev Docker Engine (repozitorij, točna verzija, `daemon.json`) |
   | `deploy.yml` + `roles/app/` | A04, A05: generična rola, iz predlog v `files/apps/<ime>/` postavi compose projekt v `/opt/apps/<ime>` |
   | `files/apps/app1/` | predlogi `compose.yml.j2` in `html/index.html.j2` |
   | `setup-ansible.sh`, `requirements.*` | kako je bil Ansible postavljen (venv, pip, kolekcije) |
3. Inventory in podatki:
   ```bash
   ansible-inventory --graph
   grep -n inventory ansible.cfg
   grep -A8 '^apps:' inventories/aws/group_vars/all.yml
   ```
   Odkod bo prišel pozdrav app1? (`greeting` v `group_vars`, v predlogi
   `files/apps/app1/html/index.html.j2` kot `{{ app.greeting }}`.)

### C. Kako je to nastalo (neobvezno)

4. ```bash
   less /usr/local/sbin/lab-bootstrap-control   # venv, kolekcije, ~/projekt
   sudo grep -E "ne postavljam|NAPAKA" /var/log/lab-bootstrap.log
   ansible-galaxy collection list -p ./collections
   ```
   Zakaj priprava ne prepiše `~/projekt`, če že obstaja?

## Pričakovan izpis

```
$ ansible --version | head -1
ansible [core 2.21.5]
$ ansible all -m ansible.builtin.ping
control | SUCCESS => { "changed": false, "ping": "pong" }
$ docker ps
Command 'docker' not found, ...
$ ansible-inventory --graph
@all:
  |--@ungrouped:
  |--@docker_hosts:
  |  |--control
  |--@app_hosts:
  |  |--control
  |--@monitoring:
  |  |--control
```

## Vprašanja za razmislek

- Zakaj venv in pinane verzije namesto `apt install ansible`?
- Kdaj je `ansible_connection: local` smiseln v praksi (CI runner, ki
  konfigurira sam sebe, `ansible-pull`) in kdaj ne?

