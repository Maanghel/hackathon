#!/bin/bash
# defense_active_full.sh - Hardening activo autosuficiente con todas las soluciones

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; CYAN="\e[36m"; RESET="\e[0m"
log(){ echo -e "${GREEN}[✔]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[⚠]${RESET} $1"; }
info(){ echo -e "${CYAN}[ℹ]${RESET} $1"; }

info "Iniciando hardening activo completo..."

# Comprobar sistema Debian/Ubuntu
if ! command -v apt-get >/dev/null; then
    echo -e "${RED}Error: Solo compatible con Debian/Ubuntu.${RESET}"
    exit 1
fi

# Actualizar repositorios
apt-get update -y

# ================================
# 1. FAIL2BAN
# ================================
info "Instalando y configurando Fail2Ban..."
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = auto

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
EOF

systemctl enable --now fail2ban
log "Fail2Ban configurado y activo para SSH."

# ================================
# 2. MODSECURITY + OWASP CRS (Apache)
# ================================
if command -v apache2 >/dev/null 2>&1; then
    info "Detectado Apache. Instalando ModSecurity y OWASP CRS..."
    apt-get install -y libapache2-mod-security2 modsecurity-crs

    # Activar motor de ModSecurity
    cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf

    # Habilitar módulo headers si no está activo
    a2enmod headers >/dev/null 2>&1

    # Activar reglas OWASP CRS
    ln -sf /usr/share/modsecurity-crs/base_rules/* /usr/share/modsecurity-crs/activated_rules/ 2>/dev/null || true

    systemctl reload apache2
    log "ModSecurity activado con OWASP CRS."
else
    warn "Apache no instalado. Saltando WAF."
fi

# ================================
# 3. AIDE (Integridad de ficheros)
# ================================
info "Instalando y configurando AIDE..."
apt-get install -y aide

if ! [ -f /var/lib/aide/aide.db.gz ]; then
    warn "Inicializando base de datos AIDE (puede tardar varios minutos)..."
    aideinit
    mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    log "Base de datos AIDE generada."
else
    info "Base de datos AIDE ya existe. Saltando inicialización."
fi

# ================================
# 4. LOGWATCH
# ================================
info "Instalando y configurando Logwatch..."
apt-get install -y logwatch

# Configuración mínima para reportes locales
mkdir -p /etc/logwatch/conf
echo "Range = yesterday" > /etc/logwatch/conf/logwatch.conf
echo "Detail = Low" >> /etc/logwatch/conf/logwatch.conf

log "Logwatch instalado y configurado localmente."

# ================================
# FIN
# ================================
log "Defensa activa completa. Todas las soluciones están aplicadas."