# Pesquisa: Restaurar backup no iPhone

## R1. A restauração altera a pasta do backup de origem?

- **Decisão**: restaurar sem `--copy`, com verificação da origem antes e depois (Clarifications da spec). O gate só fecha com a validação manual (quickstart, passo 1).
- **Rationale**: o próprio binário tem a chave interna `RestoreDontCopyBackup`, o que indica que o
  comportamento padrão **não** copia o backup. A ajuda documenta `--copy` como "create a copy of backup
  folder before restoring". Também há a gravação de `RestoreApplications.plist` durante a restauração,
  fora da pasta de backup e ainda não confirmada.
- **Medição (2026-10-10), uma execução bem-sucedida**: restauração sem `--copy` no clone APFS do backup,
  com Buscar desativado. Resultado `Restore Successful.`, saída 0. A árvore do clone ficou **idêntica**
  (51.552 arquivos, mesmos tamanhos e datas de modificação), e a origem também. Indica que a ferramenta
  lê o backup sem regravá-lo. Limite: um caso, comparando tamanho e data (não hash); falta repetir com
  interrupção no meio, que é o caso que mais importa para FR-006.
- **Interrupção (2026-10-10)**: restauração sem `--copy` morta com `SIGKILL` após 1.596 arquivos
  enviados (saída 137, sem `Restore Successful.`). Depois: SHA-256 de `Info.plist`, `Status.plist`,
  `Manifest.plist` e `Manifest.db` iguais aos de antes; árvore inteira (51.552 arquivos) com mesmos
  tamanhos e datas; origem igual. O iPhone sumiu da lista por alguns segundos e voltou sozinho, em iOS
  16.7.16. Limite: `SIGKILL` no processo, não corte físico do cabo; o estado do aparelho após a
  interrupção (dados parciais ou não) não foi verificado.
- **Cabo desconectado (2026-10-10)**: desconexão física cerca de 24 s após o início, com só 4 arquivos
  enviados. O motor saiu com `Could not receive from mobilebackup2 (-256)`, `Restore Aborted.` e saída
  255. Origem, clone e hashes iguais aos de antes. O iPhone voltou em iOS 16.7.16. Limite: o corte
  ocorreu cedo, antes da transferência principal, então não cobre a interrupção no meio.
- **Cabo desconectado no meio (2026-10-10)**: restauração sem `--copy` interrompida com o cabo depois de
  cerca de 11.900 arquivos enviados. O motor saiu com `Could not receive from mobilebackup2 (-256)`,
  `Restore Aborted.` e saída 255. Origem, clone e hashes iguais aos de antes. O iPhone voltou em iOS
  16.7.16. Limite: o horário exato do corte não foi registrado; a detecção por polling já tinha
  terminado quando a desconexão aconteceu.
- Tentativas anteriores foram recusadas com `ErrorCode 211` (Buscar ativo) antes de gravar nada.
- **Alternativas**: sempre `--copy` (descartada, ver R2); restaurar de uma cópia privada.

## R2. Custo de `--copy`

- **Decisão**: `--copy` descartado como salvaguarda (medição abaixo).
- **Rationale**: no NAS medido no MVP, criar arquivos pequenos custa ~107 ms cada. Um backup do iPhone
  tem ~51 mil arquivos. Uma cópia completa no SMB leva pelo menos ~90 min só de criação de arquivos,
  e o backup completo em SMB já se mostrou inviável (ver `validation-log.md`).
- **Medição (2026-10-10)**: `--copy` **não funciona de forma confiável**. A ferramenta criou
  `<udid>-20261010-091244` com `Info.plist`, `Manifest.db` e demais arquivos de topo completos (~89 MB),
  mas os diretórios `00`–`ff` viraram **arquivos vazios de 0 byte**: 260 arquivos no total, contra
  51.552 na origem. Mesmo assim a restauração terminou com `Restore Successful.`. A origem permaneceu
  intacta. Ou seja, a ferramenta não valida a própria cópia.
- **Consequência**: não usar `--copy` como salvaguarda. Qualquer proteção da origem tem de vir da
  verificação do próprio app (checar a cópia antes de depender dela), ou da medição de R1. Cópia
  completa com `cp -R` local leva ~16 s e ocupa mais 3,1 GB; no SMB, a estimativa é de ≥ 90 min só de
  criação de arquivos.
- **Decisão**: `copy: false` como padrão. Pendente: validar a verificação do app em iPhone real (quickstart, passo 1).
- **Alternativas**: (a) `--copy` para cópia local temporária no Mac (espaço e tempo a medir); (b) sem
  `--copy`, se R1 mostrar que o backup não é alterado; (c) limitar a restauração a destinos locais.

## R3. Detecção de Buscar (Find My) antes de restaurar

- **Medido (2026-10-10)**: a recusa é `ErrorCode 211: Find My iPhone must be disabled before restoring
  (MBErrorDomain/211)`, com `Restore Failed (Error Code 211).`. Ocorre antes da transferência, e o
  backup não é alterado. Dá para mapear para uma razão específica (`findMyEnabled`) pelo código 211.
- **Decisão**: mapear o código 211 para bloqueio com causa clara, sem pré-verificação própria.
- **Rationale**: o binário tem `device refused to start the restore process`, mas não há texto específico
  para Buscar. Detectar antes sem API confirmada seria chute.
- **Alternativas**: consultar o estado do recurso via `ideviceinfo` (não confirmado); aceitar a recusa
  como falha limpa (escolha atual).

## R4. Reinstalação de apps e reinício

- **Decisão**: padrões da ferramenta (sem `--skip-apps`, o aparelho reinicia).
- **Rationale**: evita flags não validadas. A reinstalação depende de rede e App Store, o que pode alongar
  ou falhar a restauração; revisar após medição.

## R5. Formato da saída e sinais de sucesso

- **Decisão**: sucesso = `Restore Successful.` + saída 0. Falha = `Restore Aborted.`,
  `Restore Failed (Error Code N).` ou saída diferente de 0. Progresso pelo mesmo parser do backup.
- **Rationale**: as strings existem no binário 1.4.0. O formato do progresso de restauração ainda não foi
  capturado, então o parser pode precisar de ajuste (medir na validação).
- **Erros reconhecidos**: `Aborting restore. Info.plist is missing.`, `Cannot ensure we restore from a
  successful backup`, `backup protocol version mismatch` (iOS incompatível).

## R6. Compatibilidade de iOS

- **Decisão**: restaurar só em versões da lista `TestedIOSVersions`, com confirmação extra fora dela
  (FR-009 da spec). A mensagem `backup protocol version mismatch` vira falha com causa e ação.
- **Rationale**: a restauração é a operação com maior risco de incompatibilidade de protocolo.
