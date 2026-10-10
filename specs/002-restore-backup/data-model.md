# Modelo de dados: Restaurar backup

Acréscimos ao modelo do MVP ([001 data-model](../001-iphone-backup-mvp/data-model.md)). Nada é
persistido além do que já existe; a restauração é registrada como uma execução (`BackupRun`).

## RunKind (acréscimo)

| Valor | Regra |
| --- | --- |
| `full` / `incremental` | existente |
| `restore` | nova; execução sem staging nem promoção. Não altera `lastValidBackup` |

## RunState (acréscimo)

| Valor | Regra |
| --- | --- |
| `restoring` | nova; entre o início do motor e a confirmação `Restore Successful.` |

Transições: `validating → preparing → restoring → verified | failed | cancelled`. Restauração
bem-sucedida termina em `verified`, com o significado de "motor confirmou a conclusão" (não de dados
comparados). Diferente do backup, não há `verifying`/`promoting`.

## FailureReason (acréscimos)

| Razão | Causa | Ação para o usuário |
| --- | --- | --- |
| `restoreIncomplete` | falha ou cancelamento depois do início da gravação no aparelho | aparelho pode ter dados parciais; tentar de novo |
| `restoreRefused` | motor recusou antes do primeiro progresso (ex.: Buscar ativo, bloqueio) | nada foi alterado; ver a causa mostrada e tentar de novo |
| `protocolMismatch` | `backup protocol version mismatch` | versão de iOS incompatível com o backup |
| `originChanged` | a verificação da origem depois da restauração difere da de antes | o backup de origem foi alterado; fazer um novo backup antes de restaurar de novo |

Cada razão ganha mensagem em pt-BR e en-US (regra existente, verificada por `LocalizationTests`).

## Pré-condições (regras, não persistidas)

- `Device.lastValidBackup != nil` e `Device.destination` disponível.
- Aparelho pareado, desbloqueado e confiável no momento da ação.
- Nenhuma execução em andamento (`CoordinatorError.busy`).
- Versão de iOS na lista testada ou confirmação extra (FR-009).

## Backup de origem

Entidade existente (`ValidBackup`). A restauração **não** altera `sizeBytes`, `completedAt` ou `runID`
do backup de origem, e a pasta de origem deve permanecer como estava (FR-006, verificado antes e depois; ver Clarifications da spec).
