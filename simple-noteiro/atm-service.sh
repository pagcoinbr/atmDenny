#!/bin/bash
# Script para configurar e gerenciar os serviços ATM Bitcoin Lightning

SERVICES_DIR="/home/dennytorresrbp/Desktop/atmDenny/simple-noteiro"
SYSTEMD_DIR="/etc/systemd/system"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

install_services() {
    print_status "Instalando serviços systemd..."
    
    # Copiar arquivos de serviço
    sudo cp "$SERVICES_DIR/atm-frontend.service" "$SYSTEMD_DIR/"
    sudo cp "$SERVICES_DIR/atm-backend.service" "$SYSTEMD_DIR/"
    
    # Definir permissões
    sudo chmod 644 "$SYSTEMD_DIR/atm-frontend.service"
    sudo chmod 644 "$SYSTEMD_DIR/atm-backend.service"
    
    # Recarregar systemd
    sudo systemctl daemon-reload
    
    # Habilitar serviços para iniciar no boot
    sudo systemctl enable atm-frontend.service
    sudo systemctl enable atm-backend.service
    
    print_success "Serviços instalados e habilitados!"
}

uninstall_services() {
    print_status "Removendo serviços systemd..."
    
    # Parar serviços se estiverem rodando
    sudo systemctl stop atm-frontend.service 2>/dev/null
    sudo systemctl stop atm-backend.service 2>/dev/null
    
    # Desabilitar serviços
    sudo systemctl disable atm-frontend.service 2>/dev/null
    sudo systemctl disable atm-backend.service 2>/dev/null
    
    # Remover arquivos de serviço
    sudo rm -f "$SYSTEMD_DIR/atm-frontend.service"
    sudo rm -f "$SYSTEMD_DIR/atm-backend.service"
    
    # Recarregar systemd
    sudo systemctl daemon-reload
    
    print_success "Serviços removidos!"
}

start_services() {
    print_status "Iniciando serviços ATM..."
    
    sudo systemctl start atm-frontend.service
    sudo systemctl start atm-backend.service
    
    sleep 2
    
    if systemctl is-active --quiet atm-frontend.service && systemctl is-active --quiet atm-backend.service; then
        print_success "Ambos os serviços iniciados com sucesso!"
        print_status "Frontend: http://localhost:3005"
        print_status "Backend: Monitorando GPIO pino 17"
    else
        print_error "Erro ao iniciar um ou ambos os serviços"
        show_status
    fi
}

stop_services() {
    print_status "Parando serviços ATM..."
    
    sudo systemctl stop atm-frontend.service
    sudo systemctl stop atm-backend.service
    
    print_success "Serviços parados!"
}

restart_services() {
    print_status "Reiniciando serviços ATM..."
    
    sudo systemctl restart atm-frontend.service
    sudo systemctl restart atm-backend.service
    
    sleep 2
    show_status
}

show_status() {
    echo
    print_status "Status dos serviços:"
    echo "===================="
    
    # Frontend status
    if systemctl is-active --quiet atm-frontend.service; then
        print_success "Frontend: ATIVO"
    else
        print_error "Frontend: INATIVO"
    fi
    
    # Backend status
    if systemctl is-active --quiet atm-backend.service; then
        print_success "Backend: ATIVO"
    else
        print_error "Backend: INATIVO"
    fi
    
    echo
    print_status "Detalhes completos:"
    systemctl status atm-frontend.service --no-pager -l
    echo
    systemctl status atm-backend.service --no-pager -l
}

show_logs() {
    service="$1"
    if [ -z "$service" ]; then
        print_status "Logs do Frontend (últimas 20 linhas):"
        sudo journalctl -u atm-frontend.service -n 20 --no-pager
        echo
        print_status "Logs do Backend (últimas 20 linhas):"
        sudo journalctl -u atm-backend.service -n 20 --no-pager
    else
        print_status "Logs do $service:"
        sudo journalctl -u "atm-$service.service" -f
    fi
}

show_help() {
    echo "ATM Bitcoin Lightning - Gerenciador de Serviços"
    echo "=============================================="
    echo
    echo "Uso: $0 [COMANDO]"
    echo
    echo "Comandos:"
    echo "  install     - Instalar serviços no systemd"
    echo "  uninstall   - Remover serviços do systemd"
    echo "  start       - Iniciar ambos os serviços"
    echo "  stop        - Parar ambos os serviços"
    echo "  restart     - Reiniciar ambos os serviços"
    echo "  status      - Mostrar status dos serviços"
    echo "  logs        - Mostrar logs de ambos os serviços"
    echo "  logs-front  - Seguir logs do frontend em tempo real"
    echo "  logs-back   - Seguir logs do backend em tempo real"
    echo "  help        - Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 install     # Instalar serviços"
    echo "  $0 start       # Iniciar ATM"
    echo "  $0 status      # Ver status"
    echo "  $0 logs-front  # Ver logs do frontend"
}

# Verificar se está rodando como root para comandos que precisam
check_sudo() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Este script não deve ser executado como root!"
        print_warning "Execute sem sudo. O script pedirá senha quando necessário."
        exit 1
    fi
}

main() {
    check_sudo
    
    case "${1:-help}" in
        "install")
            install_services
            ;;
        "uninstall")
            uninstall_services
            ;;
        "start")
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "logs-front")
            show_logs "frontend"
            ;;
        "logs-back")
            show_logs "backend"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"