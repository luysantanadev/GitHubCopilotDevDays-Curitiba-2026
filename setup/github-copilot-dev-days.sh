#!/usr/bin/env bash
set -euo pipefail

# Cores para output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}Informações para configuração da conta Git${NC}"
read -rp "Digite seu nome: " NOME
read -rp "Digite seu e-mail: " EMAIL_RAW
EMAIL="${EMAIL_RAW,,}"  # Converte para minúsculas

# ─── Homebrew ────────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo -e "\n📦 Instalando Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Adiciona Homebrew ao PATH para sessão atual (Apple Silicon e Intel)
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo -e "${GREEN}✅ Homebrew já está instalado.${NC}"
fi

# ─── Pacotes via Homebrew ─────────────────────────────────────────────────────
declare -A BREW_PACKAGES=(
    ["git"]="formula"
    ["gh"]="formula"
    ["nvm"]="formula"
    ["oh-my-posh"]="formula"
    ["dotnet@10"]="cask"          # .NET SDK 10
    ["powershell"]="cask"         # PowerShell (opcional no macOS)
)

echo -e "\n${CYAN}🔧 Instalando pacotes via Homebrew...${NC}"

for pkg in "${!BREW_PACKAGES[@]}"; do
    type="${BREW_PACKAGES[$pkg]}"
    if [[ "$type" == "cask" ]]; then
        if brew list --cask "$pkg" &>/dev/null 2>&1; then
            echo -e "${GREEN}✅ $pkg já está instalado.${NC}"
        else
            echo -e "${YELLOW}📦 Instalando $pkg (cask)...${NC}"
            brew install --cask "$pkg" || echo -e "${RED}⚠️  Falha ao instalar $pkg${NC}"
        fi
    else
        if brew list --formula "$pkg" &>/dev/null 2>&1; then
            echo -e "${GREEN}✅ $pkg já está instalado.${NC}"
        else
            echo -e "${YELLOW}📦 Instalando $pkg...${NC}"
            brew install "$pkg" || echo -e "${RED}⚠️  Falha ao instalar $pkg${NC}"
        fi
    fi
done

# ─── Configurar NVM ───────────────────────────────────────────────────────────
NVM_DIR="$HOME/.nvm"
if [[ -s "$(brew --prefix nvm)/nvm.sh" ]]; then
    export NVM_DIR
    # shellcheck source=/dev/null
    source "$(brew --prefix nvm)/nvm.sh"
fi

# ─── Recarregar PATH com .NET ─────────────────────────────────────────────────
# O .NET instalado via cask adiciona ao PATH automaticamente; garantir para sessão atual
if [[ -d "/usr/local/share/dotnet" ]]; then
    export PATH="$PATH:/usr/local/share/dotnet"
elif [[ -d "/opt/homebrew/opt/dotnet@10/libexec" ]]; then
    export DOTNET_ROOT="/opt/homebrew/opt/dotnet@10/libexec"
    export PATH="$PATH:$DOTNET_ROOT"
fi

# ─── Ferramentas .NET globais ─────────────────────────────────────────────────
DOTNET_TOOLS=(
    "dotnet-reportgenerator-globaltool"
    "dotnet-coverage"
    "dotnet-sonarscanner"
    "dotnet-ef"
    "dotnet-outdated-tool"
)

echo -e "\n${CYAN}🔧 Instalando ferramentas .NET globais...${NC}"
for tool in "${DOTNET_TOOLS[@]}"; do
    if dotnet tool list -g 2>/dev/null | grep -q "$tool"; then
        echo -e "${YELLOW}🔄 Atualizando $tool...${NC}"
        dotnet tool update --global "$tool" || true
    else
        echo -e "${YELLOW}📦 Instalando $tool...${NC}"
        dotnet tool install --global "$tool" || echo -e "${RED}⚠️  Falha ao instalar $tool${NC}"
    fi
done

# Adicionar ferramentas .NET ao PATH
export PATH="$PATH:$HOME/.dotnet/tools"

# ─── Extensões GitHub CLI ─────────────────────────────────────────────────────
echo -e "\n🤖 Instalando extensão Copilot do GitHub Agentic Workflow..."
# https://github.com/github/gh-aw
gh extension install github/gh-aw || echo -e "${RED}⚠️  Falha ao instalar gh-aw${NC}"

echo -e "\n🤖 Instalando extensão GitHub Models..."
# https://docs.github.com/en/github-models/use-github-models/integrating-ai-models-into-your-development-workflow
gh extension install https://github.com/github/gh-models || echo -e "${RED}⚠️  Falha ao instalar gh-models${NC}"

# ─── Configuração global do Git ───────────────────────────────────────────────
echo -e "\n${CYAN}🔧 Configurando Git... (Faça a configuracao do .gitconfig)${NC}"
git config --global init.defaultBranch main
git config --global user.name "$NOME"
git config --global user.email "$EMAIL"

# ─── Oh My Posh ──────────────────────────────────────────────────────────────
echo -e "\n${GREEN}✅ Configurando Oh My Posh${NC}"

echo -e "${GREEN}✅    Instalando a fonte Meslo (via oh-my-posh)${NC}"
oh-my-posh font install meslo || echo -e "${RED}⚠️  Falha ao instalar fonte Meslo${NC}"

# Detecta shell padrão do usuário
SHELL_NAME="$(basename "$SHELL")"
case "$SHELL_NAME" in
    zsh)
        PROFILE_FILE="$HOME/.zshrc"
        OMP_INIT='eval "$(oh-my-posh init zsh --config '"'"'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/1_shell.omp.json'"'"')"'
        ;;
    bash)
        PROFILE_FILE="$HOME/.bashrc"
        OMP_INIT='eval "$(oh-my-posh init bash --config '"'"'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/1_shell.omp.json'"'"')"'
        ;;
    *)
        PROFILE_FILE="$HOME/.profile"
        OMP_INIT='eval "$(oh-my-posh init bash --config '"'"'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/1_shell.omp.json'"'"')"'
        ;;
esac

echo -e "${GREEN}✅    Escrevendo configuração do Oh My Posh em ${PROFILE_FILE}${NC}"

# Evita duplicar a entrada caso o script seja executado mais de uma vez
OMP_MARKER="# oh-my-posh config (github-copilot-dev-days)"
if ! grep -qF "$OMP_MARKER" "$PROFILE_FILE" 2>/dev/null; then
    {
        echo ""
        echo "$OMP_MARKER"
        echo "$OMP_INIT"
        # NVM
        echo 'export NVM_DIR="$HOME/.nvm"'
        echo '[ -s "$(brew --prefix nvm)/nvm.sh" ] && source "$(brew --prefix nvm)/nvm.sh"'
        # .NET tools
        echo 'export PATH="$PATH:$HOME/.dotnet/tools"'
    } >> "$PROFILE_FILE"
    echo -e "${GREEN}✅    Configuração adicionada ao ${PROFILE_FILE}${NC}"
else
    echo -e "${GREEN}✅    Configuração já existe em ${PROFILE_FILE}${NC}"
fi

# ─── Login no GitHub ──────────────────────────────────────────────────────────
echo -e "\n${GREEN}✅    Login no GitHub${NC}"
gh auth login

# ─── Finalização ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}✅ Configuração concluída!${NC}"
echo -e "${CYAN}   Reinicie o terminal ou execute: source ${PROFILE_FILE}${NC}"
