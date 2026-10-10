# Implementation Plan: MVP de backup completo do iPhone para destino escolhido

**Branch**: `001-iphone-backup-mvp` | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-iphone-backup-mvp/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

App macOS nativo que faz backup completo e incremental do iPhone por cabo para uma pasta escolhida
(local, externa ou SMB montado), na estrutura padrão da Apple. O motor é o `idevicebackup2` da
libimobiledevice rodando como processo filho. Cada execução grava em staging no destino (clone do
último backup válido quando o volume suporta, cópia completa quando não), verifica o manifesto e só
então promove por `rename`, de modo que uma falha nunca destrói o último backup válido.

## Technical Context

**Language/Version**: Swift 6.2 (Xcode 26), modo de linguagem Swift 6

**Primary Dependencies**: SwiftUI, Foundation, IOKit (asserção de energia),
SQLite do sistema; libimobiledevice 1.4.0 (`idevicebackup2`, `idevice_id`,
`ideviceinfo`, `idevicepair`) como executáveis auxiliares. Nenhuma dependência Swift de terceiros.

**Storage**: `state.json` (Codable, escrita atômica) em Application Support; backups no destino do
usuário

**Testing**: XCTest via `swift test` (alvo `PhoneVaultCore`), com motor falso para falhas;
roteiro manual em hardware e SMB ([quickstart.md](quickstart.md))

**Target Platform**: macOS 13 (Ventura)+, Apple Silicon e Intel

**Project Type**: desktop-app (pacote SwiftPM: biblioteca com a lógica + executável SwiftUI)

**Performance Goals**: incremental sem mudanças < 2 min por cabo (SC-002); CPU média < 25%
durante o backup (PRD §6)

**Constraints**: nunca alterar o backup válido in-place; logs sem dados pessoais;
nenhum dado enviado para fora do Mac; fora da Mac App Store (sem sandbox)

**Scale/Scope**: poucos iPhones por Mac, um backup por vez, backups de até ~1 TB; ~6 telas
(assistente, lista, detalhe, progresso, ajustes, erros)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Último backup válido preservado em interrupções, cancelamentos e falhas de destino; validação prévia e verificação após execução planejadas. *(R3, R5, R6; layout do destino)*
- [x] Dados ficam sob controle do usuário; logs sem dados pessoais e telemetria opt-in previstos. *(R10; sem telemetria no MVP)*
- [x] Estados de falha/verificação e limites de retomada e restauração comunicados sem promessas não validadas. *(RunState; R4 sem retomada; Finder não prometido)*
- [x] Testes de sucesso e falha definidos; validação em iPhone real, versões de iOS e SMB prevista quando aplicável. *(R13; quickstart)*
- [x] Escopo da fase, acessibilidade, localização e distribuição alinhados ao PRD; exceções justificadas abaixo. *(MVP sem Wi-Fi/agendamento; pt-BR/en-US (FR-018) e VoiceOver no escopo; assinatura/notarização e binários universais na fase 3, ver Complexity Tracking)*

**Pós-desenho (Fase 1)**: reavaliado após data-model e contratos — continua passando. O estado
`verified` só é alcançável via `verifying`, e o layout mantém staging e previous no mesmo volume.

## Project Structure

### Documentation (this feature)

```text
specs/001-iphone-backup-mvp/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── backup-engine.md
│   └── destination-layout.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
Package.swift                   # um pacote: PhoneVaultCore (lib) + PhoneVault (app executável)
Sources/
├── PhoneVaultCore/             # toda a lógica testável
│   ├── Engine/                 # DeviceEngine, processo idevice*, parser de progresso
│   ├── Destination/            # validação, clone/cópia, staging, promoção, reconciliação
│   ├── Verification/           # plists e Manifest.db
│   ├── Backup/                 # BackupCoordinator (máquina de estados RunState)
│   ├── Store/                  # state.json
│   ├── System/                 # asserção de energia, logging
│   └── Resources/TestedIOSVersions.plist
└── PhoneVault/                 # app SwiftUI (só interface)
    ├── PhoneVaultApp.swift
    ├── Views/                  # assistente, lista, detalhe, progresso, erros
    └── Resources/Localizable.strings (en.lproj e pt-BR.lproj)   # en (en-US, reserva) e pt-BR; FR-018
Tests/PhoneVaultCoreTests/
├── Fixtures/                   # backups pequenos e falsos, saída de progresso
└── fake-engine.sh              # executável falso do motor
scripts/make-app.sh             # swift build -c release + monta PhoneVault.app (Info.plist, Helpers)
```

**Structure Decision**: Um único pacote SwiftPM com dois alvos. Toda regra de backup, destino e
verificação fica em `PhoneVaultCore` para rodar com `swift test` sem interface nem iPhone. O app é
um executável SwiftUI empacotado em `.app` por `scripts/make-app.sh`, sem projeto Xcode gerado à
mão. shortcut: bundle montado por script; migrar para projeto Xcode na fase 3 se assinatura e
notarização exigirem.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Executáveis auxiliares de terceiros (libimobiledevice) | Único caminho viável para MobileBackup2 fora do Finder (PRD §2) | Implementar o protocolo do zero levaria meses; vincular a biblioteca acopla crashes ao app |
| Assinatura, notarização e binário universal adiados para fase 3 | O MVP valida o motor com binários do Homebrew (só arm64); Intel não é validado no MVP | Compilar e embutir universal agora atrasa o protótipo sem afetar o resultado das medições |
