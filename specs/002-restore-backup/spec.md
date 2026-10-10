# Feature Specification: Restaurar backup no iPhone

**Feature Branch**: `002-restore-backup`

**Created**: 2026-10-10

**Status**: Draft

**Input**: User description: "adicionar feature de restore"

## Roadmap e governança

Esta feature pertence à fase pós-lançamento do PRD (restauração), não ao MVP `001-iphone-backup-mvp`.
A constituição 2.1.0 (Princípio V) prevê a restauração em fase posterior à v1. A v1 continua sem
restauração, e nada desta especificação pode ser prometido ao usuário antes de medido em iPhones reais.

## Clarifications

### Session 2026-10-10

- Q: Como garantir o FR-006 (backup de origem não alterado), já que `--copy` não é confiável? → A: Restaurar sem `--copy`, com verificação do app antes e depois; o app informa se a origem mudou
- Q: Qual nível de verificação da origem antes e depois da restauração? → A: Contagem, tamanho e data de modificação de todos os arquivos, mais SHA-256 de `Info.plist`, `Status.plist`, `Manifest.plist` e `Manifest.db`
- Q: Como tratar o cancelamento durante a restauração? → A: Interromper a restauração em andamento e tratar como falha: dados parciais possíveis, nova tentativa oferecida (detalhes de encerramento do processo ficam no contrato do motor)
- Q: Como tratar Buscar (localização) ativo antes de restaurar? → A: Deixar o motor recusar (erro 211) e mostrar a causa e a ação; nenhuma escrita acontece antes disso

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Restaurar o último backup verificado (Priority: P1)

O usuário escolhe um iPhone que já tem um backup verificado no destino, confirma que quer substituir os
dados atuais do aparelho e acompanha a restauração até o fim, com o resultado informado de forma clara.

**Why this priority**: É o valor central da feature. Sem ela, o backup não serve para recuperar dados.

**Independent Test**: Com um backup verificado de um aparelho, restaurar para esse mesmo aparelho e
confirmar que o aparelho termina com os dados do backup e que o app informa sucesso.

**Acceptance Scenarios**:

1. **Given** um iPhone com backup verificado no destino e o iPhone conectado, **When** o usuário inicia
   a restauração e confirma a substituição dos dados, **Then** o app mostra o progresso e, ao final,
   informa sucesso apenas se o aparelho confirmar a conclusão.
2. **Given** um iPhone com backup verificado, **When** o usuário inicia a restauração, **Then** o app
   exige uma confirmação explícita que informa que os dados atuais do aparelho serão substituídos.
3. **Given** um aparelho sem backup verificado, **When** o usuário tenta restaurar, **Then** a ação
   fica indisponível e o app explica que é preciso fazer um backup primeiro.

---

### User Story 2 - Proteção contra falhas durante a restauração (Priority: P1)

Se a restauração for interrompida (cabo, aparelho bloqueado, falta de energia, cancelamento), o usuário
recebe um resultado claro e o backup de origem permanece intacto e utilizável.

**Why this priority**: Uma restauração interrompida deixa o aparelho em estado parcial. O app não pode
deixar o usuário sem saber o que aconteceu nem sem caminho para tentar de novo.

**Independent Test**: Interromper uma restauração no meio e confirmar que o app informa a falha, que o
backup de origem continua verificável e que uma nova tentativa é oferecida.

**Acceptance Scenarios**:

1. **Given** uma restauração em andamento, **When** o cabo é desconectado, **Then** o app informa que a
   restauração não foi concluída, que o aparelho pode estar com dados parciais e que é preciso tentar de novo.
2. **Given** uma restauração falha, **When** o usuário consulta o backup, **Then** o backup de origem
   continua no estado verificado, sem alteração.
3. **Given** uma restauração em andamento, **When** o usuário cancela, **Then** o app interrompe o motor,
   informa que a restauração não foi concluída, que o aparelho pode estar com dados parciais e oferece nova tentativa.

---

### User Story 3 - Pré-condições claras antes de começar (Priority: P2)

Antes de iniciar, o app verifica as condições necessárias e explica o que falta, sem iniciar uma operação
que vá falhar no meio.

**Why this priority**: Evita tentativas desperdiçadas e reduz o risco de deixar o aparelho em estado parcial.

**Independent Test**: Tentar restaurar com cada pré-condição faltando e confirmar que a ação é bloqueada
com a causa e a ação para resolver.

**Acceptance Scenarios**:

1. **Given** o iPhone bloqueado ou sem confiança no Mac, **When** o usuário tenta restaurar, **Then** o app
   bloqueia a ação e explica o próximo passo.
