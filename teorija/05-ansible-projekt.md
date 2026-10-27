# Ansible 2: projekt z eno aplikacijo, nato še z drugo

Trajanje: ~45 min · Vaje: A03, A04, A05 (obvezne), neobvezno A06 (§5)

Cilj: zgraditi majhen, a resničen projekt, ki na Docker hoste postavi Docker
Engine in nanje aplikacijo kot `docker compose` projekt, nato dodati drugo
aplikacijo skoraj samo s podatki, in na koncu varno nadgraditi Docker Engine
na vseh hostih. Struktura je namenoma podobna temu, kar ekipe uporabljajo v
produkciji (pogosto rola `docker` in po ena rola na aplikacijo), le da je
tu aplikacijska rola ena, generična.

Na AWS labu je ta projekt (brez app2) ob postavitvi strežnika pripravljen v
`~/projekt`, pognali pa ga boste sami: A03 `site.yml` (§2, samo Docker),
A04 `deploy.yml --tags app1` (§3, app1 in nov pozdrav), A05 §4 (app2).

## 1. Struktura projekta

```
ansible-projekt/
├── ansible.cfg
├── requirements.txt, requirements.yml, setup-ansible.sh
├── inventories/
│   └── aws/
│       ├── hosts.yml              control v docker_hosts, app_hosts, monitoring (ansible_connection: local)
│       └── group_vars/all.yml     docker_version, apps: [app1, app2]
├── roles/
│   ├── docker/                    OS priprava, uradni repo, daemon.json, live-restore
│   └── app/                       generičen deploy ene aplikacije (compose projekt)
├── files/apps/                    app1/{compose.yml.j2,html/index.html.j2}, app2/ (kopija app1)
├── site.yml                       Docker Engine na vseh hostih
├── deploy.yml                     aplikacije na app_hosts
└── upgrade.yml                    rolling upgrade Docker Engine (serial: 1)
```

Ločitev, ki se izplača: **koda** (role, playbooki) je ista za vsa okolja,
**podatki** (inventory, group_vars) so po okolju. Nova aplikacija ali novo
okolje ne spreminja rol.

## 2. Rola `docker`

1. `assert`: podprt OS.
2. Priprava: Python moduli, ki jih rabijo community.docker moduli na hostu
   (`python3-docker`, `python3-yaml`), ura (chrony), požarni zid (ufw: SSH
   in porti za metrike samo z monitoring hosta). Pozor: porti, ki jih objavi
   Docker, gredo mimo ufw.
3. Uradni repozitorij: `get_url` za ključ, `deb822_repository` za vir.
4. Točna verzija: `apt-cache madison` → `docker-ce=5:29.8.2-1~ubuntu.24.04~noble`
   (task samo bere, zato `check_mode: false`: deluje tudi ob `--check`).
5. `daemon.json` iz slovarja v `vars/` (`to_nice_json`), z
   `validate: dockerd --validate --config-file %s` (pokvarjena datoteka ne
   pride na disk). Vključuje rotacijo logov, metrike in `live-restore`.
6. Handler `Restart docker`, `meta: flush_handlers`, preverjanje verzije.

Drugi zagon: `changed=0`.

Play v `site.yml` kliče rolo s tagom `docker`:
`ansible-playbook site.yml --tags docker` požene samo njo (koristno, ko bo
v `site.yml` več rol). Tag izbere taske, `--limit` izbere hoste; inventory
izberete z `-i` (privzetega določa `ansible.cfg`).

## 3. Rola `app`: ena koda, poljubno aplikacij

Vhod: `app_name`, `app_vars` (v predlogah kot `app.*`), `app_files`, `app_state`.

1. Mape in dodatne datoteke (npr. `html/index.html.j2`) kot predloge v
   `/opt/apps/<ime>/`.
2. `files/apps/<ime>/compose.yml.j2` v `/opt/apps/<ime>/compose.yml` z
   `validate: docker compose -f %s config -q`.
