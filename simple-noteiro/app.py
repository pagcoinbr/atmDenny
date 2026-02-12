#!/usr/bin/env python3
"""
ATM Bitcoin Lightning - Frontend Web Simplista
Recebe pulsos via POST e exibe status com QR code
"""

from flask import Flask, render_template, request, jsonify
import json
import base64
import io
import qrcode
from datetime import datetime

app = Flask(__name__)

# Estado global da aplicação
estado_atual = {
    "status": "aguardando",  # aguardando, sucesso, processando
    "pulsos": 0,
    "valor_brl": 0.0,
    "qr_code": None,
    "timestamp": None,
    "lnurl": None
}

def gerar_qr_base64(data):
    """Gera QR code e retorna como base64 para exibir no HTML"""
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(data)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Converter para base64
        buffer = io.BytesIO()
        img.save(buffer, format='PNG')
        buffer.seek(0)
        
        qr_base64 = base64.b64encode(buffer.getvalue()).decode()
        return f"data:image/png;base64,{qr_base64}"
        
    except Exception as e:
        print(f"Erro ao gerar QR code: {e}")
        return None

@app.route('/')
def index():
    """Página principal"""
    return render_template('index.html', estado=estado_atual)

@app.route('/api/pulsos', methods=['POST'])
def receber_pulsos():
    """Endpoint para receber pulsos do ATM"""
    global estado_atual
    
    try:
        data = request.get_json()
        
        # Atualizar estado
        estado_atual["status"] = "sucesso"
        estado_atual["pulsos"] = data.get("pulsos", 0)
        estado_atual["valor_brl"] = data.get("valor_brl", 0.0)
        estado_atual["timestamp"] = data.get("timestamp")
        estado_atual["qr_code"] = None  # Reset QR code
        estado_atual["lnurl"] = None
        
        print(f"✅ Pulsos recebidos: {estado_atual['pulsos']} (R$ {estado_atual['valor_brl']:.2f})")
        
        return jsonify({"success": True, "message": "Pulsos recebidos"})
        
    except Exception as e:
        print(f"❌ Erro ao processar pulsos: {e}")
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/api/qrcode', methods=['POST'])
def receber_qrcode():
    """Endpoint para receber QR code de saque"""
    global estado_atual
    
    try:
        data = request.get_json()
        
        lnurl = data.get("lnurl")
        valor_brl = data.get("valor_brl", estado_atual["valor_brl"])
        
        if lnurl:
            # Gerar QR code
            qr_base64 = gerar_qr_base64(lnurl)
            
            estado_atual["qr_code"] = qr_base64
            estado_atual["lnurl"] = lnurl
            estado_atual["valor_brl"] = valor_brl
            estado_atual["status"] = "qr_gerado"
            
            print(f"✅ QR Code gerado para R$ {valor_brl:.2f}")
            
            return jsonify({"success": True, "message": "QR code gerado"})
        else:
            return jsonify({"success": False, "error": "LNURL não fornecida"}), 400
            
    except Exception as e:
        print(f"❌ Erro ao processar QR code: {e}")
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/api/reset', methods=['POST'])
def reset():
    """Reset do estado da aplicação"""
    global estado_atual
    
    estado_atual = {
        "status": "aguardando",
        "pulsos": 0,
        "valor_brl": 0.0,
        "qr_code": None,
        "timestamp": None,
        "lnurl": None
    }
    
    print("🔄 Estado resetado")
    return jsonify({"success": True, "message": "Estado resetado"})

@app.route('/api/status')
def get_status():
    """Endpoint para obter status atual (para polling do frontend)"""
    return jsonify(estado_atual)

if __name__ == '__main__':
    print("🚀 Iniciando frontend ATM Bitcoin Lightning...")
    print("📱 Acesse: http://localhost:3005")
    print("🔗 API disponível em: http://localhost:3005/api/pulsos")
    
    app.run(host='0.0.0.0', port=3005, debug=False)