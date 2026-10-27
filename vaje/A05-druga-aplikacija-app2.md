# Vaja A05 · Druga aplikacija (app2): kopija app1 z drugim pozdravom in portom (obvezna, ~25 min)

## Cilj

Docker (A03) in prva aplikacija **app1** (A04, port 8080) tečeta. Zdaj
postavite **drugo aplikacijo app2**: kopirate app1 in spremenite samo
**pozdravno besedilo** in **port (8081)**.

Pri tem opazite bistvo projekta z rolami: rola `app` in `deploy.yml` se
**ne spremenita**. Nova aplikacija je nova mapa s predlogami in nov element
v seznamu `apps` (podatki, ne koda).

## Predpogoji

- Prijava na strežnik (`ssh lab-control`), ste v `~/projekt`
  ([`../00-priprava-aws.md`](../00-priprava-aws.md)).
- A04: `docker ps` pokaže `app1-web-1` (healthy), `curl -s localhost:8080`
  vrne vaš pozdrav app1. Če ne: `ansible-playbook deploy.yml --tags app1`
  (in pred tem A03, če Dockerja ni).
- Teorija: [`../teorija/05-ansible-projekt.md`](../teorija/05-ansible-projekt.md) §4.

## Koraki

### A. Poglejte app1 (3 min)

1. ```bash
   cd ~/projekt
   tree files/apps                          # app1/compose.yml.j2, app1/html/index.html.j2
   cat files/apps/app1/html/index.html.j2   # <h1>{{ app.greeting }}</h1>
   grep -A8 '^apps:' inventories/aws/group_vars/all.yml
   ```
   Pozdrav (`greeting`) in port (`port`) nista v predlogi, ampak v
   `group_vars`. Predloga dobi vrednosti kot `app.greeting`, `app.port`,
   ime aplikacije pa kot `app_name`.

### B. app2 (10 min)

2. Kopirajte mapo app1:
   ```bash
   cp -r files/apps/app1 files/apps/app2
   ```
   Predlog vam ni treba spreminjati (ime `app2` pride iz `app_name`). Če
   želite, v `files/apps/app2/html/index.html.j2` dodajte še kakšno vrstico.
3. V `inventories/aws/group_vars/all.yml` pod app1 dodajte element app2
   (namesto komentarja `# Vaja A05: ...`). Zamik je enak kot pri app1:
   ```yaml
     - name: app2
       files: [html/index.html.j2]
       vars:
         image: nginx:1.30-alpine
         port: 8081
         greeting: "Pozdrav iz app2"      # vaše besedilo
   ```
4. Preverite in poženite **samo app2** (tag = ime aplikacije, app1 se ne
   dotakne):
   ```bash
   ansible-playbook deploy.yml --syntax-check
   ansible-playbook deploy.yml --tags app2 --diff    # samo taski za app2, changed
   ```
   Če javi napako v YAML ali `'app' is undefined`, preverite zamik v
   `group_vars` (`- name: app2` mora biti točno pod `- name: app1`).
5. Preverite:
   ```bash
   docker ps                                 # app1-web-1 in app2-web-1, oba healthy
   docker compose ls                         # app1 in app2
   curl -s localhost:8081                    # <h1>Pozdrav iz app2</h1>
   curl -s localhost:8080 | grep h1          # app1 nespremenjena
   docker logs -f app2-web-1                 # Ctrl+C za konec; v drugi seji curl localhost:8081
   ```
   V brskalniku: http://<javni IP strežnika>:8080 in :8081.
6. Celoten `ansible-playbook deploy.yml` (obe aplikaciji): `changed=0`
   (idempotenca; app1 `ok`, app2 `ok`).
7. Koliko vrstic **kode** (rola `app`, `deploy.yml`) ste spremenili?
   ```bash
   diff -r ~/resitve/ansible-projekt/roles roles && echo "rola enaka"
   diff deploy.yml ~/resitve/ansible-projekt/deploy.yml && echo "deploy.yml enak"
   ```

### C. Neobvezno: sprememba in nadzor (10 min)

