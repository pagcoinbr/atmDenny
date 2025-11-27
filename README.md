# 🏧 ATM Bitcoin Lightning - Sistema Completo

Sistema completo de ATM para converter notas de Real em Bitcoin via Lightning Network usando um noteiro M5 conectado ao ESP32.

## 📋 Visão Geral

Este projeto consiste em três componentes principais:

1. **ESP32 (Noteiro.ino)** - Lê pulsos do noteiro e envia para a API
2. **Backend API (api-server/)** - Processa pulsos e gera LNURL-withdraw no LNbits
3. **Frontend Next.js (frontend-nextjs/)** - Interface para o usuário escanear e sacar

## 🔧 Componentes

### 1. ESP32 + Noteiro M5

O ESP32 está conectado ao noteiro e detecta os pulsos de cada nota inserida.

**Hardware necessário:**

- ESP32 DevKit
- Noteiro M5 (ou similar)
- Conexão: Pino 18 do ESP32 → Fio branco/azul do noteiro

**Configuração (Noteiro.ino):**

```cpp
const char* WIFI_SSID = "SEU_WIFI_SSID";         // ALTERE
const char* WIFI_PASSWORD = "SUA_SENHA_WIFI";    // ALTERE
const char* API_URL = "http://192.168.1.100:3001/api/pulsos"; // IP do servidor
```

**Upload do código:**

```bash
# Use Arduino IDE ou PlatformIO
# Selecione a placa: ESP32 Dev Module
# Porta: /dev/ttyUSB0 (ou similar)
```

### 2. Backend API (Node.js + Express)

Processa os pulsos recebidos do ESP32 e gera links de saque via LNbits.

**Instalação:**

```bash
cd api-server
npm install
```

**Configuração (.env):**

```env
LNBITS_URL=https://wallet.br-ln.com
LNBITS_API_KEY=44701baa681845059fc9687bdf3b4c95
PORT=3001
BRL_TO_SATS=300  # Taxa de conversão: 1 BRL = 300 sats
```

**Iniciar servidor:**

```bash
npm start
# ou para desenvolvimento com hot-reload:
npm run dev
```

**Endpoints disponíveis:**

- `POST /api/pulsos` - Recebe pulsos do ESP32
- `GET /api/session` - Retorna sessão atual
- `POST /api/withdraw` - Gera LNURL-withdraw
- `POST /api/reset` - Reseta sessão
- `GET /api/withdraw/:id/status` - Verifica status do saque

### 3. Frontend Next.js

Interface web moderna para visualizar notas e gerar QR codes de saque.

**Instalação:**

```bash
cd frontend-nextjs
npm install
```

**Configuração (.env.local):**

```env
NEXT_PUBLIC_API_URL=http://localhost:3001
```

**Iniciar desenvolvimento:**

```bash
npm run dev
# Acesse: http://localhost:3000
```

**Build para produção:**

```bash
npm run build
npm start
```

## 🚀 Como Usar

### Passo 1: Iniciar Backend

```bash
cd api-server
npm start
```

Verifique que o servidor está rodando na porta 3001.

### Passo 2: Iniciar Frontend

```bash
cd frontend-nextjs
npm run dev
```

Acesse http://localhost:3000 no navegador.

### Passo 3: Configurar e Carregar ESP32

1. Abra `Noteiro.ino` no Arduino IDE
2. Configure WiFi SSID e senha
3. Configure o IP do servidor API
4. Faça upload para o ESP32

### Passo 4: Usar o ATM

1. Insira notas no noteiro
2. O frontend exibe automaticamente as notas detectadas
3. Clique em "SACAR AGORA"
4. Escaneie o QR code com sua carteira Lightning
5. Receba os satoshis instantaneamente!

## 🔄 Fluxo de Dados

