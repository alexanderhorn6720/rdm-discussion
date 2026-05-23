# Audit-as-code

Scripts reproducibles para auditorías META del repo rdm-discussion.

## Convención

`audit-NN-purpose.py` (o `aN_purpose.py` para legacy) donde NN = orden de creación.

Cada script debe tener:
- Docstring top con: propósito, fecha, autor, dependencias
- `if __name__ == "__main__"` guard
- Idempotente (correr 2x = mismo output)
- Standalone (`python3 audit-NN-foo.py` sin args extra)
- Output a `../` (reports root) en formato `.json` y `.md`

## Scripts actuales

| Script | Propósito | Output |
|---|---|---|
| a1_threads.py | Inventario completo de threads (número, autor, estado) | META-A1-threads-inventory |
| a2_prs.py | Inventario de PRs (open/merged/closed) | META-A2-prs-inventory |
| a3_migrations.py | Inventario de migraciones D1 | META-A3-migrations-inventory |
| a4_branches.py | Inventario de branches activas | META-A4-branches-inventory |
| a5_cross.py | Cross-reference matrix (threads ↔ PRs ↔ branches) | META-A5-cross-reference-matrix |
| a6_docs_json.py | Docs drift analysis (ADRs, specs, docs) | META-A6-docs-drift-analysis |
| a7_pending_json.py | Pending decisions inventory | META-A7-pending-decisions |
| a8_lost_work.py | Lost work / orphans detection | META-A8-lost-work-orphans |
| audit-09-collisions.py | Detectar colisiones de números (threads, migrations) | META-collisions |

## Ejecutar

```bash
# Desde la raíz del repo rdm-discussion
python3 reports/.audit-scratch/a1_threads.py
# Output → reports/YYYY-MM-DD-META-A1-threads-inventory.{json,md}
```

## Notas

- Scripts usan `REPO = Path("c:/dev/rdm/dev/discussion")` — ajustar si el clone está en otra ruta.
- Última corrida completa: 2026-05-22 (thread/176 meta-archaeology audit).
- Próxima corrida sugerida: post-megaspec Wave 1 (thread/182) para capturar nuevo estado.
