# Razno 2: ali obstaja GUI za Ansible (in za Swarm)?

Trajanje: ~10 min · Samo teorija (brez vaje)

Kratek odgovor: **da**, več. Ansible sam je ukazna vrstica; GUI je ločen
strežnik, ki hrani projekte (git), inventoryje, poverilnice in zgodovino
zagonov, ter dovoli, da playbook požene tudi nekdo brez dostopa do terminala.
Za Swarm obstajajo GUI za pregled in ročne posege.

## 1. Zakaj GUI za Ansible

- **Kdo je kaj pognal in kdaj**: zgodovina zagonov z izpisom (revizijska sled).
- **Poverilnice na enem mestu**: SSH ključi in Vault gesla niso na
  laptopih, uporabnik jih uporabi, ne vidi.
- **Pravice**: razvijalec sme pognati "deploy app1 na test", ne "site.yml na prod".
- **Urnik**: nočni `--check` (drift), tedenski backup.
- **Gumb za ne-Ansible ljudi**: dežurni požene "restart app" brez SSH.

Ni nadomestek za git in code review: playbooki še vedno živijo v gitu, GUI
jih samo poganja.

## 2. Možnosti

| Orodje | Licenca | Namestitev | Za koga | Opombe |
| --- | --- | --- | --- | --- |
| **Semaphore UI** | MIT (odprta koda), plačljiv Pro | en kontejner, baza SQLite/MySQL/Postgres | manjše ekipe | Ansible, Terraform/OpenTofu, PowerShell, Bash; projekti iz gita, ključi, urniki, LDAP/OIDC. Aktiven razvoj (v2.19, oktober 2026). |
| **AWX** | Apache 2.0 | Kubernetes (AWX Operator) | srednje in velike | upstream od AAP. **Izdaje so zamrznjene od julija 2024** (zadnja 24.6.1) zaradi prenove arhitekture; za nov sistem danes ni prva izbira. |
| **Red Hat Ansible Automation Platform (AAP)** | komercialna naročnina | RPM, kontejnerji ali OpenShift | podjetja z Red Hat podporo | controller (AWX), Event-Driven Ansible, private automation hub, podpora |
| **Rundeck** (PagerDuty) | Apache 2.0 Community, plačljiv Runbook Automation | Java, kontejner | operativa, runbooki | splošni "job scheduler", Ansible plugin |
| **ansible-navigator** | odprta koda | pip | posameznik | TUI v terminalu, ne spletni GUI; poganja execution environments |
| CI (GitLab, Jenkins) | | že imate | ekipe s CI | pipeline z ročnim gumbom (`when: manual`) je pogosto dovolj |

Priporočilo za majhno ekipo z Dockerjem in Ansiblom: **Semaphore UI** ali
**GitLab pipeline z ročnim korakom**. AWX samo, če že imate Kubernetes in vas
zamrznitev ne moti; AAP, če želite podporo.

## 3. Semaphore UI v praksi

```
 git repozitorij (playbooki) ──► Semaphore: Project
                                  ├─ Repository (git ali lokalna mapa)
                                  ├─ Key Store (SSH ključ, Vault geslo)
                                  ├─ Inventory (datoteka iz repozitorija ali vnos)
                                  ├─ Variable Group (extra vars, env)
                                  └─ Task Template (playbook + inventory + ključ)
                                        └─ Run ► zgodovina, izpis, urnik
```

- Zagon: `docker run semaphoreui/semaphore` s `SEMAPHORE_DB_DIALECT=sqlite`
  (od v2.16) in admin uporabnikom iz spremenljivk; gesla prek `*_FILE` in
  secretov, ne v compose datoteki.
- `SEMAPHORE_ACCESS_KEY_ENCRYPTION` (`head -c32 /dev/urandom | base64`)
  šifrira ključe v bazi. Izgubljen ključ = izgubljene shranjene poverilnice.
- Kolekcije: Semaphore namesti `requirements.yml` iz repozitorija
  (`collections/requirements.yml` ali `requirements.yml`).
- Python paketi za Ansible v kontejnerju: `requirements.txt` v
  `/etc/semaphore` ali lastna slika.

## 4. GUI za Swarm

| Orodje | Kaj zna | Opombe |
| --- | --- | --- |
| **Portainer CE** | servisi, stacki (tudi iz gita), nodi, logi, konzola, uporabniki | agent kot global servis; Business Edition plačljiv |
| **Swarmpit** | pregled servisov, nodov, stackov, osnovne metrike | manjši projekt, redke izdaje (1.10, april 2026) |
| Grafana | metrike in logi (če imate Prometheus) | ni za spremembe |
| Dozzle | logi kontejnerjev v brskalniku | samo branje |

Past: GUI, ki zna spreminjati servise, je obvod mimo gita. Sprememba v
Portainerju, ki je ni v Ansiblu, ob naslednjem `deploy.yml` izgine (ali
obratno). Dogovor: GUI za branje in nujne posege, vse trajne spremembe v git.
(Pogosta kombinacija: Portainer in Dozzle za pregled, deploy pa iz Ansibla.)

## 5. Povzetek

- GUI za Ansible = zgodovina, poverilnice, pravice, urniki, gumb.
- Semaphore UI: en kontejner, odprta koda, primeren za manjše ekipe.
- AWX: izdaje zamrznjene od 2024; AAP je komercialna pot.
- Za Swarm: Portainer (upravljanje), Swarmpit (pregled), Grafana (metrike).
- Trajne spremembe ostanejo v gitu, GUI jih le poganja ali prikazuje.

## Viri

- Semaphore UI documentation, https://docs.semaphoreui.com/
- Semaphore UI: Docker installation, https://docs.semaphoreui.com/administration-guide/installation/docker/
- Semaphore UI releases, https://github.com/semaphoreui/semaphore/releases
- AWX README (zamrznitev izdaj), https://github.com/ansible/awx
- AWX: Upcoming changes to the AWX project, https://www.ansible.com/blog/upcoming-changes-to-the-awx-project/
- Red Hat Ansible Automation Platform, https://www.redhat.com/en/technologies/management/ansible
- Rundeck documentation, https://docs.rundeck.com/docs/
- ansible-navigator, https://docs.ansible.com/projects/navigator/
- Portainer: Install Portainer CE on Docker Swarm, https://docs.portainer.io/start/install-ce/server/swarm
- Swarmpit, https://github.com/swarmpit/swarmpit
