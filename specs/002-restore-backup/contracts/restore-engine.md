# Contrato: motor de restauração

Acréscimo ao contrato do motor do MVP ([001 contracts/backup-engine.md](../../001-iphone-backup-mvp/contracts/backup-engine.md)).

## Protocolo

```swift
protocol DeviceEngine {
    // ... existentes: listDevices, pairingState, pair, info, backup ...
    func restore(udid: String, from parentDir: URL, copy: Bool) -> AsyncThrowingStream<EngineEvent, Error>
}
```

`copy` reflete a decisão de R1/R2: `true` adiciona `--copy`. Padrão `false` (Clarifications da spec).

## Comando

| Ação | Comando | Sucesso |
| --- | --- | --- |
| Restaurar | `idevicebackup2 -u <udid> restore [--copy] <parentDir>` | saída 0 **e** linha `Restore Successful.` |

`parentDir` é o mesmo diretório usado pelo backup (`<parentDir>/<udid>`). Sem flags `--system`,
`--settings`, `--remove`, `--password` e `--skip-apps` (ver plano, decisões de desenho).

## Eventos

| Linha do motor | Evento |
| --- | --- |
| progresso (formato a confirmar, R5) | `.progress(percent:)` |
| `Waiting for passcode` | `.waitingForDevicePasscode` |
| `Restore Successful.` + saída 0 | `.finished` |
| `Restore Aborted.` / `Restore Failed (Error Code N).` | falha `engineCrashed(N)` ou `restoreIncomplete` |
| `backup protocol version mismatch` | `protocolMismatch` |
| recusa antes da gravação (texto a medir, R3) | `restoreRefused` |
| UDID some de `idevice_id -l` | `deviceDisconnected` → `restoreIncomplete` |
| cancelamento | `SIGINT`, 10 s, `SIGTERM`; `restoreIncomplete` |

## Regras

- Nada de senha (backups sem criptografia).
- Saída bruta do motor não é logada (mesma regra do backup, R10).
- Sem `--copy`, o app verifica a origem antes e depois (FR-006) e informa se ela mudou.
- Gravação iniciada = primeiro evento `.progress` do motor. Falha ou recusa antes disso vira `restoreRefused`; depois, `restoreIncomplete`. `Waiting for passcode` não conta como gravação.