3. `community.docker.docker_compose_v2` s `project_src`, `state`,
   `pull: missing`, `remove_orphans: true`, `wait: true` (počaka na zdrave
   kontejnerje).
4. `uri` na port aplikacije: deploy je uspešen šele, ko aplikacija odgovarja.

`deploy.yml` rolo pokliče za vsak element seznama `apps`:

```yaml
- name: Deploy aplikacije
  ansible.builtin.include_role:
    name: app
  vars:
    app_name: "{{ app_item.name }}"
    app_files: "{{ app_item.files | default([]) }}"
    app_vars: "{{ app_item.vars | default({}) }}"
    app_state: "{{ app_item.state | default('present') }}"
    apply:
      tags: [app, deploy, "{{ app_item.name }}"]   # tagi za taske role
  tags: [always]           # sam include se izvede vedno, filtrira apply
  loop: "{{ apps }}"
  loop_control:
    loop_var: app_item     # rola uporablja item; brez tega se spremenljivki prekrijeta
  when: only is not defined or app_item.name == only
```

Tagi: `include_role` je dinamičen, zato tagi na samem includu ne preidejo
na taske role. `apply` jim doda tage `app`, `deploy` in ime aplikacije, tako
da `ansible-playbook deploy.yml --tags app1` posodobi samo app1, `--tags
app` vse aplikacije. Taski za mape in datoteke imajo še tag `config`
(`--tags config` zapiše datoteke brez `compose up`). Dinamičnih tagov
`--list-tags` ne izpiše. `-e only=app1` je enakovreden način brez tagov.

Play teče na **vseh** hostih iz `app_hosts`; vsak host ima svoj compose
projekt. Pred več hosti v produkciji stoji load balancer.

Vsebina, ki se pogosto spreminja (pozdravna stran, konfiguracija), je v
bind mountu **mape** (`./html`): Ansible zamenja datoteko, kontejner jo vidi
takoj, brez ponovnega zagona. Bind mount ene datoteke bi kazal staro vsebino
(nov inode).

> **Alternativa v Swarmu** (samo za informacijo)
>
> | Ansible + compose | Ansible + Swarm |
> | --- | --- |
> | rola `docker` | rola `docker` + rola `swarm` (`community.docker.docker_swarm` init/join, `docker_node` za vloge in labele, `throttle: 1`) |
> | `community.docker.docker_compose_v2` na vsakem hostu | `community.docker.docker_stack` na enem managerju (`hosts: managers[0]`) |
> | `validate: docker compose -f %s config -q` | `validate: docker stack config -c %s` |
> | bind mount mape za vsebino | Swarm `configs`, ime s hashem vsebine (configi so nespremenljivi) |

## 4. Druga aplikacija

Za `app2` (enaka kot app1, drug pozdrav in port 8081) dodamo:

1. mapo `files/apps/app2/`: kopija `files/apps/app1/` (predlogi sta
   generični, ime pride iz `app_name`, pozdrav in port iz `app.*`),
2. element v `apps` (ime, `files`, `vars` z `image`, `port: 8081`,
   `greeting`).

Rola se ne spremeni. `ansible-playbook deploy.yml` poroča `ok` za app1 in
`changed` za app2. `-e only=app2` deploya samo eno, `state: absent` jo
odstrani. To je isti vzorec kot v vaji 07 tečaja 02 (ena rola, seznam
aplikacij v inventoryju), tu s compose projekti na več hostih.

Kdaj ena generična rola in kdaj rola na aplikacijo? Generična, dokler se
aplikacije razlikujejo samo v compose datoteki in vrednostih. Ko aplikacija
potrebuje svoje korake (migracija baze, inicializacija bucketa, secret iz
trezorja), dobi svojo rolo, ki na koncu kliče `app`.

## 5. Posodobitev in rollback aplikacije (vaja A06)

