# dbt_sgfood

Proyecto dbt del Data Warehouse de SG-Food. La documentación completa está en el README de `PROYECTO1`.

| Capa | Carpeta | Materialización | Schema |
|---|---|---|---|
| Staging | `models/staging` | view | `staging` |
| Intermediate | `models/intermediate` | view | `intermediate` |
| Marts | `models/marts` | table | `marts` |

```bash
dbt debug
dbt build
dbt docs generate
dbt docs serve
```
