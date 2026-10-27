# Vaja A04 · Prva aplikacija app1: deploy, nov pozdrav in tagi (obvezna, ~30 min)

## Cilj

Z `deploy.yml` in generično rolo `app` postaviti prvo aplikacijo **app1**
(nginx s pozdravno stranjo, port 8080) kot `docker compose` projekt, jo
preveriti z `docker` ukazi in nato **spremeniti pozdrav samo s
spremembo podatka** v inventoryju. Ob tem spoznate **tage**: z
`--tags app1` poženete samo taske za app1, ne celega playbooka.

Rola `app`, `deploy.yml` in predloge `files/apps/app1` so pripravljeni; v
tej vaji jih poženete in spreminjate samo podatke.

## Predpogoji

- A03: Docker teče, `docker ps` deluje **brez** `sudo` (po novi prijavi).
- Teorija: [`../teorija/05-ansible-projekt.md`](../teorija/05-ansible-projekt.md) §3 (rola app, tagi) in §5.
- Neobvezno ozadje (aplikacija kot compose projekt): [`../teorija/01-ozadje-docker-engine.md`](../teorija/01-ozadje-docker-engine.md) §4.
- Priporočeno: **dve SSH seji** (dva terminala, v obeh `ssh lab-control`).
  V drugi boste gledali log kontejnerja (`docker logs -f`).

## Koraki

### A. Predloge, podatki in tagi (5 min)

1. ```bash
   cat files/apps/app1/compose.yml.j2        # image, port, ./html bind mount, healthcheck, limiti
   cat files/apps/app1/html/index.html.j2    # <h1>{{ app.greeting }}</h1>
   grep -A8 '^apps:' inventories/aws/group_vars/all.yml   # app1: image, port 8080, greeting
   cat deploy.yml                            # include_role app v zanki čez apps
   grep -n 'tags' deploy.yml roles/app/tasks/main.yml
   ```
   `deploy.yml` vsakemu tasku role `app` doda tage `app`, `deploy` in
   **ime aplikacije** (`apply: tags: [app, deploy, "{{ app_item.name }}"]`).
   Taski s predlogami imajo še tag `config`. Zato:

   | Ukaz | Kaj teče |
   | --- | --- |
   | `ansible-playbook deploy.yml` | vse aplikacije iz `apps` |
   | `ansible-playbook deploy.yml --tags app1` | samo taski za app1 |
   | `ansible-playbook deploy.yml --tags app` | vse aplikacije (enako kot brez taga) |
   | `ansible-playbook deploy.yml --tags config` | samo mape in predloge, brez `docker compose up` |
   | `ansible-playbook deploy.yml -e only=app1` | samo app1, s spremenljivko namesto taga |

   Tagi so dinamični (iz zanke), zato jih `--list-tags` ne izpiše.

### B. Deploy app1 s tagom (5 min)

2. ```bash
   ansible-playbook deploy.yml --tags app1
   ```
   Taski: mape, `Dodatne datoteke za app1` (index.html), `Compose datoteka
   za app1` (preverjena z `docker compose config`), `Compose projekt app1`
   (slika, kontejner, čaka na healthy), `HTTP preverba za app1`.
3. Preverite:
   ```bash
   docker ps                                 # app1-web-1 ... Up ... (healthy) 0.0.0.0:8080->80/tcp
   docker compose ls                         # app1 running(1) /opt/apps/app1/compose.yml
   curl -s localhost:8080                    # <h1>Pozdrav iz app1</h1>
   ls -R /opt/apps/app1                      # compose.yml, html/index.html (zapisal Ansible)
   ```
   V brskalniku: http://<javni IP strežnika>:8080.
4. Drugi zagon: `ansible-playbook deploy.yml --tags app1`: `changed=0`.

### C. Log kontejnerja v živo (5 min)

5. V **drugi** seji:
   ```bash
   docker logs -f app1-web-1
   ```
   Vsakih 10 s se pojavi vrstica healthchecka (`"Wget"`). V **prvi** seji
   nekajkrat `curl -s localhost:8080 >/dev/null` in osvežite brskalnik:
   vsak zahtevek je nova vrstica (`"GET / HTTP/1.1" 200 ... "curl/..."`).
   `docker logs -f` pustite teči za korak 6; ustavite ga s Ctrl+C.
   Še nekaj različic:
   ```bash
   docker logs --tail 5 app1-web-1           # zadnjih 5 vrstic, brez -f
   docker logs --since 2m app1-web-1         # zadnji 2 minuti
   docker compose -p app1 logs -f            # isto prek compose projekta
   ```

### D. Nov pozdrav samo za app1 (10 min)

6. V `inventories/aws/group_vars/all.yml` spremenite pozdrav app1:
   ```bash
   nano inventories/aws/group_vars/all.yml   # greeting: "Pozdrav iz app1, verzija 2"
   ```
   in poženite **samo app1**, s prikazom razlik:
   ```bash
   ansible-playbook deploy.yml --tags app1 --diff
   ```
   `--diff` pokaže spremenjeno vrstico `<h1>...`. Kateri task je `changed`?
7. ```bash
   curl -s localhost:8080 | grep h1          # nov pozdrav
   docker ps --format '{{.Names}} {{.Status}}'   # STATUS "Up ... minutes": kontejner NI bil ponovno zagnan
   ```
   Zakaj ne? Stran je v bind mountu **mape** `./html`: Ansible zamenja
   datoteko, nginx jo takoj streže. V drugi seji (`docker logs -f`) vidite
   vaš `curl`, ne pa ponovnega zagona nginx.
