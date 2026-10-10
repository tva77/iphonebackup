---

description: "Task list para restaurar o último backup verificado no iPhone"

---

# Tasks: Restaurar backup no iPhone

**Input**: Design documents from `/specs/002-restore-backup/`

**Prerequisites**: plan.md, spec.md (Clarifications incluídas), research.md, data-model.md, contracts/restore-engine.md, quickstart.md

**Tests**: Obrigatórios (constituição IV): sucesso, falha, interrupção e preservação da origem, escritos antes da implementação e falhando. Validação em iPhone real é manual (quickstart) e exige autorização explícita, pois a restauração substitui os dados do aparelho.

**Organization**: Tarefas agrupadas por história. Caminhos relativos à raiz do repositório. Lógica em `Sources/PhoneVaultCore`, interface em `Sources/PhoneVault`, testes em `Tests/PhoneVaultCoreTests`. Rodar com `swift test`.

## Format: `[ID] [P?] [Story] Descrição`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência)
- **[Story]**: US1 (restaurar), US2 (proteção contra falhas), US3 (pré-condições)

---

## Phase 1: Setup (Shared Infrastructure)

Nenhuma tarefa: o pacote SwiftPM, os alvos de teste e o `fake-engine.sh` já existem (feature 001).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Modelos, motor, parser e origem verificável, usados por todas as histórias

- [X] T001 [P] Adicionar `RunKind.restore`, `RunState.restoring` e as razões `restoreIncomplete`, `restoreRefused`, `protocolMismatch` em `Sources/PhoneVaultCore/Store/Models.swift`
- [X] T002 [P] Adicionar a mensagem de cada razão nova em `Sources/PhoneVaultCore/Backup/FailureReason+Message.swift` e as chaves em `Sources/PhoneVaultCore/Resources/{en,pt}.lproj/Localizable.strings` (causa e ação, FR-010)
- [X] T003 Adicionar `restore(udid:from:copy:)` ao protocolo e a `LibimobiledeviceEngine` em `Sources/PhoneVaultCore/Engine/DeviceEngine.swift`: `idevicebackup2 -u <udid> restore [--copy] <parentDir>`, `copy` padrão `false`, sem `--system`, `--settings`, `--remove`, `--password` ou `--skip-apps` (contrato)
- [X] T004 [P] Escrever testes que falham para as linhas de restauração em `Tests/PhoneVaultCoreTests/ProgressParserTests.swift`: `Restore Successful.`, `Restore Aborted.`, `Restore Failed (Error Code N).`, `Waiting for passcode`, `backup protocol version mismatch` e erro 211
- [X] T005 Implementar essas linhas em `Sources/PhoneVaultCore/Engine/ProgressParser.swift` para passar nos testes de T004 (formato de progresso da restauração ainda não medido, R5: manter o parser do backup e ajustar na validação)
- [X] T006 [P] Adicionar modos de restauração em `Tests/PhoneVaultCoreTests/fake-engine.sh`: sucesso, abortado, recusa com 211, versão incompatível, saída 0 sem `Restore Successful.`, desconexão no meio
- [X] T007 [P] Escrever testes que falham em `Tests/PhoneVaultCoreTests/OriginSnapshotTests.swift`: a assinatura muda quando um arquivo muda de tamanho, data ou conteúdo dos quatro arquivos de topo, e fica igual quando nada muda
- [X] T008 Implementar `OriginSnapshot` em `Sources/PhoneVaultCore/Verification/OriginSnapshot.swift`: contagem, tamanho e data de modificação de todos os arquivos, mais SHA-256 de `Info.plist`, `Status.plist`, `Manifest.plist` e `Manifest.db` (Clarifications da spec)

**Checkpoint**: Modelos, motor, parser, fake engine e verificação da origem prontos

---

## Phase 3: User Story 1 - Restaurar o último backup verificado (Priority: P1) 🎯 MVP

**Goal**: Restaurar o último backup verificado para o mesmo aparelho, com confirmação explícita, progresso e sucesso só após confirmação do motor

