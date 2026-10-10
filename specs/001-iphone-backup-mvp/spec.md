# Feature Specification: MVP de backup completo do iPhone para destino escolhido

**Feature Branch**: `001-iphone-backup-mvp`

**Created**: 2026-10-09

**Status**: Draft

**Input**: User description: "a partir do PRD - Aplicativo macOS de Backup Completo do iPhone.md"

Recorte: Fase 1 (MVP) do roadmap do PRD, cobrindo RF-01 a RF-03, RF-05 a RF-07, RF-10 a RF-17
e RF-25, e os critérios de aceite da seção 15. Agendamento, Wi-Fi, menu bar, notificações,
montagem automática de volumes, staging local, retenção, verificação profunda e restauração
ficam fora deste recorte.

## Clarifications

### Session 2026-10-09

- Q: Como preservar o último backup válido durante um backup incremental? → A: Usar clone/snapshot
  barato do destino quando disponível; senão, cópia completa do backup anterior, avisando o espaço
  necessário.
- Q: O que fazer com versão de iOS não testada? → A: Aviso destacado e confirmação explícita do
  usuário a cada execução para prosseguir.
- Q: Qual formato o backup deve ter no destino? → A: A mesma estrutura do backup padrão da Apple
  (a do Finder); compatibilidade de restauração é testada no protótipo, não prometida na v1.
- Q: Qual o estado padrão da criptografia? → A: Removida do MVP por decisão posterior; ver Assumptions.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Primeiro backup completo em pasta escolhida (Priority: P1)

O usuário conecta o iPhone por cabo, confia no Mac, escolhe uma pasta local, disco externo
ou volume de rede já montado e executa um backup completo, acompanhando o progresso até
ver o resultado da verificação.

**Why this priority**: É o problema central do PRD: o backup padrão só vai para a pasta
fixa do Mac. Sem essa jornada não há produto.

**Independent Test**: Com um iPhone pareado e uma pasta vazia, executar o backup e
confirmar que o backup completo aparece na pasta escolhida e é marcado como verificado.

**Acceptance Scenarios**:

1. **Given** um iPhone desbloqueado conectado por cabo e ainda não pareado, **When** o
   usuário abre o app, **Then** o app orienta a tocar em "Confiar" e inserir o código, e
   após o pareamento exibe nome, modelo, versão do iOS, capacidade e espaço usado.
2. **Given** um iPhone pareado e uma pasta de destino válida, **When** o usuário toca em
   "Fazer backup agora", **Then** o app mostra progresso, velocidade e tempo estimado e,
   ao final, grava o backup completo na pasta escolhida.
3. **Given** um backup que terminou de ser gravado, **When** a verificação de integridade
   termina, **Then** o app exibe o backup como "verificado" ou "falhou", nunca como
   sucesso sem verificação.
4. **Given** o usuário recusou a confiança ou o iPhone está bloqueado, **When** o app
   tenta acessar o dispositivo, **Then** exibe instrução objetiva para desbloquear e
   confiar e não inicia o backup.
5. **Given** um backup que exige o código do iPhone, **When** o iPhone aguarda o código,
   **Then** o app mostra "Digite o código no iPhone" e retoma o progresso após a digitação;
   se o usuário cancelar no iPhone, o app informa "cancelado no iPhone" e o último backup
   válido é mantido.

---

### User Story 2 - Backup não destrói o último backup válido (Priority: P1)

Qualquer falha durante o backup, como cabo desconectado, destino de rede indisponível,
falta de espaço ou cancelamento, termina de forma limpa e deixa intacto o último backup
verificado.

**Why this priority**: A constituição define a integridade do último backup válido como
princípio inegociável; um backup que destrói o anterior é pior que nenhum backup.

**Independent Test**: Com um backup verificado no destino, iniciar um novo backup e
interrompê-lo por cada causa listada; confirmar que o backup anterior continua
verificável e é o exibido como último backup válido.

**Acceptance Scenarios**:

1. **Given** um backup verificado no destino, **When** o cabo é desconectado durante um
   novo backup, **Then** o app encerra com segurança, informa a falha e o backup anterior
   permanece íntegro e verificável.
2. **Given** um backup em andamento, **When** o usuário cancela, **Then** o app
   interrompe sem promover dados parciais e confirma que o backup anterior foi mantido.
3. **Given** o destino de rede deixa de responder, **When** o app detecta a perda,
   **Then** não grava em nenhum outro caminho e informa o que ocorreu.
