#!/usr/bin/env python3
"""
ATM Bitcoin Lightning - Simple Terminal Version
Counts GPIO pulses from banknote acceptor and generates Lightning QR codes via LNbits
"""

import RPi.GPIO as GPIO
import time
import threading
import requests
import json
import qrcode
import hashlib
from datetime import datetime
import os
import sys
import signal

# Hardware Configuration
PINO_SINAL = 17
TEMPO_DEBOUNCE = 0.1  # 100ms debounce
TIMEOUT_SEM_PULSOS = 3.0  # Timeout after no pulses detected (seconds)

# LNbits Configuration
LNBITS_URL = "https://wallet.br-ln.com"  # Change this to your LNbits URL
LNBITS_ADMIN_KEY = "808edf38d8b7447a94e339ef835ec991"  # Change this to your admin key
LNBITS_WALLET_ID = "ca115665923c443ea28fe1a179d42413"  # Change this to your wallet ID

# API Configuration for local frontend notification
API_ENDPOINT = "http://localhost:3005/api/pulsos"  # Local frontend endpoint

# Note values mapping (pulses -> BRL value)
PULSO_PARA_REAL = {
    2: 2.0,
    5: 5.0,
    10: 10.0,
    20: 20.0,
    40: 40.0,  # Added 40 pulses mapping
    50: 50.0,
    100: 100.0,
    200: 200.0
}

# Global variables
contador_pulsos = 0
ultimo_tempo = 0
ultimo_tempo_pulso = 0  # Track last pulse time for timeout detection
total_sessao = 0.0
notas_sessao = []
processando = False
timer_ativo = None  # Store active timer reference
lock = threading.Lock()
daemon_mode = False  # Flag to control daemon vs interactive mode
shutdown_event = threading.Event()  # Event to signal shutdown

# Exchange rate cache
PRICE_UPDATE_INTERVAL = 300  # Update every 5 minutes
btc_price_brl = 500000.0  # Default BTC price fallback (R$)
last_price_update = 0  # Last price update timestamp

