# Research: MVP de backup completo do iPhone

Fase 0 do plano. Cada item resolve uma incógnita do Technical Context. Itens marcados
**[protótipo]** precisam de medição em hardware real antes de virarem compromisso (constituição,
Fluxo de Entrega).

## R1. Motor de backup

- **Decision**: Executar `idevicebackup2` (libimobiledevice 1.4.0) como processo filho, com
  `idevice_id`, `ideviceinfo` e `idevicepair` para detecção, dados e pareamento.
- **Rationale**: Decisão 1 do PRD §9: processo isolado facilita atualização da biblioteca e
  tratamento de falhas (um crash do motor não derruba o app). Cumpre a LGPL sem vinculação no app:
  os binários ficam separados no bundle. A 1.4.0 suporta iOS 17+.
- **Alternatives considered**: Vincular `libimobiledevice` diretamente (mais controle de progresso,
  porém crash no protocolo derruba o app e exige ponte C/Swift); implementar MobileBackup2 do zero
  (meses de trabalho, sem ganho no MVP).
- **Prototype**: Homebrew (`brew install libimobiledevice`). Release (fase 3): compilar universal
  (arm64 + x86_64) e embutir em `Contents/Helpers` com dylibs, aviso de licença e link do código.

## R2. Senha de criptografia sem vazamento

> **Removida do MVP**: criptografia fora do escopo por decisão do usuário. Mantida só como registro.

- **Decision**: Passar a senha por `BACKUP_PASSWORD` (e `BACKUP_PASSWORD_NEW` ao trocar), definida
  só em `Process.environment` do filho, sem `-i`; nunca como argumento, arquivo ou log.
- **Rationale**: Canal oficial do `idevicebackup2` 1.4.0 (ver `--help`). No macOS o ambiente de
  outro processo só é legível pelo mesmo usuário ou root, enquanto argumentos aparecem em `ps` para
  todos (FR-011, princípio II). `-i` lê do terminal e exigiria pseudo-terminal.
- **Alternatives considered**: `encryption on <senha>` por argumento (vaza em `ps`); `-i` com
  pseudo-terminal (mais código, sem ganho de segurança); arquivo temporário (vaza em disco).
- **[protótipo]**: Confirmar com `ps -E` de outro usuário que a variável não aparece.

## R3. Preservação do último backup válido (clarificação Q1)

- **Decision**: Escrever sempre em diretório de staging no mesmo volume do destino e promover por
  `rename` após verificação. O staging nasce como clone do backup válido:
  1. `<dest>/.phonevault/staging/<UDID>` ← `copyfile(COPYFILE_CLONE)` do backup válido
     (clone instantâneo em APFS; cópia completa onde clone não existe).
  2. `idevicebackup2 backup` incremental no staging (passa o diretório pai; o motor grava em
     `<pai>/<UDID>`).
  3. Verificação (R5). Falhou → apaga staging; backup válido intacto.
  4. Promoção: `rename(valid → .phonevault/previous/<UDID>)`, `rename(staging → valid)`,
     apaga `previous`. Ao abrir, o app reconcilia: se `valid` sumiu e `previous` existe, restaura.
- **Rationale**: `rename` no mesmo volume é atômico em APFS/HFS+ e no servidor SMB; o backup
  válido nunca é alterado in-place. Detecção de clone: tentar `COPYFILE_CLONE_FORCE` em um arquivo
  de teste no destino; falha → modo cópia completa, e o espaço extra entra na validação (FR-004).
- **Alternatives considered**: Escrever direto no backup válido (viola FR-007); snapshot Btrfs
  do Synology via API (não-objetivo; exige credenciais administrativas do NAS).
- **[protótipo]**: Medir se o SMB do macOS faz clone server-side no Synology (provavelmente não) e
  o tempo de cópia completa em SMB para um backup de 64–128 GB.

## R4. Retomada após interrupção

- **Decision**: Sem retomada no MVP. Interrupção → staging descartado, mensagem "inicie um novo
  backup"; o próximo backup é incremental sobre o último válido.
- **Rationale**: FR-008 permite falha limpa; `idevicebackup2` não retoma sessões. Reusar staging
  parcial arrisca promover dados inconsistentes.
- **Alternatives considered**: Manter staging parcial e retomar (ganho só em interrupções no
  primeiro backup completo; fica para fase 2 se o protótipo mostrar dor real).

## R5. Verificação de integridade (FR-013)

- **Decision**: Após o backup, verificar no staging:
  - `Info.plist`, `Manifest.plist` e `Status.plist` presentes e legíveis; `Status.plist`
    com `SnapshotState == "finished"`; UDID igual ao dispositivo.
  - `Manifest.db`: abrir com SQLite (`libsqlite3` do sistema) e conferir que todo `fileID` da
    tabela `Files` com `flags == 1` (arquivo) existe em `<xx>/<fileID>`.
  - Backup criptografado: `Manifest.db` é cifrado. Derivar a chave do keybag em `Manifest.plist`
    (PBKDF2-SHA256 com DPSL/DPIC, depois PBKDF2-SHA1 com SALT/ITER) e desembrulhar com AES Key
    Wrap via CommonCrypto; decifrar `Manifest.db` em memória/arquivo temporário apagado ao final.
- **Rationale**: É a definição de integridade básica do PRD RF-25; usa apenas frameworks do
  sistema (SQLite, CommonCrypto), sem dependência nova.
- **Alternatives considered**: Confiar no código de saída do motor (não detecta arquivos ausentes;
  viola princípio III); checksums completos (RF-26, verificação profunda, fora do MVP).
