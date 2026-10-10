# PRD: Aplicativo macOS de Backup Completo do iPhone

**Versão:** 0.1 (rascunho) | **Data:** 09/10/2026 | **Status:** Para revisão

## 1. Visão geral

Aplicativo nativo para macOS que faz o backup completo do iPhone (apps, mensagens, ajustes, fotos e demais dados incluídos no backup padrão da Apple) diretamente para uma pasta ou volume escolhido pelo usuário, como um NAS Synology montado por SMB, um disco externo ou uma pasta local. O app dispensa o Finder para essa tarefa, permite agendamento e automação, e oferece verificação de integridade e histórico.

**Nome provisório:** PhoneVault (a definir).

## 2. Problema e oportunidade

- O Finder só faz backup para `~/Library/Application Support/MobileSync/Backup`, sem opção nativa de escolher outro destino.
- Usuários com NAS precisam recorrer a links simbólicos ou a cópias manuais, soluções frágeis e sem verificação.
- O iCloud cobra por espaço e não entrega ao usuário um arquivo de backup sob seu controle.
- Não existe, no iOS, API pública para um app no iPhone fazer backup completo. A solução viável é rodar no Mac, usando o protocolo que o Finder usa (MobileBackup2).

## 3. Objetivos e não-objetivos

### Objetivos

1. Fazer backup completo do iPhone para um caminho configurável pelo usuário.
2. Suportar backups incrementais, de modo que as execuções seguintes sejam rápidas.
3. Suportar backup criptografado com senha guardada no Keychain.
4. Permitir backup manual e agendado, por USB e por Wi-Fi.
5. Verificar a integridade do backup e informar o resultado com clareza.
6. Funcionar bem com destinos de rede (SMB/NFS), tolerando lentidão e quedas.

### Não-objetivos (v1)

- Restaurar backup no iPhone (previsto para fase posterior).
- Navegar ou extrair itens individuais do backup (mensagens, fotos).
- Suporte a iPad e Apple Watch como alvo principal (poderão funcionar, sem garantia na v1).
- App para iOS, Windows ou Linux.
- Burlar o pareamento, a senha de bloqueio ou qualquer proteção do dispositivo.
- Distribuição na Mac App Store.

## 4. Público-alvo

| Persona | Descrição | Necessidade principal |
| --- | --- | --- |
| Usuário doméstico com NAS | Tem Synology/QNAP e quer centralizar backups | Backup automático sem pagar iCloud extra |
| Entusiasta de privacidade | Não quer dados na nuvem | Backup local criptografado e verificável |
| Profissional de TI / pequeno escritório | Gerencia poucos iPhones | Rotina previsível, logs e alertas |

## 5. Requisitos funcionais

### 5.1 Detecção e pareamento

- **RF-01:** Detectar iPhones conectados por USB e, quando habilitado, por Wi-Fi na mesma rede.
- **RF-02:** Exibir nome, modelo, versão do iOS, capacidade e espaço usado do dispositivo.
- **RF-03:** Guiar o usuário no pareamento (tocar em "Confiar" no iPhone e inserir o código de bloqueio) e tratar claramente os casos de recusa e de dispositivo bloqueado.
- **RF-04:** Orientar a habilitação do backup por Wi-Fi (opção de sincronização por Wi-Fi, ativada uma vez com o cabo conectado).

### 5.2 Destino do backup

- **RF-05:** Permitir escolher a pasta de destino por seletor de pastas, incluindo volumes de rede montados.
- **RF-06:** Validar o destino antes de iniciar: existência, permissão de escrita, espaço livre suficiente (com margem sobre o tamanho do último backup) e tipo de sistema de arquivos.
- **RF-07:** Permitir destinos diferentes por dispositivo.
- **RF-08:** Oferecer montagem automática do volume SMB/NFS configurado antes do backup, usando credenciais do Keychain.
- **RF-09:** Opção de modo "staging local": gravar primeiro em pasta local e depois transferir ao destino final, para reduzir o efeito da latência de rede.

### 5.3 Execução do backup

- **RF-10:** Backup completo na primeira execução e incremental nas seguintes.
- **RF-11:** Backup manual com um clique, com barra de progresso, velocidade, tempo estimado e cancelamento seguro.
- **RF-12:** Escrita segura: o backup em andamento não pode corromper o último backup válido (usar diretório temporário e promoção ao final, ou mecanismo equivalente).
- **RF-13:** Retomada após interrupção (cabo desconectado, queda de rede, Mac em repouso) sempre que o protocolo permitir; caso contrário, falhar de forma limpa e informar.
- **RF-14:** Impedir que o Mac entre em repouso durante o backup.

### 5.4 Criptografia

- **RF-15:** Opção para ativar backup criptografado. O app deve explicar que, sem criptografia, o backup não inclui senhas salvas, dados de Saúde e outros itens sensíveis.
- **RF-16:** Guardar a senha do backup no Keychain do Mac, com opção de não guardar.
- **RF-17:** Alertar de forma destacada que a senha perdida torna o backup irrecuperável.

