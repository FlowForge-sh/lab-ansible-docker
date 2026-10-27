# Ansible 1: postavitev in osnovna arhitektura

Trajanje: ~45 min · Vaji: A01, A02

Cilj: postaviti control node s skripto (ponovljivo, z enakimi verzijami za
vse), razumeti gradnike Ansibla na majhnem primeru in vedeti, kaj pomeni
idempotenca. Osnove (inventory, playbook, template, handler na enem hostu) so
v uvodnem tečaju osnov Dockerja in Ansibla na enem stroju; tu jih ponovimo na
večnodnem primeru s pravim SSH.

## 1. Arhitektura

```
   control node (vaš laptop, CI runner, strežnik za avtomatizacijo)           managed nodes
  ┌─────────────────────────────────────────────┐         ┌──────────────┐
  │ ansible-core (Python, venv)                 │  SSH    │ node1        │
  │ kolekcije: community.docker, ansible.posix  │ ──────► │ python3      │
  │ ansible.cfg      kako                       │         ├──────────────┤
  │ inventories/     kje (hosti, skupine, vars) │         │ node2 ...    │
  │ playbooks, roles kaj                        │         └──────────────┘
  └─────────────────────────────────────────────┘
  Agent na nodu ni potreben. Ansible pošlje modul (Python), ga izvede, dobi JSON.
```

- **Control node**: Linux ali macOS s Pythonom. Windows samo prek WSL.
- **Managed node**: SSH dostop in Python 3. Nič drugega.
- **Push model**: spremembo sprožite vi (ali CI), ne node sam.

## 2. Namestitev: `ansible-core` ali `ansible`

| Paket | Kaj vsebuje | Kdaj |
| --- | --- | --- |
| `ansible-core` | jedro, `ansible.builtin.*` | priporočeno: kolekcije namestite sami in jih pinate |
| `ansible` | jedro + ~80 kolekcij v eni verziji | hitro za začetek, velik |
| distribucijski paket (`apt install ansible`) | pogosto star | ne za ekipo |

Načini namestitve:

| Način | Ukaz | Opomba |
| --- | --- | --- |
| **venv** | `python3 -m venv ~/.venv && ~/.venv/bin/pip install -r requirements.txt` | pinane verzije v projektu; naš izbor |
| pipx | `pipx install --include-deps ansible-core` in `pipx inject ansible-core ansible-lint` | ločeno okolje, globalno dostopno |
| uv | `uv tool install ansible-core` | hitro, novejše |
| kontejner | execution environment (`ansible-navigator`) | AWX/AAP pristop |

`ansible-core` 2.21 zahteva na control nodu **Python 3.12 ali novejši**
(Ubuntu 24.04 ga ima). Na managed nodih zadošča starejši Python 3.

## 3. `setup-ansible.sh`: ponovljiva postavitev

Vsak član ekipe in CI mora imeti iste verzije, sicer "pri meni dela". Projekt
zato vsebuje tri datoteke in skripto:

| Datoteka | Vsebina |
| --- | --- |
| `requirements.txt` | Python paketi: `ansible-core==2.21.5`, `ansible-lint==26.10.1` |
| `requirements.yml` | kolekcije: `community.docker 5.4.0`, `ansible.posix 2.2.2`, `community.general 13.5.0` |
| `ansible.cfg` | inventory, roles_path, collections_path, SSH nastavitve |
| `setup-ansible.sh` | preveri Python, naredi venv, namesti oboje, SSH ključ, izpiše verzije |

```bash
./setup-ansible.sh
source ~/.venv/bin/activate
ansible --version            # ansible [core 2.21.5]
ansible-galaxy collection list -p ./collections
```

Kolekcije gredo v `./collections` poleg projekta (ne v `~/.ansible`), da ima
projekt svoje verzije. Skripta je idempotentna: drugi zagon ne spremeni ničesar.

