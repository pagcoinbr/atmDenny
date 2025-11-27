#!/bin/bash

echo "=== Simulador de Notas ATM Bitcoin ==="
echo "Escolha uma opção:"
echo "1) Nota de R$ 1,00 (1 pulso)"
echo "2) Nota de R$ 2,00 (2 pulsos)" 
echo "3) Nota de R$ 5,00 (5 pulsos)"
echo "4) Nota de R$ 10,00 (10 pulsos)"
echo "5) Nota de R$ 20,00 (20 pulsos)"
echo "6) Nota de R$ 50,00 (50 pulsos)"
echo "7) Nota de R$ 100,00 (100 pulsos)"
echo "8) Simular várias notas automáticas"
echo "9) Ver sessão atual"
echo "0) Resetar sessão"

read -p "Digite sua opção: " opcao

case $opcao in
    1) curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 1}' ;;
    2) curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 2}' ;;
    3) curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 5}' ;;
    4) curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 10}' ;;
    5) curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 20}' ;;
    6) curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 50}' ;;
    7) curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 100}' ;;
    8) 
        echo "Simulando inserção de várias notas..."
        sleep 1
        echo "Inserindo R$ 10,00..."
        curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 10}'
        sleep 2
        echo -e "\nInserindo R$ 20,00..."
        curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 20}'
        sleep 2
        echo -e "\nInserindo R$ 50,00..."
        curl -X POST http://localhost:3001/api/pulsos -H "Content-Type: application/json" -d '{"pulsos": 50}'
        ;;
    9) curl -X GET http://localhost:3001/api/session ;;
    0) curl -X POST http://localhost:3001/api/reset ;;
    *) echo "Opção inválida!" ;;
esac

echo -e "\n"