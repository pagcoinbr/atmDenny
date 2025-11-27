#include <Arduino.h>

// --- Configurações de Hardware e Tempo ---
const int PINO_SINAL = 18;           // Pino onde o fio branco/azul está ligado
const int TEMPO_DEBOUNCE_ISR = 50;   // ms (Filtro: ignora ruídos menores que isso)
const int TEMPO_FIM_PACOTE = 300;    // ms (Tempo de silêncio para considerar que a nota acabou)

// --- Variáveis de Interrupção (Voláteis) ---
volatile int contadorPulsos = 0;
volatile unsigned long ultimoTempoInterrupcao = 0;

// --- ISR: Rotina de Interrupção (Roda na RAM) ---
void IRAM_ATTR onPulse() {
  unsigned long tempoAtual = millis();
  
  // FILTRO DE RUÍDO (Debounce de Software)
  // Se o novo pulso chegou muito rápido (menos de 40ms do anterior),
  // é considerado ruído elétrico e ignorado.
  if (tempoAtual - ultimoTempoInterrupcao > TEMPO_DEBOUNCE_ISR) {
    contadorPulsos++;
    ultimoTempoInterrupcao = tempoAtual;
  }
}

void setup() {
  Serial.begin(115200);
  

  pinMode(PINO_SINAL, INPUT_PULLUP);
  
  // Interrupção na descida (quando o noteiro aterra o fio)
  attachInterrupt(digitalPinToInterrupt(PINO_SINAL), onPulse, FALLING);
  
  Serial.println("--- Sistema de Noteiro Iniciado ---");
  Serial.println("Aguardando notas...");
}

void loop() {
  // Verifica se temos pulsos E se já passou o tempo de espera (fim da inserção)
  // A condição (contadorPulsos > 0) impede o bug de processar "zero"
  if (contadorPulsos > 0 && (millis() - ultimoTempoInterrupcao > TEMPO_FIM_PACOTE)) {
    
    // --- Zona Crítica: Ler e Zerar ---
    // Fazemos uma cópia local para liberar a interrupção rapidamente
    int pulsosCapturados = contadorPulsos;
    contadorPulsos = 0;
    
    // --- Processamento ---
    identificarValor(pulsosCapturados);
  }
}

void identificarValor(int pulsos) {
  float valorEmReais = 0.0;

  // Lógica de mapeamento (Ajuste conforme seus testes)
  // Geralmente Noteiros M5 vêm configurados para 1 pulso = 1 Real
  // OU pulsos específicos por nota (Ex: 2 pulsos = R$2, 5 pulsos = R$5)
  
  switch(pulsos) {
    case 1: 
      valorEmReais = 1.00; // Caso raro, mas possível
      break;
    case 2: 
      valorEmReais = 2.00; 
      break;
    case 5: 
      valorEmReais = 5.00; 
      break;
    case 10: 
      valorEmReais = 10.00; 
      break;
    case 20: 
      valorEmReais = 20.00; 
      break;
    case 50: 
      valorEmReais = 50.00; 
      break;
    case 100: 
      valorEmReais = 100.00; 
      break;
    default:
      // Se cair aqui, pode ser erro de leitura ou uma nota nova não mapeada
      Serial.printf("[AVISO] Quantidade de pulsos não reconhecida: %d\n", pulsos);
      return; 
  }

  Serial.println("=================================");
  Serial.printf("Pulsos: %d\n", pulsos);
  Serial.printf("CRÉDITO IDENTIFICADO: R$ %.2f\n", valorEmReais);
  Serial.println("=================================");
  
  // Envia dados estruturados para API via Serial
  enviarDadosSerial(pulsos, valorEmReais);
}

void enviarDadosSerial(int pulsos, float valor) {
  // Envia dados em formato JSON via Serial para API ler
  Serial.println("JSON_START");
  Serial.printf("{\"pulsos\":%d,\"valor\":%.2f,\"timestamp\":%lu}\n", 
                pulsos, valor, millis());
  Serial.println("JSON_END");
  Serial.flush(); // Garante que os dados foram enviados
}