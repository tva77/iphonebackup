# Contract: Layout do destino

O que o app grava no destino escolhido. Outros programas (Finder, ferramentas de leitura de
backup) só precisam conhecer `<destino>/<udid>`.

```text
<destino>/
├── <udid>/                      # último backup válido, estrutura padrão da Apple
│   ├── Info.plist
│   ├── Manifest.plist
│   ├── Manifest.db
│   ├── Status.plist
│   └── 00/ … ff/                # arquivos do backup
└── .phonevault/
    ├── staging/<udid>/          # execução em andamento; nunca é backup válido
    └── previous/<udid>/         # existe só durante a promoção
```

## Regras

- `<udid>/` só é substituído por `rename` de `staging/<udid>` após verificação aprovada.
- Ao abrir o app ou antes de um backup: se `<udid>/` não existe e `previous/<udid>/` existe,
  renomear `previous` de volta (promoção interrompida). `staging/` restante é apagado.
- `staging/` e `previous/` ficam no mesmo volume do destino para o `rename` ser atômico.
- Nada é gravado fora de `<destino>`; destino indisponível bloqueia o backup (FR-003, Edge Cases).
- Restauração pelo Finder a partir de `<udid>/` não é prometida na v1 (Clarifications Q3).
