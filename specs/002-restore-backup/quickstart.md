# Quickstart: validação da restauração

Roteiro para provar a feature. A parte automatizada cobre a lógica com motor falso; a parte manual
exige iPhone real e autorização explícita, porque a restauração substitui os dados do aparelho.
Registrar cada resultado em `specs/002-restore-backup/validation-log.md`.

## Pré-requisitos

- Backup verificado do iPhone (`<destino>/<udid>` com `Status.plist` `finished`).
- iPhone de teste com iOS na lista testada; Buscar desativado para o cenário feliz.
- Autorização explícita para a operação destrutiva no aparelho.

## Automatizados

```bash
swift test --filter Restore
```

Esperado: cenários com motor falso passam (ver tabela abaixo).

| Cenário | Esperado |
| --- | --- |
| Sem backup verificado | ação bloqueada, nada chamado no motor |
| Sucesso (`Restore Successful.`) | `verified`, `lastValidBackup` inalterado |
| Falha no meio | `restoreIncomplete`, backup de origem igual ao anterior |
| Recusa antes de gravar | `restoreRefused`, sem mensagem de dados parciais |
| Versão incompatível | `protocolMismatch` com causa e ação |
| Restauração e backup no mesmo aparelho | `busy` para o segundo |
| Saída 0 sem `Restore Successful.` | falha, sem sucesso |

## Manuais (hardware real, autorização explícita)

1. **Verificar origem (FR-006)**: restaurar sem `--copy` e comparar a origem antes e depois com contagem, tamanho
   e data de todos os arquivos e SHA-256 de `Info.plist`, `Status.plist`, `Manifest.plist` e `Manifest.db`.
   Esperado: origem inalterada e o app informa o resultado.
2. **Duração**: registrar tempo e número de arquivos enviados na restauração sem `--copy`.
3. **Buscar ativo (R3)**: restaurar com Buscar ativo. Esperado: recusa com erro 211 antes de gravar; causa mostrada.
4. **Cenário feliz**: restaurar num aparelho de teste; confirmar sucesso e dados visíveis no aparelho.
5. **Interrupção**: desconectar o cabo no meio; confirmar `restoreIncomplete` e backup de origem intacto.
6. **Compatibilidade**: repetir 4 em três versões de iOS e dois modelos (SC-005).
7. **Idioma e acessibilidade**: fluxo com VoiceOver e só teclado, em pt-BR e en-US.
