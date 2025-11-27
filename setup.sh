#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🏧 ATM Bitcoin Lightning - Setup Inicial${NC}"
echo "============================================"
echo ""

# Verifica se está no diretório correto
if [ ! -f "atm-coordinator.sh" ]; then
    echo -e "${YELLOW}❌ Execute este script no diretório raiz do projeto!${NC}"
    exit 1
fi

# Cria estrutura de diretórios
echo -e "${BLUE}📁 Criando estrutura de diretórios...${NC}"
mkdir -p logs
mkdir -p backups

# Torna scripts executáveis
echo -e "${BLUE}🔧 Configurando permissões...${NC}"
chmod +x atm-coordinator.sh
chmod +x simulador.sh
chmod +x start-serial.sh

# Instala dependências
echo -e "${BLUE}📦 Instalando dependências...${NC}"
cd api-server && npm install && cd ..
cd frontend-nextjs && npm install && cd ..

# Cria aliases úteis
echo -e "${BLUE}⚡ Criando aliases...${NC}"
PROJECT_DIR=$(pwd)
cat >> ~/.bashrc << EOF

# ATM Bitcoin Lightning - Aliases
alias atm-start="cd ${PROJECT_DIR} && ./atm-coordinator.sh start"
alias atm-stop="cd ${PROJECT_DIR} && ./atm-coordinator.sh stop"
alias atm-restart="cd ${PROJECT_DIR} && ./atm-coordinator.sh restart"
alias atm-status="cd ${PROJECT_DIR} && ./atm-coordinator.sh status"
alias atm-simulate="cd ${PROJECT_DIR} && ./simulador.sh"
alias atm-logs-api="cd ${PROJECT_DIR} && tail -f logs/api.log"
alias atm-logs-frontend="cd ${PROJECT_DIR} && tail -f logs/frontend.log"
alias atm-logs-serial="cd ${PROJECT_DIR} && tail -f logs/serial.log"
EOF

echo -e "${GREEN}✅ Setup concluído!${NC}"
echo ""
echo -e "${BLUE}🚀 Comandos disponíveis:${NC}"
echo "  ./atm-coordinator.sh start    - Inicia todo o sistema"
echo "  ./atm-coordinator.sh stop     - Para todo o sistema"
echo "  ./atm-coordinator.sh restart  - Reinicia todo o sistema"
echo "  ./atm-coordinator.sh status   - Mostra status"
echo "  ./simulador.sh                - Simula notas do ESP32"
echo ""
echo -e "${BLUE}💡 Aliases criados (após recarregar bashrc):${NC}"
echo "  atm-start       - Inicia sistema"
echo "  atm-stop        - Para sistema"
echo "  atm-restart     - Reinicia sistema"
echo "  atm-status      - Status"
echo "  atm-simulate    - Simulador"
echo ""
echo -e "${YELLOW}Para ativar os aliases, execute:${NC}"
echo "  source ~/.bashrc"
echo ""
echo -e "${GREEN}🎯 Para iniciar o sistema agora:${NC}"
echo "  ./atm-coordinator.sh start"