2. **Given** o recurso de localização do aparelho ativo, **When** o usuário tenta restaurar, **Then** o motor
   recusa antes de gravar nada, o app mostra a causa e explica que o recurso precisa ser desativado no próprio iPhone.
3. **Given** o backup de origem não passa na verificação atual, **When** o usuário tenta restaurar,
   **Then** o app bloqueia a ação e sugere um novo backup.

---

### Edge Cases

- O iPhone é desconectado no meio da restauração: falha limpa, backup de origem intacto (US2).
- O destino do backup está indisponível no início da restauração: a ação é bloqueada antes de tocar no aparelho.
- A restauração termina sem confirmação do aparelho: o app não informa sucesso.
- A versão do iOS do aparelho é diferente da do backup: o app avisa do risco e exige confirmação extra,
  sem prometer compatibilidade não testada.
- O mesmo aparelho recebe um novo backup enquanto a restauração está em andamento: o app não permite as duas operações ao mesmo tempo.
- O Mac entra em repouso durante a restauração: o app impede o repouso, como no backup.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST restaurar somente o último backup verificado de um aparelho para esse mesmo aparelho (mesmo identificador).
- **FR-002**: O sistema MUST exigir confirmação explícita antes de iniciar, informando que os dados atuais do aparelho serão substituídos.
- **FR-003**: O sistema MUST bloquear a restauração quando não houver backup verificado, quando o aparelho não estiver confiável ou bloqueado, quando o destino estiver indisponível ou quando o backup não passar na verificação atual.
- **FR-004**: O sistema MUST informar sucesso somente após o aparelho confirmar a conclusão da restauração.
- **FR-005**: Em falha ou cancelamento, o sistema MUST informar que o aparelho pode estar com dados parciais e oferecer nova tentativa.
- **FR-006**: O sistema MUST NOT alterar o backup de origem durante a restauração. O app MUST verificar a origem antes e depois da restauração e informar se ela mudou, comparando contagem, tamanho e data de modificação de todos os arquivos e SHA-256 de `Info.plist`, `Status.plist`, `Manifest.plist` e `Manifest.db`; a garantia é verificada, não assumida.
- **FR-007**: O sistema MUST impedir restauração e backup simultâneos no mesmo aparelho e impedir o repouso do Mac durante a restauração.
- **FR-008**: O sistema MUST exibir o progresso da restauração e permitir cancelamento com aviso do resultado final.
- **FR-009**: O sistema MUST avisar, com confirmação extra, quando a versão do iOS do aparelho for diferente da do backup.
- **FR-010**: Todos os textos da restauração MUST estar em português (Brasil) e inglês, com inglês como reserva.

### Key Entities *(include if feature involves data)*

- **Restauração**: uma tentativa de restaurar; aparelho, backup de origem, início, duração, resultado e motivo da falha.
- **Backup de origem**: o último backup verificado do aparelho, usado como fonte e nunca alterado pela restauração.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% das restaurações concluídas com sucesso em teste, o aparelho termina com os dados do backup de origem.
- **SC-002**: Em 100% dos testes de interrupção (cabo, cancelamento, bloqueio do aparelho), o app informa falha e o backup de origem permanece verificável.
- **SC-003**: Em 100% dos casos de pré-condição não atendida, a ação é bloqueada antes de alterar o aparelho e a mensagem informa a causa e o próximo passo.
- **SC-004**: Um usuário consegue iniciar uma restauração confirmada em até 3 cliques a partir da lista de aparelhos.
- **SC-005**: A restauração é validada em pelo menos três versões de iOS e dois modelos de iPhone antes de qualquer divulgação.

## Assumptions

- O aparelho de destino é o mesmo de origem; restauração entre aparelhos diferentes fica fora deste recorte.
- O backup de origem é o do MVP, sem criptografia, pois a criptografia está fora do escopo atual.
- O iPhone precisa estar desbloqueado e confiável no Mac; o app nunca contorna pareamento ou senha de bloqueio.
- O recurso Buscar (localização) precisa estar desativado no iPhone; o app não o desativa sozinho.
- A viabilidade técnica de restaurar a partir do formato de backup atual ainda não foi validada; será confirmada no planejamento.
- Restauração não é prometida como compatível com o Finder até ser medida (Princípio III da constituição).
- O MVP não guarda histórico, então só o último backup verificado está disponível para restauração.
- A aprovação do responsável pelo produto para a alteração da constituição (2.1.0) foi dada em 2026-10-10.
