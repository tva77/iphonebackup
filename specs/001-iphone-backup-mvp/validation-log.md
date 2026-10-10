# Validation log: T066

Registro dos cenários manuais do [quickstart.md](quickstart.md). Hardware usado: iPhone 8 Plus
(`iPhone10,4`, iOS 16.7.16), Mac arm64 e NAS SMB (`//nas1/home`).

## Medido

| Cenário | Resultado |
| --- | --- |
| Repouso (passo 4) | Durante o backup o app mantém `PreventUserIdleSystemSleep` ("PhoneVault backup") ativo, confirmado com `pmset -g assertions`. Não testado com o Mac ocioso até dormir. |
| CPU < 25% (SC) | Amostras de 5 s durante o backup SMB: média 0,5%, pico 3,9% (`idevicebackup2` + app). |
| SMB (passo 6), backup completo | **Não concluído.** Após ~10 min: 151 MB e 2.756 arquivos gravados, ~38 KB/s. Interrompido. Projeção: horas por backup completo. |
| Benchmark do NAS | Arquivo grande: 92 MB/s. Criação de arquivos pequenos: 2.000 arquivos em 3 min 34 s (~107 ms por arquivo). |

Conclusão: o gargalo no SMB é a latência por arquivo, não a banda. Um backup com ~51 mil arquivos
fica inviável em rede nessas condições. A meta de SC-002 não foi testada em SMB.

## Não medido (depende de ação manual ou de outro hardware)

- Incremental em SMB (passo 2 e 6) e tempo de cópia sem clone (research R3).
- Interrupções com cabo, desmontagem do SMB e cancelamento (passo 3).
- Repouso com o Mac ocioso até dormir (passo 4).
- Dois modelos de iPhone e três versões de iOS (passo 7, SC-007).
- VoiceOver e navegação só por teclado (passo 8).
- App em pt-BR, en-US e idioma não suportado (passo 8).

## Pendências de limpeza

- `/Volumes/home/backup/phonevault-validacao-smb` (~151 MB, com staging) ficou no NAS após a
  interrupção. A pasta foi criada pelo teste e não é o destino real `iphone13_thiago`.