### 5.5 Agendamento e automação

- **RF-18:** Agendar backups (diário, semanal, ao conectar o iPhone, ao detectar o iPhone na rede).
- **RF-19:** Executar em segundo plano por agente de login (menu bar) mesmo com a janela principal fechada.
- **RF-20:** Respeitar condições: só em corrente elétrica, só em determinada rede Wi-Fi, só se o destino estiver disponível.
- **RF-21:** Notificações do sistema para sucesso, falha e backup atrasado (por exemplo, sem backup há mais de N dias).

### 5.6 Retenção e histórico

- **RF-22:** Manter histórico de execuções com data, duração, volume transferido e resultado.
- **RF-23:** Política de retenção configurável (manter apenas o mais recente, ou N versões, quando houver suporte a snapshots).
- **RF-24:** Logs exportáveis para suporte, sem dados pessoais do conteúdo do backup.

### 5.7 Verificação

- **RF-25:** Verificar a integridade ao final de cada backup (consistência do manifesto e presença dos arquivos referenciados).
- **RF-26:** Verificação profunda sob demanda, com leitura completa e comparação de checksums quando disponíveis.

## 6. Requisitos não funcionais

| Categoria | Requisito |
| --- | --- |
| Plataforma | macOS 13 (Ventura) ou superior; Apple Silicon e Intel (binário universal) |
| Desempenho | Backup incremental sem alterações relevantes em menos de 2 minutos em USB; consumo de CPU abaixo de 25% em média durante a execução |
| Confiabilidade | Taxa de backups concluídos com sucesso acima de 98% em condições normais; nenhuma perda do último backup válido por falha do app |
| Segurança | Sem envio de dados do usuário a servidores; credenciais apenas no Keychain; binários assinados e notarizados |
| Privacidade | Sem telemetria por padrão; telemetria de uso anônima apenas com consentimento explícito |
| Usabilidade | Configuração inicial concluída em até 5 minutos; textos em português (Brasil) e inglês |
| Acessibilidade | Suporte a VoiceOver, navegação por teclado e Dynamic Type onde aplicável |
| Observabilidade | Logs estruturados locais com níveis configuráveis |

## 7. Fluxos principais

### 7.1 Primeiro uso

1. O usuário abre o app e vê o assistente de boas-vindas.
2. Conecta o iPhone por cabo, desbloqueia e toca em "Confiar".
3. O app exibe os dados do dispositivo.
4. O usuário escolhe a pasta de destino (por exemplo, um volume do Synology).
5. O app valida o destino e mostra o espaço necessário e o disponível.
6. O usuário decide pela criptografia e define a senha.
7. O app executa o primeiro backup completo, com progresso detalhado.
8. Ao fim, mostra o resultado da verificação e oferece ativar o agendamento e o Wi-Fi.

### 7.2 Backup agendado

1. O agente em segundo plano detecta que o horário chegou e que o iPhone está acessível.
2. Verifica as condições (energia, rede, destino).
3. Monta o volume de rede, se necessário.
4. Executa o backup incremental e a verificação.
5. Notifica o resultado e atualiza o histórico.

### 7.3 Falhas comuns (tratamento esperado)

- iPhone bloqueado ou sem confiança: instrução objetiva para desbloquear e confiar.
- Destino indisponível: tenta remontar, adia e notifica; não grava em pasta errada.
- Espaço insuficiente: bloqueia antes de começar e informa quanto falta.
- Conexão interrompida: encerra com segurança e agenda nova tentativa.

## 8. Interface (visão geral)

- **Janela principal:** lista de dispositivos, estado do último backup, botão "Fazer backup agora".
- **Detalhe do dispositivo:** destino, criptografia, agendamento, retenção, histórico.
- **Menu bar:** estado atual, progresso, acesso rápido para iniciar ou pausar.
- **Ajustes:** idioma, inicialização com o sistema, notificações, logs, atualizações.
- **Assistente inicial:** fluxo guiado descrito em 7.1.

## 9. Arquitetura técnica proposta

- **Camada de interface:** SwiftUI, com agente de menu bar (`MenuBarExtra`) e `SMAppService` para iniciar no login.
- **Camada de serviço:** módulo em Swift que orquestra detecção, agendamento, validação do destino, execução e verificação.
- **Motor de backup:** biblioteca open source **libimobiledevice** (protocolo MobileBackup2, equivalente a `idevicebackup2`), com **libusbmuxd/usbmuxd** para comunicação com o dispositivo. Opção de embutir como biblioteca ou como executável auxiliar dentro do bundle do app.
- **Armazenamento local:** banco SQLite (ou SwiftData) para histórico, configurações e estado das execuções.
- **Segurança:** Keychain para senha do backup e credenciais de rede; assinatura com Developer ID e notarização.
- **Rede:** montagem de volumes por `NetFS`; tratamento de reconexão e timeouts.

**Decisões a validar em protótipo:**

