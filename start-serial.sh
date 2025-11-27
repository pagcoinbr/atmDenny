#!/bin/bash

echo "🔍 Detectando ESP32..."

# Verifica se existem dispositivos USB seriais
if ls /dev/ttyUSB* 1> /dev/null 2>&1; then
    echo "📡 Encontrado(s) dispositivo(s) ttyUSB:"
    ls -la /dev/ttyUSB*
    PORTA=$(ls /dev/ttyUSB* | head -1)
elif ls /dev/ttyACM* 1> /dev/null 2>&1; then
    echo "📡 Encontrado(s) dispositivo(s) ttyACM:"
    ls -la /dev/ttyACM*
    PORTA=$(ls /dev/ttyACM* | head -1)
else
    echo "❌ Nenhum dispositivo serial encontrado!"
    echo "   Verifique se o ESP32 está conectado via USB"
    exit 1
fi

echo "✅ Usando porta: $PORTA"

# Instala dependências se necessário
echo "📦 Instalando dependências seriais..."
cd /home/pagcoin/atmDenny/api-server
npm install

# Exporta variáveis de ambiente
export SERIAL_PORT="$PORTA"
export API_URL="http://localhost:3001"

echo ""
echo "🚀 Iniciando Serial Bridge..."
echo "   Porta Serial: $SERIAL_PORT"
echo "   API URL: $API_URL"
echo ""
echo "Para parar: Ctrl+C"
echo "=============================="

# Inicia o bridge serial
node ../serial-bridge.js