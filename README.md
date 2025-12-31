# Teste-Pr-tico-SRE-Pleno
## 🐳Tarefa 1: Containerização & Execução - Decisões Técnicas: Dockerfile

A estratégia de containerização foi focada em segurança, otimização de camadas e confiabilidade para atender aos requisitos de SRE Pleno.

### 1. Imagem Base: Node 20-alpine (Active LTS)
* **Escolha:** Foi utilizada a versão `node:20-alpine`.
* **Justificativa de Tamanho:** O Alpine Linux é uma distribuição minimalista reduzindo assim o tempo de download (pull) e o consumo de storage no cluster.
* **Justificativa de Segurança:** Por conter apenas o essencial para a execução do SO, o Alpine possui menos binários e bibliotecas instaladas. Isso reduz drasticamente a "superfície de ataque", diminuindo o número de vulnerabilidades (CVEs) potenciais que ferramentas de scan podem encontrar.

### 2. Otimização de Build: Multi-Stage e Cache
* **Aproveitamento de Cache:** A cópia dos arquivos `package.json` e `yarn.lock` foi realizada antes da cópia do restante do código fonte. Como o Docker funciona em camadas (layers), isso garante que, se o código mudar mas as dependências não, o Docker reutilize a camada de instalação (cache), acelerando o tempo de build no pipeline CI/CD.
* **Multi-Stage Build:** Foi implementada a separação entre o estágio de construção (build) e o de execução (runtime). O ambiente final contém apenas os artefatos compilados, eliminando compiladores e arquivos fonte, o que garante uma imagem mais leve e segura para o ambiente de stagin.

### 3. Segurança: Usuário Non-Root com ID Fixo
* **Implementação:** Foi criado um grupo e usuário específico (`appuser`) com ID fixo `1001`.
* **Justificativa do ID 1001:** O uso de um UID/GID fixo acima de 1000 é uma convenção de segurança para garantir que o usuário da aplicação não coincida com usuários do sistema host (como o root, que é ID 0). Além disso, IDs fixos facilitam a gestão de permissões de volumes (RBAC) e políticas de segurança do pod (PodSecurityPolicies) no Kubernetes.
* **Privilégios Mínimos:** Rodar o processo como non-root impede que, em caso de invasão da aplicação, o atacante obtenha privilégios administrativos sobre o kernel do nó hospedeiro.

### 4. Execução: Binário Direto vs Gerenciadores
* **Comando:** Foi definido o uso de `CMD ["node", "dist/main.js"]`.
* **Sinais do Sistema:** O Node.js foi configurado como o processo principal (PID 1) para que possa receber sinais de terminação do Kubernetes, como o `SIGTERM`. Gerenciadores como `npm` ou `yarn` costumam "encapsular" o processo, impedindo que os sinais cheguem ao Node, o que inviabilizaria um Graceful Shutdown (desligamento limpo).
* **Determinismo:** O uso do parâmetro `--frozen-lockfile` no build garante que as versões das dependências instaladas sejam exatamente as testadas, evitando desvios entre ambientes.

## ☸️ Tarefa 2: Deployment Kubernetes - Decisões Técnicas: Helm & Kubernetes

A arquitetura de deployment foi projetada para garantir alta disponibilidade, escalabilidade automática e isolamento de recursos, seguindo as melhores práticas de infraestrutura como código.

### 1. Parametrização e Reutilização (Helm)
* **Abstração via Values:** Todos os parâmetros sensíveis e de configuração (portas, caminhos de health check, limites de recursos) foram movidos para o arquivo `values.yaml`. Isso permite que o mesmo chart seja utilizado em diferentes ambientes apenas alterando o arquivo de valores, sem a necessidade de modificar os templates base.
* **Uso de Helpers:** Foi implementado o arquivo `_helpers.tpl` para gerenciar a nomenclatura dos recursos e labels de forma dinâmica. O uso da função `fullname` garante a unicidade dos nomes dentro do cluster, evitando colisões de recursos entre diferentes releases.

### 2. Alta Disponibilidade e Distribuição (Topology Spread Constraints)
* **Estratégia de Espalhamento:** Foi utilizada a funcionalidade de `topologySpreadConstraints` com `maxSkew: 1` e `topologyKey: kubernetes.io/hostname`. 
* **Justificativa:** Diferente de uma afinidade simples, o Spread Constraint garante matematicamente que as réplicas da aplicação sejam distribuídas de forma equilibrada entre os nós disponíveis (`node-01` e `node-02`). O uso de `whenUnsatisfiable: DoNotSchedule` assegura que o cluster não concentre pods em um único nó, mitigando o risco de downtime total em caso de falha de um host físico.

### 3. Resiliência e Ciclo de Vida (PDB e Probes)
* **Pod Disruption Budget (PDB):** Foi implementado um PDB com `minAvailable: 1`. Esta configuração é vital para operações de SRE, pois impede que manutenções automatizadas (como o dreno de um nó) desliguem todas as instâncias da aplicação simultaneamente, garantindo que pelo menos 50% da capacidade esteja sempre ativa.
* **Health Checks Dinâmicos:** As Probes de `liveness` e `readiness` foram parametrizadas para validar a saúde da aplicação em tempo real. A separação entre liveness (reinício do container) e readiness (entrada no balanceador) garante que o tráfego só seja direcionado para pods que completaram seu processo de inicialização.

### 4. Escalabilidade Automática (HPA v2)
* **Métricas Combinadas:** O Horizontal Pod Autoscaler foi configurado para monitorar tanto CPU quanto Memória simultaneamente.
* **Thresholds de Performance:** Foram definidos gatilhos de **70% para CPU** e **75% para Memória**, conforme requisitos técnicos do projeto. Esta abordagem híbrida protege a aplicação contra gargalos de processamento e vazamentos de memória (memory leaks), garantindo que o cluster escale horizontalmente de forma proativa antes da degradação da latência.

### 5. Estratégia de Deploy (Rolling Update)
* **Zero Downtime:** Foi configurada a estratégia `RollingUpdate` com `maxUnavailable: 0`. Isso garante que o Kubernetes nunca remova uma versão antiga da aplicação sem antes ter uma nova versão saudável e pronta para receber tráfego, eliminando quedas de serviço durante atualizações de versão.