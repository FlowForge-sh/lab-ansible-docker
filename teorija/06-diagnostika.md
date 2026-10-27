# Razno 1: diagnostika v primeru težav

Trajanje: ~30 min · Vaja: R02 (Docker preverba in diagnostika sta v A03, A04 in A05)

Cilj: imeti postopek, ki ga uporabite vsakič, ko "nekaj ne dela", in poznati
ukaze, ki pri Dockerju na hostu in pri Ansiblu povedo **zakaj**. Osnove za posamezen
kontejner (`logs`, `inspect`, `exec`, exit kode) so v tečaju 02, Docker vaja 06.

## 1. Postopek

```
1. Simptom natančno:   kaj ne dela, od kdaj, za koga, kaj se je spremenilo?
2. Obseg:              en kontejner, ena aplikacija, en host, vsi hosti?
3. Od zgoraj navzdol:  Ansible izpis → host → Engine → projekt → kontejner → aplikacija
4. Ena hipoteza naenkrat, en popravek naenkrat, preveri.
5. Zapiši: vzrok, popravek, kako preprečiti (alarm, healthcheck, test).
```

Najprej poglejte, kaj se je spremenilo (deploy, nadgradnja, nov host). Večina
izpadov je posledica spremembe.

## 2. Docker na hostu: od hosta do kontejnerja

V tem tečaju Docker postavi Ansible, zato diagnostiko začnete na control nodu
(kaj je Ansible poročal), nato na hostu (na AWS ste že na njem) greste
od zgoraj navzdol.

| Raven | Ukaz | Kaj iščete |
| --- | --- | --- |
| Engine | `docker info`, `docker version` | ali dockerd teče, verzija, `Live Restore Enabled`, `Logging Driver` |
| Engine | `sudo journalctl -u docker -n 50` (v labu `/var/log/docker.log`) | zakaj se dockerd ne zažene (npr. napačen `daemon.json`) |
| projekti | `docker compose ls` | ali compose projekt obstaja in teče (`running(1)`) |
| kontejnerji | `docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'` | `Exited (1)`, `Restarting`, `(unhealthy)`, manjkajoč port |
| kontejner | `docker logs --tail 50 -f <c>` | napaka aplikacije ob zagonu, dostopni log |
| kontejner | `docker inspect <c> --format '{{json .State}}'` | `ExitCode`, `OOMKilled`, `Health`, `Error` |
| kontejner | `docker inspect <c> --format '{{json .State.Health}}'` | izpis zadnjih healthcheckov |
| viri | `docker stats --no-stream` | CPU, RAM blizu limita |
| dogodki | `docker events --since 10m` | `die`, `oom`, `health_status`, kdo je kaj ustavil |
| mreža | `docker network ls`, `docker network inspect <mreža>` | ali sta kontejnerja v isti mreži |
| aplikacija | `curl -sv localhost:<port>/` | ali port odgovarja na hostu |

### Pogosti vzroki

| Simptom | Vzrok | Popravek |
| --- | --- | --- |
| `Bind for 0.0.0.0:8080 failed: port is already allocated` | port že zaseda drug kontejner ali proces | `docker ps`, `ss -lntp`; drug port v `group_vars` |
| `Restarting (1)` | aplikacija pade ob zagonu (npr. napaka v konfiguraciji) | `docker logs` |
| `Exited (137)`, `OOMKilled=true` | premajhen `limits.memory` | večji limit v compose predlogi |
| `(unhealthy)`, kontejner teče | healthcheck pada; samostojni Docker kontejnerja ne zamenja | ukaz healthchecka ročno z `docker exec` |
| `Exited (0)` po ročnem `docker stop` | `unless-stopped` ga ne zažene sam | `ansible-playbook deploy.yml --limit <host>` |
| ime drugega kontejnerja se ne razreši | nista v isti uporabniški mreži (privzeti `bridge` nima DNS) | skupna mreža v compose |

Popravek naredite v Ansible projektu (predloga ali `group_vars`) in ga
uveljavite z `deploy.yml`. Ročni popravek na hostu je samo za preizkus
hipoteze: naslednji zagon Ansibla ga povozi.

