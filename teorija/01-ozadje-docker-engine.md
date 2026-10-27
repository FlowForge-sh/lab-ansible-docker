# Ozadje: Docker Engine na strežniku (neobvezno branje)

Trajanje: ~20 min (ali samo kot priročnik) · Vaje: podlaga za A03, A04, dodatno rolling upgrade Engine

Tečaj nima ločenih Docker vaj. Docker Engine na strežnike postavi Ansible
(rola `docker`, vaja A03), aplikacije pa rola `app` (A04, A05). Ta stran
razloži, **kaj** Ansible pri tem naredi, da boste razumeli taske v roli in
znali na strežniku preveriti, da je vse res postavljeno.

## 1. Priprava strežnika (OS)

| Zahteva | Zakaj | Preverjanje |
| --- | --- | --- |
| Podprt OS (Ubuntu 22.04/24.04, Debian 12/13 ...) | uradni paketi | `cat /etc/os-release` |
| Unikatno ime hosta, fiksen IP | inventory, logi, monitoring | `hostnamectl`, `ip -br addr` |
| Sinhronizirana ura | TLS, logi, metrike | `timedatectl` |
| Dovolj prostora za `/var/lib/docker` | slike, volumni, logi | `df -h /var/lib/docker` |
| Ni starih paketov `docker.io`, `podman-docker` | konflikt z uradnimi | `dpkg -l \| grep -E 'docker\|containerd'` |

V roli `docker` to pokrijeta `assert` (OS) in `tasks/prep.yml` (ura, požarni
zid), ki ju v labu izklopimo (`docker_timesync: false`, `docker_firewall: false`).

## 2. Namestitev iz uradnega repozitorija in točna verzija

Ubuntu ima paket `docker.io`, a je star in ga vzdržuje distribucija. Za
strežnike uporabimo uradni repozitorij `download.docker.com` (paketi
`docker-ce`). Ročno bi bilo to:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
# vir /etc/apt/sources.list.d/docker.sources (deb822), nato:
apt-cache madison docker-ce | head -3
sudo apt-get install -y docker-ce=5:29.8.2-1~ubuntu.24.04~noble docker-ce-cli=5:29.8.2-1~ubuntu.24.04~noble \
     containerd.io docker-buildx-plugin docker-compose-plugin
```

| Ročni korak | Task v roli `docker` |
| --- | --- |
| ključ v `/etc/apt/keyrings/docker.asc` | `ansible.builtin.get_url` |
| `docker.sources` | `ansible.builtin.deb822_repository` |
| `apt-cache madison` → točen niz verzije | `command` z `register` in `check_mode: false` |
| `apt-get install docker-ce=<verzija>` | `ansible.builtin.apt` + `notify: Restart docker` |
| uporabnik v skupini `docker` | `ansible.builtin.user` |

**Zakaj točna verzija**: vsi hosti naj imajo isto verzijo. Nov host, ki
dobi "najnovejšo", je drugačen od ostalih. Verzija je v `group_vars`
(`docker_version`), nadgradnja je sprememba tega podatka (dodatno gradivo `upgrade.yml`).

Skripta `get.docker.com` je priročna za test, za produkcijo jo uradna
dokumentacija odsvetuje (namesti najnovejše, brez potrditve). Uporabnik v
skupini `docker` ima dejansko root dostop do hosta.

## 3. `daemon.json`

Nastavitve Docker Engine so v `/etc/docker/daemon.json`. Rola jo zgradi iz
slovarja (`vars/main.yml`) in jo pred zamenjavo preveri z
`dockerd --validate --config-file %s`.

| Ključ | Pomen |
| --- | --- |
| `log-driver`, `log-opts` (`max-size`, `max-file`) | rotacija logov kontejnerjev; brez tega `json-file` raste in napolni disk |
| `metrics-addr` | Prometheus metrike Engine na portu 9323 (samo notranja mreža) |
| `default-address-pools` | iz katerih omrežij Docker jemlje bridge mreže (da ne trči z LAN ali VPN) |
| `registry-mirrors` | pull-through cache; v labu `http://10.10.0.4:5000` |
| `live-restore` | kontejnerji tečejo naprej med restartom ali nadgradnjo dockerd |

