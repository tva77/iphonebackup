# Validation log: restauração (002)

## 2026-10-10: T025, tentativa 1: bloqueada antes da restauração

- **Aparelho:** iPhone de teste conectado por cabo, iOS 16.7.16 (major 16, na lista testada). Pareamento validado com `idevicepair validate`.
- **Autorização:** explícita para restauração real, dada pelo responsável nesta data.
- **Origem:** backup `finished` (`SnapshotState`), UDID conferido, 3,1 GB, em um compartilhamento SMB.
- **Bloqueio:** o compartilhamento de rede deixou de estar montado durante a verificação. Sem a origem acessível, a validação não é válida e nada foi restaurado.
- **Snapshot parcial:** foi gravado antes da desmontagem (34.353 arquivos, 74 com tamanho 0). Não foi completado e não serve como linha de base do passo 1.
- **Estado do iPhone:** nenhum comando de escrita foi executado. Apenas leituras (`idevice_id`, `ideviceinfo`, `idevicepair validate`).

### Próximo passo

Remontar o compartilhamento, confirmar o backup (`Status.plist` `finished`) e autorizar de novo a execução, pois a origem precisa ser verificada do zero.

## 2026-10-10: T025, tentativa 2: recusa por Buscar ativo, origem intacta

- **Montagem:** compartilhamento montado de novo; backup `finished`, UDID conferido, pareamento válido.
- **Snapshot antes:** 51.553 entradas de arquivo (a pesquisa R1 citava 51.552; diferença de 1 a conferir). Hashes de `Info.plist`, `Status.plist`, `Manifest.plist` e `Manifest.db` registrados.
- **Comando:** `idevicebackup2 -u <udid> restore <parentDir>`, sem `--copy`. Saída: `Don't copy backup: Yes`, `Restoring system files: No`, `Remove items that are not restored: No`.
- **Resultado do motor:** `ErrorCode 211: Find My iPhone must be disabled before restoring`, `Restore Failed (Error Code 211).`, saída 1. Recusa antes da gravação no aparelho.
- **Snapshot depois:** hashes dos quatro arquivos de topo iguais; lista de arquivos (nomes, tamanhos e datas) idêntica. A origem não foi alterada (passo 1 validado para este caso).
- **Pendência:** desativar Buscar no iPhone e repetir para o cenário feliz (passo 4).

## 2026-10-10: T025, tentativa 3: restauração concluída, origem intacta

- **Pré-condição:** Buscar desativado pelo responsável no iPhone. Compartilhamento montado; backup `finished`; pareamento válido.
- **Snapshot antes:** 51.553 entradas de arquivo; hashes de `Info.plist`, `Status.plist`, `Manifest.plist` e `Manifest.db` registrados logo antes da escrita.
- **Comando:** `idevicebackup2 -u <udid> restore <parentDir>`, sem `--copy`.
- **Resultado do motor:** progresso 100% (`Finished`), `The device should reboot now.`, `Restore Successful.`, saída 0. Sem erro de versão nem de protocolo.
- **Snapshot depois:** hashes dos quatro arquivos de topo iguais; lista de arquivos (nomes, tamanhos e datas) idêntica. A origem não foi alterada (FR-006 validado para esta execução).
- **Pós-reinício:** o aparelho voltou à tela de configuração (Wi-Fi e depois "restaurar backup?"). O computador ainda o enxerga: `Activated`, iOS 16.7.16, espaço de dados usado de cerca de 8,4 GB (capacidade 59,1 GB, disponível 50,7 GB). Não conclusivo: o espaço antes da restauração não foi registrado. Não verificado: a opção "restaurar do backup" da configuração provavelmente só enxerga iCloud ou backups do Finder, não este diretório SMB.
- **Tela do aparelho:** "Apps & Data" (configuração inicial). Escolhido "Don't Transfer Apps & Data" pelo responsável.
- **Verificação posterior:** espaço usado caiu de cerca de 8,4 GB para cerca de 6,6 GB (disponível 52,5 GB). Indica que o conteúdo do backup não está no aparelho. Não é prova definitiva.
- **Achado:** o motor reportou `Restore Successful.`, mas os dados não estão no aparelho. Isso contraria o FR-004 e o SC-001 se a restauração for tratada apenas pelo sinal do motor. A validação visual é obrigatória antes de qualquer afirmação de sucesso.
- **Tentativa 4 (repetição):** autorizada pelo responsável após o aparelho ficar sem dados. Snapshot antes: 51.553 entradas. Comando: `idevicebackup2 -u <udid> restore <parentDir>`, sem `--copy`. Resultado: 100% (`Finished`), `Restore Successful.`, saída 0, 11.854 arquivos enviados. Origem: hashes dos quatro arquivos de topo e lista completa de arquivos idênticos antes e depois.
- **Espaço usado após a tentativa 4:** cerca de 7,5 GB (disponível 51,7 GB). Aumentou cerca de 0,8 GB em relação à verificação anterior. Não bate com os 3,1 GB do backup, então o conteúdo pode não ter sido aplicado. Não conclusivo.
- **Confirmação pelo responsável:** nenhuma foto nem app restaurado no iPhone após as tentativas 3 e 4.
- **Conteúdo do backup (leitura de cópia local do `Manifest.db`):** 69.889 registros, não criptografado (`IsEncrypted` 0). Inclui cerca de 12.231 arquivos de CameraRollDomain, 27.211 de HomeDomain, 17.199 de domínios de apps e 89 de MediaDomain. O backup contém os dados.
- **Conclusão:** o motor reporta sucesso e o aparelho volta à configuração inicial sem os dados. O passo 4 **falhou**. A causa não foi identificada. O log do aparelho capturado depois da tentativa não mostrou erro de restauração.
- **Implicação para o produto:** `Restore Successful.` sozinho não comprova a restauração. FR-004 e SC-001 exigem confirmação de dados. Uma verificação possível é comparar o espaço usado do aparelho com o tamanho do backup, mas só depois de medir isso de forma confiável.
- **Cópia para o Finder:** backup copiado para `~/Library/Application Support/MobileSync/Backup/00008110-001C18C10E11401E`, a pasta que o Finder já tinha para este aparelho (vazia antes). Cópia com `cp -Rn` (sem sobrescrita). Resultado: 51.553 arquivos, 3,1 GB, código 0, hashes dos quatro arquivos de topo iguais à origem. A origem no SMB não foi alterada.
- **Próximo passo:** restaurar pelo Finder (ação do responsável; apaga o aparelho). O resultado vai mostrar se o problema está no `idevicebackup2` ou no próprio backup.
- **Pendências:** decidir se a restauração pelo `idevicebackup2` fica bloqueada até a causa ser encontrada, e se a spec deve registrar que a compatibilidade não é prometida (Princípio III). Reativar Buscar depois, se desejado. Interrupção por cabo (passo 5) não foi executada.

### Resultados dos passos do quickstart

| Passo | Estado |
|-------|--------|
| 1. Verificar origem (FR-006) | Validado na tentativa 3 (origem intacta) |
| 2. Duração | 12:03:34 a 12:27:29 (23 min 55 s), 11.915 arquivos enviados |
| 3. Buscar ativo (erro 211) | Validado na tentativa 2 (recusa sem gravação) |
| 4. Cenário feliz | Motor confirmou sucesso (tentativa 3); verificação visual no aparelho pendente |
| 5. Interrupção por cabo | Não executado |
| 6. Compatibilidade (3 iOS, 2 modelos) | Não executável: um aparelho disponível (SC-005 pendente) |
| 7. Idioma e acessibilidade | Fora de escopo nesta rodada |