- **[protótipo]**: Validar o algoritmo de keybag contra backups de iOS 16, 17 e 18.

## R6. Validação do destino (FR-004)

- **Decision**: Antes de gravar: diretório existe; teste de escrita com arquivo temporário;
  `statfs` para tipo de FS; espaço livre via `URLResourceValues.volumeAvailableCapacity`.
  - Aceitos: `apfs`, `hfs`, `smbfs`, `nfs`, `exfat`. Recusado: `msdos` (FAT32, limite de 4 GB
    por arquivo).
  - Espaço necessário: `1,1 × base`, onde base = tamanho do último backup válido, ou espaço usado
    no iPhone no primeiro backup; somar o tamanho do backup válido quando não houver clone (R3).
- **Rationale**: APIs do sistema; FAT32 quebra com arquivos grandes de mídia.
- **Alternatives considered**: Validar só espaço (falha tardia em FAT32 e somente leitura).

## R7. Detecção, pareamento e dados do iPhone (FR-001, FR-002)

- **Decision**: Consultar `idevice_id -l` a cada 2 s com a janela aberta; para cada UDID,
  `idevicepair validate` e, se preciso, `idevicepair pair` (mostra "Confiar" no iPhone). Dados via
  `ideviceinfo -x` (plist XML lido com `PropertyListSerialization`: nome, modelo, versão do iOS) e
  `ideviceinfo -x -q com.apple.disk_usage` (`TotalDiskCapacity`; usado = `TotalDataCapacity -
  TotalDataAvailable`), só uma vez por conexão: a consulta de disco leva mais de 10 s (medido em
  iPhone10,4 com iOS 16.7). Mapear erros de `idevicepair` para "bloqueado" e "recusado".
- **Rationale**: Mesmo motor do R1, sem código de protocolo próprio.
- **Alternatives considered**: Escutar eventos do `usbmuxd` (melhor reação, exige vinculação C).
  shortcut: polling a cada 2 s; trocar por eventos se o custo de CPU aparecer no protótipo.

## R8. Progresso, velocidade e tempo estimado (FR-006)

- **Decision**: Ler stdout e stderr de `idevicebackup2` em segmentos separados por `\r` ou `\n`.
  A barra só traz porcentagem (`] NN%`) e termina com ` Finished`; não há bytes. Velocidade =
  crescimento de `.phonevault/staging/<UDID>` amostrado a cada 2 s (`totalFileAllocatedSize`),
  média móvel de 10 s. ETA = (base estimada − bytes do staging) / velocidade, base = último backup
  válido ou espaço usado no iPhone. Sucesso exige saída 0 e a linha `Backup Successful.`.
  Segmentos especiais: `Waiting for passcode` → aguardando código no iPhone;
  `User has cancelled the backup process on the device.` → cancelado no iPhone;
  `Backup Failed (Error Code N).` → falha do motor. Cancelamento: `SIGINT`, 10 s, `SIGTERM`.
- **Rationale**: Formatos confirmados nas strings do binário 1.4.0; versões antigas já saíram com 0
  em falha, por isso a linha de sucesso é obrigatória.
- **[protótipo]**: Capturar a saída real de um backup para o fixture e o texto exato de senha
  errada (T065).

## R9. Impedir repouso (FR-009)

- **Decision**: `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep)` do
  início ao fim do backup, liberada em qualquer saída.
- **Rationale**: API do sistema; não impede o repouso por fechar a tampa nem por bateria crítica,
  que viram falha limpa (Edge Cases).

## R10. Segredos e logs (FR-011, FR-015)

- **Decision**: Senha em Keychain (`SecItemAdd`, `kSecClassGenericPassword`, serviço
  `PhoneVault.backup-password`, conta = UDID), só se o usuário escolher. Logs com `os.Logger`,
  subsystem `PhoneVault`; campos com caminhos e dados do dispositivo marcados `.private`; stdout
  do motor nunca vai inteiro para o log, só eventos classificados.
- **Rationale**: Frameworks do sistema; `.private` oculta valores em logs exportados.

## R11. Persistência local

- **Decision**: Um arquivo JSON (`Codable`) em `~/Library/Application Support/PhoneVault/state.json`
  com dispositivos, destinos (caminho + bookmark) e execuções; escrita atômica
  (`Data.write(options: .atomic)`).
- **Rationale**: Poucos dispositivos e dezenas de execuções; SwiftData exige macOS 14 e o alvo é
  macOS 13; SQLite/GRDB é excessivo para esse volume.
- **Alternatives considered**: SwiftData (alvo macOS 14+), SQLite (desnecessário no MVP).
  shortcut: JSON único; migrar para SQLite quando o histórico (fase 2) passar de milhares de itens.

## R12. Versões de iOS testadas (FR-017)

- **Decision**: Lista embutida no app (`TestedIOSVersions.plist`, versões principais, ex.: 16, 17,
  18) atualizada a cada release; versão fora da lista exige confirmação a cada execução.

## R13. Testes

- **Decision**: Lógica no alvo `PhoneVaultCore` do pacote SwiftPM, testado com `swift test` (XCTest).
  O motor é acessado por protocolo; testes usam um executável falso que simula sucesso, saída
  de progresso, crash, desconexão e lentidão. Testes de destino usam volumes temporários (APFS via
  `hdiutil` e FAT32 via imagem). Hardware real e SMB ficam no roteiro manual de `quickstart.md`.
- **Rationale**: Constituição IV exige testes de falha; simulação não substitui hardware, então os
  dois existem.