**Independent Test**: Com fake engine no modo sucesso, a restauração termina em `verified` somente após `Restore Successful.` e saída 0; `lastValidBackup` não muda; a origem fica igual antes e depois

### Tests for User Story 1 (required)

> **NOTE: Escrever antes da implementação e confirmar que falham**

- [X] T009 [P] [US1] Teste de sucesso em `Tests/PhoneVaultCoreTests/RestoreTests.swift`: `verified`, `lastValidBackup` inalterado e origem igual antes e depois (FR-001, FR-004, FR-006)
- [X] T010 [P] [US1] Teste em `Tests/PhoneVaultCoreTests/RestoreTests.swift`: saída 0 sem `Restore Successful.` vira falha, nunca sucesso; origem alterada gera aviso de falha (FR-004, FR-006)

### Implementation for User Story 1

- [X] T011 [US1] Implementar `restore(udid:options:onUpdate:)` em `Sources/PhoneVaultCore/Backup/BackupCoordinator.swift`: `validating → preparing → restoring → verified`, com `BackupVerifier.verify` antes, `OriginSnapshot` antes e depois, `PowerAssertion` durante a execução, sem staging nem promoção
- [X] T012 [US1] Adicionar textos da confirmação ("os dados atuais do aparelho serão substituídos") em `Sources/PhoneVaultCore/Resources/{en,pt}.lproj/Localizable.strings` e `Sources/PhoneVault/Resources/{en,pt}.lproj/Localizable.strings` (FR-002, FR-010)
- [X] T013 [US1] Adicionar a ação de restauração em `Sources/PhoneVault/AppModel.swift`, chamando o coordenador
- [X] T014 [US1] Adicionar botão Restaurar no detalhe e alerta de confirmação em `Sources/PhoneVault/Views/MainView.swift`

**Checkpoint**: US1 funciona com motor falso: restauração feliz com confirmação e origem preservada

---

## Phase 4: User Story 2 - Proteção contra falhas durante a restauração (Priority: P1)

**Goal**: Falhas, desconexões e cancelamentos geram resultado claro, aviso de dados parciais quando aplicável e nova tentativa; o backup de origem continua verificável

**Independent Test**: Com fake engine nos modos de desconexão e cancelamento, o app informa `restoreIncomplete`, a origem fica igual e a nova tentativa é oferecida

### Tests for User Story 2 (required)

- [X] T015 [P] [US2] Teste de desconexão no meio em `Tests/PhoneVaultCoreTests/RestoreTests.swift`: `restoreIncomplete`, origem igual, nova tentativa possível (FR-005, SC-002)
- [X] T016 [P] [US2] Teste de cancelamento em `Tests/PhoneVaultCoreTests/RestoreTests.swift`: motor interrompido, `restoreIncomplete` e resultado informado (FR-008)

### Implementation for User Story 2

- [X] T017 [US2] Mapear falhas em `Sources/PhoneVaultCore/Backup/BackupCoordinator.swift`: falha após o primeiro evento `.progress` do motor vira `restoreIncomplete`; recusa ou falha antes desse evento (211) vira `restoreRefused`; desconexão via `DeviceMonitor` vira `restoreIncomplete`; o log de restauração não contém nomes de arquivos do backup nem saída bruta do motor (Princípio II)
- [X] T018 [US2] Garantir o encerramento do motor no cancelamento: SIGINT, 10 s, depois SIGTERM, em `Sources/PhoneVaultCore/Engine/ProcessRunner.swift` (reusar o que já existe para o backup)
- [X] T019 [US2] Adicionar cancelamento e resultado final (incluindo "dados parciais" e "tentar de novo") em `Sources/PhoneVault/Views/BackupProgressView.swift` e `Sources/PhoneVault/AppModel.swift`

**Checkpoint**: US1 e US2 funcionam: falhas e cancelamentos não deixam dúvida sobre o resultado

---

