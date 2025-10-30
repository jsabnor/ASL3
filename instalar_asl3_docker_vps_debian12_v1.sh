#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║  🚀 Instalador ASL3 Docker con configuración personalizada         ║
# ║  🛠️ Creado por: EA7KNZ — ea7knz@gmail.com                          ║
# ╚════════════════════════════════════════════════════════════════════╝

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'; NC='\033[0m'

echo -e "${CYAN}╔═════════════════════════════════════════════════════╗"
echo -e "║        🚀 INSTALADOR AUTOMÁTICO ASL3 DOCKER         ║"
echo -e "║        📟 Creado por EA7KNZ — ea7knz@gmail.com      ║"
echo -e "╚═════════════════════════════════════════════════════╝${NC}"

# === DATOS PERSONALIZADOS ===
echo -e "${YELLOW}🔧 Introduce los datos de configuración:${NC}"
read -p "📟 Número de nodo: " NODE
read -p "🔑 Contraseña del nodo: " NODE_PASS
read -p "📡 Indicativo (callsign): " CALLSIGN
read -p "👤 Usuario IAX para DVSwitch: " IAX_USER
read -p "🔐 Contraseña IAX: " IAX_PASS
read -p "📍 Prefijo local (HOMENPA): " HOMENPA

# === CLONAR REPOSITORIO ===
echo -e "${BLUE}📁 Clonando ASL3-Docker...${NC}"
mkdir -p /docker && cd /docker || exit 1
[ ! -d "ASL3-Docker" ] && git clone https://github.com/AllStarLink/ASL3-Docker.git
cd ASL3-Docker || { echo -e "${RED}❌ No se pudo acceder al repositorio.${NC}"; exit 1; }

# === CONSTRUIR Y LANZAR CONTENEDOR ===
echo -e "${BLUE}🔧 Construyendo y lanzando contenedor...${NC}"
docker compose up -d --build --force-recreate

# === ESPERAR Y VERIFICAR ===
echo -e "${BLUE}🔍 Verificando contenedor...${NC}"
sleep 10
docker ps | grep -q allstarlink3 || { echo -e "${RED}❌ El contenedor no está activo.${NC}"; exit 1; }

# === CREAR ARCHIVOS TEMPORALES PERSONALIZADOS ===
echo -e "${BLUE}📝 Generando archivos temporales personalizados...${NC}"
mkdir -p /tmp/asl3-config

# rpt.conf
cat > /tmp/asl3-config/rpt.conf <<EOF
[general]
node_lookup_method = dns

[nodes]
$NODE = radio@127.0.0.1/$NODE,NONE

[node-main](!)
rxchannel = dahdi/pseudo
duplex = 0
hangtime = 100
idrecording = |i$CALLSIGN
context = radio
callerid = "$CALLSIGN <$NODE>"
functions = functions
link_functions = functions
phone_functions = functions
telemetry = telemetry
morse = morse
macro = macro
controlstates = controlstates
events = events
scheduler = schedule
wait_times = wait-times

[$NODE](node-main)
EOF

# iax.conf
cat > /tmp/asl3-config/iax.conf <<EOF
[general]
register => $NODE:$NODE_PASS@register.allstarlink.org
bindport = 4569
disallow = all
allow = ulaw
allow = adpcm
allow = gsm

[$IAX_USER]
type = friend
context = iax-client
auth = md5
secret = $IAX_PASS
host = dynamic
disallow = all
allow = ulaw
allow = adpcm
allow = gsm
EOF

# extensions.conf
cat > /tmp/asl3-config/extensions.conf <<EOF
[globals]
HOMENPA = $HOMENPA
NODE = $NODE

[default]
exten => i,1,Hangup

[iax-client]
exten => $NODE,1,Ringing()
 same => n,Wait(10)
 same => n,Answer()
 same => n,Set(CALLSIGN=\${CALLERID(name)})
 same => n,Playback(rpt/connected-to&rpt/node)
 same => n,SayDigits($NODE)
 same => n,rpt($NODE,P,\${CALLSIGN}-P)
 same => n,Hangup
EOF

# === COPIAR ARCHIVOS AL CONTENEDOR ===
echo -e "${BLUE}📦 Copiando archivos al contenedor...${NC}"
docker cp /tmp/asl3-config/rpt.conf allstarlink3:/etc/asterisk/rpt.conf
docker cp /tmp/asl3-config/iax.conf allstarlink3:/etc/asterisk/iax.conf
docker cp /tmp/asl3-config/extensions.conf allstarlink3:/etc/asterisk/extensions.conf

# === VALIDAR QUE SE COPIARON CORRECTAMENTE ===
echo -e "${BLUE}🔍 Validando archivos en el contenedor...${NC}"
docker exec allstarlink3 ls -l /etc/asterisk/{rpt.conf,iax.conf,extensions.conf} || {
  echo -e "${RED}❌ Error al copiar los archivos.${NC}"
  exit 1
}

# === REINICIAR CONTENEDOR PARA APLICAR CAMBIOS ===
echo -e "${BLUE}🔄 Reiniciando contenedor...${NC}"
docker restart allstarlink3

# === FINAL ===
echo -e "${GREEN}✅ Nodo $NODE con indicativo $CALLSIGN configurado correctamente.${NC}"
echo -e "${CYAN}📱 DVSwitch: usuario '$IAX_USER' / contraseña '$IAX_PASS'${NC}"
echo -e "${BLUE}📟 Menú ASL: docker exec -it allstarlink3 asl-menu${NC}"
