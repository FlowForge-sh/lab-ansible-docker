# Rešitev · Vaja R02

| Primer | Simptom | Orodje, ki pokaže vzrok | Vzrok | Popravek |
| --- | --- | --- | --- | --- |
| inventory | `control \| UNREACHABLE! ... root@127.0.0.1: Permission denied` | `ansible-inventory --host control`, `-vvv` (vidi se `User=root`) | `ansible_user: root` na hostu povozi `lab` iz `all.vars`; root prijava s ključem ni dovoljena | vrstico odstranite (`hosts.yml` v tej mapi) |
| napaka1 | `conflicting action statements: ansible.builtin.file, ansible.builtin.debug` | `--syntax-check` | dva modula v enem tasku (manjka `- name:`) | dva taska |
| napaka2 | `'app_port' is undefined` | izpis napake, `debug: var=app_port`, `ansible-inventory --host control --vars` | tipkarska napaka `app_prot` | `app_port` |
| napaka3 | `couldn't resolve module/action 'community.docker.docker_host_infos'` | izpis, `ansible-doc -l community.docker`, `ansible-lint` (`syntax-check[unknown-module]`) | tipkarska napaka v imenu modula | `community.docker.docker_host_info` |

Ukazi (na strežniku, v `~/r02`):

```bash
ansible all -m ansible.builtin.ping                       # control UNREACHABLE
ansible-inventory --host control                          # "ansible_user": "root"
cp ~/resitve/R02-ansible-diagnostika/hosts.yml .      # ali ročno odstranite vrstico
ansible all -m ansible.builtin.ping                       # pong

ansible-playbook napaka1.yml --syntax-check               # [ERROR]: conflicting action statements
ansible-playbook napaka2.yml                              # 'app_port' is undefined
ansible-playbook napaka3.yml                              # couldn't resolve module/action
ansible-lint napaka3.yml

# popravki (datoteke v tej mapi)
for f in napaka1 napaka2 napaka3; do ansible-playbook ~/resitve/R02-ansible-diagnostika/$f.yml; done
```

Rešitve poganjajte iz `~/r02` (ansible.cfg in popravljen `hosts.yml` sta tam)
ali kopirajte celotno mapo rešitve.

## Odgovori

- `--syntax-check` prebere YAML in strukturo playbooka brez povezave na
  hoste. Ne ujame nedefiniranih spremenljivk (te se vrednotijo med izvajanjem),
  nedosegljivih hostov in manjkajočih modulov na nodu.
- ansible-lint ujame napaka1 (sintaksa), napaka3 (neznan modul),
  ne ujame
  inventoryja in tipkarske napake v imenu spremenljivke. Opomba: kratko ime
  `docker_host_info` (brez FQCN) v ansible-core 2.21 še deluje prek
  preusmeritev, ansible-lint pa ga označi z `fqcn[action]`; uporabljajte FQCN.
- `--start-at-task` preskoči vse prejšnje taske, tudi `set_fact` in
  `register`, od katerih so kasnejši odvisni. Primeren za ponovitev po napaki,
  ko veste, da je začetek že narejen.
