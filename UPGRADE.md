# 📋 UPGRADES — Moodle Lab Infrastructure

Historial de cambios sobre la infraestructura Terraform + GitHub Actions para Moodle en Azure. Cada entrada documenta **qué se cambió, por qué, y en qué archivos**.

---

## [v1.0.0]

### Added
- Variable `moodle_branch` en `variables.tf` para parametrizar qué rama de `moodle-lab` se clona en el `cloud-init.yml` (default: `main`).
- Variables `moodle_db_name`, `moodle_db_user`, `moodle_db_password` en `variables.tf` para eliminar credenciales de base de datos hardcodeadas.
- Soporte de restauración desde snapshot en `main.tf`:
  - `azurerm_managed_disk.from_snapshot` — crea un disco gestionado a partir de un snapshot existente.
  - `azurerm_virtual_machine.vm_from_snapshot` — VM que arranca con el disco restaurado (Moodle ya instalado, sin wizard).
  - Variable `snapshot_id` para indicar el snapshot a restaurar.
- Paso "Get snapshot ID" en `spin-up.yml` que resuelve el `snapshot_id` vía Azure CLI antes del `terraform apply`, cuando `use_snapshots = true`.
- Timeouts de FastCGI en `cloud-init.yml` (`fastcgi_read_timeout`, `fastcgi_send_timeout`, `fastcgi_connect_timeout` a 300s) para evitar cortes de Nginx durante instalaciones/migraciones largas de Moodle en VMs de recursos bajos.

### Changed
- `cloud-init.yml`: el `git clone` de Moodle ahora apunta a `https://github.com/RenzoMedina/moodle-lab.git` en vez del repo oficial `moodle/moodle`, usando `--recurse-submodules` (preparado para cuando se agreguen plugins como submodules) y `--branch ${moodle_branch}` parametrizado.
- `cloud-init.yml`: credenciales de MySQL (`moodleuser` / password) reemplazadas por variables `${moodle_db_name}`, `${moodle_db_user}`, `${moodle_db_password}` en las 3 ocurrencias donde se creaba la base de datos.
- `main.tf`: `azurerm_linux_virtual_machine.vm` ahora usa `count = var.use_snapshots ? 0 : 1` — solo se crea cuando **no** se usa snapshot, coexistiendo con la VM restaurada.
- `main.tf`: `templatefile()` del `custom_data` ahora recibe `moodle_branch`, `moodle_db_name`, `moodle_db_user`, `moodle_db_password`.
- `spin-up.yml` y `teardown.yml`: agregado `TF_VAR_moodle_db_password` en el bloque `env` de ambos workflows (variable sin default en Terraform requiere estar presente en **todo** workflow que corra `plan`/`apply`/`destroy`, o el job queda colgado esperando input interactivo).

### Fixed
- **Bug crítico de sintaxis YAML** en `cloud-init.yml`: la línea del `git clone` tenía un `- -` (doble guion) al inicio, lo que hacía que cloud-init interpretara el comando como una lista anidada de un solo elemento y lo ejecutara vía `execve` sin dividir en argumentos → error `not found`. Corregido a un solo `-` (string plano).
- **Timeout de Nginx durante el wizard de instalación** (`upstream timed out (110)`): el wizard de Moodle tardaba más de los 60s por defecto de `fastcgi_read_timeout` en VMs `Standard_B1ms` (1 vCPU / 2GB RAM). El proceso de PHP-FPM seguía trabajando en segundo plano y terminaba solo, pero Nginx cortaba la conexión antes, mostrando error al usuario. Resuelto con los timeouts de 300s documentados arriba.
- **State lock huérfano en Terraform** (`Error acquiring the state lock`): ocurrió al cancelar manualmente un job de `teardown.yml` que había quedado esperando input interactivo (por la falta de `TF_VAR_moodle_db_password`, ver arriba). Resuelto puntualmente con `terraform force-unlock <LOCK_ID>` como paso temporal, luego removido del workflow.

### Security
- Eliminado el password de MySQL hardcodeado (`MoodlePass2026!`) del `cloud-init.yml`, ahora inyectado en runtime desde el secret `MOODLE_DB_PASSWORD` de GitHub Actions vía `TF_VAR_moodle_db_password`.

---

## Contexto / decisiones de arquitectura

- **`moodle-lab` (repo de Moodle) separado de `moodle-lab-infra`** (este repo de Terraform): se decidió mantener el código de Moodle en su propio repo (`github.com/RenzoMedina/moodle-lab`), clonado desde `MOODLE_405_STABLE` **sin el historial oficial** (squash a un commit inicial vía `git checkout --orphan main`), para portafolio propio y para permitir agregar plugins como submodules sin arrastrar el historial completo de Moodle.
- **Plugins como submodules**: pendiente de implementar. El `--recurse-submodules` ya está en el `git clone` del cloud-init, listo para cuando se agreguen.
- **Ambientes (dev/staging/prod)**: pendiente. Por ahora solo existe "staging" (nombres de recursos hardcodeados). Evaluar carpetas por ambiente vs. workspaces cuando se necesite un segundo ambiente real.
- **Snapshot restore**: se usa `azurerm_virtual_machine` (recurso legacy) en paralelo a `azurerm_linux_virtual_machine`, porque este último no soporta `create_option = "Attach"` sobre un disco ya existente. Mutuamente excluyentes vía `count` + `var.use_snapshots`.

## Pendientes conocidos

- [ ] Agregar plugins como submodules en `moodle-lab` (`local/`, `mod/`, `theme/`).
- [ ] Workflow de deploy individual de plugin (rsync a VM viva, sin pasar por Terraform completo).
- [ ] Separar ambientes dev/staging/prod (carpetas + backend keys distintos).
- [ ] Fix del error `Primary script unknown` en Nginx (agregar `try_files $uri =404;` antes del `fastcgi_pass`).
- [ ] Evaluar si `Standard_B1ms` es suficiente a largo plazo o conviene subir a `Standard_B2s` de forma permanente.
- [ ] `.gitignore` en `moodle-lab` para no versionar `config.php` ni `moodledata/`.