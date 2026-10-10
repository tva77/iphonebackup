# Quickstart: validação do MVP

Roteiro para provar que o MVP cumpre a spec. Testes automatizados cobrem a lógica; o roteiro
manual cobre hardware e rede, que a simulação não substitui (constituição IV). Registrar cada
resultado manual em `specs/001-iphone-backup-mvp/validation-log.md`.

## Pré-requisitos

- macOS 13+ com Xcode 26 (Swift 6).
- `brew install libimobiledevice` (1.4.0+) para o protótipo.
- Pelo menos dois modelos de iPhone e três versões de iOS (SC-007).
- Destino local APFS, disco externo e um compartilhamento SMB montado (ex.: Synology).

## Automatizados

```bash
swift test
scripts/make-app.sh && open .build/PhoneVault.app
```

Esperado: todos os testes passam, incluindo os de falha listados abaixo com o motor falso
([contracts/backup-engine.md](contracts/backup-engine.md)).

| Cenário | Esperado |
| --- | --- |
| Crash do motor no meio | `failed(engineCrashed)`; backup válido igual ao anterior (hash da árvore) |
| Cancelamento | `cancelled`; staging apagado; backup válido intacto |
| Arquivo ausente em `Manifest.db` | `failed(verificationFailed)`; nada promovido |
| Promoção interrompida entre os dois `rename` | Reabrir restaura `previous` ([layout](contracts/destination-layout.md)) |
| Destino FAT32, somente leitura, cheio | Bloqueado antes de gravar, com causa e ação |
| Destino sem clone | Espaço exigido inclui cópia do backup válido |
| iOS fora da lista testada sem confirmação | `failed(untestedIOSNotConfirmed)`; nada gravado |
| Saída 0 sem `Backup Successful.` | `failed(engineCrashed)`; nada promovido |
| Código pedido / cancelado no iPhone | Estado `waitingForDevice` e retomada / `failed(cancelledOnDevice)` |
| Repouso do Mac durante o backup | `failed(sleepOrPowerLoss)`; backup válido intacto |

## Manuais (hardware real)

1. **Primeiro backup (US1)**: iPhone novo no Mac → "Confiar" → escolher pasta APFS → backup.
   Esperado: dados do iPhone exibidos, progresso com velocidade e ETA, estado "verificado",
   `<pasta>/<udid>/Status.plist` existe. Cronometrar configuração inicial (SC-001 ≤ 5 min).
2. **Incremental (US4)**: repetir sem mudanças. Esperado: < 2 min por cabo (SC-002).
3. **Interrupções (US2)**: com backup válido, desconectar o cabo, desmontar o SMB e cancelar
   durante novos backups. Esperado: falha limpa e backup anterior verificável (SC-003).
4. **Repouso**: iniciar backup e deixar o Mac ocioso além do tempo de repouso. Esperado: não dorme.
5. (Removido: criptografia fora do MVP.)
6. **SMB**: repetir 1–3 no compartilhamento de rede; medir tempo da cópia sem clone (research R3).
7. **Compatibilidade**: repetir 1, 2 e 5 em cada combinação iPhone × iOS (SC-007).
8. **Acessibilidade e idioma (FR-018, SC-009)**: percorrer o fluxo com VoiceOver e só teclado.
   Repetir com o idioma do app (Ajustes > Geral > Idioma e Região > Apps) em português → tudo em
   pt-BR; em inglês → tudo em en-US; em espanhol → tudo em en-US. Nenhum texto misturado.