## Phase 5: User Story 3 - Pré-condições claras antes de começar (Priority: P2)

**Goal**: Bloquear a restauração antes de qualquer escrita quando faltar pré-condição, com causa e ação; exigir confirmação extra para iOS fora da lista testada

**Independent Test**: Cada pré-condição faltando (sem backup, sem confiança, destino indisponível, operação em andamento, iOS não testado) bloqueia a ação sem chamar o motor

### Tests for User Story 3 (required)

- [X] T020 [P] [US3] Testes em `Tests/PhoneVaultCoreTests/RestoreTests.swift`: sem backup verificado, não pareado, destino indisponível e operação em andamento bloqueiam sem chamar o motor (FR-003, SC-003)
- [X] T021 [P] [US3] Testes em `Tests/PhoneVaultCoreTests/RestoreTests.swift`: iOS fora de `TestedIOSVersions.plist` exige confirmação extra (FR-009); `backup protocol version mismatch` vira `protocolMismatch`

### Implementation for User Story 3

- [X] T022 [US3] Implementar as pré-condições em `Sources/PhoneVaultCore/Backup/BackupCoordinator.swift`, reusando `DestinationValidator`, `BackupVerifier`, `DeviceEngine.pairingState` e `TestedIOSVersions.plist`; `busy` impede backup e restauração simultâneos no mesmo aparelho (FR-007)
- [X] T023 [US3] Desabilitar o botão Restaurar com o motivo em `Sources/PhoneVault/Views/MainView.swift` e exigir confirmação extra para iOS não testado; textos em `Sources/PhoneVault/Resources/{en,pt}.lproj/Localizable.strings`

**Checkpoint**: Todas as histórias funcionam de forma independente com motor falso

---

## Phase N: Polish & Cross-Cutting Concerns

- [X] T024 Rodar `swift test --filter Restore` e `swift test`; `LocalizationTests` cobre as chaves novas em pt e en (FR-010)
- [ ] T025 Validação manual em iPhone real (quickstart passos 1 a 7), com autorização explícita por escrito, registrando em `specs/002-restore-backup/validation-log.md`. Bloqueado até a autorização; bloqueia divulgação, não a implementação (gates I e IV do plano)
- [X] T026 [P] Revisar se `BackupVerifier`, `OriginSnapshot` e o fluxo de backup não mudaram comportamento para backups já existentes (regressão do 001)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: bloqueia todas as histórias. T005 depende de T004; T008 depende de T007.
- **US1 (Phase 3)**: depende da Foundational. T011 depende de T001, T003, T008 e de T009/T010 escritos.
- **US2 (Phase 4)**: depende de US1 (mesmo coordenador). T017 depende de T011; T018 é independente.
- **US3 (Phase 5)**: depende de US1. T022 depende de T011.
- **Polish**: depende das histórias desejadas.

### User Story Dependencies

- US1 e US2 são P1 e compartilham `BackupCoordinator.restore`; implementar nesta ordem.
- US3 é P2 e pode ser feita depois de US1, sem bloquear US2.

### Parallel Opportunities

- T001, T002, T004, T006 e T007 mexem em arquivos diferentes.
- T009 e T010 rodam em paralelo; T015 e T016 também.
- T020 e T021 rodam em paralelo.

---

## Implementation Strategy

### MVP (US1 + US2)

Entregar US1 e US2 juntas. US1 sozinha não deve ir para o usuário, porque não trata falhas no meio.

### Incremental

1. Foundational
2. US1 + US2 com motor falso (`swift test --filter Restore`)
3. US3
4. Validação manual em iPhone real (T025), só com autorização

---

## Notes

- [P] = arquivos diferentes, sem dependência
- Nenhuma tarefa escreve em `<dest>/<udid>` além da leitura (contrato 001 e spec FR-006)
- Nenhuma senha vai para argumento de processo (backups sem criptografia; ver AGENTS.md)
- Saída bruta do motor não é logada (mesma regra do backup, R10)