```
[Noteiro M5] → Pulsos → [ESP32] → HTTP POST → [API Backend]
                                                    ↓
                                            [Sessão atualizada]
                                                    ↑
[Frontend] ← Polling (1s) ← GET /api/session ←─────┘
     ↓
[Usuário clica "SACAR"]
     ↓
POST /api/withdraw → [LNbits API] → LNURL-withdraw
     ↓
[QR Code exibido]
     ↓
[Usuário escaneia com carteira Lightning]
     ↓
[Satoshis recebidos! ⚡]
```

## 📊 Mapeamento de Pulsos

| Pulsos | Valor (R$) |
| ------ | ---------- |
| 1      | R$ 1,00    |
| 2      | R$ 2,00    |
| 5      | R$ 5,00    |
| 10     | R$ 10,00   |
| 20     | R$ 20,00   |
| 50     | R$ 50,00   |
| 100    | R$ 100,00  |

> ⚠️ **Importante:** Ajuste o mapeamento de pulsos no arquivo `Noteiro.ino` conforme a configuração do seu noteiro.

## 💡 Conversão BRL → Satoshis

Taxa padrão configurada: **1 BRL = 300 sats**

Para ajustar, altere no `.env` do backend:

```env
BRL_TO_SATS=300
```

## 🔐 Segurança LNbits

O sistema usa LNURL-withdraw com as seguintes características:

- ✅ QR codes de uso único (`uses: 1`)
- ✅ Valor fixo (min = max)
- ✅ Links únicos (`is_unique: true`)
- ✅ Expiração automática após uso

## 🧪 Testando a API LNbits

Teste manual via curl:

```bash
# Criar LNURL-withdraw
curl -X POST https://wallet.br-ln.com/withdraw/api/v1/links \
  -H "X-Api-Key: SUA_CHAVE_API" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Teste Saque",
    "min_withdrawable": 300,
    "max_withdrawable": 300,
    "uses": 1,
    "wait_time": 1,
    "is_unique": true
  }'
```

## 🛠️ Troubleshooting

### ESP32 não conecta ao WiFi

- Verifique SSID e senha
- Certifique-se de que é uma rede 2.4GHz
- Use Serial Monitor (115200 baud) para debug

### Frontend não recebe notas

- Verifique se o backend está rodando
- Confirme o `NEXT_PUBLIC_API_URL` no `.env.local`
- Abra o console do navegador para ver erros

### Erro ao gerar QR code

- Verifique a chave API do LNbits
- Confirme que há saldo na carteira LNbits
- Teste o endpoint manualmente com curl

### Noteiro não detecta notas

- Verifique conexão física: Pino 18 do ESP32
- Ajuste `TEMPO_DEBOUNCE_ISR` e `TEMPO_FIM_PACOTE`
- Use Serial Monitor para ver pulsos em tempo real

## 📦 Dependências

### Backend

- express
- axios
- cors
- dotenv

### Frontend

- next
- react
- tailwindcss
- typescript

### ESP32

- WiFi.h
- HTTPClient.h

## 🎨 Personalização

### Cores do Frontend

Edite `frontend-nextjs/app/page.tsx` e ajuste as classes Tailwind:

```tsx
// Gradiente principal
className = "bg-gradient-to-br from-orange-500 via-yellow-500 to-orange-600";
```

### Taxa de Conversão

Ajuste no backend `.env`:

```env
BRL_TO_SATS=350  # Exemplo: 1 BRL = 350 sats
```

## 📝 Licença

MIT

## 🤝 Contribuindo

Contribuições são bem-vindas! Abra issues ou pull requests.

## ⚡ Lightning Network

Este projeto usa Lightning Network para saques instantâneos e com taxas mínimas.

**Carteiras compatíveis:**

- Phoenix Wallet
- Wallet of Satoshi
- Muun
- BlueWallet
- Zeus

## 📞 Suporte

Para dúvidas ou problemas, abra uma issue no repositório.

---

**Desenvolvido com ⚡ para a comunidade Bitcoin**
