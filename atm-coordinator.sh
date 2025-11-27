#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variáveis
PROJECT_DIR="/home/pagcoin/atmDenny"
API_DIR="$PROJECT_DIR/api-server"
FRONTEND_DIR="$PROJECT_DIR/frontend-nextjs"
LOG_DIR="$PROJECT_DIR/logs"
PID_FILE="$PROJECT_DIR/.pids"

# Função para imprimir cabeçalho
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              🏧 ATM BITCOIN LIGHTNING            ║${NC}"
    echo -e "${CYAN}║              Coordenador de Serviços             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Função para logging
log() {
    echo -e "$1" | tee -a "$LOG_DIR/coordinator.log"
}

# Função para verificar se porta está em uso
check_port() {
    local port=$1
    # Verifica com netstat e lsof
    if netstat -tuln 2>/dev/null | grep ":$port " >/dev/null || lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Porta em uso
    else
        return 1  # Porta livre
    fi
}

# Função para parar todos os serviços
stop_services() {
    log "${YELLOW}🛑 Parando todos os serviços...${NC}"
    
    # Lê PIDs salvos e mata processos
    if [ -f "$PID_FILE" ]; then
        while IFS= read -r pid_line; do
            if [ -n "$pid_line" ]; then
                pid=$(echo $pid_line | cut -d':' -f1)
                service_name=$(echo $pid_line | cut -d':' -f2)
                if kill -0 $pid 2>/dev/null; then
                    log "  🔴 Parando $service_name (PID: $pid)"
                    kill -TERM $pid 2>/dev/null
                fi
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # Mata processos por porta
    log "  🔍 Verificando processos nas portas 3000 e 3001..."
    pkill -f "node.*server.js" 2>/dev/null
    pkill -f "next.*dev" 2>/dev/null
    pkill -f "serial-bridge.js" 2>/dev/null
    
    sleep 2
    log "${GREEN}✅ Serviços parados${NC}"
}

# Função para verificar dependências
check_dependencies() {
    log "${BLUE}🔍 Verificando dependências...${NC}"
    
    # Verifica Node.js
    if ! command -v node &> /dev/null; then
        log "${RED}❌ Node.js não encontrado!${NC}"
        exit 1
    fi
    
    # Verifica npm
    if ! command -v npm &> /dev/null; then
        log "${RED}❌ npm não encontrado!${NC}"
        exit 1
    fi
    
    log "  ✅ Node.js $(node --version)"
    log "  ✅ npm $(npm --version)"
    
    # Verifica se diretórios existem
    if [ ! -d "$API_DIR" ]; then
        log "${RED}❌ Diretório da API não encontrado: $API_DIR${NC}"
        exit 1
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        log "${RED}❌ Diretório do frontend não encontrado: $FRONTEND_DIR${NC}"
        exit 1
    fi
    
    # Cria diretório de logs
    mkdir -p "$LOG_DIR"
    
    log "${GREEN}✅ Dependências verificadas${NC}"
}

# Função para instalar dependências
install_dependencies() {
    log "${BLUE}📦 Instalando/verificando dependências...${NC}"
    
    # API Backend
    log "  📡 Verificando dependências da API..."
    cd "$API_DIR"
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        log "  📥 Instalando dependências da API..."
        npm install &> "$LOG_DIR/api-install.log"
        if [ $? -eq 0 ]; then
            log "  ✅ API: dependências instaladas"
        else
            log "${RED}  ❌ Falha ao instalar dependências da API${NC}"
            exit 1
        fi
    else
        log "  ✅ API: dependências já instaladas"
    fi
    
    # Frontend Next.js
    log "  🎨 Verificando dependências do frontend..."
    cd "$FRONTEND_DIR"
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        log "  📥 Instalando dependências do frontend..."
        npm install &> "$LOG_DIR/frontend-install.log"
        if [ $? -eq 0 ]; then
            log "  ✅ Frontend: dependências instaladas"
        else
            log "${RED}  ❌ Falha ao instalar dependências do frontend${NC}"
            exit 1
        fi
    else
        log "  ✅ Frontend: dependências já instaladas"
    fi
    
    log "${GREEN}✅ Todas as dependências verificadas${NC}"
}

