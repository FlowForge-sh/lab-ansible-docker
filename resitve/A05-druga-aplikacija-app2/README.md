# Rešitev · Vaja A05

app2 je kopija app1: mapa [`files/apps/app2/`](../ansible-projekt/files/apps/app2/)
je enaka [`files/apps/app1/`](../ansible-projekt/files/apps/app1/) (predlogi
sta generični: ime iz `app_name`, pozdrav in port iz `app.*`). Nov je samo
en element v `apps` (`inventories/aws/group_vars/all.yml`). Rola `app` in `deploy.yml` sta nespremenjeni.

```bash
cd ~/projekt
cp -r files/apps/app1 files/apps/app2
```

```yaml
  - name: app2
    files: [html/index.html.j2]
    vars:
      image: nginx:1.30-alpine
      port: 8081
      greeting: "Pozdrav iz app2"
```

```bash
ansible-playbook deploy.yml --tags app2 --diff   # samo app2, changed
curl -s localhost:8081                      # <h1>Pozdrav iz app2</h1>, Host: control
docker ps                                   # app1-web-1, app2-web-1 (healthy)
docker compose ls                           # app1, app2
docker logs -f app2-web-1                   # Ctrl+C
ansible-playbook deploy.yml                 # obe aplikaciji, changed=0
ansible-playbook deploy.yml -e only=app2    # app1 "skipping"
# state: absent -> deploy.yml --tags app2 -> docker compose down, mapa /opt/apps/app2 ostane
```

Preverjeno (oktober 2026) in na pripravljenem strežniku (Ubuntu 24.04, isti
postopek kot `lab-bootstrap-control`): app2 odgovori s "Pozdrav iz app2"
(vrstica `Host:` z imenom hosta), `app2-web-1` je healthy, drugi zagon `changed=0`,
`--tags app2` ne požene nobenega taska za app1, `-e only=app2` preskoči app1, `state: absent` odstrani kontejner, ponoven
deploy ga vrne.

Korak 7: 0 vrstic kode; 6 vrstic podatkov in kopija mape s predlogama.

## Odgovori

- Kopija zadošča, ker se app1 in app2 razlikujeta samo v vrednostih
  (pozdrav, port), ki so v `group_vars`. Druga slika z drugimi servisi
  (npr. baza) pomeni svojo `compose.yml.j2` v `files/apps/app2/`; rola še
  vedno ostane ista.
- Svojo rolo, ko potrebuje več kot predlogo: pripravo na hostih (mape,
  uporabniki, sysctl), skrivnosti, migracije baze, posebne preverbe po deployu.
- Drugi inventory (`inventories/test/`) s svojim `group_vars/all.yml` in
  drugim `greeting`; predloge in rola ostanejo iste.
- Produkcija: skrivnosti iz Ansible Vault (v `.env` ali `secrets: file:` z
  `mode: "0600"`), skupna mreža (`networks: external: true`), `docker login`
  (`community.docker.docker_login`), load balancer pred hosti.
