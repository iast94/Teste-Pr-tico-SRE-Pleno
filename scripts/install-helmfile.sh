#!/bin/bash

# Aborta o script se qualquer comando falhar
set -e

HELMFILE_VERSION="v1.2.3"
BIN_PATH="/usr/local/bin/helmfile"

if [ ! -f "$BIN_PATH" ]; then
    echo "Instalando Helmfile ${HELMFILE_VERSION}..."
    
    # Download do binário
    curl -L "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION#v}_linux_amd64.tar.gz" | tar -xz
    
    # Move para o path do sistema
    mv helmfile /usr/local/bin/
    chmod 755 "$BIN_PATH"

    echo "Helmfile instalado com sucesso!"
else
    echo "Helmfile já está instalado. Versão: $(helmfile --version)"
fi

# Instalação do plugin necessário para o comando 'diff' do Helmfile
echo "Garantindo instalação do plugin helm-diff..."
helm plugin install https://github.com/databus23/helm-diff || echo "Plugin já instalado ou erro na instalação."