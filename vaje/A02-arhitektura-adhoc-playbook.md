# Vaja A02 · Arhitektura na enostavnem primeru: ad-hoc, moduli, playbook (neobvezna, ~30 min)

> **Neobvezna vaja.** Obvezna pot je A03 (Docker), A04 (app1), A05 (app2).
> To vajo naredite, če želite spoznati gradnike Ansibla (ad-hoc ukazi,
> moduli, playbook); naredite jo lahko kadarkoli po A01, Docker ni potreben.

## Cilj

Na svojem strežniku (en host `control` v vseh skupinah, lokalna
povezava) preizkusiti gradnike Ansibla: inventory in skupine, ad-hoc
ukaze, module, facts, playbook s spremenljivkami, `register`, `when` in
handlerjem, ter videti idempotenco (`changed=0` ob drugem zagonu) in
`--check --diff`.

## Predpogoji

- A01 (pregled): Ansible v `~/.venv` (na AWS nameščen ob postavitvi), `ansible all -m ansible.builtin.ping` vrne pong.
- Teorija: [`../teorija/04-ansible-postavitev-in-arhitektura.md`](../teorija/04-ansible-postavitev-in-arhitektura.md) §5 do §9.

## Koraki

### A. Inventory in spremenljivke

1. ```bash
   cd ~/projekt
   ansible-inventory --host control                 # ansible_user, ansible_connection
   ansible app_hosts --list-hosts
   ansible 'docker_hosts:!app_hosts' --list-hosts   # vzorci: unija (:), razlika (:!), presek (:&)
   ansible 'app_hosts:&monitoring' --list-hosts
   ```
   Na AWS je razlika prazna (`hosts (0)`): isti host je v obeh skupinah.
   Vzorci delujejo enako, le rezultat je pri enem strežniku trivialen.

### B. Ad-hoc in facts

2. ```bash
   ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*'
   ansible all -m ansible.builtin.setup -a 'filter=ansible_default_ipv4'
   ansible all -m ansible.builtin.shell -a 'df -h / | tail -1'
   ansible all -b -m ansible.builtin.apt -a 'name=ncdu state=present update_cache=true'
   ```
   Poženite zadnji ukaz dvakrat: prvič `changed: true` (ncdu se namesti),
   drugič `changed: false`. `cache_updated: true` je obakrat, ker
   `update_cache=true` brez `cache_valid_time` seznam paketov osveži ob
   vsakem zagonu; to ni sprememba sistema. (htop, jq in tree so na AWS
   strežniku že nameščeni, zato z njimi razlike ne vidite.) Zakaj se ad-hoc
   s `shell` vedno pokaže kot `CHANGED`?
3. `ansible-doc ansible.builtin.copy | head -40` in `ansible-doc -l | grep community.docker | head`.

### C. Prvi playbook: zagon

Playbook je pripravljen v `~/vaje/A02-arhitektura/priprava.yml`: play za
skupino `docker_hosts` z `become: true`, ki namesti orodja iz seznama
(`apt`), z `command: which docker` in `register` ugotovi, ali je Docker
nameščen, to izpiše (`debug`) in samo na `app_hosts` izpiše sporočilo
(`when`). Manjka ena vrstica (označena `TODO`).

4. Kopirajte ga v projekt in preberite (komentarji ob vsakem delu povedo, kaj dela):
   ```bash
   cp ~/vaje/A02-arhitektura/priprava.yml ~/projekt/ && cd ~/projekt
   less priprava.yml
   ansible-playbook priprava.yml --syntax-check
   ansible-playbook priprava.yml --list-tasks
   ```
5. Prvi zagon in drugi zagon:
   ```bash
   ansible-playbook priprava.yml      # Orodja: changed (namesti ncdu)
   ansible-playbook priprava.yml      # drugič: Orodja ok, a changed=1. Zakaj?
   ```
   Drugi zagon ni `changed=0`: task `Ali je Docker nameščen?` je vsakič
   `changed`, ker modul `command` ne ve, da ukaz `which` samo bere.
6. Popravite: v `priprava.yml` pri tasku `Ali je Docker nameščen?` dodajte
   vrstico iz komentarja `TODO`:
   ```yaml
      changed_when: false
   ```
   Še enkrat `ansible-playbook priprava.yml`: `changed=0`. To je
   idempotenca: drugi zagon ne spremeni ničesar.
7. Nov paket samo s podatkom: v seznam `orodja` dodajte `iotop`
   (`orodja: [ncdu, htop, jq, tree, iotop]`) in poženite znova:
   ```bash
   ansible-playbook priprava.yml      # Orodja: changed=1 (iotop)
   which iotop                        # /usr/sbin/iotop
   ansible-playbook priprava.yml      # changed=0
   ```
   Playbook opisuje želeno stanje: nov paket je nova vrstica v seznamu,
   ne nov ukaz.

### D. Lint

8. `ansible-lint priprava.yml`: brez opozoril. Če ste korak 6 preskočili,
   lint javi `no-changed-when` prav pri tasku z `command`. Rešitev
   (končno stanje): `~/resitve/A02-arhitektura/priprava.yml`.

## Pričakovan izpis

```
$ ansible all -b -m ansible.builtin.apt -a 'name=ncdu state=present update_cache=true'
control | CHANGED => ... changed: true      (prvič; drugič SUCCESS, changed: false)
$ ansible all -m ansible.builtin.shell -a 'df -h / | tail -1'
control | CHANGED | rc=0 >>                  (vedno CHANGED, tudi če samo bere)

TASK [Orodja] ****
changed: [control]                            (prvič; drugič ok)
TASK [Izpiši] ****
ok: [control] => { "msg": "control: docker NI nameščen" }     (po A03: JE)
TASK [Samo na app hostih] ****
ok: [control] => { "msg": "control je v skupini app_hosts" }

PLAY RECAP (prvi zagon)
control : ok=5  changed=2  ...          (Orodja, which docker)
PLAY RECAP (drugi zagon, pred popravkom)
control : ok=4  changed=1  ...          (task "Ali je Docker nameščen?"; ok je manjši,
                                         ker so facts iz predpomnilnika)
PLAY RECAP (po changed_when: false)
control : ok=4  changed=0  unreachable=0  failed=0  skipped=0
PLAY RECAP (po dodanem iotop)
control : ok=4  changed=1  ...          (Orodja), nato spet changed=0
```

## Vprašanja za razmislek

- Kdaj je ad-hoc ukaz v redu in kdaj mora sprememba v playbook?
- Kaj pomeni `changed_when: false` in kdaj je to laž?
- Kje bi seznam `orodja` definirali, da bi bil za prod drugačen kot za lab
  (namig: `group_vars` ob inventoryju)?
- Kaj naredi `state: present`, ko je paket že nameščen, in kaj bi naredil `state: latest`?
