# Pripravljen Ansible projekt (izhodišče za vaje)

To je projekt, ki ga dobite v `~/projekt`. Ni prazen: vsebuje vse, kar
postavi Docker in prvo aplikacijo, pognali pa ga boste sami: A03 Docker,
A04 app1 (nov pozdrav, `--tags app1`), A05 **druga aplikacija app2**
(kopija app1, drug pozdrav in port).

```
~/projekt
├── ansible.cfg                  inventory, roles, collections (AWS: inventories/aws)
├── inventories/aws/
│   ├── hosts.yml                en host "control", ansible_connection: local
│   └── group_vars/all.yml       docker_version, ...  in seznam apps (zdaj samo app1)
├── roles/
│   ├── docker/                  namesti Docker Engine (repozitorij, verzija, daemon.json)
│   └── app/                     postavi eno aplikacijo kot docker compose projekt
├── files/apps/app1/
│   ├── compose.yml.j2           nginx, port {{ app.port }}, healthcheck, limiti
│   └── html/index.html.j2       <h1>{{ app.greeting }}</h1>
├── site.yml                     rola docker na docker_hosts
├── deploy.yml                   rola app za vsak element seznama apps
├── setup-ansible.sh             kako je bil Ansible postavljen (venv, kolekcije)
└── requirements.txt, requirements.yml
```

## AWS lab (privzeto)

Ob pripravi strežnika (`lab-bootstrap-control`) sta nameščena Ansible in ta
projekt, Dockerja in aplikacij še ni (`docker ps`: command not found).
Postavite jih sami, po vajah v `/kurs/vaje/`:

```bash
# A03: samo Docker
ansible-playbook -i inventories/aws/hosts.yml site.yml
ansible-playbook site.yml --tags docker        # drugič: changed=0
exit; ssh lab-control                          # skupina docker
docker ps

# A04: app1, nato nov pozdrav v group_vars in samo app1
ansible-playbook deploy.yml --tags app1
curl -s localhost:8080                         # <h1>Pozdrav iz app1</h1>
docker logs -f app1-web-1                      # druga seja, Ctrl+C
nano inventories/aws/group_vars/all.yml        # greeting app1
ansible-playbook deploy.yml --tags app1 --diff

# A05: app2 kot kopija app1
cp -r files/apps/app1 files/apps/app2
nano inventories/aws/group_vars/all.yml        # nov element app2: drug greeting, port 8081
ansible-playbook deploy.yml --tags app2 --diff
curl -s localhost:8081                         # <h1>... vaš pozdrav ...</h1>
docker ps; docker compose ls
```

Končno stanje (rešitev): `~/resitve/ansible-projekt/`.