Posodobitev je sprememba podatka (`image: nginx:1.31-alpine`) in
`deploy.yml`. Rollback je ista operacija s staro vrednostjo: deklarativno,
na točno verzijo, v gitu. Neobstoječa oznaka pade že pri `pull` (pred
zamenjavo kontejnerja), zato stara verzija streže naprej. Compose kontejner
zamenja (ustavi starega, zažene novega); brez izpada pomeni več hostov in
`--limit` ali `serial`.

## 6. Nadgradnja Docker Engine: `upgrade.yml` (dodatno, ni vaja)

```yaml
- name: Rolling upgrade Docker Engine
  hosts: docker_hosts
  become: true
  serial: 1                 # en host naenkrat
  order: inventory
  any_errors_fatal: true    # ob napaki stop, ne nadaljuj na naslednji host
  pre_tasks:
    - preskoči host, ki že ima ciljno verzijo (meta: end_host)
    - preveri live-restore (docker info), opozori, če ni vklopljen
  roles:
    - docker                # nova docker_version iz group_vars, handler restart
  post_tasks:
    - aplikacije na hostu odgovarjajo (uri na port vsake aplikacije, retries)
```

Postopek: v `group_vars/all.yml` spremenite `docker_version: "29.9.1"`,
`ansible-playbook upgrade.yml`. Z `live-restore` kontejnerji med restartom
dockerd tečejo naprej. Isti playbook je uporaben za vsako vzdrževanje hosta
(jedro OS, reboot): zamenjate samo srednji del. S pravim load balancerjem
pred `roles` host vzamete iz bazena in ga v `post_tasks` vrnete.

> **Alternativa v Swarmu** (samo za informacijo)
>
> Swarm ne dovoli `live-restore`. Namesto tega `pre_tasks` naredijo drain
> (`community.docker.docker_node` z `availability: drain`, `delegate_to`
> drug manager) in počakajo, da na nodu ni taskov; `post_tasks` počakajo na
> Ready/Reachable (`community.docker.docker_node_info`) in naredijo
> `availability: active`. `serial: 1` je tam nujen zaradi quoruma managerjev.

## 7. Dobre prakse, ki jih projekt pokaže

- Verzije pinane: ansible-core, kolekcije, Docker Engine, slike (`nginx:1.30-alpine`, ne `latest`).
- Skrivnosti niso v repozitoriju: Ansible Vault/SOPS, na hostu datoteka z `mode: "0600"`.
- Vsak playbook drugič `changed=0`.
- `--check --diff` pred vsakim zagonom na produkciji; `--limit` za en host.
- ansible-lint v CI (profil production zahteva tudi predpono role pri spremenljivkah: `app_*`, `docker_*`).

## 8. Povzetek

- Dve roli: `docker` (Engine), `app` (aplikacija kot compose projekt), trije playbooki.
- Skupine po vlogi: `docker_hosts`, `app_hosts`, `monitoring`.
- Generična rola + seznam `apps`: druga app = nov podatek + nova predloga.
- `upgrade.yml`: `serial: 1`, live-restore, nadgradnja, preverba aplikacij.
- Koda enaka, podatki po okolju.

## Viri

- community.docker: docker_compose_v2 module, https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_compose_v2_module.html
- community.docker: docker_container module, https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_container_module.html
- community.docker: docker_stack module (alternativa v Swarmu), https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_stack_module.html
- Docker: Live restore, https://docs.docker.com/engine/daemon/live-restore/
- Ansible: deb822_repository module, https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/deb822_repository_module.html
- Ansible: Controlling playbook execution (serial, throttle, order), https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_strategies.html
- Ansible: Error handling (any_errors_fatal), https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html
- Ansible: Validating tasks: check mode and diff mode, https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html
- Ansible: Sample Ansible setup (struktura projekta), https://docs.ansible.com/projects/ansible/latest/tips_tricks/sample_setup.html
- Docker: Upgrade Docker Engine, https://docs.docker.com/engine/install/ubuntu/#upgrade-docker-engine
