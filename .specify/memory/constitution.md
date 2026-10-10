<!--
Sync Impact Report
- Version change: 2.0.0 → 2.1.0 (MINOR: restauração adicionada como capacidade de fase posterior à v1;
  escopo da v1 inalterado).
- Modified principles: V (inclui a restauração planejada para fase posterior, com as condições de entrega).
- Added sections: none.
- Removed sections: none.
- Templates requiring updates: verificados (spec, plan, tasks); nenhuma alteração necessária.
- Command templates and runtime guidance: none present in the repository.
- Follow-up TODOs: nenhum. Aprovação do responsável pelo produto registrada em 2026-10-10 (pedido
  explícito de adicionar a feature de restauração). Feature 002 atualizada para refletir a nova regra.
- Earlier history: 2.0.0 removeu o requisito de criptografia por decisão do usuário; o PRD ainda
  descreve criptografia como requisito do produto.
-->
# PhoneVault Constitution

## Core Principles

### I. Integridade do último backup válido

Toda execução MUST preservar o último backup verificado até que o novo backup seja concluído e
verificado. Cancelamento, desconexão, falta de espaço e queda do destino MUST terminar sem
promover um backup incompleto nem gravar em outro caminho. O app MUST validar destino,
permissões e espaço antes de escrever e verificar manifesto e arquivos referenciados ao final.
Isso protege a única cópia recuperável do usuário em caso de falha.

### II. Privacidade e segredos por padrão

Dados de backup MUST permanecer sob controle do usuário e não podem ser enviados a terceiros.
Credenciais e segredos MUST ficar apenas no Keychain quando armazenados; logs MUST omitir
conteúdo, nomes de arquivos pessoais e segredos. Telemetria MUST ser desligada por padrão e
exigir consentimento explícito. No MVP os backups são gravados sem criptografia; remover essa
proteção é decisão de escopo, e sua reintrodução MUST preservar este princípio, sem a senha em
argumentos, arquivos ou logs.

### III. Resultados verificáveis, não promessas

O app MUST distinguir backup em andamento, falho e verificado no estado exibido ao usuário.
Integridade básica MUST ser verificada após cada execução e falhas MUST ser registradas e
comunicadas sem sinalizar sucesso. Recursos dependentes do protocolo, como retomada, MUST
indicar quando não são possíveis; compatibilidade de restauração com o Finder MUST ser medida
antes de ser prometida. Isso evita falsa confiança em backups que não podem ser usados.

### IV. Testes de falha e compatibilidade antes da entrega

Mudanças no fluxo de backup MUST ter testes de sucesso e de falha, incluindo interrupção e
preservação do último backup válido. O MVP MUST ser validado em destino local e de rede,
com pelo menos três versões de iOS e dois modelos de iPhone, e com backup inicial
e incremental. Se um cenário não puder ser automatizado, sua validação
manual e resultado MUST ser registrados antes da entrega. Testes em ambiente simulado
não substituem a comunicação real com iPhone e destino de rede.

### V. Escopo explícito e experiência acessível

A v1 MUST focar em backup no macOS, sem afirmar suporte a restauração, extração individual,
iPad ou outras plataformas. Os fluxos de pareamento, erros e agendamento MUST explicar o
próximo passo ao usuário; interfaces entregues MUST suportar VoiceOver e navegação por
teclado, com textos em português (Brasil) e inglês no lançamento. Restringir promessas
reduz riscos operacionais e impede que o usuário confunda backup com restauração.

A restauração é capacidade planejada para fase posterior à v1 (ver `specs/002-restore-backup`).
Ela MUST restaurar somente o último backup verificado para o mesmo aparelho, MUST exigir
confirmação explícita, pois substitui os dados do iPhone, e MUST NOT ser prometida ao usuário
antes de a compatibilidade ser medida em iPhones reais (Princípio III).

## Restrições do Produto

O destino MUST ser escolhido pelo usuário e pode ser uma pasta local, disco externo ou
volume de rede montado; o app não pode depender de links simbólicos em MobileSync nem
burlar proteções do iPhone. A meta de plataforma é macOS 13+ em Apple Silicon e Intel,
com distribuição assinada e notarizada fora da Mac App Store. Dependências usadas no
motor de backup MUST ter suas licenças respeitadas, incluindo as obrigações LGPL da
libimobiledevice. As escolhas entre biblioteca e processo auxiliar, staging local e
snapshots permanecem decisões de protótipo, não imposições desta constituição.

## Fluxo de Entrega

Cada especificação MUST identificar o recorte do roadmap, requisitos do PRD atendidos,
critérios mensuráveis, riscos de perda de dados e dependências ainda não validadas. Cada
plano MUST demonstrar conformidade com os cinco princípios antes da implementação e
revalidá-la após o desenho técnico; exceções exigem justificativa documentada. As tarefas
MUST incluir testes de falha e verificação, validação em hardware/SMB quando aplicável,
e passos de segurança, acessibilidade, localização e distribuição conforme a fase.
Protótipos MUST validar viabilidade antes que decisões técnicas provisórias virem
compromissos de produto.

## Governance

Esta constituição prevalece sobre templates, planos e práticas conflitantes; o PRD
continua sendo a fonte do escopo e de questões em aberto. Alterações MUST registrar
motivação, impacto nos artefatos dependentes e aprovação do responsável pelo produto
antes da adoção. Versões seguem SemVer: MAJOR para remoção ou redefinição incompatível
de princípios, MINOR para novos princípios/seções ou expansão material, PATCH para
clarificações sem mudança normativa. Toda revisão de especificação, plano, tarefas e
entrega MUST verificar conformidade e registrar exceções e sua mitigação; desvios que
afetem integridade ou privacidade MUST ser resolvidos antes da entrega.

**Version**: 2.1.0 | **Ratified**: 2026-10-09 | **Last Amended**: 2026-10-10
