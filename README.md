# kernel-change

Script automatizado para instalar o **kernel generic** em instâncias **Ubuntu** (especialmente imagens cloud da AWS) e configurar o **GRUB** para inicializar com esse kernel por padrão.

Útil em cenários de migração (por exemplo, **AWS Application Migration Service**), em que o agente de replicação exige ou recomenda o kernel `generic` em vez do `aws` (ou outro kernel específico da imagem).

---

## O que o script faz

1. Exibe o kernel em execução (`uname -r`)
2. Instala os pacotes:
   - `linux-generic`
   - `linux-image-generic`
   - `linux-headers-generic`
3. **Valida** a instalação (meta-pacotes + pacotes versionados `linux-image-*-generic` e `linux-headers-*-generic`)
4. Localiza no `/boot/grub/grub.cfg` o submenu *Advanced options for Ubuntu* e a entrada do kernel generic
5. Faz backup de `/etc/default/grub.d/50-cloudimg-settings.cfg`
6. Define `GRUB_DEFAULT` para bootar o kernel generic
7. Executa `update-grub`
8. Pergunta se deseja reiniciar — só executa `reboot` se você digitar **`yes`** (exatamente assim)

---

## Requisitos

| Item | Detalhe |
|------|---------|
| SO | Ubuntu (testado em **Ubuntu 24.04** em imagens cloud) |
| Permissões | `sudo` |
| Rede | Acesso aos repositórios `apt` |
| Arquivo GRUB | `/etc/default/grub.d/50-cloudimg-settings.cfg` (presente em imagens **cloud** Ubuntu/AWS) |
| Shell | `bash` |

> **Atenção:** em instalações Ubuntu **desktop** ou sem o arquivo `50-cloudimg-settings.cfg`, o script pode falhar na etapa do GRUB. Nesses casos, ajuste manualmente `/etc/default/grub`.

---

## Execução rápida (sem clonar o repositório)

Ideal para rodar em outra máquina **sem deixar o script no disco** — o conteúdo é baixado e executado via pipe:

```bash
curl -fsSL \
  -H 'Cache-Control: no-cache' \
  "https://raw.githubusercontent.com/ericmelomp/kernel-change/main/change-kernel.sh?t=$(date +%s)" \
  | sudo bash
```

O parâmetro `?t=$(date +%s)` evita cache do CDN e garante a versão mais recente da branch `main`.

### Via SSH (do seu computador para a VM)

```bash
ssh usuario@IP_DA_VM 'curl -fsSL -H "Cache-Control: no-cache" "https://raw.githubusercontent.com/ericmelomp/kernel-change/main/change-kernel.sh?t=$(date +%s)" | sudo bash'
```

### Enviar o script sem salvar arquivo na VM

```bash
ssh usuario@IP_DA_VM 'sudo bash -s' < change-kernel.sh
```

---

## Execução com clone do repositório

```bash
git clone https://github.com/ericmelomp/kernel-change.git
cd kernel-change
sudo bash change-kernel.sh
```

Atualizar e rodar novamente:

```bash
cd kernel-change
git pull
sudo bash change-kernel.sh
```

---

## Confirmação de reinício

Ao final, o script pergunta:

```text
Reiniciar o sistema agora? Digite 'yes' para confirmar:
```

| Entrada | Comportamento |
|---------|----------------|
| `yes` | Reinicia a máquina (`sudo reboot`) |
| Qualquer outra coisa | Cancela o reboot; kernel e GRUB **já foram alterados** |

Você pode reiniciar manualmente depois:

```bash
sudo reboot
```

---

## Arquivos alterados no sistema

| Caminho | Ação |
|---------|------|
| Pacotes `linux-*-generic` | Instalados via `apt` |
| `/etc/default/grub.d/50-cloudimg-settings.cfg` | Sobrescrito com novo `GRUB_DEFAULT` |
| `/etc/default/50-cloudimg-settings.cfg.bk` | Backup do arquivo original |
| `/boot/grub/grub.cfg` | Regenerado por `update-grub` |

O script **não** deixa cópia de si mesmo no servidor quando executado via `curl | bash`.

---

## Verificação após o reboot

```bash
# Kernel em uso (deve conter "generic")
uname -r

# Pacotes generic instalados
dpkg -l | grep -E 'linux-image.*generic|linux-headers.*generic'

# Configuração GRUB aplicada
cat /etc/default/grub.d/50-cloudimg-settings.cfg
```

Exemplo de saída esperada do kernel:

```text
6.8.0-XX-generic
```

---

## Reversão (rollback)

Se precisar voltar ao boot anterior:

```bash
# Restaurar backup do GRUB (se existir)
sudo cp /etc/default/50-cloudimg-settings.cfg.bk /etc/default/grub.d/50-cloudimg-settings.cfg

sudo update-grub
sudo reboot
```

Para remover pacotes do kernel generic (opcional):

```bash
sudo apt remove --purge 'linux-image-*-generic' 'linux-headers-*-generic' linux-generic linux-image-generic linux-headers-generic
sudo update-grub
```

---

## Solução de problemas

### Falha na instalação do kernel

- Verifique conectividade e mirrors do `apt`: `sudo apt update`
- Confira erros: `sudo apt install -y linux-generic linux-image-generic linux-headers-generic`

### `50-cloudimg-settings.cfg` não encontrado

A imagem pode não ser Ubuntu cloud. Edite `/etc/default/grub` manualmente ou adapte o script para o seu layout de GRUB.

### Submenu ou entrada do kernel não encontrados no `grub.cfg`

O script depende dos textos:

- `submenu 'Advanced options for Ubuntu'`
- `menuentry 'Ubuntu, with Linux .*generic'`

Se a imagem usar outro idioma ou estrutura de menu, ajuste as linhas `awk` em `change-kernel.sh` ou configure `GRUB_DEFAULT` manualmente.

### Script interrompido antes do reboot

Kernel e GRUB podem já estar configurados. Reinicie quando conveniente ou valide com os comandos da seção [Verificação após o reboot](#verificação-após-o-reboot).

### Inspecionar o script antes de executar

```bash
curl -fsSL "https://raw.githubusercontent.com/ericmelomp/kernel-change/main/change-kernel.sh?t=$(date +%s)" | less
```

---

## Avisos importantes

- Execute apenas em **máquinas de teste, staging ou servidores** onde a troca de kernel é esperada.
- Há **downtime** no reboot.
- Faça **snapshot/backup** da instância (EBS, AMI, etc.) antes de rodar em produção.
- O script usa `apt install -y` e altera o boot padrão de forma **irreversível** sem o passo de rollback acima.

---

## Estrutura do repositório

```text
kernel-change/
├── change-kernel.sh   # Script principal
└── README.md          # Esta documentação
```

---

## Licença

Uso sob sua própria responsabilidade. Adicione uma licença (MIT, Apache-2.0, etc.) se for distribuir publicamente.
