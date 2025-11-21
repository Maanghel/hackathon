#!/bin/bash
# access_control_full.sh - Control de acceso y hardening web con headers de seguridad (autosuficiente)

set -euo pipefail

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; CYAN="\e[36m"; RESET="\e[0m"
log(){ echo -e "${GREEN}[✔]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[⚠]${RESET} $1"; }
info(){ echo -e "${CYAN}[ℹ]${RESET} $1"; }

info "Iniciando Hardening de Control de Acceso con Headers de Seguridad..."

# ================================
# 1. PERMISOS INTELIGENTES
# ================================
if [ -d /var/www ]; then
    info "Ajustando permisos en /var/www..."
    WEB_USER=""
    for u in www-data nginx apache; do
        if id "$u" >/dev/null 2>&1; then
            WEB_USER="$u"
            break
        fi
    done

    if [ -n "$WEB_USER" ]; then
        chown -R "$WEB_USER:$WEB_USER" /var/www
        find /var/www -type d -exec chmod 750 {} \;
        find /var/www -type f -exec chmod 640 {} \;
        log "Permisos corregidos: Directorios 750, Archivos 640."
    else
        warn "No se encontró usuario web. Saltando ajuste de permisos."
    fi
else
    warn "/var/www no existe. Saltando permisos."
fi

# ================================
# 2. HARDENING NGINX + HEADERS
# ================================
if command -v nginx >/dev/null 2>&1; then
    info "Configurando hardening Nginx y headers de seguridad..."

    SNIPPET_DIR="/etc/nginx/snippets"
    mkdir -p "$SNIPPET_DIR"
    NGINX_SNIPPET="$SNIPPET_DIR/hardening_rules.conf"

    cat > "$NGINX_SNIPPET" << 'EOF'
# Hardening básico Nginx
server_tokens off;
client_max_body_size 10M;
autoindex off;

# Bloquear archivos sensibles
location ~ /\.(?!well-known).* { deny all; }
location ~* \.(env|git|svn|hg|bak|sql|sqlite|log|passwd|htpasswd|htaccess|sh)$ { deny all; }
location ~* ^/(backup|private|config|storage|secret)/ { deny all; }
location ^~ /uploads/ { location ~ \.php$ { deny all; } }

# HEADERS DE SEGURIDAD
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self';" always;
EOF

    # Insertar snippet automáticamente en todos los server blocks
    for site in /etc/nginx/sites-enabled/*; do
        if ! grep -q "include snippets/hardening_rules.conf;" "$site"; then
            sed -i '/server_name/a \    include snippets/hardening_rules.conf;' "$site"
            log "Snippet incluido en $site"
        fi
    done

    nginx -t && systemctl reload nginx && log "Nginx endurecido y headers aplicados." || warn "Error al recargar Nginx."
else
    warn "Nginx no instalado."
fi

# ================================
# 3. HARDENING APACHE + HEADERS
# ================================
if command -v apache2 >/dev/null 2>&1; then
    info "Configurando hardening Apache y headers de seguridad..."

    APACHE_CONF="/etc/apache2/conf-available/access_hardening.conf"
    a2enmod rewrite headers >/dev/null 2>&1 || true

    cat > "$APACHE_CONF" << 'EOF'
# Hardening básico Apache
Options -Indexes

# Bloquear archivos sensibles
<FilesMatch "^\.(?!well-known)">Require all denied</FilesMatch>
<FilesMatch "\.(env|git|svn|bak|sql|log|sh)$">Require all denied</FilesMatch>
<DirectoryMatch "(backup|private|config|secret)">Require all denied</DirectoryMatch>

# HEADERS DE SEGURIDAD
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header always set Content-Security-Policy "default-src 'self';"
EOF

    a2enconf access_hardening >/dev/null 2>&1 || true
    apache2ctl configtest && systemctl reload apache2 && log "Apache endurecido y headers aplicados." || warn "Error al recargar Apache."
else
    warn "Apache no instalado."
fi

log "Control de acceso y headers de seguridad aplicados correctamente."