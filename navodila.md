# Lab okolje env01: dostop

Tečaj: **Docker in Ansible v praksi**

| | |
| --- | --- |
| Uporabnik | `lab` |
| Geslo | `dostavjeno` |
| Strežnik | `ip bo dostavljen` (ime na strežniku `control`) |

Dobite **en strežnik** (Ubuntu 24.04): na njem teče Ansible (control) in na
istem strežniku Ansible namesti Docker in aplikacije (Docker host). Uporabnik
ima `sudo` brez gesla. Geslo si lahko spremenite z ukazom `passwd`.

## 1. Prva prijava

```bash
ssh lab@ip
```

Ob prvi povezavi potrdite ključ strežnika (`yes`) in vpišite geslo.
Deluje v terminalu na macOS in Linuxu ter v PowerShell na Windows 10/11
(vgrajen OpenSSH). PuTTY: Host `IP`, port 22, uporabnik
`lab`.


```

## 2. Aplikacije v brskalniku

Porti vaj so odprti na javnem naslovu strežnika (lab okolje):

| Kaj | Naslov | Od kdaj |
| --- | --- | --- |
| app1 | http://ip:8080 | po vaji A04 |
| app2 | http://io:8081 | po vaji A05 |

Pred vajo A04 na teh naslovih ni ničesar.

## 4. Na strežniku

- Vse vaje delate na tem strežniku, na svojem računalniku potrebujete samo
  SSH. Ansible je že nameščen (`~/.venv`, aktiven ob prijavi), projekt je v
  `~/projekt` (inventory `inventories/aws`: en host `control` z
  `ansible_connection: local`, kolekcije v `~/projekt/collections`).
  Po prijavi ste že v `~/projekt`: preverite z `ansible --version` in
  `ansible all -m ansible.builtin.ping` (1x pong).
