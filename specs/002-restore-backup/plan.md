# Implementation Plan: Restaurar backup no iPhone

**Branch**: `002-restore-backup` | **Date**: 2026-10-10 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-restore-backup/spec.md`

## Summary

Adicionar ao app a restauração do último backup verificado de um iPhone para o mesmo aparelho, usando
`idevicebackup2 restore` como processo filho, como o backup já faz. A restauração substitui dados do
aparelho e é a operação mais arriscada do produto: precisa preservar o backup de origem (FR-006),
exigir confirmação explícita e nunca informar sucesso sem a confirmação do motor. A pesquisa mediu R1 e R2
([research.md](research.md)); a decisão de origem está nas Clarifications da spec e depende de validação
manual em iPhone real. Sem divulgação ao usuário até o SC-005 ser atendido (Princípio III).

## Technical Context

**Language/Version**: Swift 6.2 (Xcode 26), modo de linguagem Swift 6

**Primary Dependencies**: SwiftUI, Foundation, IOKit (asserção de energia); libimobiledevice 1.4.0
(`idevicebackup2`, `idevice_id`, `ideviceinfo`, `idevicepair`) como executáveis auxiliares. Nenhuma
dependência Swift de terceiros.

**Storage**: `state.json` em Application Support; backups no destino do usuário (sem alteração de formato)

**Testing**: XCTest via `swift test` (alvo `PhoneVaultCore`), com motor falso para falhas; validação
manual em iPhone real ([quickstart.md](quickstart.md))

**Target Platform**: macOS 13+ (arm64 e Intel), iPhone com iOS na lista testada

**Project Type**: app nativo de desktop com núcleo testável (`PhoneVaultCore`) e interface (`PhoneVault`)

**Performance Goals**: sem meta de tempo definida para a restauração; registrar a duração no quickstart

**Constraints**: nunca alterar o backup de origem; sem sucesso sem confirmação do motor; senhas não se aplicam
(backups sem criptografia); textos em pt-BR e en-US

**Scale/Scope**: um aparelho por vez, um backup por aparelho (último verificado), uma operação por vez no app

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [ ] **I. Integridade do último backup válido**: desenho definido (sem `--copy`, com verificação da origem
  antes e depois, ver Clarifications da spec). Gate aberto até o passo 1 do quickstart passar em iPhone real.
- [x] **II. Privacidade e segredos**: sem senha (backups sem criptografia); logs sem conteúdo do backup
  (R10 do MVP reaproveitado).
- [x] **III. Resultados verificáveis**: sucesso só com `Restore Successful.` e saída 0. A equivalência
  dos dados restaurados não é verificada automaticamente e não será prometida (ver Assumptions da spec).
- [ ] **IV. Testes de falha e compatibilidade**: testes com motor falso definidos; validação em iPhone real
  pendente (depende de autorização explícita, pois é operação destrutiva).
- [x] **V. Escopo explícito**: a constituição 2.1.0 prevê restauração pós-v1; a entrega fica condicionada
  aos gates I e IV antes de qualquer divulgação.

**Resultado**: gates I e IV abertos. Tasks podem começar com motor falso; a validação em iPhone real fecha I e IV antes de divulgação.

## Project Structure

### Documentation (this feature)

```text
specs/002-restore-backup/
├── spec.md
├── plan.md              # este arquivo
├── research.md          # Fase 0
├── data-model.md        # Fase 1
├── quickstart.md        # Fase 1
├── contracts/
│   └── restore-engine.md
└── checklists/requirements.md
```

### Source Code (alterações previstas)

```text
Sources/PhoneVaultCore/
├── Engine/DeviceEngine.swift       # + restore(udid:from:) no protocolo e na implementação
├── Engine/ProgressParser.swift     # + Restore Successful / Restore Aborted / Restore Failed
├── Backup/BackupCoordinator.swift  # + restore(udid:options:onUpdate:), sem staging nem promoção
├── Store/Models.swift              # + RunKind.restore, RunState.restoring, FailureReason novos
└── Backup/FailureReason+Message.swift

Sources/PhoneVault/
├── Views/MainView.swift            # + botão Restaurar no detalhe, alerta de confirmação
├── AppModel.swift                  # + ação de restauração
└── Resources/{en,pt}.lproj/Localizable.strings

Tests/PhoneVaultCoreTests/
├── RestoreTests.swift              # coordenador com motor falso
├── ProgressParserTests.swift       # novas linhas de restore
└── fake-engine.sh                  # modos de restore
```

**Structure Decision**: estender os componentes existentes, sem novo módulo. A restauração reutiliza o
processo filho, o motor, o monitor de desconexão e o aviso de repouso. Não reutiliza staging nem
promoção, porque não grava backup novo.

## Decisões de desenho

- Comando: `idevicebackup2 -u <udid> restore <parentDir>`, sem `--copy` (R1, R2 e Clarifications da spec).
- Origem: verificação antes e depois (contagem, tamanho e data de todos os arquivos; SHA-256 de quatro arquivos de topo).
- Sem `--system`, `--settings` e `--remove`: a restauração trata dados do usuário. `--remove` apagaria
  itens do aparelho que não estão no backup, o que não está na spec e não será ativado por padrão.
- Reinstalação de apps: comportamento padrão da ferramenta, sem flag. Revisar após a medição (R4).
- Reinício: padrão da ferramenta (o aparelho reinicia ao terminar). Mantido.
- Sucesso: linha `Restore Successful.` e saída 0. Qualquer outra saída é falha.

## Complexity Tracking

| Violação | Por que é necessária | Alternativa mais simples rejeitada porque |
|----------|----------------------|-------------------------------------------|
| Gate I aberto até validação manual | A ferramenta pode gravar na pasta de origem | Só a verificação em iPhone real prova que a origem não muda |
| Gate IV aberto até validação em hardware | Testes com motor falso cobrem sucesso, falha e interrupção; compatibilidade real exige aparelhos | Esperar hardware bloquearia toda a implementação |
</content>