1. Embutir a biblioteca versus executar `idevicebackup2` como processo filho (o processo isolado facilita atualização e tratamento de falhas).
2. Gravar direto no destino de rede versus staging local (medir desempenho em SMB).
3. Estratégia de versões: a estrutura do backup da Apple guarda um estado por dispositivo, então várias versões exigem snapshots no nível do sistema de arquivos do destino (por exemplo, Btrfs no Synology) ou cópias gerenciadas pelo app.

## 10. Segurança e privacidade

- O backup contém dados altamente sensíveis; o app nunca os envia a terceiros.
- Criptografia recomendada e ativada por padrão na interface, com explicação clara.
- Senhas e credenciais somente no Keychain, nunca em arquivos de configuração ou logs.
- Logs não registram conteúdo do backup nem nomes de arquivos do usuário.
- Respeito às permissões do macOS (acesso a volumes de rede e pastas escolhidas pelo usuário).
- Dependências open source monitoradas quanto a vulnerabilidades.

## 11. Distribuição e licenciamento

- **Canal:** download direto no site, assinado com Developer ID e notarizado. A Mac App Store é inviável, pois o app depende de comunicação de baixo nível com o dispositivo e de componentes fora do sandbox.
- **Atualizações:** framework Sparkle.
- **Licença da biblioteca:** a libimobiledevice é LGPL; é preciso cumprir os termos (vinculação dinâmica ou binário separado, aviso de licença, código-fonte da biblioteca disponível).
- **Modelo comercial (a decidir):** gratuito/open source, compra única ou assinatura.

## 12. Métricas de sucesso

| Métrica | Meta (6 meses após o lançamento) |
| --- | --- |
| Taxa de sucesso dos backups | ≥ 98% |
| Usuários que concluem o primeiro backup após a instalação | ≥ 80% |
| Usuários com agendamento ativo | ≥ 60% |
| Tempo médio até o primeiro backup concluído | ≤ 15 min (excluindo o tempo de transferência) |
| Tickets de suporte por 100 usuários ativos | ≤ 5 por mês |

## 13. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| A Apple altera o protocolo em uma nova versão do iOS | Alto | Acompanhar betas, manter a biblioteca atualizada, bloquear versões não testadas com aviso claro |
| Lentidão em SMB | Médio | Modo staging local, medição de desempenho, orientações de configuração do NAS |
| Backup corrompido sem o usuário perceber | Alto | Escrita atômica, verificação automática, alerta de backup antigo |
| Perda da senha de criptografia | Alto | Avisos reforçados, opção de guardar no Keychain, instruções de recuperação |
| Backup por Wi-Fi instável | Médio | Reconexão e retomada, preferência por USB na primeira execução |
| Conformidade de licença (LGPL) | Médio | Revisão jurídica e empacotamento correto |
| Expectativa de restauração | Médio | Deixar claro que a v1 não restaura e documentar o uso do Finder para restaurar, se os formatos forem compatíveis |

## 14. Roadmap

| Fase | Entregas | Duração estimada |
| --- | --- | --- |
| 0. Protótipo técnico | Backup via libimobiledevice para pasta local e SMB; medições de desempenho; teste de compatibilidade com a estrutura do Finder | 2 a 3 semanas |
| 1. MVP | Detecção, pareamento, destino configurável, backup manual completo e incremental, criptografia, verificação básica | 6 a 8 semanas |
| 2. Automação | Agendamento, menu bar, Wi-Fi, notificações, histórico, montagem de volumes | 4 a 6 semanas |
| 3. Polimento e lançamento | Localização, acessibilidade, notarização, atualizações, documentação, beta fechado | 4 semanas |
| 4. Pós-lançamento | Restauração, retenção por versões, suporte a vários dispositivos, relatórios | A definir |

## 15. Critérios de aceite do MVP

1. O usuário escolhe uma pasta (local ou de rede) e o backup completo é gravado nela.
2. Uma segunda execução é incremental e conclui visivelmente mais rápido.
3. O backup criptografado inclui dados sensíveis e a senha fica no Keychain.
4. Interromper o backup (cabo ou destino) não destrói o último backup válido.
5. O app valida espaço e permissões antes de iniciar e exibe mensagens de erro compreensíveis.
6. O app é assinado, notarizado e instala sem avisos de segurança em macOS 13 ou superior.
7. Testado com ao menos três versões de iOS e dois modelos de iPhone.

## 16. Questões em aberto

1. O backup gerado precisa ser compatível com o Finder para restauração, ou o app terá formato e restauração próprios?
2. Qual será o modelo comercial e a licença do código do app?
3. Haverá suporte oficial a iPad na v1?
4. Como oferecer versões históricas em destinos que não têm snapshots?
5. O staging local deve ser o padrão para destinos de rede?
6. Qual a política de suporte às versões do iOS (apenas as mais recentes ou uma janela fixa)?

## 17. Referências técnicas

- libimobiledevice e `idevicebackup2` (protocolo MobileBackup2).
- usbmuxd / libusbmuxd (comunicação com dispositivos iOS).
- Documentação da Apple sobre Keychain, `SMAppService`, `NetFS` e notarização.
- Sparkle (atualizações de apps macOS fora da App Store).
