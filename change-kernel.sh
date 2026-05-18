GREEN='\033[0;32m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() {
  echo -e "${GREEN}$1${NC}"
}

error() {
  echo -e "${RED}$1${NC}" >&2
}

# --- Banner ---
echo -e "${MAGENTA}"
echo " .d8888b.                                 .d8888b.                    888          "
echo "d88P  Y88b                               d88P  Y88b                   888          "
echo "888    888                               Y88b.                        888          "
echo "888         .d88b.  888d888 .d88b.        \"Y888b.    .d8888b  8888b.  888  .d88b.  "
echo "888        d88\"\"88b 888P\"  d8P  Y8b          \"Y88b. d88P\"        \"88b 888 d8P  Y8b "
echo "888    888 888  888 888    88888888            \"888 888      .d888888 888 88888888 "
echo "Y88b  d88P Y88..88P 888    Y8b.          Y88b  d88P Y88b.    888  888 888 Y8b.     "
echo " \"Y8888P\"   \"Y88P\"  888     \"Y8888        \"Y8888P\"   \"Y8888P \"Y888888 888  \"Y8888  "
echo ""
echo -e "${NC}"

log "Kernel atual: $(uname -r)"

log "Instalando kernel generic..."
sudo apt install -y linux-generic linux-image-generic linux-headers-generic

log "Verificando instalação do kernel generic..."
kernel_ok=true

for pkg in linux-generic linux-image-generic linux-headers-generic; do
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
    error "Erro: pacote $pkg não está instalado."
    kernel_ok=false
  fi
done

if ! dpkg -l | grep -qE '^ii\s+linux-image-[0-9].+-generic'; then
  error "Erro: imagem do kernel generic (linux-image-*-generic) não encontrada."
  kernel_ok=false
fi

if ! dpkg -l | grep -qE '^ii\s+linux-headers-[0-9].+-generic'; then
  error "Erro: headers do kernel generic (linux-headers-*-generic) não encontrados."
  kernel_ok=false
fi

if [ "$kernel_ok" = false ]; then
  error "Instalação do kernel generic falhou. Abortando."
  exit 1
fi

log "Kernel generic instalado com sucesso:"
dpkg -l | grep -E "linux-image.*generic|linux-headers.*generic"

SUBMENU_ID=$(awk "/submenu 'Advanced options for Ubuntu'/"'{print $(NF-1)}' /boot/grub/grub.cfg | cut -d"'" -f2 | head -n1)
KERNEL_ID=$(awk "/menuentry 'Ubuntu, with Linux .*generic'/"'{print $(NF-1)}' /boot/grub/grub.cfg | cut -d"'" -f2 | head -n1)
log "GRUB_DEFAULT: $SUBMENU_ID>$KERNEL_ID"

log "Alterando o kernel padrão no GRUB..."
sudo cp /etc/default/grub.d/50-cloudimg-settings.cfg /etc/default/50-cloudimg-settings.cfg.bk
echo "GRUB_DEFAULT="$SUBMENU_ID>$KERNEL_ID"" | sudo tee /etc/default/grub.d/50-cloudimg-settings.cfg

log "Conteúdo do arquivo grub.cfg:"
cat /etc/default/grub.d/50-cloudimg-settings.cfg

log "Atualizando o GRUB..."
sudo update-grub

echo -e "${GREEN}Reiniciar o sistema agora? Digite 'yes' para confirmar:${NC} "
read -r confirm
if [ "$confirm" != "yes" ]; then
  log "Reinício cancelado."
  exit 0
fi

log "Reiniciando o sistema..."
sudo reboot