Ali je sprememba res uveljavljena, preverite z `docker info` (ne s
`cat daemon.json`).

## 4. Aplikacija kot compose projekt

Rola `app` za vsako aplikacijo zapiše `/opt/apps/<ime>/compose.yml` in
požene `docker compose up` (modul `community.docker.docker_compose_v2`).
V compose datoteki so pomembni:

```yaml
services:
  web:
    image: nginx:1.30-alpine          # točna oznaka, nikoli latest
    restart: unless-stopped           # po padcu ali restartu dockerd se zažene
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://127.0.0.1/"]
      interval: 10s
      retries: 3
    deploy:
      resources:
        limits: { cpus: "0.50", memory: 64M }   # prekoračitev RAM: OOM, exit 137
```

- **Healthcheck**: samostojni Docker unhealthy kontejnerja **ne** zamenja,
  samo označi ga. Zato rola po deployu še preveri HTTP (`uri`).
- **Posodobitev in rollback**: nova oznaka slike v `group_vars` in znova
  `deploy.yml`. Neobstoječa oznaka pade pri `pull`, stari kontejner streže naprej.

## 5. Nadgradnja Engine in live-restore

Nadgradnja paketa `docker-ce` restarta dockerd. Brez `live-restore` se
ob tem ustavijo vsi kontejnerji na hostu. Z `live-restore: true` tečejo
naprej (kratek izpad lahko ima le objava portov, ker jo dela dockerd).
`upgrade.yml` (dodatno gradivo) nadgradi host za hostom (`serial: 1`) in po vsakem
preveri aplikacije.

## 6. Preverba na strežniku: "ali je res postavljeno?"

Po `site.yml` in `deploy.yml` na hostu (na AWS ste že na njem)
poglejte z Docker ukazi. To je preverba, ne postavitev: ničesar ne
spreminjamo ročno, ker bi naslednji zagon Ansibla to povozil.

| Ukaz | Kaj vidite |
| --- | --- |
| `docker version --format '{{.Server.Version}}'` | verzija Engine iz `group_vars` |
| `docker info --format '{{.LiveRestoreEnabled}} {{.LoggingDriver}}'` | `true json-file` iz `daemon.json` |
| `docker compose ls` | compose projekti, ki jih je postavila rola `app` (`app1`, `app2`) |
| `docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'` | kontejnerji, slike, `(healthy)`, porti |
| `docker logs --tail 20 app1-web-1` | dostopni log nginx (vsak `curl` doda vrstico) |
| `docker logs -f app1-web-1` | log v živo (Ctrl+C za konec): healthcheck vsakih 10 s, vaš `curl` takoj |
| `docker inspect -f '{{.State.Health.Status}}' app1-web-1` | `healthy` |
| `docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' app1-web-1` | limiti iz compose (`67108864 500000000`) |
| `docker stats --no-stream` | trenutna poraba CPU in RAM |
| `curl -s localhost:8080` | aplikacija odgovarja na hostu |
| `cat /opt/apps/app1/compose.yml` | datoteka, ki jo je zapisal Ansible |

Isto lahko vidite brez prijave, z ad-hoc ukazom s control noda:
`ansible app_hosts -m ansible.builtin.command -a 'docker ps'`.

> **Alternativa v Swarmu** (samo za informacijo)
>
> V Swarmu bi namesto `docker ps` in `docker logs` na vsakem hostu
> uporabili `docker service ls`, `docker service ps <servis>` in
> `docker service logs <servis>` na managerju; namesto `live-restore`
> (v Swarm načinu ni dovoljen) pred nadgradnjo node izpraznite (drain).

## Viri

- Docker: Install Docker Engine on Ubuntu, https://docs.docker.com/engine/install/ubuntu/
- Docker: Daemon configuration file, https://docs.docker.com/reference/cli/dockerd/#daemon-configuration-file
- Docker: Live restore, https://docs.docker.com/engine/daemon/live-restore/
- Docker: Compose file reference (healthcheck, deploy.resources), https://docs.docker.com/reference/compose-file/services/
- Docker: docker container logs, https://docs.docker.com/reference/cli/docker/container/logs/
- Docker: Packet filtering and firewalls, https://docs.docker.com/engine/network/packet-filtering-firewalls/
