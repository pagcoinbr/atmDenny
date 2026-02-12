#!/bin/bash
# Script de controle dos serviços ATM Bitcoin Lightning
# Controla frontend e backend via PIDs

# Configurações
PROJECT_DIR="/home/dennytorresrbp/Desktop/atmDenny/simple-noteiro"
PID_DIR="$PROJECT_DIR/pids"
FRONTEND_PID="$PID_DIR/frontend.pid"
BACKEND_PID="$PID_DIR/backend.pid"
LOG_DIR="$PROJECT_DIR/logs"
FRONTEND_LOG="$LOG_DIR/frontend.log"
BACKEND_LOG="$LOG_DIR/backend.log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Criar diretórios se não existirem
mkdir -p "$PID_DIR" "$LOG_DIR"

# Função para mostrar status
show_status() {
    echo -e "${BLUE}=== STATUS DOS SERVIÇOS ATM ===${NC}"
    
    # Frontend
    if [ -f "$FRONTEND_PID" ] && kill -0 "$(cat $FRONTEND_PID)" 2>/dev/null; then
        echo -e "Frontend: ${GREEN}RODANDO${NC} (PID: $(cat $FRONTEND_PID))"
        echo "  URL: http://localhost:3005"
    else
        echo -e "Frontend: ${RED}PARADO${NC}"
        [ -f "$FRONTEND_PID" ] && rm "$FRONTEND_PID"
    fi
    
    # Backend
    if [ -f "$BACKEND_PID" ] && kill -0 "$(cat $BACKEND_PID)" 2>/dev/null; then
        echo -e "Backend:  ${GREEN}RODANDO${NC} (PID: $(cat $BACKEND_PID))"
        echo "  Monitorando GPIO pino 17"
    else
        echo -e "Backend:  ${RED}PARADO${NC}"
        [ -f "$BACKEND_PID" ] && rm "$BACKEND_PID"
    fi
    
    echo
}

# Função para iniciar frontend
start_frontend() {
    if [ -f "$FRONTEND_PID" ] && kill -0 "$(cat $FRONTEND_PID)" 2>/dev/null; then
        echo -e "${YELLOW}Frontend já está rodando (PID: $(cat $FRONTEND_PID))${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Iniciando Frontend...${NC}"
    cd "$PROJECT_DIR"
    source venv/bin/activate
    
    # Iniciar em background e capturar PID
    nohup python3 app.py > "$FRONTEND_LOG" 2>&1 &
    FRONTEND_PID_NUM=$!
    
    # Salvar PID
    echo $FRONTEND_PID_NUM > "$FRONTEND_PID"
    
    # Aguardar um pouco para verificar se iniciou
    sleep 2
    
    if kill -0 $FRONTEND_PID_NUM 2>/dev/null; then
        echo -e "${GREEN}Frontend iniciado com sucesso (PID: $FRONTEND_PID_NUM)${NC}"
        echo -e "Acesse: ${BLUE}http://localhost:3005${NC}"
        return 0
    else
        echo -e "${RED}Erro ao iniciar frontend${NC}"
        rm -f "$FRONTEND_PID"
        return 1
    fi
}

# Função para iniciar backend
start_backend() {
    if [ -f "$BACKEND_PID" ] && kill -0 "$(cat $BACKEND_PID)" 2>/dev/null; then
        echo -e "${YELLOW}Backend já está rodando (PID: $(cat $BACKEND_PID))${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Iniciando Backend...${NC}"
    cd "$PROJECT_DIR"
    source venv/bin/activate
    
    # Iniciar em background e capturar PID
    nohup python3 atm-simple.py > "$BACKEND_LOG" 2>&1 &
    BACKEND_PID_NUM=$!
    
    # Salvar PID
    echo $BACKEND_PID_NUM > "$BACKEND_PID"
    
    # Aguardar um pouco para verificar se iniciou
    sleep 2
    
    if kill -0 $BACKEND_PID_NUM 2>/dev/null; then
        echo -e "${GREEN}Backend iniciado com sucesso (PID: $BACKEND_PID_NUM)${NC}"
        echo -e "Monitorando GPIO pino 17"
        return 0
    else
        echo -e "${RED}Erro ao iniciar backend${NC}"
        rm -f "$BACKEND_PID"
        return 1
    fi
}

# Função para parar frontend
stop_frontend() {
    if [ -f "$FRONTEND_PID" ]; then
        PID=$(cat "$FRONTEND_PID")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "${BLUE}Parando Frontend (PID: $PID)...${NC}"
            kill "$PID"
            sleep 2
            
            # Force kill se necessário
            if kill -0 "$PID" 2>/dev/null; then
                echo -e "${YELLOW}Force killing frontend...${NC}"
                kill -9 "$PID"
            fi
            
            rm -f "$FRONTEND_PID"
            echo -e "${GREEN}Frontend parado${NC}"
        else
            echo -e "${YELLOW}Frontend não estava rodando${NC}"
            rm -f "$FRONTEND_PID"
        fi
    else
        echo -e "${YELLOW}Frontend não estava rodando${NC}"
    fi
}

