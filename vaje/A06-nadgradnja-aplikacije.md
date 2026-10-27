# Vaja A06 · Nadgradnja aplikacije: nova verzija app2 in rollback (neobvezna, ~20 min)

> **Neobvezna vaja** po obveznih vajah A03 do A05.

## Cilj

Aplikacijo **app2** dvigniti na novo verzijo nginx samo s spremembo
podatka v `group_vars` in `deploy.yml --tags app2`, preveriti, da je app1
pri miru (Docker Engine in app1 se ne dotaknemo), nato narediti
**rollback** na prejšnjo verzijo z isto potezo. Nadgradnja in rollback sta
ista operacija: sprememba vrednosti `image` in ponoven deploy.

## Predpogoji

- A05: app1 in app2 tečeta (`docker compose ls`: `app1`, `app2`), obe s
  sliko `nginx:1.30-alpine` (`curl -s localhost:8081 | grep slika`).
- Teorija: [`../teorija/05-ansible-projekt.md`](../teorija/05-ansible-projekt.md) §5.
- Priporočeno: v drugi seji `docker logs -f app2-web-1`.

## Koraki

### A. Stanje pred nadgradnjo (2 min)

1. ```bash
   cd ~/projekt
   docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'   # obe nginx:1.30-alpine
   curl -s localhost:8081 | grep slika                                 # slika: nginx:1.30-alpine
   grep -n 'image:' inventories/aws/group_vars/all.yml
   ```

### B. Nova verzija app2 (8 min)

2. V `inventories/aws/group_vars/all.yml` spremenite sliko **samo pri app2**:
   ```yaml
     - name: app2
       ...
       vars:
         image: nginx:1.31-alpine      # prej 1.30-alpine
   ```
   app1 ostane `nginx:1.30-alpine`.
3. Najprej poglejte, kaj bi se spremenilo, nato uveljavite samo app2:
   ```bash
   ansible-playbook deploy.yml --tags app2 --check --diff   # compose.yml: -image: nginx:1.30-alpine / +image: nginx:1.31-alpine
   ansible-playbook deploy.yml --tags app2 --diff           # Compose datoteka za app2: changed, Compose projekt app2: changed
   ```
   Task `Compose projekt app2` potegne novo sliko (`pull: missing`: je še
   ni) in **zamenja kontejner**: ustavi starega in zažene novega z novo
   sliko. V drugi seji `docker logs -f` se konča (star kontejner je šel).
4. Preverite:
   ```bash
   docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'   # app2-web-1 nginx:1.31-alpine Up ... seconds; app1-web-1 Up ... minutes
   curl -s localhost:8081 | grep slika                                 # slika: nginx:1.31-alpine
   curl -s localhost:8080 | grep slika                                 # app1 še 1.30-alpine
   docker images nginx                                                 # obe oznaki, stara ostane na hostu
   ansible-playbook deploy.yml --tags app2                             # changed=0
   ```
   app1 ni bil ponovno zagnan (`Up` čas se ni ponastavil), Docker Engine se
   ni dotaknil. Nadgradnja je bila samo sprememba enega podatka.

### C. Rollback (5 min)

5. Vrnite `image: nginx:1.30-alpine` pri app2 in poženite isto:
   ```bash
   ansible-playbook deploy.yml --tags app2 --diff           # Compose projekt app2: changed
   curl -s localhost:8081 | grep slika                       # spet 1.30-alpine
   docker ps --format '{{.Names}} {{.Image}} {{.Status}}'    # app2 nov kontejner s staro sliko; app1 nespremenjen
   ```
   Rollback je bil hiter, ker je stara slika že na hostu (`docker images`).
   Vrnitev na točno verzijo je zapisana v `group_vars`, torej v gitu.

### Preverba na strežniku (5 min)

6. Na strežniku:
   ```bash
   docker inspect app2-web-1 --format '{{.Config.Image}} {{.State.StartedAt}}'   # slika in čas zagona novega kontejnerja
   docker inspect app1-web-1 --format '{{.Config.Image}} {{.State.StartedAt}}'   # app1: stara slika, star čas
   docker compose ls                                                            # oba running(1)
   docker logs --tail 5 app2-web-1                                              # healthcheck novega kontejnerja
   cat /opt/apps/app2/compose.yml | grep image                                  # kar je zapisal Ansible
   ```
7. Za vse hoste brez prijave:
   `ansible app_hosts -m ansible.builtin.command -a "docker ps --format '{{ '{{' }}.Names{{ '}}' }} {{ '{{' }}.Image{{ '}}' }}'"`.

### D. Neobvezno: napačna oznaka (3 min)

8. `image: nginx:9.99-alpine` pri app2, `deploy.yml --tags app2`: task pade
   pri `pull`, **stari kontejner teče naprej** (`curl -s localhost:8081` še
   odgovarja). Vrnite `1.30-alpine` in poženite znova. Napaka v podatku ne
   podre aplikacije, ker `pull: missing` sliko potegne pred zamenjavo.

> **Alternativa v Swarmu** (samo za informacijo, v labu tega ne poganjamo)
>
> | Ansible + compose | Ansible + Swarm |
> | --- | --- |
> | `docker_compose_v2` zamenja kontejner (kratek izpad na tem hostu) | `docker_stack` posodobi servis po replikah (`update_config: parallelism: 1, order: start-first`), brez izpada |
> | rollback = stara vrednost `image` + deploy | isto, ali `docker service rollback app2_web` (Swarm hrani prejšnjo specifikacijo) |
> | napačna oznaka: pull pade, stari kontejner teče | napačna oznaka: naloge Rejected, `failure_action: rollback` vrne prejšnjo verzijo sam |
>
> Primer: `~/vaje/swarm-primer/files/apps/app1/stack.yml.j2` (`update_config`) in `deploy-stack.yml`.

## Pričakovan izpis

```
korak 3 (--check --diff):
TASK [app : Compose datoteka za app2] ****
-    image: nginx:1.30-alpine
+    image: nginx:1.31-alpine
changed: [control]
korak 3 (zares):
TASK [app : Compose projekt app2] ****  changed: [control]
PLAY RECAP: control : ok=... changed=2 failed=0      (compose.yml, compose projekt)

korak 4:
app2-web-1   nginx:1.31-alpine   Up 20 seconds (healthy)
app1-web-1   nginx:1.30-alpine   Up 35 minutes (healthy)
<p>Host: control, slika: nginx:1.31-alpine</p>

korak 5: slika: nginx:1.30-alpine, app2-web-1 Up 5 seconds, app1-web-1 Up 40 minutes
korak 8: fatal ... nginx:9.99-alpine ... (pull); curl localhost:8081 še odgovarja
```

## Vprašanja za razmislek

- Zakaj compose kontejner zamenja (ustavi in zažene novega) in ne samo
  osveži? Kaj to pomeni za aplikacijo brez replik (kratek izpad)?
- Kako bi nadgradili app1 brez izpada, če bi tekla na dveh hostih
  (`--limit`, `serial`, load balancer)?
- Kaj bi se zgodilo z `image: nginx:latest` in `pull: always`? Zakaj je
  točna oznaka boljša za rollback?
- Kje v produkciji hranite prejšnjo verzijo (git zgodovina `group_vars`,
  slike na hostu, registry)?

Rešitev: [`../resitve/A06-nadgradnja-aplikacije/`](../resitve/A06-nadgradnja-aplikacije/README.md).
Dodatno (ni vaja): rolling upgrade Docker Engine z `upgrade.yml`,
[`dodatno-rolling-upgrade-engine.md`](dodatno-rolling-upgrade-engine.md).