8. Spremenite pozdrav app2 v `group_vars` in ga uveljavite na dva načina:
   `ansible-playbook deploy.yml --tags app2 --diff`, nato (z drugim
   pozdravom) `ansible-playbook deploy.yml -e only=app2 --diff`. Kaj pokaže
   izpis za app1 pri `-e only=app2` (`skipping`) in kaj pri `--tags app2`?
   Je app2 ob tem ponovno zagnala kontejner (`docker ps`, stolpec `CREATED`)?
9. Samo en host: `ansible-playbook deploy.yml --limit control --tags app2`.
10. Odstranitev s podatkom: elementu app2 dodajte `state: absent` (v isti
    višini kot `name`), poženite `deploy.yml --tags app2`, preverite
    `docker ps` in `docker compose ls`. Nato `state` odstranite in app2
    vrnite (`--tags app2`).

### Preverba na strežniku

11. Na strežniku:
    ```bash
    docker compose ls                       # app1 in app2, oba running(1)
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
    curl -s localhost:8081                  # vaš pozdrav, "Host: control"
    docker inspect app2-web-1 --format '{{.State.Health.Status}} {{.HostConfig.Memory}}'
    ls /opt/apps/ /opt/apps/app2            # app1 app2; compose.yml html
    ```
12. Isto za vse hoste z aplikacijami brez prijave:
    `ansible app_hosts -m ansible.builtin.command -a 'docker compose ls'`.

Rešitev: [`../resitve/A05-druga-aplikacija-app2/`](../resitve/A05-druga-aplikacija-app2/README.md),
celoten projekt `~/resitve/ansible-projekt/`.

> **Alternativa v Swarmu** (samo za informacijo, v labu tega ne poganjamo)
>
> | Ansible + compose | Ansible + Swarm |
> | --- | --- |
> | app2 na vsakem hostu iz `app_hosts`, en kontejner na host | `deploy.replicas: 3`, Swarm razporedi po nodih (`placement.preferences: spread`) |
> | `state: absent` → `docker compose down` | `state: absent` → `docker stack rm` |
> | dva porta 8081 na dveh hostih (pred njima load balancer) | en port 8081 na vseh nodih (routing mesh) |
>
> Primer: app2 je v `~/vaje/swarm-primer/deploy-stack.yml` samo nov element seznama,
> `replicas: 3` pa pove Swarmu, koliko kopij razporedi po nodih:
>
> ```yaml
>     apps:
>       - name: app1
>         vars: { image: nginx:1.30-alpine, port: 8080, greeting: "Pozdrav iz app1", replicas: 2 }
>       - name: app2
>         vars: { image: nginx:1.30-alpine, port: 8081, greeting: "Pozdrav iz app2", replicas: 3 }
> ```
>
> `curl http://<katerikoli node>:8081` odgovori prek routing mesha, tudi z noda, kjer replika ne teče.

## Pričakovan izpis

```
$ ansible-playbook deploy.yml --tags app2 --diff
TASK [Deploy aplikacije] ****
included: app for control => (item=app1)
included: app for control => (item=app2)
TASK [app : Compose projekt app2] **** changed: [control]
PLAY RECAP: control ok=... changed=... failed=0
(taskov za app1 ni: niso označeni s tagom app2)

$ curl -s localhost:8081
<head><meta charset="utf-8"><title>app2</title></head>
<h1>Pozdrav iz app2</h1>
<p>Host: control, slika: nginx:1.30-alpine</p>

$ docker ps --format '{{.Names}} {{.Status}} {{.Ports}}'
app2-web-1 Up 5 seconds (healthy) 0.0.0.0:8081->80/tcp, [::]:8081->80/tcp
app1-web-1 Up 2 hours (healthy) 0.0.0.0:8080->80/tcp, [::]:8080->80/tcp

korak 8: -e only=app2: skipping: [control] => (item=app1)
korak 11: healthy 67108864
```

## Vprašanja za razmislek

- Zakaj je bilo dovolj kopirati mapo in dodati podatke? Kaj bi morali
  spremeniti, če bi app2 potrebovala drugo sliko (npr. z bazo)?
- Kdaj bi app2 dobila svojo rolo namesto samo predloge?
- Kako bi imeli app2 v testu z drugim pozdravom kot v produkciji?
- Kaj manjka za produkcijo: skrivnosti (Ansible Vault), skupna mreža z app1, registry z avtentikacijo, load balancer pred hosti?
