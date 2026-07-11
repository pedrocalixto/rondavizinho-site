#!/bin/bash
# RondaVizinho — instalação em uma linha (Debian/Ubuntu e derivados):
#   curl -fsSL https://rondavizinho.com.br/get.sh | sudo bash
#
# Baixa o código para /opt/vigia, instala dependências (python3, ffmpeg) e os
# serviços systemd; ao final, abra http://IP-do-computador:8080 no navegador e
# siga o assistente. Variáveis p/ testes: RONDA_ZIP, RONDA_DEST.
set -euo pipefail

ZIP="${RONDA_ZIP:-https://github.com/pedrocalixto/rondavizinho/archive/refs/heads/main.zip}"
DEST="${RONDA_DEST:-/opt/vigia}"

echo
echo "  RondaVizinho — o vigia inteligente da sua rua"
echo

if [ "$(id -u)" != 0 ]; then
    echo "Rode com sudo:  curl -fsSL .../get.sh | sudo bash" >&2
    exit 1
fi

echo "Instalando dependências (python3, ffmpeg)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 ffmpeg unzip curl >/dev/null

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Baixando o RondaVizinho..."
if ! curl -fsSL "$ZIP" -o "$TMP/ronda.zip"; then
    echo
    echo "Não consegui baixar o código. Verifique sua internet e tente de novo;"
    echo "se persistir, abra uma issue em:"
    echo "  https://github.com/pedrocalixto/rondavizinho/issues"
    exit 1
fi
unzip -q "$TMP/ronda.zip" -d "$TMP"
RAIZ="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"

# atualização: para os serviços antes de trocar o código
systemctl stop vigia vigia-web 2>/dev/null || true
mkdir -p "$DEST" /var/lib/vigia
cp -r "$RAIZ"/. "$DEST/"

cd "$DEST" && python3 -m vigia --check

cp "$DEST"/systemd/vigia.service "$DEST"/systemd/vigia-web.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now vigia-web             # serve o assistente (e depois o painel)
systemctl enable vigia                       # o daemon entra em serviço após o assistente
if [ -f /var/lib/vigia/config.json ]; then
    systemctl start vigia                    # reinstalação/atualização: já configurado
fi

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "Instalado! Abra o assistente no navegador:  http://${IP:-localhost}:8080"
echo "Ele acha seu DVR, testa as câmeras e configura tudo passo a passo."