4. **Given** um backup em andamento, **When** o Mac ficaria inativo, **Then** ele não
   entra em repouso até o backup terminar ou falhar.

---

### User Story 3 - Validação do destino antes de começar (Priority: P2)

Antes de gravar qualquer dado, o app confirma que o destino existe, aceita escrita, tem
espaço suficiente e usa um sistema de arquivos aceitável, e explica o problema quando não.

**Why this priority**: Evita backups que falham na metade e cobre o critério de aceite 5
do PRD, mas depende da jornada principal existir.

**Independent Test**: Selecionar destinos inválidos (somente leitura, cheio, desmontado)
e confirmar que o backup não começa e que a mensagem informa a causa e a ação necessária.

**Acceptance Scenarios**:

1. **Given** um destino com espaço insuficiente, **When** o usuário inicia o backup,
   **Then** o app bloqueia o início e informa quanto espaço falta.
2. **Given** um destino sem permissão de escrita ou indisponível, **When** o usuário
   inicia o backup, **Then** o app bloqueia o início e explica o problema.
3. **Given** dois iPhones pareados, **When** o usuário escolhe destinos diferentes para
   cada um, **Then** cada backup é gravado apenas no destino do seu dispositivo.

---

### User Story 4 - Backup incremental rápido (Priority: P2)

Depois do primeiro backup, as execuções seguintes transferem apenas o que mudou e
terminam visivelmente mais rápido.

**Why this priority**: Torna o uso recorrente viável, mas só faz sentido após o backup
completo funcionar.

**Independent Test**: Executar um segundo backup logo após o primeiro, sem alterações
relevantes no iPhone, e comparar a duração e o volume transferido.

**Acceptance Scenarios**:

1. **Given** um backup verificado no destino, **When** o usuário executa novo backup sem
   alterações relevantes, **Then** o app transfere apenas as mudanças e conclui em menos
   de 2 minutos por cabo.

---

### User Story 5 - Backup criptografado (removida do MVP)

Criptografia fica fora do MVP por decisão do usuário. Esta história e FR-010 a FR-012 não se aplicam.

---

### Edge Cases

- iPhone com iOS em versão ainda não testada: o app avisa de forma destacada e só inicia
  após confirmação explícita; sem confirmação, nada é gravado.
- Destino desmontado entre a escolha e o início do backup: bloqueia e informa, sem
  gravar em pasta local de substituição.
- Espaço que se esgota durante o backup apesar da validação prévia: falha limpa,
  preservando o backup anterior.
- Mac sem energia suficiente ou fechado durante o backup: falha limpa e explicada.
- Retomada impossível após interrupção: o app informa que será preciso iniciar de novo,
  sem prometer retomada.
- Primeiro backup sem nenhum backup anterior a preservar: falha limpa sem deixar dados
  parciais marcados como válidos.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST detectar iPhones conectados por cabo e exibir nome, modelo,
  versão do iOS, capacidade e espaço usado.
- **FR-002**: O sistema MUST guiar o pareamento e tratar recusa de confiança e
  dispositivo bloqueado com instrução objetiva, sem iniciar o backup.
- **FR-003**: Usuários MUST poder escolher a pasta de destino, incluindo disco externo e
  volume de rede já montado, separadamente para cada dispositivo.
- **FR-004**: O sistema MUST validar existência, permissão de escrita, espaço livre e
  tipo de sistema de arquivos antes de gravar; espaço necessário MUST considerar margem
  sobre o último backup ou a capacidade usada no primeiro backup, mais o tamanho de uma
  cópia do backup anterior quando o destino não oferece clone/snapshot.
- **FR-005**: O sistema MUST fazer backup completo na primeira execução e incremental
  nas seguintes para o mesmo dispositivo e destino, gravando na mesma estrutura do backup
  padrão da Apple, sem conversão para formato próprio.
- **FR-006**: Usuários MUST poder iniciar o backup com uma ação e acompanhar progresso,
  velocidade e tempo estimado, com cancelamento seguro.
- **FR-007**: O sistema MUST manter o último backup verificado intacto até que o novo
  backup termine e seja verificado; dados parciais nunca podem ser marcados como válidos.
  A preservação MUST usar clone/snapshot do destino quando disponível; caso contrário, uma
  cópia completa do backup anterior, e o usuário MUST ver o espaço extra exigido antes do início.
- **FR-008**: Em interrupção, o sistema MUST retomar quando possível ou falhar de forma
  limpa e informar que é necessário um novo backup.