**SSH ključi.** Ansible uporablja vaš SSH. Ključ ed25519, javni del na node
(`ssh-copy-id lab@node1`), zasebni ostane na control nodu. Gesla v
inventoryju (`ansible_ssh_pass`, `ansible_become_pass`) so v čisti obliki
slaba praksa; če jih morate imeti, v Ansible Vault ali SOPS.

## 4. `ansible.cfg`

```ini
[defaults]
inventory = inventories/aws/hosts.yml
roles_path = roles
collections_path = collections
interpreter_python = auto_silent
callback_result_format = yaml

[ssh_connection]
ssh_args = -o StrictHostKeyChecking=accept-new -o ControlMaster=auto -o ControlPersist=60s
pipelining = true
```

Ansible išče `ansible.cfg` v trenutni mapi, nato `~/.ansible.cfg`, nato
`/etc/ansible/ansible.cfg` (prvi zmaga, ne združujejo se). `ansible
--version` pokaže, katerega uporablja. `ansible-config dump --only-changed`
pokaže, kaj ste spremenili.

`StrictHostKeyChecking=accept-new`: nov host ključ sprejme, spremenjenega
zavrne. Izklop preverjanja (`host_key_checking = False`) je udoben in nevaren.

## 5. Inventory, skupine, spremenljivke

```yaml
# primer z več hosti (na vašem strežniku: inventories/aws/hosts.yml, en host control)
all:
  vars:
    ansible_user: lab
  children:
    docker_hosts:
      hosts: { node1: , node2: , node3: , node4: }
    app_hosts:                # kje tečejo aplikacije
      hosts: { node1: , node2: }
    monitoring:               # kje teče Prometheus
      hosts: { node1: }
```

En host je lahko v več skupinah. Skupina pove **vlogo** hosta, ne njegove
lokacije.

```bash
ansible-inventory --graph
ansible-inventory --host node1          # vse spremenljivke enega hosta
ansible app_hosts --list-hosts
ansible 'docker_hosts:!app_hosts' --list-hosts   # razlika skupin
```

Spremenljivke po prednosti (poenostavljeno, od šibke proti močni): role
`defaults/` → `group_vars/all` → `group_vars/<skupina>` → `host_vars/<host>`
→ `vars:` v playu → `set_fact`/`register` → `-e` na ukazni vrstici.
Okolje (lab, test, prod) = svoja mapa `inventories/<okolje>/` z istimi imeni
spremenljivk in drugimi vrednostmi.

## 6. Ad-hoc ukazi in moduli

Ad-hoc = en modul na več hostih, brez playbooka. Za vprašanja, ne za
spremembe, ki jih želite ponoviti.

```bash
ansible all -m ansible.builtin.ping
ansible docker_hosts -m ansible.builtin.shell -a 'docker info | grep -E "Server Version|Live Restore"'
# Pozor: {{ ... }} v -a Ansible razume kot Jinja2; Go predloge (--format) zato v ad-hoc ukazih izpustite.
ansible app_hosts -m ansible.builtin.setup -a 'filter=ansible_default_ipv4'
ansible all -b -m ansible.builtin.apt -a 'name=ncdu state=present'   # -b = become (sudo); prvič changed, drugič ok
```

Modul je enota dela: `apt`, `copy`, `template`, `service`, `user`,
`community.docker.docker_container`, `docker_compose_v2`, `docker_host_info`. Vsak modul
pozna želeno stanje in poroča `ok` (nič ni bilo treba) ali `changed`.
`command` in `shell` tega ne vesta, zato jim dodate `changed_when` in
`creates`. Dokumentacija brez interneta: `ansible-doc community.docker.docker_compose_v2`.

## 7. Playbook, task, handler, facts

```yaml
- name: Osnovna priprava nodov
  hosts: docker_hosts
  become: true
  vars:
    motd_text: "Ta strežnik upravlja Ansible"
  tasks:
    - name: Orodja
      ansible.builtin.apt:
        name: [htop, jq]
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: Sporočilo ob prijavi
      ansible.builtin.copy:
        content: "{{ motd_text }} ({{ ansible_facts['hostname'] }}, {{ ansible_facts['default_ipv4']['address'] }})\n"
        dest: /etc/motd
        mode: "0644"
      notify: Izpiši spremembo

  handlers:
    - name: Izpiši spremembo
      ansible.builtin.debug:
        msg: "motd spremenjen na {{ inventory_hostname }}"
```

