# Rešitev · Vaja A06

Sprememba je samo vrednost `image` pri app2 v `inventories/aws/group_vars/all.yml`;
rola `app`, `deploy.yml` in app1 ostanejo
nespremenjeni. Končno stanje po rollbacku je enako kot po A05, zato
[`../ansible-projekt/`](../ansible-projekt/) nima app2 na 1.31.

```bash
cd ~/projekt
sed -i '0,/image: nginx:1.30-alpine/! {0,/image: nginx:1.30-alpine/ s/image: nginx:1.30-alpine/image: nginx:1.31-alpine/}' inventories/aws/group_vars/all.yml   # drugi image (app2); ali nano
ansible-playbook deploy.yml --tags app2 --check --diff   # diff compose.yml
ansible-playbook deploy.yml --tags app2 --diff           # changed=2 (compose.yml, compose projekt)
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'   # app2 1.31 Up seconds, app1 1.30 Up minutes
curl -s localhost:8081 | grep slika                      # nginx:1.31-alpine
ansible-playbook deploy.yml --tags app2                  # changed=0
# rollback
sed -i 's/image: nginx:1.31-alpine/image: nginx:1.30-alpine/' inventories/aws/group_vars/all.yml
ansible-playbook deploy.yml --tags app2 --diff           # changed=2, nov kontejner s staro sliko (brez pull)
curl -s localhost:8081 | grep slika                      # nginx:1.30-alpine
```

Preverjeno (oktober 2026): po nadgradnji ima `app2-web-1`
sliko `nginx:1.31-alpine` in nov `StartedAt`, `app1-web-1` ima isti
`StartedAt` kot prej in sliko 1.30; `curl localhost:8081` vrne 1.31,
`localhost:8080` 1.30; drugi zagon `changed=0`; rollback vrne 1.30. Napačna oznaka
(`nginx:9.99-alpine`) pade pri `pull`, stara verzija streže naprej (isto
kot v A04, korak 13).

## Odgovori

- Kontejner je nespremenljiv: nova slika pomeni nov kontejner. Compose
  starega ustavi in zažene novega, vmes aplikacija na tem hostu nekaj sekund
  ne odgovarja. Brez replik je kratek izpad neizogiben; z več hosti ga
  skrijeta `--limit` ali `serial` in load balancer, ki host med zamenjavo
  vzame iz bazena (v Swarmu `update_config` s `start-first`).
- `nginx:latest` s `pull: always` bi ob vsakem deployu lahko prinesel drugo
  vsebino pod isto oznako; rollback na "prejšnjo latest" ni mogoč. Točna
  oznaka (ali digest) pomeni, da je stara verzija en `sed` stran.
- Prejšnja verzija je zapisana v git zgodovini `group_vars`; slika je še na
  hostu (`docker images`), dokler je ne počistite, in v registryju.