def enviar_pulsos_para_frontend(pulsos, valor_brl=None):
    """Send pulse count to local frontend via POST request"""
    try:
        data = {
            "pulsos": pulsos,
            "timestamp": datetime.now().isoformat(),
            "valor_brl": valor_brl
        }
        
        response = requests.post(API_ENDPOINT, json=data, timeout=5)
        
        if response.status_code == 200:
            print(f"✅ Pulsos enviados para frontend: {pulsos}")
            return True
        else:
            print(f"⚠️ Erro no frontend: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"⚠️ Frontend não disponível: {e}")
        return False
    except Exception as e:
        print(f"⚠️ Erro ao enviar para frontend: {e}")
        return False

def enviar_qrcode_para_frontend(lnurl, valor_brl):
    """Send QR code data to local frontend"""
    try:
        data = {
            "lnurl": lnurl,
            "valor_brl": valor_brl,
            "timestamp": datetime.now().isoformat()
        }
        
        qr_endpoint = API_ENDPOINT.replace('/pulsos', '/qrcode')
        response = requests.post(qr_endpoint, json=data, timeout=5)
        
        if response.status_code == 200:
            print(f"✅ QR code enviado para frontend")
            return True
        else:
            print(f"⚠️ Erro ao enviar QR para frontend: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"⚠️ Frontend não disponível para QR: {e}")
        return False
    except Exception as e:
        print(f"⚠️ Erro ao enviar QR para frontend: {e}")
        return False

def get_btc_price():
    """Get current BTC price in BRL from CoinGecko API"""
    global btc_price_brl, last_price_update
    
    current_time = time.time()
    
    # Check if we need to update the price
    if current_time - last_price_update < PRICE_UPDATE_INTERVAL:
        return btc_price_brl
    
    try:
        print("💱 Atualizando preço do Bitcoin...")
        url = "https://api.coingecko.com/api/v3/simple/price"
        params = {
            "ids": "bitcoin",
            "vs_currencies": "brl"
        }
        
        response = requests.get(url, params=params, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            new_price = float(data["bitcoin"]["brl"])
            
            btc_price_brl = new_price
            last_price_update = current_time
            
            print(f"✅ Preço atualizado: 1 BTC = R$ {btc_price_brl:,.2f}")
            return btc_price_brl
        else:
            print(f"⚠️  Erro na API CoinGecko: {response.status_code}")
            return btc_price_brl
            
    except requests.exceptions.RequestException as e:
        print(f"⚠️  Erro de conexão com CoinGecko: {e}")
        return btc_price_brl
    except Exception as e:
        print(f"⚠️  Erro ao buscar preço: {e}")
        return btc_price_brl

def calculate_sats_from_brl(amount_brl):
    """Calculate satoshis from BRL amount using current BTC price"""
    btc_price = get_btc_price()
    
    # 1 BTC = 100,000,000 satoshis
    sats_per_btc = 100_000_000
    
    # Calculate satoshis
    btc_amount = amount_brl / btc_price
    sats_amount = int(btc_amount * sats_per_btc)
    
    return sats_amount

def setup_gpio():
    """Initialize GPIO configuration"""
    try:
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(PINO_SINAL, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        print("🔧 GPIO configurado - Pino 17 como entrada com pull-up")
        return True
    except Exception as e:
        print(f"❌ Erro ao configurar GPIO: {e}")
        return False

def cleanup_gpio():
    """Clean up GPIO resources"""
    global timer_ativo
    try:
        # Cancel any active timer
        if timer_ativo:
            timer_ativo.cancel()
        GPIO.cleanup()
        print("🧹 GPIO cleanup realizado")
    except:
        pass

def create_lnbits_withdraw(amount_brl):
    """Create withdraw link via LNbits API"""
    try:
        # Check if LNbits is configured
        if LNBITS_URL == "https://your-lnbits-instance.com":
            print("⚠️  LNbits não configurado - gerando QR simulado")
            return create_simulated_withdraw(amount_brl)
        
        # Convert BRL to satoshis using real-time rate
        amount_sats = calculate_sats_from_brl(amount_brl * 0.95)
        
        # LNbits withdraw link creation
        url = f"{LNBITS_URL}/withdraw/api/v1/links"
        headers = {
            "X-Api-Key": LNBITS_ADMIN_KEY,
            "Content-Type": "application/json"
        }
        
        data = {
            "title": f"ATM Withdraw R${amount_brl:.2f}",
            "min_withdrawable": amount_sats,
            "max_withdrawable": amount_sats,
            "uses": 1,
            "wait_time": 1,
            "is_unique": True,
            "webhook_url": "",
            "webhook_headers": "",
            "webhook_body": ""
        }
        
        print(f"🔗 Conectando com LNbits: {url}")
        response = requests.post(url, headers=headers, json=data, timeout=10)
        
        if response.status_code == 201:
            result = response.json()
            return {
                "success": True,
                "lnurl": result["lnurl"],
                "withdraw_id": result["id"],
                "amount_brl": amount_brl,
                "amount_sats": amount_sats
            }
        else:
            print(f"❌ Erro LNbits: {response.status_code} - {response.text}")
            print("🔄 Gerando QR simulado como fallback")
            return create_simulated_withdraw(amount_brl)
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erro de conexão com LNbits: {e}")
        print("🔄 Gerando QR simulado como fallback")
        return create_simulated_withdraw(amount_brl)
    except Exception as e:
        print(f"❌ Erro ao criar withdraw: {e}")
        print("🔄 Gerando QR simulado como fallback")
        return create_simulated_withdraw(amount_brl)

def create_simulated_withdraw(amount_brl):
    """Create a simulated withdraw for testing"""
    amount_sats = calculate_sats_from_brl(amount_brl)
    
    # Generate a fake but valid-looking LNURL
    data_string = f"atm_withdraw_{amount_brl}_{int(time.time())}"
    fake_id = hashlib.md5(data_string.encode()).hexdigest()[:8]
    
    # Create a Lightning invoice-like string for the QR code
    fake_lnurl = f"lnurl1dp68gurn8ghj7mrww4exctnzd9nhxatw9eu8j730d3h82unvwqhhvceh9gm{fake_id}"
    
    return {
        "success": True,
        "lnurl": fake_lnurl,
        "withdraw_id": fake_id,
        "amount_brl": amount_brl,
        "amount_sats": amount_sats,
        "simulated": True
    }

def generate_qr_code(data, filename):
    """Generate and display QR code"""
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=1,  # Smaller for terminal display
            border=2,
        )
        qr.add_data(data)
        qr.make(fit=True)
        
        # Print QR code to terminal with better formatting
        print("\n" + "=" * 50)
        print("📱 QR CODE PARA SAQUE LIGHTNING:")
        print("=" * 50)
        qr.print_ascii(invert=False)
        print("=" * 50)
        
        # Save QR code as image
        img = qr.make_image(fill_color="black", back_color="white")
        img.save(filename)
        print(f"💾 QR Code salvo em: {filename}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erro ao gerar QR code: {e}")
        return False

def gpio_polling_loop():
    """Continuously poll GPIO for pulse detection"""
    global contador_pulsos, ultimo_tempo, ultimo_tempo_pulso, processando, timer_ativo
    
    previous_state = GPIO.input(PINO_SINAL)
    print(f"🔍 Polling iniciado - Estado inicial: {'HIGH' if previous_state else 'LOW'}")
    
    while True:
        try:
            current_state = GPIO.input(PINO_SINAL)
            tempo_atual = time.time()
            
            # Detect falling edge (HIGH -> LOW) = pulse from bill acceptor
            if previous_state == 1 and current_state == 0:
                with lock:
                    # Debounce filter
                    if tempo_atual - ultimo_tempo > TEMPO_DEBOUNCE:
                        contador_pulsos += 1
                        ultimo_tempo = tempo_atual
                        ultimo_tempo_pulso = tempo_atual  # Update last pulse time
                        print(f"🟡 Pulso detectado! Total: {contador_pulsos}")
                        
                        # Cancel previous timer if exists and start new one
                        if timer_ativo:
                            timer_ativo.cancel()
                        
                        # Start/restart timeout to detect end of note insertion
                        if not processando:
                            processando = True
                        
                        timer_ativo = threading.Timer(TIMEOUT_SEM_PULSOS, processar_nota)
                        timer_ativo.start()
            
            previous_state = current_state
            time.sleep(0.01)  # 10ms polling interval
            
        except Exception as e:
            print(f"❌ Erro no polling GPIO: {e}")
            break

def processar_nota():
    """Process detected note after timeout (when pulses stop arriving)"""
    global contador_pulsos, total_sessao, notas_sessao, processando, timer_ativo
    
    print(f"⏱️  Timeout atingido - processando nota...")
    
    with lock:
        if not processando:  # Avoid double processing
            return
            
        pulsos_detectados = contador_pulsos
        contador_pulsos = 0  # Reset counter immediately
        processando = False
        timer_ativo = None  # Clear timer reference
    
    if pulsos_detectados == 0:
        return
    
    print(f"\n📊 Processando nota com {pulsos_detectados} pulsos...")
    
    # Identify note value
    if pulsos_detectados in PULSO_PARA_REAL:
        valor = PULSO_PARA_REAL[pulsos_detectados]
        
        nota = {
            "pulsos": pulsos_detectados,
            "valor": valor,
            "timestamp": datetime.now().isoformat()
        }
        
        notas_sessao.append(nota)
        total_sessao += valor
        
        print("=" * 50)
        print(f"💰 NOTA DETECTADA: R$ {valor:.2f}")
        print(f"📈 Total da sessão: R$ {total_sessao:.2f}")
        print(f"🗓️  Timestamp: {datetime.now().strftime('%H:%M:%S')}")
        print("=" * 50)
        
        # Enviar pulsos para o frontend local
        enviar_pulsos_para_frontend(pulsos_detectados, valor)
        
        # Automatically generate QR code for each note
        print(f"\n⚡ Gerando QR code automaticamente para R$ {valor:.2f}...")
        gerar_saque(valor)
        
        print(f"\n💵 Aguardando próxima nota ou comandos...")
    
    else:
        print(f"⚠️  Quantidade de pulsos não reconhecida: {pulsos_detectados}")
        print(f"💡 Valores válidos: {list(PULSO_PARA_REAL.keys())} pulsos")
        # Don't reset session on unknown pulse count, just continue

def gerar_saque(valor=None):
    """Generate Lightning withdrawal QR code"""
    global total_sessao
    
    if valor is None:
        valor = total_sessao
    
    if valor <= 0:
        print("❌ Nenhum valor disponível para saque")
        return
    
    print(f"\n⚡ Gerando saque Lightning de R$ {valor:.2f}...")
    
    # Create LNbits withdraw link
    resultado = create_lnbits_withdraw(valor)
    
    if resultado["success"]:
        print(f"✅ Saque criado com sucesso!")
        print(f"💰 Valor: R$ {resultado['amount_brl']:.2f} ({resultado['amount_sats']} sats)")
        print(f"🆔 ID: {resultado['withdraw_id']}")
        
        if resultado.get('simulated'):
            print("🎯 MODO SIMULAÇÃO - QR Code de teste")
        
        # Generate and display QR code
        filename = f"saque_{int(time.time())}.png"
        qr_success = generate_qr_code(resultado["lnurl"], filename)
        
        if qr_success:
            print(f"\n🔗 LNURL: {resultado['lnurl']}")
            
            # Enviar QR code para o frontend
            enviar_qrcode_para_frontend(resultado["lnurl"], resultado["amount_brl"])
            
            if resultado.get('simulated'):
                print("\n⚠️  Este é um QR code simulado para testes!")
                print("   Configure LNbits para gerar QR codes reais.")
            else:
                print("\n✅ QR code real gerado via LNbits!")
                print("   Escaneie com sua wallet Lightning!")
        
        # Reset session if full amount was withdrawn
        if valor == total_sessao:
            reset_sessao()
    
    else:
        print(f"❌ Erro ao gerar saque: {resultado.get('error', 'Erro desconhecido')}")

def reset_sessao():
    """Reset current session"""
    global total_sessao, notas_sessao
    total_sessao = 0.0
    notas_sessao = []
    print("🔄 Sessão resetada")

def mostrar_status():
    """Show current session status"""
    print(f"\n📊 STATUS DA SESSÃO:")
    print(f"💰 Total acumulado: R$ {total_sessao:.2f}")
    print(f"📄 Notas detectadas: {len(notas_sessao)}")
    
    if notas_sessao:
        print("📝 Histórico:")
        for i, nota in enumerate(notas_sessao, 1):
            timestamp = datetime.fromisoformat(nota['timestamp']).strftime('%H:%M:%S')
            print(f"  {i}. R$ {nota['valor']:.2f} ({nota['pulsos']} pulsos) - {timestamp}")

def mostrar_ajuda():
    """Show available commands"""
    print("\n📋 COMANDOS DISPONÍVEIS:")
    print("  'status' ou 's'    - Mostrar status da sessão")
    print("  'sacar' ou 'w'     - Gerar saque do valor total")
    print("  'reset' ou 'r'     - Resetar sessão")
    print("  'teste' ou 't'     - Simular nota (para testes)")
    print("  'config'           - Mostrar configurações")
    print("  'preco' ou 'p'     - Atualizar preço do Bitcoin")
    print("  'mapa' ou 'm'      - Adicionar mapeamento de pulsos")
    print("  'ajuda' ou 'h'     - Mostrar esta ajuda")
    print("  'sair' ou 'q'      - Sair do programa")

def atualizar_preco():
    """Force update Bitcoin price"""
    global last_price_update
    last_price_update = 0  # Force update
    price = get_btc_price()
    print(f"💰 Preço atual do Bitcoin: R$ {price:,.2f}")

def mostrar_config():
    """Show current configuration"""
    print(f"\n⚙️  CONFIGURAÇÃO ATUAL:")
    print(f"🔌 GPIO: Pino {PINO_SINAL}")
    print(f"⚡ LNbits URL: {LNBITS_URL}")
    print(f"💰 Preço BTC atual: R$ {btc_price_brl:,.2f}")
    print(f"📊 Última atualização: {datetime.fromtimestamp(last_price_update).strftime('%H:%M:%S') if last_price_update else 'Nunca'}")
    print(f"📋 Valores aceitos: {list(PULSO_PARA_REAL.values())} BRL")
    
    # Show conversion examples
    print(f"\n💱 CONVERSÕES ATUAIS:")
    for valor in [10.0, 50.0, 100.0]:
        sats = calculate_sats_from_brl(valor)
        print(f"  R$ {valor:.2f} = {sats:,} sats")

def adicionar_mapeamento():
    """Add custom pulse mapping for unknown banknote values"""
    print("\n🔧 ADICIONAR NOVO MAPEAMENTO:")
    
    try:
        pulsos = int(input("Quantidade de pulsos detectados: "))
        valor = float(input("Valor da nota em Reais (R$): "))
        
        if pulsos > 0 and valor > 0:
            PULSO_PARA_REAL[pulsos] = valor
            print(f"✅ Mapeamento adicionado: {pulsos} pulsos = R$ {valor:.2f}")
            print(f"📋 Mapeamentos atuais: {PULSO_PARA_REAL}")
        else:
            print("❌ Valores devem ser positivos")
            
    except ValueError:
        print("❌ Digite números válidos")

def simular_nota():
    """Simulate note insertion for testing"""
    global contador_pulsos, processando, timer_ativo
    
    print("\n🎯 SIMULAÇÃO DE NOTA:")
    print("Valores disponíveis:", list(PULSO_PARA_REAL.keys()))
    
    try:
        pulsos = int(input("Digite a quantidade de pulsos: "))
        
        if pulsos in PULSO_PARA_REAL:
            with lock:
                contador_pulsos = pulsos
                processando = True
                # Cancel any existing timer
                if timer_ativo:
                    timer_ativo.cancel()
                # Start immediate processing for simulation
                timer_ativo = threading.Timer(0.1, processar_nota)
                timer_ativo.start()
            
            print(f"🟡 Simulando {pulsos} pulsos...")
        else:
            print(f"❌ Valor {pulsos} pulsos não reconhecido")
            print(f"💡 Use 'mapa' para adicionar novos mapeamentos")
            
    except ValueError:
        print("❌ Digite um número válido")

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    global shutdown_event
    print(f"\n🛑 Sinal recebido: {signum}")
    shutdown_event.set()

def run_daemon():
    """Run in daemon mode - no interactive input"""
    global shutdown_event
    
    print("🤖 Modo daemon ativo - aguardando notas e sinais de shutdown...")
    print("💵 Sistema pronto para detectar notas...")
    
    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    try:
        # Keep running until shutdown signal
        while not shutdown_event.is_set():
            time.sleep(1)
    except Exception as e:
        print(f"❌ Erro no modo daemon: {e}")
    
    print("🛑 Encerrando modo daemon...")

def run_interactive():
    """Run in interactive mode with command input"""
    print("\n🚀 Sistema iniciado! Digite 'ajuda' para ver os comandos.")
    print("💵 Insira uma nota ou use comandos no terminal...\n")
    
    # Main command loop
    try:
        while True:
            comando = input("ATM> ").lower().strip()
            
            if comando in ['sair', 'quit', 'exit', 'q']:
                break
            elif comando in ['ajuda', 'help', 'h']:
                mostrar_ajuda()
            elif comando in ['status', 's']:
                mostrar_status()
            elif comando in ['sacar', 'withdraw', 'w']:
                gerar_saque()
            elif comando in ['reset', 'r']:
                reset_sessao()
            elif comando in ['teste', 'test', 't']:
                simular_nota()
            elif comando == 'config':
                mostrar_config()
            elif comando in ['preco', 'price', 'p']:
                atualizar_preco()
            elif comando in ['mapa', 'map', 'm']:
                adicionar_mapeamento()
            elif comando == '':
                continue
            else:
                print(f"❓ Comando '{comando}' não reconhecido. Digite 'ajuda' para ver os comandos.")
    
    except KeyboardInterrupt:
        print("\n\n🛑 Interrompido pelo usuário")
    except EOFError:
        print("\n\n🛑 EOF detectado - encerrando...")

def main():
    """Main function"""
    global btc_price_brl, last_price_update, daemon_mode
    
    # Check for daemon mode flag
    if len(sys.argv) > 1 and sys.argv[1] == '--daemon':
        daemon_mode = True
    
    print("=" * 60)
    print("    ATM BITCOIN LIGHTNING - VERSÃO TERMINAL SIMPLES")
    print("=" * 60)
    
    if daemon_mode:
        print("🤖 Iniciando em modo daemon (serviço)")
    else:
        print("🖥️  Iniciando em modo interativo")
    
    # Initialize Bitcoin price
    print("🔄 Inicializando preço do Bitcoin...")
    get_btc_price()
    
    # Check LNbits configuration
    if LNBITS_URL == "https://your-lnbits-instance.com":
        print("⚠️  AVISO: Configure suas credenciais LNbits antes de usar!")
        print("   Edite as variáveis no topo do script:")
        print("   - LNBITS_URL")
        print("   - LNBITS_ADMIN_KEY")
        print("   - LNBITS_WALLET_ID")
        print()
    
    # Setup GPIO
    if not setup_gpio():
        print("❌ Erro na inicialização do GPIO - usando modo simulação")
        gpio_disponivel = False
    else:
        gpio_disponivel = True
        print("✅ GPIO inicializado com sucesso")
        
        # Start polling thread instead of interrupts
        print("🔍 Iniciando monitoramento por polling...")
        polling_thread = threading.Thread(target=gpio_polling_loop, daemon=True)
        polling_thread.start()
        print("✅ Monitoramento de pulsos ativo")
    
    try:
        if daemon_mode:
            run_daemon()
        else:
            run_interactive()
    finally:
        cleanup_gpio()
        print("👋 Obrigado por usar o ATM Bitcoin Lightning!")

if __name__ == "__main__":
    main()