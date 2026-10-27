# Vaja R02 · Diagnostika Ansible: inventory, sintaksa, spremenljivke, moduli (neobvezna, ~20 min)

> **Neobvezna vaja** po obveznih vajah A03 do A05 (vsaj po A04).

## Cilj

Najti in popraviti štiri tipične napake v Ansible projektu z orodji, ki jih ima
Ansible sam: `--syntax-check`, `ansible-inventory`, `ping`, `-vvv`,
`--check --diff`, `--start-at-task`, `--step`, `debug`, `ansible-lint`.

## Predpogoji

- A01 (Ansible v `~/.venv`, kolekcije v `~/projekt/collections`; na AWS
  pripravljeno ob postavitvi), Docker iz A03 in app1 iz A04, najbolje
  tudi app2 (A05).
- Teorija: [`../teorija/06-diagnostika.md`](../teorija/06-diagnostika.md) §3.
- Most iz tečaja 02: Ansible vaja 08 (iste vrste napak na enem hostu).

## Koraki

1. Na strežniku kopirajte gradivo v delovno mapo:
   ```bash
   cp -r ~/vaje/R02-ansible-diagnostika ~/r02 && cd ~/r02
   ```
   Inventory `hosts.yml` je za AWS: en host `control`, do katerega gre
   Ansible tu prek pravega SSH (`ansible_host: 127.0.0.1`), kot do
   oddaljenega strežnika.
2. **Inventory**: `ansible all -m ansible.builtin.ping`. Kateri host pade in
   s kakšnim sporočilom? Poiščite vzrok z `ansible-inventory --host control` in
   `ansible control -m ansible.builtin.ping -vvv | grep -i -E 'user|denied'`. Popravite `hosts.yml`.
   Dokler inventory ni popravljen, vsi naslednji playbooki padejo že pri
   `Gathering Facts` z `UNREACHABLE` (prava napaka se ne pokaže); napake 3
   do 6 torej iščite šele, ko `ping` vrne `pong`.
3. **napaka1.yml**: `ansible-playbook napaka1.yml --syntax-check`. Kaj je
   narobe in kako popraviti? (Dva taska.)
4. **napaka2.yml**: poženite. Preberite napako. Kako bi brez branja YAML
   ugotovili, katere spremenljivke host ima? (`debug: var=hostvars[inventory_hostname]`,
   `ansible-inventory --host control --vars`.) Popravite.
5. **napaka3.yml**: poženite. Sporočilo? Poiščite pravo ime modula
   (`ansible-doc -l community.docker | grep host`). Kaj pove `ansible-lint napaka3.yml`?
   Popravite.
6. Orodja za vmesne korake (na popravljenem napaka2.yml):
   ```bash
   ansible-playbook napaka2.yml --list-tasks
   ansible-playbook napaka2.yml --start-at-task 'Datoteka app.conf'
   ansible-playbook napaka2.yml --step
   ansible-playbook napaka2.yml --check --diff -e app_port=9090 --limit control
   ```

## Pričakovan izpis

```
(ansible-core 2.21 piše napake kot [ERROR]:)
korak 2:  control | UNREACHABLE! => ... root@127.0.0.1: Permission denied (publickey,password).
korak 3:  [ERROR]: conflicting action statements: ansible.builtin.file, ansible.builtin.debug
korak 4:  [ERROR]: Task failed: 'app_port' is undefined
korak 5:  [ERROR]: couldn't resolve module/action 'community.docker.docker_host_infos'
          (ansible-lint: syntax-check[unknown-module])
```

## Vprašanja za razmislek

- Zakaj je `--syntax-check` hitrejši od zagona in česa ne ujame?
- Katere od teh napak bi ujel ansible-lint v CI pred merge requestom?
- Kdaj uporabite `--start-at-task` in zakaj je lahko nevaren?
