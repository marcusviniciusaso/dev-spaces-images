#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo
echo "────────────────────────────────────────────────────────────────"
echo "                 Validação de Ambiente Python                  "
echo "────────────────────────────────────────────────────────────────"
echo

PYTHON_DIR="$HOME/.python"

# Estrutura base
echo -e "${BLUE}== Estrutura Python ==${NC}"

if [ -d "$PYTHON_DIR/versions" ]; then
  echo -e "${GREEN}Diretório versions encontrado${NC}"
else
  echo -e "${RED}Diretório versions NÃO encontrado${NC}"
  exit 1
fi

echo

# Versões instaladas
echo -e "${BLUE}== Versões instaladas ==${NC}"

if compgen -G "$PYTHON_DIR/versions/*" > /dev/null; then
  for v in $(ls $PYTHON_DIR/versions); do
    echo -e " - ${GREEN}$v${NC}"
  done
else
  echo -e "${RED}Nenhuma versão encontrada${NC}"
fi

echo

# Versão ativa
echo -e "${BLUE}== Versão ativa ==${NC}"

if [ -f "$PYTHON_DIR/current" ]; then
  CURRENT=$(cat $PYTHON_DIR/current)
  echo -e "Ativa: ${GREEN}$CURRENT${NC}"
else
  echo -e "${RED}Arquivo current não encontrado${NC}"
fi

echo

# python3 (comportamento esperado)
echo -e "${BLUE}== python3 ==${NC}"

if command -v python3 >/dev/null 2>&1; then
  echo -e "python3 version : ${GREEN}$(python3 -V 2>&1)${NC}"
  echo -e "python3 path    : $(which python3)"
else
  echo -e "${RED}python3 não encontrado${NC}"
fi

echo

# pip
echo -e "${BLUE}== pip ==${NC}"

if command -v pip >/dev/null 2>&1; then
  echo -e "pip version  : ${GREEN}$(pip --version)${NC}"
  echo -e "pip path     : $(which pip)"
else
  echo -e "${RED}pip não encontrado${NC}"
fi

echo
echo "────────────────────────────────────────────────────────────────"
echo -e "${GREEN}Validação concluída ✅${NC}"
echo