# Função para detectar ESP32
detect_esp32() {
    log "${PURPLE}🔌 Detectando ESP32...${NC}"
    
    ESP32_PORT=""
    
    # Verifica portas USB
    if ls /dev/ttyUSB* 1> /dev/null 2>&1; then
        ESP32_PORT=$(ls /dev/ttyUSB* | head -1)
        log "  📡 ESP32 encontrado em: $ESP32_PORT"
    elif ls /dev/ttyACM* 1> /dev/null 2>&1; then
        ESP32_PORT=$(ls /dev/ttyACM* | head -1)
        log "  📡 ESP32 encontrado em: $ESP32_PORT"
    else
        log "${YELLOW}  ⚠️  ESP32 não detectado (modo simulação disponível)${NC}"
        ESP32_PORT=""
    fi
    
    export SERIAL_PORT="$ESP32_PORT"
}

# Função para iniciar API Backend
start_api() {
    log "${BLUE}🚀 Iniciando API Backend...${NC}"
    
    cd "$API_DIR"
    
    if check_port 3001; then
        log "${YELLOW}  ⚠️  Porta 3001 já está em uso${NC}"
        log "  💡 Tentando usar API existente..."
        sleep 2
        # Testa se API responde
        if curl -s http://localhost:3001/health >/dev/null 2>&1; then
            log "${GREEN}  ✅ API Backend já está rodando na porta 3001${NC}"
            return 0
        else
            log "${YELLOW}  ⚠️  Porta ocupada mas API não responde. Tentando parar...${NC}"
            pkill -f "node.*server.js" 2>/dev/null
            sleep 3
        fi
    fi
    
    # Inicia API em background
    npm run dev > "$LOG_DIR/api.log" 2>&1 &
    API_PID=$!
    
    # Salva PID
    echo "$API_PID:API_Backend" >> "$PID_FILE"
    
    # Aguarda API inicializar - aumentando timeout
    log "  ⏳ Aguardando API inicializar..."
    for i in {1..20}; do
        sleep 1
        # Verifica se processo ainda existe
        if ! kill -0 $API_PID 2>/dev/null; then
            log "${RED}  ❌ Processo da API morreu inesperadamente${NC}"
            log "  📄 Últimas linhas do log:"
            tail -5 "$LOG_DIR/api.log" | sed 's/^/    /'
            return 1
        fi
        
        # Testa se API responde
        if curl -s http://localhost:3001/health >/dev/null 2>&1; then
            log "${GREEN}  ✅ API Backend rodando na porta 3001 (PID: $API_PID)${NC}"
            return 0
        fi
        
        echo -n "."
    done
    
    log ""
    log "${RED}  ❌ Timeout ao aguardar API inicializar${NC}"
    log "  📄 Log completo:"
    cat "$LOG_DIR/api.log" | sed 's/^/    /'
    return 1
}

# Função para iniciar Serial Bridge
start_serial_bridge() {
    if [ -n "$ESP32_PORT" ]; then
        log "${PURPLE}🔗 Iniciando Serial Bridge...${NC}"
        
        cd "$PROJECT_DIR"
        
        # Inicia bridge em background
        node serial-bridge.js > "$LOG_DIR/serial.log" 2>&1 &
        SERIAL_PID=$!
        
        # Salva PID
        echo "$SERIAL_PID:Serial_Bridge" >> "$PID_FILE"
        
        sleep 2
        if kill -0 $SERIAL_PID 2>/dev/null; then
            log "${GREEN}  ✅ Serial Bridge rodando (PID: $SERIAL_PID)${NC}"
            log "  📡 Conectado à porta: $ESP32_PORT"
        else
            log "${YELLOW}  ⚠️  Falha ao iniciar Serial Bridge${NC}"
        fi
    else
        log "${YELLOW}  ⚠️  ESP32 não detectado - Serial Bridge não iniciado${NC}"
        log "  💡 Use o simulador: ./simulador.sh"
    fi
}

# Função para iniciar Frontend
start_frontend() {
    log "${CYAN}🎨 Iniciando Frontend Next.js...${NC}"
    
    cd "$FRONTEND_DIR"
    
    if check_port 3000; then
        log "${YELLOW}  ⚠️  Porta 3000 já está em uso${NC}"
        return 1
    fi
    
    # Inicia frontend em background
    npm run dev > "$LOG_DIR/frontend.log" 2>&1 &
    FRONTEND_PID=$!
    
    # Salva PID
    echo "$FRONTEND_PID:Frontend_NextJS" >> "$PID_FILE"
    
    # Aguarda frontend inicializar
    log "  ⏳ Aguardando frontend inicializar..."
    for i in {1..15}; do
        if check_port 3000; then
            log "${GREEN}  ✅ Frontend rodando na porta 3000 (PID: $FRONTEND_PID)${NC}"
            return 0
        fi
        sleep 1
    done
    
    log "${RED}  ❌ Falha ao iniciar Frontend${NC}"
    return 1
}

