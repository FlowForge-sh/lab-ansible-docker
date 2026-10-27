# Rešitev · Vaja A03

Projekt: [`../ansible-projekt/`](../ansible-projekt/): `roles/docker`,
`site.yml`, `inventories/aws/hosts.yml`, `inventories/aws/group_vars/all.yml`.

```bash
cd ~/projekt
docker ps                                       # command not found (pred A03)
ansible-playbook site.yml --list-tags           # TASK TAGS: [docker]
ansible-playbook -i inventories/aws/hosts.yml site.yml   # prvi zagon, ~2 min
ansible-playbook site.yml --tags docker         # changed=0
exit; ssh lab-control                           # skupina docker velja v novi seji
docker version --format '{{.Client.Version}} / {{.Server.Version}}'   # 29.8.2 / 29.8.2
docker info --format '{{.ServerVersion}} {{.LiveRestoreEnabled}} {{.LoggingDriver}}'
docker run --rm hello-world | head -2
docker ps -a                                    # prazno
ansible docker_hosts -m ansible.builtin.shell -a 'docker info | grep -E "Server Version|Live Restore"'
ansible-lint                                    # Passed: 0 failure(s), 0 warning(s) ... profile 'production'
```

Na AWS (en strežnik `control`, local): prvi zagon namesti Docker na isti
strežnik, nato se odjavite in prijavite znova (skupina `docker`), drugi zagon
`changed=0`. ufw pravilo za SSH je `allow` (`docker_firewall_ssh_rule` v
`inventories/aws/group_vars/all.yml`), da `limit` ne zapre učilnice za istim
NAT naslovom. Preverba kar na strežniku: `docker info`, `docker run --rm
hello-world`.

Preverjeno (oktober 2026): prvi zagon na svežem strežniku uspe,
drugi zagon `changed=0`, verzija `29.8.2` in
`LiveRestoreEnabled=true`. `--check --diff -e docker_log_max_size=20m`
pokaže spremembo `daemon.json` in na hostu ne spremeni ničesar. Na hostu
`docker info` vrne `29.8.2 true json-file`, `docker run --rm
hello-world` izpiše `Hello from Docker!`.

Korak 7 (`docker_log_max_size: 20m` zares): `daemon.json` se spremeni na
vseh hostih in handler "Restart docker" se sproži na vseh **hkrati**. Ker je
`live-restore` vklopljen, kontejnerji tečejo naprej; brez njega bi to bil
izpad na vseh hostih naenkrat. Spremembe `daemon.json` zato v produkciji
uvajamo z `upgrade.yml` (serial) ali `--limit`.

## Odgovori

- `validate` preveri novo vsebino na začasni datoteki, preden zamenja staro;
  napačen `daemon.json` po restartu pomeni, da se Docker ne zažene.
- Tag `docker` izbere taske (dele playbooka), `--limit` hoste. Tag je
  uporaben, ko ima `site.yml` več rol (npr. še `monitoring`), `--limit`, ko
  dodate nov host ali delate po enem.
- Skupina `docker`: dostop do Docker API = root na hostu; v produkciji samo
  servisni računi in administratorji, ostali prek `sudo` ali CI.
- Na ročno postavljenem strežniku (npr. `lab install-docker`): repozitorij, paketi in verzija se
  ujemajo (`ok`), `daemon.json` se prepiše po predlogi (live-restore), kar
  sproži en restart. Ročne spremembe, ki jih ni v predlogi, izginejo.
- Hkraten restart: vse aplikacije na vseh hostih za trenutek brez Dockerja
  (DNS, objavljeni porti, restart policy). dodatno gradivo `upgrade.yml`: `serial: 1` in preverba
  aplikacij po vsakem hostu.
- `command: apt-get install docker-ce` ali `shell: echo ... > daemon.json`
  bi bila vedno `changed` in bi vsakič sprožila restart.
