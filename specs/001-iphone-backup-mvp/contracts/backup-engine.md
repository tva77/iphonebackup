# Contract: Motor de backup (processo auxiliar)

Interface entre `PhoneVaultCore` e os executáveis da libimobiledevice 1.4.0. Em testes, um
executável falso implementa o mesmo contrato (research R13).

## Protocolo Swift

```swift
protocol DeviceEngine {
    func listDevices() async throws -> [String]                 // idevice_id -l
    func pairingState(udid: String) async throws -> PairingState // idevicepair validate
    func pair(udid: String) async throws -> PairingState         // idevicepair pair
    func info(udid: String) async throws -> DeviceInfo           // ideviceinfo -x (+ disk_usage)
    func backup(udid: String, into parentDir: URL, full: Bool) -> AsyncThrowingStream<EngineEvent, Error>
}

enum PairingState { case paired, needsTrust, locked, denied }
enum EngineEvent { case progress(percent: Double), waitingForDevicePasscode, finished }
```

Bytes transferidos e velocidade não vêm do motor: o coordenador mede o crescimento do staging
(research R8).

## Invocações

| Operação | Comando | Sucesso |
| --- | --- | --- |
| Listar | `idevice_id -l` | Um UDID por linha |
| Validar pareamento | `idevicepair -u <udid> validate` | Saída 0 |
| Parear | `idevicepair -u <udid> pair` | Saída 0; senão mapear para `locked`/`denied`/`needsTrust` |
| Dados | `ideviceinfo -u <udid> -x` e `-x -q com.apple.disk_usage` | Plist XML; disco só uma vez por conexão (>10 s) |
| Backup | `idevicebackup2 -u <udid> backup [--full] <parentDir>` | Saída 0 **e** linha `Backup Successful.`; grava `<parentDir>/<udid>` |

## Saída do backup

Segmentos de stdout/stderr separados por `\r` ou `\n`:

| Segmento | Evento / erro |
| --- | --- |
| `[====      ]  35%` (contém `] NN%`) | `.progress(percent: 35)` |
| ` Finished` | `.progress(percent: 100)` |
| contém `Waiting for passcode` | `.waitingForDevicePasscode` |
| `User has cancelled the backup process on the device.` | erro `cancelledOnDevice` |
| `Backup Failed (Error Code N).` | erro `engineCrashed(N)` |
| `Backup Successful.` | habilita `.finished` na saída 0 |

## Regras

- Cancelar: `SIGINT`, 10 s, `SIGTERM`. O stream termina com `CancellationError`.
- Saída diferente de 0, ou saída 0 sem `Backup Successful.` → `engineCrashed(exitCode)`.
- Desaparecimento do UDID em `idevice_id -l` durante o backup → `deviceDisconnected`.
- stdout/stderr completos não são logados; só eventos classificados (R10).
- Caminho dos executáveis: `Contents/Helpers` no bundle; no protótipo, `/opt/homebrew/bin`.
