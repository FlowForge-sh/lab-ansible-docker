#!/usr/bin/env bash
#
# setup-ansible.sh: pripravi control node za ta projekt.
#
#   ./setup-ansible.sh            venv v ~/.venv, pip paketi, kolekcije, SSH ključ
#   VENV=/pot/venv ./setup-ansible.sh
#
# Kaj naredi (vsak korak je idempotenten, skripto lahko poženete večkrat):
#   1. preveri Python >= 3.12 (zahteva ansible-core 2.21 na control nodu)
#   2. ustvari venv in vanj namesti pakete iz requirements.txt (pinned verzije)
#   3. namesti kolekcije iz requirements.yml v ./collections (poleg projekta)
#   4. če SSH ključa ni, ga ustvari (ed25519) in izpiše javni del
#   5. izpiše verzije in požene ansible-lint, da vidite, da vse dela
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
VENV="${VENV:-$HOME/.venv}"
PY="${PYTHON:-python3}"

echo "==> 1/5 Python"
"$PY" -c 'import sys; assert sys.version_info >= (3, 12), sys.version' 2>/dev/null || {
    echo "Potreben je Python 3.12 ali novejši (ansible-core 2.21). Imate: $("$PY" -V 2>&1)" >&2
    echo "Ubuntu 24.04: apt install python3 python3-venv; macOS: brew install python@3.13" >&2
    exit 1
}
"$PY" -c 'import venv' 2>/dev/null || { echo "Manjka python3-venv (apt install python3-venv)" >&2; exit 1; }

echo "==> 2/5 venv $VENV in pip paketi"
[ -x "$VENV/bin/python" ] || "$PY" -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r requirements.txt

echo "==> 3/5 kolekcije (requirements.yml -> ./collections)"
"$VENV/bin/ansible-galaxy" collection install -r requirements.yml -p ./collections

echo "==> 4/5 SSH ključ"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -q -t ed25519 -N "" -C "ansible@$(hostname)" -f "$HOME/.ssh/id_ed25519"
    echo "Nov ključ. Javni del dodajte na strežnike (ssh-copy-id uporabnik@strežnik):"
    cat "$HOME/.ssh/id_ed25519.pub"
else
    echo "ključ obstaja: $HOME/.ssh/id_ed25519"
fi

echo "==> 5/5 preverjanje"
"$VENV/bin/ansible" --version | head -1
"$VENV/bin/ansible-galaxy" collection list -p ./collections 2>/dev/null | grep -E 'community\.|ansible\.' || true
# ansible-lint želi svoj venv na PATH (sicer opozori).
PATH="$VENV/bin:$PATH" ansible-lint --version 2>/dev/null | head -1 || true
echo
echo "Pripravljeno. Aktivirajte venv:  source $VENV/bin/activate"
echo "Nato:                            ansible all -m ansible.builtin.ping"
