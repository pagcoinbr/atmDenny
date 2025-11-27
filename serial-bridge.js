const { SerialPort } = require("serialport");
const { ReadlineParser } = require("@serialport/parser-readline");
const axios = require("axios");

// Configurações
const SERIAL_PORT = process.env.SERIAL_PORT || "/dev/ttyUSB0"; // ou /dev/ttyACM0
const BAUD_RATE = 115200;
const API_URL = process.env.API_URL || "http://localhost:3001";

class SerialToAPIBridge {
  constructor() {
    this.isConnected = false;
    this.setupSerial();
  }

  setupSerial() {
    try {
      // Lista portas disponíveis
      SerialPort.list().then((ports) => {
        console.log("Portas seriais disponíveis:");
        ports.forEach((port) => {
          console.log(`- ${port.path} (${port.manufacturer || "Unknown"})`);
        });
      });

      // Conecta à porta serial
      this.port = new SerialPort({
        path: SERIAL_PORT,
        baudRate: BAUD_RATE,
        autoOpen: false,
      });

      this.parser = this.port.pipe(new ReadlineParser({ delimiter: "\n" }));

      // Event handlers
      this.port.on("open", () => {
        console.log(`✅ Conectado à porta serial: ${SERIAL_PORT}`);
        this.isConnected = true;
      });

      this.port.on("error", (err) => {
        console.error(`❌ Erro na porta serial: ${err.message}`);
        this.isConnected = false;
        this.reconnect();
      });

      this.port.on("close", () => {
        console.log("🔌 Porta serial fechada");
        this.isConnected = false;
        this.reconnect();
      });

      // Processa dados recebidos
      this.parser.on("data", (data) => {
        this.processSerialData(data.trim());
      });

      // Abre a conexão
      this.port.open();
    } catch (error) {
      console.error(`❌ Erro ao configurar porta serial: ${error.message}`);
      setTimeout(() => this.setupSerial(), 5000);
    }
  }

  processSerialData(data) {
    console.log(`📡 Recebido: ${data}`);

    // Procura por dados JSON estruturados
    if (data === "JSON_START") {
      this.jsonMode = true;
      return;
    }

    if (data === "JSON_END") {
      this.jsonMode = false;
      return;
    }

    if (this.jsonMode) {
      try {
        const jsonData = JSON.parse(data);
        this.sendToAPI(jsonData);
      } catch (error) {
        console.error(`❌ Erro ao parsear JSON: ${error.message}`);
      }
    }

    // Fallback: detecta padrões conhecidos na saída serial
    if (data.includes("CRÉDITO IDENTIFICADO")) {
      this.parseTraditionalOutput(data);
    }
  }

  parseTraditionalOutput(data) {
    // Extrai valor da string "CRÉDITO IDENTIFICADO: R$ X.XX"
    const match = data.match(/R\$\s*([\d,]+\.?\d*)/);
    if (match) {
      const valor = parseFloat(match[1].replace(",", "."));
      const pulsos = this.valorToPulsos(valor);

      console.log(`💰 Detectado: R$ ${valor.toFixed(2)} (${pulsos} pulsos)`);

      this.sendToAPI({
        pulsos: pulsos,
        valor: valor,
        timestamp: Date.now(),
      });
    }
  }

  valorToPulsos(valor) {
    // Mapeia valor de volta para pulsos
    const mapeamento = {
      1.0: 1,
      2.0: 2,
      5.0: 5,
      10.0: 10,
      20.0: 20,
      50.0: 50,
      100.0: 100,
    };
    return mapeamento[valor] || Math.round(valor);
  }

  async sendToAPI(data) {
    try {
      console.log(`🚀 Enviando para API: ${JSON.stringify(data)}`);

      const response = await axios.post(
        `${API_URL}/api/pulsos`,
        {
          pulsos: data.pulsos,
        },
        {
          headers: { "Content-Type": "application/json" },
          timeout: 5000,
        }
      );

      if (response.data.success) {
        console.log(
          `✅ API confirmou: R$ ${response.data.valorNota.toFixed(2)}`
        );
        console.log(
          `📊 Total acumulado: R$ ${response.data.totalAcumulado.toFixed(2)}`
        );
      }
    } catch (error) {
      console.error(`❌ Erro ao enviar para API: ${error.message}`);
      if (error.response) {
        console.error(`   Status: ${error.response.status}`);
        console.error(`   Dados: ${JSON.stringify(error.response.data)}`);
      }
    }
  }

  reconnect() {
    if (!this.isConnected) {
      console.log("🔄 Tentando reconectar em 5 segundos...");
      setTimeout(() => this.setupSerial(), 5000);
    }
  }

  // Método para listar portas disponíveis
  static async listPorts() {
    try {
      const ports = await SerialPort.list();
      console.log("\n📋 Portas seriais disponíveis:");
      ports.forEach((port) => {
        console.log(`   ${port.path}`);
        if (port.manufacturer)
          console.log(`      Fabricante: ${port.manufacturer}`);
        if (port.vendorId) console.log(`      Vendor ID: ${port.vendorId}`);
        console.log("");
      });
      return ports;
    } catch (error) {
      console.error("❌ Erro ao listar portas:", error.message);
      return [];
    }
  }
}

// Função principal
async function main() {
  console.log("🔗 Serial to API Bridge - Iniciando...");
  console.log(`📡 Porta: ${SERIAL_PORT}`);
  console.log(`🌐 API: ${API_URL}`);
  console.log("=====================================");

  // Lista portas antes de conectar
  await SerialToAPIBridge.listPorts();

  // Inicia o bridge
  const bridge = new SerialToAPIBridge();

  // Graceful shutdown
  process.on("SIGINT", () => {
    console.log("\n🛑 Encerrando...");
    if (bridge.port && bridge.port.isOpen) {
      bridge.port.close();
    }
    process.exit(0);
  });
}

// Executa se for chamado diretamente
if (require.main === module) {
  main();
}

module.exports = SerialToAPIBridge;