- **FR-009**: O sistema MUST impedir o repouso do Mac durante o backup.
- **FR-010 a FR-012**: Removidos do MVP (criptografia fora do escopo).
- **FR-013**: O sistema MUST verificar ao final de cada backup a consistência do índice
  do backup e a presença de todos os arquivos referenciados.
- **FR-014**: O sistema MUST exibir por dispositivo o estado do último backup
  (em andamento, falhou, verificado), com data e destino.
- **FR-015**: O sistema MUST manter logs locais sem conteúdo do backup, nomes de
  arquivos pessoais ou segredos, e nunca enviar dados do backup a terceiros.
- **FR-016**: Mensagens de erro MUST informar a causa e a próxima ação do usuário, com
  suporte a leitor de tela e navegação por teclado.
- **FR-017**: O sistema MUST exibir aviso destacado antes de iniciar um backup com versão
  de iOS não testada e só prosseguir após confirmação explícita do usuário a cada execução.
- **FR-018**: O app MUST ter todos os textos visíveis ao usuário (telas, botões, alertas,
  mensagens de erro e de progresso) em dois idiomas: português (pt-BR) e inglês (en-US). O
  idioma MUST seguir o idioma preferido do macOS; se não for português nem inglês, o app
  usa inglês (en-US).

### Key Entities *(include if feature involves data)*

- **Dispositivo**: iPhone pareado; identificador, nome, modelo, versão do iOS,
  capacidade, espaço usado e destino configurado.
- **Destino**: pasta escolhida para um dispositivo; caminho, tipo (local, externo, rede),
  disponibilidade, permissão e espaço livre.
- **Execução de backup**: tentativa de backup; dispositivo, destino, início, duração,
  volume transferido, tipo (completo ou incremental), resultado e motivo da falha.
- **Backup válido**: último backup verificado de um dispositivo em seu destino; data e
  resultado da verificação.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Um usuário novo conclui a configuração inicial (pareamento e
  destino) em até 5 minutos.
- **SC-002**: Um backup incremental sem alterações relevantes termina em menos de
  2 minutos por cabo.
- **SC-003**: Em 100% dos testes de interrupção (cabo, destino, espaço, cancelamento), o
  último backup válido continua íntegro e verificável.
- **SC-004**: Pelo menos 98% dos backups iniciados em condições normais terminam
  verificados.
- **SC-005**: Em 100% dos testes com destino inválido, o backup é bloqueado antes de
  gravar e a mensagem informa causa e ação.
- **SC-006**: Removido do MVP (criptografia fora do escopo).
- **SC-007**: O MVP é validado em pelo menos três versões de iOS, dois modelos de iPhone,
  destino local e destino de rede.
- **SC-008**: Pelo menos 80% dos participantes do teste concluem o primeiro backup sem
  ajuda externa.
- **SC-009**: 100% dos textos visíveis ao usuário existem em pt-BR e en-US; com o macOS em
  português o app aparece em pt-BR, em inglês ou em outro idioma aparece em en-US.

## Assumptions

- O MVP atende apenas iPhone por cabo; Wi-Fi, iPad e Apple Watch ficam fora do escopo.
- Volumes de rede precisam estar montados pelo usuário; montagem automática vem depois.
- Cada dispositivo mantém um único backup válido por destino; versões históricas e
  retenção ficam para fases posteriores.
- O backup usa a estrutura padrão da Apple; a compatibilidade de restauração pelo Finder
  não é prometida neste recorte e será medida no protótipo técnico, conforme a constituição.
- O backup é iniciado manualmente; agendamento e execução em segundo plano não fazem
  parte deste recorte.
- O critério de aceite 6 do PRD (assinado, notarizado, sem avisos) e o binário universal
  passam para a fase 3 (Polimento e lançamento); a validação do MVP roda o app sem
  assinatura, só em Apple Silicon.
- O idioma segue o macOS, sem seletor dentro do app no MVP (o macOS já permite escolher o
  idioma por app em Ajustes > Geral > Idioma e Região). Inglês é o idioma de reserva
  porque atende mais usuários que não falam português.
- O app depende de o usuário desbloquear e confiar no iPhone; ele nunca contorna
  pareamento ou senha de bloqueio.
- A criptografia do backup está fora do MVP por decisão do usuário: os backups são gravados
  sem criptografia, e não há configuração, senha nem Keychain neste recorte.