8. Še enkrat `ansible-playbook deploy.yml --tags app1`: `changed=0`.
9. Samo predloge, brez `docker compose up`:
   ```bash
   ansible-playbook deploy.yml --tags config  # samo Mape, Dodatne datoteke, Compose datoteka
   ```
   Koliko taskov je teklo v primerjavi s `--tags app1`?

### Preverba na strežniku (5 min)

10. Na strežniku (ste že na njem):
    ```bash
    docker compose ls                                   # projekt app1, running(1)
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
    cat /opt/apps/app1/compose.yml                      # izpolnjena predloga
    cat /opt/apps/app1/html/index.html                  # vaš pozdrav
    docker inspect app1-web-1 --format '{{.State.Health.Status}} {{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}'
    docker stats --no-stream app1-web-1                 # poraba proti limitu 64MiB
    docker logs --tail 3 app1-web-1
    ```
11. Isto za vse hoste z aplikacijami brez prijave:
    `ansible app_hosts -m ansible.builtin.command -a 'docker compose ls'`.

### E. Neobvezno: drift in rollback

12. **Drift.** `docker stop app1-web-1`, nato `docker ps -a` (STATUS
    `Exited (0)`) in `curl -s localhost:8080` (ne dela). `restart:
    unless-stopped` ga ne zažene sam. `ansible-playbook deploy.yml --tags
    app1`: task `Compose projekt app1` je `changed`, kontejner spet teče.
    Ansible vrne stanje, ki je opisano v projektu.
13. **Slaba slika.** `image: nginx:9.99-alpine` za app1, nato `deploy.yml
    --tags app1`: task pade pri `pull`. Kaj streže `curl -s
    localhost:8080`? Vrnite `nginx:1.30-alpine` in poženite znova: to je
    **deklarativni rollback** na točno verzijo.

> **Alternativa v Swarmu** (samo za informacijo, v labu tega ne poganjamo)
>
> | Ansible + compose | Ansible + Swarm |
> | --- | --- |
> | `community.docker.docker_compose_v2` (`project_src`, `state`, `wait`) | `community.docker.docker_stack` (`name`, `compose`, `state`, `detach: false`) |
> | play na vseh `app_hosts`, vsak host svoj projekt | play na enem managerju (`managers[0]`), Swarm razporedi replike |
> | `docker logs -f app1-web-1` | `docker service logs -f app1_web` |
> | vsebina v bind mountu mape (`./html`) | Swarm `configs` z hashem vsebine v imenu (config je nespremenljiv) |
> | neobstoječa slika: pull pade, stari kontejner teče | neobstoječa slika: task Rejected, `failure_action: rollback` |
>
> Primer (`~/vaje/swarm-primer/deploy-stack.yml` in `files/apps/app1/stack.yml.j2`): en play na managerju, ista predloga z `deploy`:
>
> ```yaml
> - name: Aplikacije kot Swarm stacki
>   hosts: managers[0]
>   become: true
>   tasks:
>     - community.docker.docker_stack:
>         name: "{{ item.name }}"
>         state: present              # absent -> docker stack rm
>         compose: ["/opt/stacks/{{ item.name }}/stack.yml"]
>         detach: false
>       loop: "{{ apps }}"
> ```
>
> ```yaml
> # stack.yml.j2 (izsek): replike, razporeditev, vsebina kot config
>     deploy:
>       replicas: {{ app.replicas | default(2) }}
>       placement: { constraints: ["node.labels.tier == app"] }
>       update_config: { parallelism: 1, order: start-first, failure_action: rollback }
>     configs:
>       - { source: index_html, target: /usr/share/nginx/html/index.html }
> configs:
>   index_html:
>     file: ./html/index.html
>     name: {{ app_name }}_index_{{ app.greeting | hash('sha1') | truncate(8, true, '') }}
> ```
>
> Preverba: `docker service ls`, `docker service ps --no-trunc app1_web`, `docker service logs -f app1_web`.

## Pričakovan izpis

```
$ ansible-playbook deploy.yml --tags app1
TASK [Deploy aplikacije] ****
included: app for control => (item=app1)
TASK [app : Compose projekt app1] ****
changed: [control]
TASK [app : HTTP preverba za app1] ****
ok: [control]
PLAY RECAP: control : ok=...  changed=...  failed=0
drugič:     control : ok=...  changed=0

$ curl -s localhost:8080 | grep -E 'h1|Host'
<h1>Pozdrav iz app1</h1>
<p>Host: control, slika: nginx:1.30-alpine</p>

$ docker logs -f app1-web-1
... "GET / HTTP/1.1" 200 ... "-" "Wget" ...
... "GET / HTTP/1.1" 200 ... "-" "curl/8...." ...

korak 6 (--diff):
TASK [app : Dodatne datoteke za app1] ****
-<h1>Pozdrav iz app1</h1>
+<h1>Pozdrav iz app1, verzija 2</h1>
changed: [control] => (item=html/index.html.j2)
PLAY RECAP: control : ... changed=1

korak 7: app1-web-1 Up 6 minutes (healthy)
korak 12: app1-web-1 Exited (0), nato changed=1, spet (healthy)
korak 13: fatal ... nginx:9.99-alpine ... (pull), curl localhost:8080 vrne staro stran
```

## Vprašanja za razmislek

- Kdaj bi uporabili `--tags app1` in kdaj `-e only=app1`?
- Kaj pomeni `pull: missing` in kdaj bi rabili `pull: always`?
- Korak 12: kdo v produkciji opazi, da kontejner ne teče, če ga nihče ne zažene (monitoring, periodičen `deploy.yml --check`)?

Rešitev: [`../resitve/A04-rola-app-app1/`](../resitve/A04-rola-app-app1/README.md).
