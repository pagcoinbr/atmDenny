const express = require("express");
const cors = require("cors");
const axios = require("axios");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Estado da aplicação
let currentSession = {
  totalAmount: 0,
  notes: [],
  lastPulseTime: null,
};

// Configuração LNbits
const LNBITS_URL = process.env.LNBITS_URL || "https://wallet.br-ln.com";
const LNBITS_API_KEY =
  process.env.LNBITS_API_KEY || "44701baa681845059fc9687bdf3b4c95";

// Mapeamento de pulsos para valores em Reais
const PULSO_PARA_REAL = {
  1: 1.0,
  2: 2.0,
  5: 5.0,
  10: 10.0,
  20: 20.0,
  50: 50.0,
  100: 100.0,
};

// Conversão Real para Satoshis (aproximadamente 1 BRL = 300 sats, ajuste conforme taxa atual)
const BRL_TO_SATS = parseInt(process.env.BRL_TO_SATS) || 300;

/**
 * POST /api/pulsos
 * Recebe pulsos do ESP32 e identifica o valor da nota
 */
app.post("/api/pulsos", (req, res) => {
  const { pulsos } = req.body;

  if (!pulsos || typeof pulsos !== "number") {
    return res.status(400).json({ error: "Número de pulsos inválido" });
  }

  const valorEmReais = PULSO_PARA_REAL[pulsos];

  if (!valorEmReais) {
    console.log(`[AVISO] Quantidade de pulsos não reconhecida: ${pulsos}`);
    return res
      .status(400)
      .json({ error: "Quantidade de pulsos não reconhecida", pulsos });
  }

  // Adiciona à sessão atual
  currentSession.totalAmount += valorEmReais;
  currentSession.notes.push({
    pulsos,
    valor: valorEmReais,
    timestamp: new Date().toISOString(),
  });
  currentSession.lastPulseTime = Date.now();

  console.log(
    `[OK] Nota identificada: R$ ${valorEmReais.toFixed(2)} (${pulsos} pulsos)`
  );
  console.log(
    `[INFO] Total acumulado: R$ ${currentSession.totalAmount.toFixed(2)}`
  );

  res.json({
    success: true,
    valorNota: valorEmReais,
    totalAcumulado: currentSession.totalAmount,
    notas: currentSession.notes,
  });
});

/**
 * GET /api/session
 * Retorna o estado atual da sessão
 */
app.get("/api/session", (req, res) => {
  res.json(currentSession);
});

/**
 * POST /api/reset
 * Reseta a sessão atual
 */
app.post("/api/reset", (req, res) => {
  currentSession = {
    totalAmount: 0,
    notes: [],
    lastPulseTime: null,
  };

  console.log("[INFO] Sessão resetada");
  res.json({ success: true, message: "Sessão resetada" });
});

/**
 * POST /api/withdraw
 * Gera um LNURL-withdraw no LNbits para saque
 */
app.post("/api/withdraw", async (req, res) => {
  try {
    const { amount } = req.body; // Valor em Reais

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: "Valor inválido" });
    }

    // Verifica se há saldo suficiente na sessão
    if (amount > currentSession.totalAmount) {
      return res.status(400).json({
        error: "Saldo insuficiente",
        disponivel: currentSession.totalAmount,
        solicitado: amount,
      });
    }

    // Converte para satoshis
    const amountSats = Math.floor(amount * BRL_TO_SATS);

    console.log(
      `[INFO] Gerando LNURL-withdraw: R$ ${amount.toFixed(
        2
      )} (${amountSats} sats)`
    );

    // Cria o LNURL-withdraw no LNbits
    const response = await axios.post(
      `${LNBITS_URL}/withdraw/api/v1/links`,
      {
        title: `Saque ATM - R$ ${amount.toFixed(2)}`,
        min_withdrawable: amountSats,
        max_withdrawable: amountSats,
        uses: 1,
        wait_time: 1,
        is_unique: true,
      },
      {
        headers: {
          "X-Api-Key": LNBITS_API_KEY,
          "Content-Type": "application/json",
        },
      }
    );

    const withdrawData = response.data;

    // Atualiza a sessão (subtrai o valor sacado)
    currentSession.totalAmount -= amount;

    console.log(`[OK] LNURL-withdraw gerado: ${withdrawData.lnurl}`);
    console.log(
      `[INFO] Saldo restante: R$ ${currentSession.totalAmount.toFixed(2)}`
    );

    res.json({
      success: true,
      lnurl: withdrawData.lnurl,
      id: withdrawData.id,
      amountBRL: amount,
      amountSats: amountSats,
      saldoRestante: currentSession.totalAmount,
      url: `${LNBITS_URL}/withdraw/${withdrawData.id}`,
    });
  } catch (error) {
    console.error(
      "[ERRO] Falha ao gerar LNURL-withdraw:",
      error.response?.data || error.message
    );
    res.status(500).json({
      error: "Falha ao gerar link de saque",
      details: error.response?.data || error.message,
    });
  }
});

/**
 * GET /api/withdraw/:id/status
 * Verifica o status de um withdraw específico
 */
app.get("/api/withdraw/:id/status", async (req, res) => {
  try {
    const { id } = req.params;

    const response = await axios.get(
      `${LNBITS_URL}/withdraw/api/v1/links/${id}`,
      {
        headers: {
          "X-Api-Key": LNBITS_API_KEY,
        },
      }
    );

    res.json({
      success: true,
      used: response.data.used,
      uses: response.data.uses,
      data: response.data,
    });
  } catch (error) {
    console.error(
      "[ERRO] Falha ao verificar status:",
      error.response?.data || error.message
    );
    res.status(500).json({
      error: "Falha ao verificar status",
      details: error.response?.data || error.message,
    });
  }
});

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Inicia o servidor
app.listen(PORT, () => {
  console.log(`=================================`);
  console.log(`🚀 Servidor rodando na porta ${PORT}`);
  console.log(`📡 LNbits: ${LNBITS_URL}`);
  console.log(`💱 Taxa: 1 BRL = ${BRL_TO_SATS} sats`);
  console.log(`=================================`);
});

module.exports = app;
