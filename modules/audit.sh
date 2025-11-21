#!/bin/bash
# audit.sh - Auditoría rápida de seguridad para servidores Linux


set -euo pipefail

# Configuración básica
WEB_ROOT="/var/www"
CURL_OPTS="-sS --max-time 3 --path-as-is"

# Colores
RED="\e[31m"
YELLOW="\e[33m"
GREEN="\e[32m"
CYAN="\e[36m"
NC="\e[0m"

# Funciones visuales
section() { echo -e "\n${CYAN}==== $1 ====${NC}"; }
crit()    { echo -e "${RED}[CRÍTICO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC}   $1"; }
info()    { echo -e "${GREEN}[OK/INFO]${NC} $1"; }

# Banner
clear
echo -e "${CYAN}AUDITORÍA RÁPIDA DE SEGURIDAD LINUX (IP REAL)${NC}"
echo "================================================="

# 1. CHEQUEO DE USUARIO
section "Usuario"
if [[ $(id -u) -eq 0 ]]; then
    info "Ejecutando como root (Acceso total)"
else
    warn "No eres root. Resultados limitados."
fi

# 2. DETECTAR IP REAL
section "Detección de IP del servidor"
SERVER_IP=$(hostname -I | awk '{print $1}')
if [[ -z "$SERVER_IP" ]]; then
    crit "No se pudo detectar la IP del servidor."
    exit 1
else
    info "IP detectada: $SERVER_IP"
fi

# 3. ESCANEO DE PUERTOS CRÍTICOS CON NMAP
section "Puertos Críticos (Nmap)"
if ! command -v nmap >/dev/null; then
    crit "Nmap no está instalado. Instálalo con: sudo apt install nmap"
    exit 1
fi

CRITICAL_PORTS="21,23,25,53,110,143,3306,6379,11211,27017,3389,5900"
info "Escaneando $SERVER_IP"
SCAN=$(nmap -Pn -p $CRITICAL_PORTS $SERVER_IP)

echo "$SCAN"
echo

for port in $(echo $CRITICAL_PORTS | tr ',' ' '); do
    if echo "$SCAN" | grep -q "$port/tcp open"; then
        crit "Puerto crítico ABIERTO → $port"
    else
        info "Puerto seguro (cerrado) → $port"
    fi
done

# 4. EXPOSICIÓN WEB
section "Exposición Web ($SERVER_IP)"
if curl -s -o /dev/null "http://$SERVER_IP"; then
    for archivo in "/.git/HEAD" "/.env" "/wp-config.php.bak" "/info.php"; do
        code=$(curl -o /dev/null -w '%{http_code}' $CURL_OPTS "http://$SERVER_IP$archivo" || echo "ERR")
        if [[ "$code" == "200" ]]; then
            crit "EXPUESTO: http://$SERVER_IP$archivo (HTTP 200)"
        else
            info "Seguro: $archivo ($code)"
        fi
    done
else
    warn "No se detecta servicio HTTP en $SERVER_IP (Omitiendo checks web)"
fi

# 5. HEADERS DE SEGURIDAD
section "Headers de Seguridad (HTTP)"
if curl -s -o /dev/null "http://$SERVER_IP"; then
    headers=$(curl -I $CURL_OPTS "http://$SERVER_IP" 2>/dev/null)

    check_header() {
        local name=$1
        local friendly=$2
        if echo "$headers" | grep -qi "^$name:"; then
            info "$friendly presente ($name)"
        else
            warn "$friendly ausente ($name)"
        fi
    }

    check_header "X-Frame-Options" "Protección Clickjacking"
    check_header "X-Content-Type-Options" "Protección MIME-Sniffing"
    check_header "X-XSS-Protection" "Protección XSS (legacy)"
    check_header "Content-Security-Policy" "CSP"
    check_header "Strict-Transport-Security" "HSTS"
else
    warn "No se detecta HTTP en $SERVER_IP (omitidos headers)"
fi

# 6. DETECCIÓN DE SERVIDOR WEB
section "Versión del Servidor Web"
server_header=$(curl -I $CURL_OPTS "http://$SERVER_IP" 2>/dev/null | grep -i "^Server:" || true)
if [[ -n "$server_header" ]]; then
    info "Server header detectado: $server_header"
else
    warn "No se encontró header 'Server:'"
fi

if command -v apache2 >/dev/null; then
    info "Apache detectado: $(apache2 -v 2>/dev/null | head -n1)"
elif command -v httpd >/dev/null; then
    info "Apache (httpd) detectado: $(httpd -v 2>/dev/null | head -n1)"
fi

if command -v nginx >/dev/null; then
    info "Nginx detectado: $(nginx -v 2>&1)"
fi

# 7. ARCHIVOS PELIGROSOS
section "Archivos peligrosos en $WEB_ROOT"
if [[ -d "$WEB_ROOT" ]]; then
    found=$(find "$WEB_ROOT" -maxdepth 4 -type f \( -iname ".env*" -o -iname "wp-config.php" -o -iname "*.bak" \) 2>/dev/null)
    if [[ -n "$found" ]]; then
        echo "$found"
        warn "Revisa los permisos de los archivos listados arriba."
    else
        info "No se encontraron archivos sensibles obvios en profundidad 4."
    fi
else
    warn "El directorio $WEB_ROOT no existe."
fi

# 8. PERMISOS WORLD-WRITABLE
section "Permisos World-Writable (777)"
if [[ -d "$WEB_ROOT" ]]; then
    ww_dirs=$(find "$WEB_ROOT" -type d -perm -0002 2>/dev/null)
    if [[ -n "$ww_dirs" ]]; then
        crit "Directorios escribibles por todos (Peligroso):"
        echo "$ww_dirs"
    else
        info "No hay directorios con permisos 777/world-writable."
    fi
fi

# 9. FIREWALL Y SEGURIDAD
section "Estado del Firewall"
if command -v ufw >/dev/null; then
    ufw status | grep -i "Status" || echo "UFW instalado pero error al leer estado"
elif command -v nft >/dev/null; then
    echo "NFTables detectado."
elif command -v iptables >/dev/null; then
    count=$(iptables -L -n | wc -l)
    info "IPtables tiene $count reglas."
else
    crit "No se detecta firewall activo."
fi

echo -e "\n${CYAN}==== Fin de la auditoría ====${NC}"