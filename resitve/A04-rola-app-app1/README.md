# Rešitev · Vaja A04

Datoteke: [`roles/app/`](../ansible-projekt/roles/app/),
[`files/apps/app1/compose.yml.j2`](../ansible-projekt/files/apps/app1/compose.yml.j2),
[`files/apps/app1/html/index.html.j2`](../ansible-projekt/files/apps/app1/html/index.html.j2),
[`deploy.yml`](../ansible-projekt/deploy.yml) in seznam `apps` v
`inventories/aws/group_vars/all.yml`.

```bash
ansible-playbook deploy.yml --tags app1     # app1 postavljena
docker ps; docker compose ls
curl -s localhost:8080                      # AWS: <h1>Pozdrav iz app1</h1>, Host: control
docker logs -f app1-web-1                   # druga seja: Wget vsakih 10 s, GET ob curl
ansible-playbook deploy.yml --tags app1     # changed=0
# group_vars: greeting: "Pozdrav iz app1, verzija 2"
ansible-playbook deploy.yml --tags app1 --diff   # changed=1: Dodatne datoteke za app1
curl -s localhost:8080 | grep h1            # <h1>Pozdrav iz app1, verzija 2</h1>
ansible-playbook deploy.yml --tags config   # samo predloge, brez Compose projekt in HTTP preverbe
```

Tagi pridejo iz `deploy.yml`: `include_role` z `apply: tags: [app, deploy,
"{{ app_item.name }}"]` (tagi za taske role) in `tags: [always]` na samem
includu (da se zanka izvede pri vsakem `--tags`). Tag na includu brez
`apply` ne bi prešel na taske role (dinamičen vnos). Taski `Mape`, `Dodatne
datoteke` in `Compose datoteka` imajo še `tags: [config]`.

Na AWS teče app1 na edinem hostu `control`, z laptopa na
`http://<javni IP>:8080`; drift popravi `ansible-playbook deploy.yml --tags app1`.

Preverjeno (oktober 2026):

- app1 teče na vseh hostih iz `app_hosts`, `healthy`, drugi zagon `changed=0`.
- Korak 6 in 7 (pozdrav, `--tags app1`): spremeni se samo `html/index.html`; kontejner
  `app1-web-1` ni bil ponovno zagnan (isti `StartedAt`), stran je nova takoj,
  ker je bind mount na **mapo**.
- Korak 13 (`nginx:9.99-alpine`): task `Compose projekt app1` pade pri pull
  (`pull: missing`), stari kontejner streže naprej. Vrnjena verzija in
  ponoven deploy uspeta.
- Preverba na hostu (korak 10): `docker compose ls` pokaže `app1
  running(1)`, `docker ps` `app1-web-1 ... (healthy)`, `docker logs` vsebuje
  GET zahtevek po `curl localhost:8080`, `inspect` vrne `healthy 67108864
  500000000` (64M, 0.50 CPU).
- Korak 12: po `docker stop` je kontejner `Exited (0)`; `deploy.yml
  --tags app1` ga zažene (`changed`), nato
  je spet `healthy`.
- `--tags app1` ob več aplikacijah (rešitev z app2) teče samo za app1, za
  app2 ni nobenega taska; `--tags config` zapiše samo datoteke.

## Odgovori

- `--tags app1` je izbira ob zagonu (ukazna vrstica, CI),
  `-e only=app1` je spremenljivka, ki jo lahko nastavi tudi inventory ali
  CI; tag preskoči taske, `only` preskoči celoten include (`skipping`).

- `pull: missing` potegne sliko samo, če je še ni na hostu (nova oznaka).
  `pull: always` rabite pri premičnih oznakah (`:1.30-alpine` dobi popravke);
  bolje je pinati oznako ali digest.
- `remove_orphans: true` odstrani kontejnerje projekta, ki jih ni več v
  `compose.yml`. Nevaren, če dva različna compose datoteki uporabljata isto
  ime projekta.
- Po koraku 13 je na hostu `compose.yml` z napačno sliko: ročni `docker
  compose up -d` na hostu bi poskusil isto napako, restart kontejnerja pa ne
  (teče stari kontejner). Ponoven deploy s pravo verzijo stanje poravna.
- Ustavljen kontejner: Docker ga po `docker stop` ne zažene (`unless-stopped`).
  Opazi ga monitoring (Prometheus, uptime preverba) ali periodičen
  `deploy.yml --check` (pokaže `changed`).
