#!/bin/bash
# main.sh — Script principal para auditoría y hardening de servidores Linux
# Versión robusta sin generación de reportes

# Colores
RED="\033[38;5;196m"
GREEN="\033[38;5;46m"
BLUE="\033[38;5;39m"
YELLOW="\033[38;5;226m"
MAGENTA="\033[38;5;207m"
CYAN="\033[38;5;51m"
NC="\033[0m"

# ==============================
# Funciones
# ==============================
banner() {
    clear
    echo -e "${CYAN}"
    echo " _   _    _    ____ _  __    _  _____ _   _  ___  _   _ "
    echo "| | | |  / \  / ___| |/ /   / \|_   _| | | |/ _ \| \ | |"
    echo "| |_| | / _ \| |   | ' /   / _ \ | | | |_| | | | |  \| |"
    echo "|  _  |/ ___ \ |___| . \  / ___ \| | |  _  | |_| | |\  |"
    echo "|_| |_/_/   \_\____|_|\_\/_/   \_\_| |_| |_|\___/|_| \_|"
    echo -e "${NC}"
    echo -e "${MAGENTA}        🛡️ SUITE DE AUDITORÍA & HARDENING — Reto 05 🛡️${NC}"
    echo "=========================================================="
    echo
}

# Validación root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Debes ejecutar este script como root.${NC}"
    exit 1
fi

# Rutas
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$BASE_DIR/modules"

# Validar módulos de forma segura
shopt -s nullglob
MODULES=("$MODULES_DIR"/*.sh)
if [ ${#MODULES[@]} -eq 0 ]; then
    echo -e "${RED}[ERROR] No se encontraron módulos en: $MODULES_DIR${NC}"
    exit 1
fi
chmod +x "${MODULES[@]}"

# Ejecutar módulo
run_module() {
    local module_name="$1"
    local script_path="$MODULES_DIR/$2"

    if [[ -f "$script_path" ]]; then
        echo -e "${YELLOW}[+] Ejecutando módulo: ${CYAN}$module_name${NC}"
        "$script_path" || {
            echo -e "${RED}[!] Error en $module_name, continuando...${NC}"
        }
        echo
    else
        echo -e "${RED}[ERROR] Módulo no encontrado: $script_path${NC}"
    fi
}

# ==============================
# Menú principal
# ==============================
while true; do
    banner
    echo -e "${BLUE}Módulos disponibles:${NC}"
    for f in "${MODULES[@]}"; do
        echo " - $(basename "$f")"
    done
    echo
    echo -e "${YELLOW}1)${NC} Ejecutar TODO (Auditoría + Hardening + Defensa Activa + Control de Acceso)"
    echo -e "${YELLOW}2)${NC} Auditoría del Sistema"
    echo -e "${YELLOW}3)${NC} Hardening del Sistema"
    echo -e "${YELLOW}4)${NC} Defensa Activa"
    echo -e "${YELLOW}5)${NC} Controles de Acceso"
    echo -e "${YELLOW}6)${NC} Salir"
    echo

    read -p "Selecciona una opción: " choice

    case "$choice" in
        1)
            run_module "AUDITORÍA" "audit.sh"
            run_module "HARDENING SISTEMA" "system_hardening.sh"
            run_module "DEFENSA ACTIVA" "defense_active.sh"
            run_module "CONTROL DE ACCESO" "access_control.sh"
            read -p "Presiona Enter para continuar..."
            ;;
        2) run_module "AUDITORÍA" "audit.sh"; read -p "Enter...";;
        3) run_module "HARDENING SISTEMA" "system_hardening.sh"; read -p "Enter...";;
        4) run_module "DEFENSA ACTIVA" "defense_active.sh"; read -p "Enter...";;
        5) run_module "CONTROL DE ACCESO" "access_control.sh"; read -p "Enter...";;
        6) echo -e "${GREEN}Saliendo...${NC}"; exit 0;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1;;
    esac
done