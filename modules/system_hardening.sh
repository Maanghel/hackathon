#!/bin/bash
# system_hardening_full.sh - Hardening seguro y autosuficiente para servidores Linux

GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"; RED="\e[31m"; RESET="\e[0m"
log(){ echo -e "${GREEN}[✔]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[⚠]${RESET} $1"; }
info(){ echo -e "${CYAN}[ℹ]${RESET} $1"; }

info "Iniciando hardening del sistema..."

# ================================
# 1. Actualizaciones
# ================================
info "Aplicando actualizaciones del sistema..."
apt-get update -y && apt-get upgrade -y
log "Sistema actualizado."

# ================================
# 2. Firewall (UFW)
# ================================
info "Instalando y configurando UFW..."
apt-get install -y ufw

ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS

yes | ufw enable
log "Firewall configurado."

# ================================
# 3. SSH Hardening
# ================================
info "Asegurando SSH..."
SSHD="/etc/ssh/sshd_config"

sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD"
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSHD"
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD"

systemctl reload sshd || systemctl restart ssh
log "SSH asegurado."

# ================================
# 4. Sysctl básico
# ================================
info "Aplicando reglas de kernel básicas..."
cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF

sysctl --system >/dev/null
log "Parámetros de kernel aplicados."

# ================================
# 5. Puertos críticos (mejorado)
# ================================
info "Revisando y cerrando puertos críticos..."

# Lista ampliada de puertos críticos
CRITICAL_PORTS=(21 23 25 53 110 143 3306 6379 11211 27017 3389 5900)

declare -A PORT_SERVICES=(
    [21]="vsftpd proftpd"
    [23]="telnetd"
    [25]="postfix exim"
    [53]="bind9"
    [110]="dovecot"
    [143]="dovecot"
    [3306]="mysql mariadb"
    [6379]="redis"
    [11211]="memcached"
    [27017]="mongod"
    [3389]="xrdp"
    [5900]="vncserver"
)

for port in "${CRITICAL_PORTS[@]}"; do
    if ss -tulpen | grep -q ":$port "; then
        warn "Puerto crítico detectado: $port"

        # Revisar servicios asociados
        svcs="${PORT_SERVICES[$port]}"
        for s in $svcs; do
            if systemctl list-unit-files | grep -q "^$s"; then
                if systemctl is-active --quiet "$s"; then
                    warn "  → Deteniendo servicio activo: $s"
                    systemctl stop "$s"
                else
                    info "  → Servicio $s detectado pero no activo."
                fi
            fi
        done
    fi
done

log "Puertos críticos revisados."

# ================================
# 6. Permisos críticos
# ================================
info "Corrigiendo permisos de archivos sensibles..."

chmod 600 /etc/ssh/ssh_host_*key 2>/dev/null || true
chmod 600 /etc/shadow 2>/dev/null || true
chmod 644 /etc/passwd 2>/dev/null || true

log "Permisos de archivos críticos corregidos."

# ================================
log "Hardening del sistema completado."