# Função para mostrar status
show_status() {
    log "${GREEN}🎯 Sistema ATM Bitcoin Lightning - ATIVO${NC}"
    echo ""
    log "📋 Serviços rodando:"
    log "  🔗 API Backend:     http://localhost:3001"
    log "  🎨 Frontend Web:    http://localhost:3000"
    
    if [ -n "$ESP32_PORT" ]; then
        log "  📡 Serial Bridge:   $ESP32_PORT → API"
    else
        log "  🔧 Simulador:       ./simulador.sh"
    fi
    
    echo ""
    log "📁 Logs disponíveis em: $LOG_DIR"
    log "  📄 API:      tail -f $LOG_DIR/api.log"
    log "  📄 Frontend: tail -f $LOG_DIR/frontend.log"
    
    if [ -n "$ESP32_PORT" ]; then
        log "  📄 Serial:   tail -f $LOG_DIR/serial.log"
    fi
    
    echo ""
    log "${BLUE}💡 Comandos úteis:${NC}"
    log "  🔄 Reiniciar:    $0 restart"
    log "  🛑 Parar:        $0 stop"
    log "  📊 Status:       $0 status"
    log "  🧪 Simular nota: ./simulador.sh"
    echo ""
}

# Função para verificar status dos serviços
check_status() {
    log "${BLUE}📊 Status dos serviços:${NC}"
    
    if check_port 3001; then
        log "${GREEN}  ✅ API Backend (porta 3001)${NC}"
    else
        log "${RED}  ❌ API Backend (porta 3001)${NC}"
    fi
    
    if check_port 3000; then
        log "${GREEN}  ✅ Frontend (porta 3000)${NC}"
    else
        log "${RED}  ❌ Frontend (porta 3000)${NC}"
    fi
    
    if [ -f "$PID_FILE" ]; then
        log "  📋 Processos ativos:"
        while IFS= read -r pid_line; do
            if [ -n "$pid_line" ]; then
                pid=$(echo $pid_line | cut -d':' -f1)
                service_name=$(echo $pid_line | cut -d':' -f2)
                if kill -0 $pid 2>/dev/null; then
                    log "${GREEN}    ✅ $service_name (PID: $pid)${NC}"
                else
                    log "${RED}    ❌ $service_name (PID: $pid - morto)${NC}"
                fi
            fi
        done < "$PID_FILE"
    fi
}

# Função principal
main() {
    case "${1:-start}" in
        "start")
            print_header
            check_dependencies
            install_dependencies
            detect_esp32
            
            log "${YELLOW}🚀 Iniciando sistema completo...${NC}"
            echo ""
            
            if start_api; then
                sleep 2
                start_serial_bridge
                sleep 1
                if start_frontend; then
                    echo ""
                    show_status
                    
                    # Modo interativo
                    log "${BLUE}▶️  Sistema iniciado! Pressione Ctrl+C para parar todos os serviços${NC}"
                    
                    # Trap para capturar Ctrl+C
                    trap stop_services INT
                    
                    # Loop infinito
                    while true; do
                        sleep 1
                    done
                else
                    log "${RED}❌ Falha ao iniciar frontend${NC}"
                    stop_services
                    exit 1
                fi
            else
                log "${RED}❌ Falha ao iniciar API${NC}"
                stop_services
                exit 1
            fi
            ;;
            
        "stop")
            print_header
            stop_services
            ;;
            
        "restart")
            print_header
            stop_services
            sleep 2
            exec "$0" start
            ;;
            
        "status")
            print_header
            check_status
            ;;
            
        "logs")
            if [ -n "$2" ]; then
                case "$2" in
                    "api") tail -f "$LOG_DIR/api.log" ;;
                    "frontend") tail -f "$LOG_DIR/frontend.log" ;;
                    "serial") tail -f "$LOG_DIR/serial.log" ;;
                    *) echo "Logs disponíveis: api, frontend, serial" ;;
                esac
            else
                echo "Uso: $0 logs [api|frontend|serial]"
            fi
            ;;
            
        "help"|"-h"|"--help")
            print_header
            echo "Uso: $0 [comando]"
            echo ""
            echo "Comandos:"
            echo "  start     - Inicia todos os serviços (padrão)"
            echo "  stop      - Para todos os serviços"
            echo "  restart   - Reinicia todos os serviços"
            echo "  status    - Mostra status dos serviços"
            echo "  logs      - Mostra logs específicos"
            echo "  help      - Mostra esta ajuda"
            echo ""
            ;;
            
        *)
            echo "Comando inválido. Use: $0 help"
            exit 1
            ;;
    esac
}

# Executa função principal
main "$@"