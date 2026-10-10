# Data Model: MVP de backup completo do iPhone

Persistido em `~/Library/Application Support/PhoneVault/state.json` (ver research R11). Segredos
nunca entram neste arquivo.

## Device

| Campo | Tipo | Regra |
| --- | --- | --- |
| udid | String | Identidade única; chave primária |
| name | String | De `ideviceinfo` |
| model | String | Identificador do produto (ex.: `iPhone15,2`) |
| iosVersion | String | Ex.: `18.1` |
| capacityBytes | Int64 | Capacidade total |
| usedBytes | Int64 | Base de espaço para o primeiro backup (R6) |
| destination | Destination? | Um por dispositivo (FR-003) |
| lastValidBackup | ValidBackup? | Só preenchido após verificação aprovada |

Dados como nome e versão são atualizados a cada conexão; o UDID nunca muda.

## Destination

| Campo | Tipo | Regra |
| --- | --- | --- |
| path | String | Pasta escolhida pelo usuário |
| bookmark | Data | Bookmark do URL para achar o volume após remontagem |
| kind | enum `local`, `external`, `network` | Derivado do volume |
| fsType | String | De `statfs`; `msdos` é recusado (R6) |
| supportsClone | Bool? | Medido na validação; `nil` até medir |

Disponibilidade, permissão e espaço livre são calculados na hora da validação e não persistidos.
O backup válido fica em `<path>/<udid>`; staging em `<path>/.phonevault/staging/<udid>`.

## BackupRun

| Campo | Tipo | Regra |
| --- | --- | --- |
| id | UUID | |
| udid | String | Referência ao Device |
| destinationPath | String | Destino no momento da execução |
| kind | enum `full`, `incremental` | `full` se não havia backup válido |
| startedAt / endedAt | Date | |
| bytesTransferred | Int64 | Crescimento medido do staging (o motor não informa bytes) |
| state | RunState | Ver transições abaixo |
| failure | FailureReason? | Obrigatório quando `state == failed` |

### RunState

```text
validating → preparing → backingUp → verifying → promoting → verified
     │            │           │            │           │
     └────────────┴───────────┴────────────┴───────────┴──→ failed
                              └──→ cancelled

backingUp ⇄ waitingForDevice   (motor aguarda o código digitado no iPhone)
```

- Nenhuma transição para `verified` sem passar por `verifying` com sucesso (princípio III).
- `failed` e `cancelled` sempre descartam o staging; `lastValidBackup` não muda (FR-007).
- `preparing` = clone ou cópia do backup válido para o staging.

### FailureReason

`deviceLocked`, `trustDenied`, `deviceDisconnected`, `cancelledOnDevice`, `destinationUnavailable`,
`destinationReadOnly`, `insufficientSpace(missingBytes)`, `unsupportedFileSystem(fsType)`,
`engineCrashed(exitCode)`, `verificationFailed(missingFiles)`,
`untestedIOSNotConfirmed`, `sleepOrPowerLoss`.

Cada razão tem mensagem com causa e ação em pt-BR e en-US (FR-016, FR-018).

## ValidBackup

| Campo | Tipo | Regra |
| --- | --- | --- |
| runID | UUID | Execução que gerou e verificou |
| completedAt | Date | |
| sizeBytes | Int64 | Base de espaço do próximo backup (R6) |

## Relações

- Device 1 → 0..1 Destination, 0..1 ValidBackup, 0..N BackupRun.
- Uma execução por vez em todo o app no MVP (spec: concorrência fora de escopo).