> **Alternativa v Swarmu** (samo za informacijo)
>
> V Swarmu gre pot od clustra navzdol: `docker node ls` → `docker service ls`
> → `docker service ps <s> --no-trunc` (stolpec `ERROR`, stanja `Pending`,
> `Rejected`) → `docker service logs <s>`. `Pending` pomeni razporejanje
> (constraint, rezervacije, drain), `Rejected` napako na nodu (slika,
> registry). Med nodi morajo biti odprti porti 2377, 7946 in 4789/udp.

## 3. Ansible

| Ukaz | Za kaj |
| --- | --- |
| `ansible-playbook site.yml --syntax-check` | YAML in struktura, brez povezave |
| `ansible-lint` | slogovne in pogoste napake |
| `ansible-inventory --graph` in `--host node1` | ali je host v skupini, katere spremenljivke dobi |
| `ansible all -m ansible.builtin.ping` | SSH, uporabnik, Python |
| `ansible-playbook site.yml --check --diff` | kaj bi se spremenilo, brez sprememb |
| `-v`, `-vv`, `-vvv`, `-vvvv` | več podrobnosti; `-vvvv` pokaže SSH povezavo |
| `--limit node2` | samo en host |
| `--start-at-task "Ime taska"` | nadaljuj od taska, kjer je padlo |
| `--step` | potrdi vsak task posebej |
| `--list-tasks`, `--list-hosts`, `--list-tags` | kaj bi se izvedlo |
| `ansible.builtin.debug: var=ime` | vrednost spremenljivke med izvajanjem |
| `ANSIBLE_DEBUG=1` | interni debug (zelo veliko) |

### Pogoste napake

| Izpis | Vzrok | Popravek |
| --- | --- | --- |
| `UNREACHABLE! ... Permission denied (publickey)` | napačen uporabnik ali ključ | `ansible_user`, `ssh -i ... lab@node1` ročno |
| `UNREACHABLE! ... Host key verification failed` | node ima nov host ključ (reinstall) | `ssh-keygen -R node1`, preverite, da je to pričakovano |
| `Missing sudo password` | `become` brez NOPASSWD | `-K` ali sudoers |
| `'xyz' is undefined` | spremenljivka ni definirana za ta host (napačna skupina, tipkarska napaka) | `ansible-inventory --host`, `debug` |
| `couldn't resolve module/action 'docker_stack'` | kolekcija ni nameščena ali ni FQCN | `ansible-galaxy collection install -r requirements.yml`, `collections_path` |
| `Failed to import the required Python library (Docker SDK for Python)` | na **nodu** manjka Python modul | `python3-docker` na nodu (rola docker) |
| `The loop variable 'item' is already in use` | `include_role` v zanki, rola uporablja `item` | `loop_control: loop_var` |
| `changed` ob vsakem zagonu | `command` brez `changed_when`, predloga z datumom | `changed_when`, odstranite spremenljive dele |
| `ERROR! conflicting action statements` | dva modula v enem tasku, slab zamik | YAML zamik |

## 4. Povzetek

- Od zgoraj navzdol: `docker info` → `compose ls` → `ps -a` → `logs` → `inspect`.
- Exit koda pove veliko: 1 aplikacija, 137 OOM ali kill, 0 ročni stop.
- Popravek v Ansible projektu, ne ročno na hostu; DNS med kontejnerji samo v skupni mreži.
- Ansible: `--syntax-check`, `ansible-inventory`, `ping`, `--check --diff`, `-vvv`, `--start-at-task`.
- Vsak incident konča z zapisom in preventivo (alarm, healthcheck, test).

## Viri

- Docker: docker container logs, https://docs.docker.com/reference/cli/docker/container/logs/
- Docker: docker container inspect, https://docs.docker.com/reference/cli/docker/container/inspect/
- Docker: docker system events, https://docs.docker.com/reference/cli/docker/system/events/
- Docker: docker compose ls, https://docs.docker.com/reference/cli/docker/compose/ls/
- Docker: Bridge network driver, https://docs.docker.com/engine/network/drivers/bridge/
- Docker: Swarm task states (alternativa v Swarmu), https://docs.docker.com/engine/swarm/how-swarm-mode-works/swarm-task-states/
- Ansible: Debugging tasks, https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_debugger.html
- Ansible: Validating tasks: check mode and diff mode, https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html
- Ansible: Executing playbooks for troubleshooting (start-at-task, step), https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_startnstep.html
- Ansible: Connection methods and details, https://docs.ansible.com/projects/ansible/latest/inventory_guide/connection_details.html