- **Play**: kateri hosti, kot kdo, kateri taski.
- **Task**: en klic modula z imenom.
- **Handler**: task, ki teče samo, če ga je kdo `notify`, enkrat na koncu
  playa (ali ob `meta: flush_handlers`). Tipično: restart storitve po
  spremembi konfiguracije.
- **Facts**: podatki o hostu, zbrani na začetku (`ansible_facts['hostname']`,
  `['default_ipv4']['address']`, `['distribution_release']`).
- **register**: rezultat taska v spremenljivko; **when**: pogoj.

## 8. Role in kolekcije

**Rola** je mapa s fiksno strukturo, ki jo playbook uporabi po imenu:

```
roles/docker/
├── defaults/main.yml    privzete vrednosti (inventory jih povozi)
├── vars/main.yml        konstante role
├── tasks/main.yml       taski (lahko import_tasks drugih datotek)
├── handlers/main.yml    handlerji
├── templates/*.j2       predloge
├── files/               statične datoteke
└── meta/main.yml        opis, odvisnosti
```

**Kolekcija** je paket modulov, rol in pluginov z imenom `namespace.ime`
(`community.docker`). Namesti se z `ansible-galaxy collection install`.
V taskih vedno uporabljajte polno ime (FQCN): `community.docker.docker_compose_v2`,
ne `docker_compose_v2`. ansible-lint to preverja.

## 9. Idempotenca

Playbook, pognan dvakrat zapored, mora drugič poročati `changed=0`. Šele
potem mu zaupate: vsak `changed` pomeni resnično spremembo, ki jo lahko
pregledate z `--check --diff`.

| Ni idempotentno | Idempotentno |
| --- | --- |
| `shell: echo "x" >> /etc/conf` | `lineinfile: line=x` |
| `command: docker run -d --name web nginx` | `community.docker.docker_container: name=web image=nginx` |
| `command: apt-get install -y docker-ce` | `apt: name=docker-ce state=present` |
| `command: docker network create app` | `community.docker.docker_network: name=app` |

## 10. ansible-lint

```bash
ansible-lint                 # celoten projekt, profil "production" je najstrožji
ansible-lint --profile=basic site.yml
```

Preverja FQCN, imena taskov, `changed_when` pri `command`, pravice datotek,
odvečne `latest` verzije, YAML slog. V CI naj teče na vsak merge request.

## 11. Povzetek

- Control node z venv in pinanimi verzijami (`setup-ansible.sh`), managed node samo SSH + Python.
- `ansible.cfg` v projektu; `accept-new` za host ključe.
- Inventory: skupine po vlogi (`docker_hosts`, `app_hosts`, `monitoring`); vrednosti v `group_vars`, okolje = mapa.
- Modul pozna želeno stanje; `command`/`shell` samo z `changed_when`.
- Drugi zagon `changed=0`, sicer playbooku ne zaupamo.

## Viri

- Ansible: Installing Ansible, https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html
- Ansible: Ansible core support matrix (Python verzije), https://docs.ansible.com/projects/ansible/latest/reference_appendices/release_and_maintenance.html
- Ansible: Getting started, https://docs.ansible.com/projects/ansible/latest/getting_started/index.html
- Ansible: How to build your inventory, https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html
- Ansible: Variable precedence, https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence
- Ansible: Roles, https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html
- Ansible: Using collections, https://docs.ansible.com/projects/ansible/latest/collections_guide/index.html
- Ansible: Configuration settings, https://docs.ansible.com/projects/ansible/latest/reference_appendices/config.html
- Ansible Lint documentation, https://docs.ansible.com/projects/lint/
- pipx: Installing Ansible, https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html#installing-and-upgrading-ansible-with-pipx