# Função para parar backend
stop_backend() {
    if [ -f "$BACKEND_PID" ]; then
        PID=$(cat "$BACKEND_PID")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "${BLUE}Parando Backend (PID: $PID)...${NC}"
            kill "$PID"
            sleep 2
            
            # Force kill se necessário
            if kill -0 "$PID" 2>/dev/null; then
                echo -e "${YELLOW}Force killing backend...${NC}"
                kill -9 "$PID"
            fi
            
            rm -f "$BACKEND_PID"
            echo -e "${GREEN}Backend parado${NC}"
        else
            echo -e "${YELLOW}Backend não estava rodando${NC}"
            rm -f "$BACKEND_PID"
        fi
    else
        echo -e "${YELLOW}Backend não estava rodando${NC}"
    fi
}

# Função para reiniciar serviços
restart_frontend() {
    stop_frontend
    sleep 1
    start_frontend
}

restart_backend() {
    stop_backend
    sleep 1
    start_backend
}

# Função para mostrar logs
show_logs() {
    case $1 in
        frontend)
            echo -e "${BLUE}=== LOGS FRONTEND ===${NC}"
            if [ -f "$FRONTEND_LOG" ]; then
                tail -n 20 "$FRONTEND_LOG"
            else
                echo "Nenhum log encontrado"
            fi
            ;;
        backend)
            echo -e "${BLUE}=== LOGS BACKEND ===${NC}"
            if [ -f "$BACKEND_LOG" ]; then
                tail -n 20 "$BACKEND_LOG"
            else
                echo "Nenhum log encontrado"
            fi
            ;;
        *)
            echo -e "${BLUE}=== LOGS FRONTEND ===${NC}"
            [ -f "$FRONTEND_LOG" ] && tail -n 10 "$FRONTEND_LOG" || echo "Nenhum log encontrado"
            echo -e "\n${BLUE}=== LOGS BACKEND ===${NC}"
            [ -f "$BACKEND_LOG" ] && tail -n 10 "$BACKEND_LOG" || echo "Nenhum log encontrado"
            ;;
    esac
}

# Função para limpeza
cleanup() {
    echo -e "${BLUE}Limpando arquivos temporários...${NC}"
    rm -f "$FRONTEND_PID" "$BACKEND_PID"
    
    # Matar processos órfãos
    pkill -f "python3 app.py" 2>/dev/null || true
    pkill -f "python3 atm-simple.py" 2>/dev/null || true
    
    echo -e "${GREEN}Limpeza concluída${NC}"
}

# Função para mostrar ajuda
show_help() {
    echo -e "${BLUE}=== CONTROLE ATM BITCOIN LIGHTNING ===${NC}"
    echo
    echo "Uso: $0 [COMANDO]"
    echo
    echo "Comandos disponíveis:"
    echo "  start [frontend|backend]  - Iniciar serviço(s)"
    echo "  stop [frontend|backend]   - Parar serviço(s)"
    echo "  restart [frontend|backend] - Reiniciar serviço(s)"
    echo "  status                    - Mostrar status dos serviços"
    echo "  logs [frontend|backend]   - Mostrar logs"
    echo "  cleanup                   - Limpar PIDs e processos órfãos"
    echo "  help                      - Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 start                  # Inicia ambos os serviços"
    echo "  $0 start frontend         # Inicia apenas o frontend"
    echo "  $0 stop                   # Para ambos os serviços"
    echo "  $0 restart backend        # Reinicia apenas o backend"
    echo "  $0 logs frontend          # Mostra logs do frontend"
    echo
}

# Função principal
main() {
    case $1 in
        start)
            case $2 in
                frontend)
                    start_frontend
                    ;;
                backend)
                    start_backend
                    ;;
                *)
                    start_frontend
                    start_backend
                    ;;
            esac
            ;;
        stop)
            case $2 in
                frontend)
                    stop_frontend
                    ;;
                backend)
                    stop_backend
                    ;;
                *)
                    stop_frontend
                    stop_backend
                    ;;
            esac
            ;;
        restart)
            case $2 in
                frontend)
                    restart_frontend
                    ;;
                backend)
                    restart_backend
                    ;;
                *)
                    restart_frontend
                    restart_backend
                    ;;
            esac
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs $2
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            show_status
            echo
            echo -e "${YELLOW}Use '$0 help' para ver todos os comandos disponíveis${NC}"
            ;;
    esac
}

# Executar função principal
main "$@"