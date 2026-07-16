# 📋 UPGRADES — Moodle Lab Infrastructure

Historial de cambios sobre la infraestructura Terraform + GitHub Actions para Moodle en Azure. Cada entrada documenta **qué se cambió, por qué, y en qué archivos**.

---

## [1.0.1]

### Added — Restauración desde snapshot (fixes posteriores a v1.0.0)
- `time_sleep.wait_after_disk_create` en `main.tf`: espera 30s en el `destroy` entre eliminar la VM y eliminar el disco restaurado, evitando el conflicto 409 "disco todavía adjunto" por consistencia eventual de la API de Azure.
- `lifecycle { replace_triggered_by = [azurerm_managed_disk.from_snapshot[0].id] }` en `azurerm_virtual_machine.vm_from_snapshot`: fuerza el reemplazo completo de la VM (no un update in-place, que Azure rechaza) cuando cambia el disco restaurado.
- Provider `hashicorp/time ~> 0.11` agregado en `terraform.tf`.
- `create-snapshot.yml` reescrito con: validación explícita de secrets requeridos, `az group create` idempotente del RG de snapshots (auto-suficiente, no depende de `setup-backend.yml`), y borrado del snapshot anterior antes de crear uno nuevo (los snapshots de Azure tienen `CreationData` inmutable — no se pueden "sobrescribir" con `az snapshot create` sobre un nombre existente).
- **`cloud-init.yml` hecho idempotente**: los bloques de "clonar Moodle" y "forzar wizard" ahora verifican `if [ ! -d /var/www/moodle ]` / `if [ ! -f /var/www/moodle/config.php ]` antes de ejecutarse. Esto neutraliza el efecto de un bug de cloud-init que se re-dispara solo en ciertos boots (aún sin causa raíz confirmada) sin romper la instalación existente.
- Swap de 2GB agregado manualmente a la VM de prueba (`/swapfile`) — la VM `Standard_B1ms` (2GB RAM) se queda muy justa corriendo Nginx + PHP-FPM + MySQL a la vez. **Pendiente**: agregar esto al `cloud-init.yml` para que sea permanente en cada instalación limpia.

### Fixed (posteriores a v1.0.0)
- **Ciclo de dependencias en Terraform** (`Cycle: azurerm_managed_disk.from_snapshot, time_sleep...`): el `time_sleep` y el `managed_disk` se referenciaban mutuamente vía `depends_on`. Corregido: el orden correcto es disco → `time_sleep` → VM (nunca al revés).
- **`count` invertido en `azurerm_linux_virtual_machine.vm`**: tenía `var.use_snapshots ? 1 : 0` (al revés), causando que con `use_snapshots=true` se creara la VM equivocada (la de cloud-init limpio, en vez de la restaurada). Corregido a `? 0 : 1`.
- **409 Conflict `osDisk.createOption` no se puede cambiar**: al reintentar un `apply` sobre una VM ya existente con disco distinto. Resuelto con `lifecycle.replace_triggered_by` (ver arriba).
- **409 al destruir el disco restaurado** (`Disk is being attached to VM`): consistencia eventual de Azure. Resuelto con `time_sleep` de 30s en el destroy. Alternativa si persiste: reintentar el `destroy` una vez más.
- **SSH `Host key verification failed`**: al recrear la VM repetidamente con el mismo dominio DuckDNS, cada VM nueva genera claves de host SSH distintas. Solución aplicada: entrada en `~/.ssh/config` con `StrictHostKeyChecking no` y `UserKnownHostsFile /dev/null` específica para `moodlelab.duckdns.org`.
- **`Permission denied (publickey)`**: la llave SSH usada tenía nombre custom (`moodlelab`/`moodlelab.pub`), no el nombre por defecto que el cliente SSH prueba automáticamente. Resuelto agregando `IdentityFile` explícito en `~/.ssh/config`.
- **Contraseña de admin corrupta tras restaurar snapshot** (`$6$rounds=...` en `mdl_user.password`, formato SHA-512 crypt en vez del bcrypt `$2y$...` normal de Moodle): causado por el mismo bug de cloud-init re-disparándose sin protección, antes de aplicar el fix idempotente. Resuelto puntualmente con `admin/cli/reset_password.php` (ver runbook abajo). Con el fix idempotente ya aplicado, no debería repetirse — validado en un ciclo de `spin-up` limpio donde cloud-init se re-disparó pero el guard evitó tocar `config.php`/la base de datos.

### 🐛 Bug conocido, sin causa raíz confirmada: cloud-init se re-dispara solo
Se observó (vía `journalctl`) que cloud-init ejecuta el `runcmd` completo más de una vez dentro del mismo ciclo de vida de una VM (ej. a los ~32 minutos del primer boot), sin relación aparente a un reboot manual. Ocurre tanto en VMs restauradas desde snapshot como en instalaciones limpias. Confirmado que **no es un bug de Terraform** (el `plan`/`apply` muestran exactamente los recursos esperados). Con el fix idempotente del `cloud-init.yml`, este re-disparo ya no es destructivo, pero la causa raíz sigue sin confirmarse (hipótesis: comportamiento de WALinuxAgent/datasource de Azure re-evaluando la instancia). Queda como investigación pendiente, sin urgencia.

### 🛠️ Runbook — comandos operativos

**Antes de tomar un snapshot (siempre, para evitar capturar el disco con datos a medio escribir):**
```bash
ssh moodlelab.duckdns.org
sudo systemctl stop nginx
sudo systemctl stop php8.1-fpm
sudo systemctl stop mysql

# confirmar que quedaron detenidos:
sudo systemctl status nginx php8.1-fpm mysql
```
Recién con los 3 en `inactive (dead)`, correr `create-snapshot.yml`. Después, si se quiere seguir usando la VM:
```bash
sudo systemctl start mysql
sudo systemctl start php8.1-fpm
sudo systemctl start nginx
```

**Si el login de Moodle da "contraseña incorrecta" (aunque la contraseña sea la correcta):**
```bash
ssh moodlelab.duckdns.org
cd /var/www/moodle
sudo -u www-data /usr/bin/php admin/cli/reset_password.php --username=admin --password='TuNuevaPassword123!' --ignore-password-policy
```
El flag `--ignore-password-policy` es necesario si la nueva contraseña no cumple las reglas de complejidad por defecto de Moodle (mínimo de dígitos, mayúsculas, símbolos). Alternativa 100% interactiva (no deja la contraseña en el historial de bash):
```bash
cd /var/www/moodle
sudo -u www-data /usr/bin/php admin/cli/reset_password.php
```
Pregunta el username y luego la nueva contraseña (oculta al escribir). Esto re-hashea la contraseña con el mecanismo correcto de Moodle, sin importar qué haya quedado corrupto en la base de datos.

**Variante equivalente, confirmada funcionando (ruta absoluta, sin necesidad de `cd` primero):**
```bash
sudo -u www-data php /var/www/moodle/admin/cli/reset_password.php --username=admin --password='TuNuevaPassword123!' --ignore-password-policy
```

**Para confirmar si cloud-init se re-disparó solo en el boot actual (diagnóstico del bug de arriba):**
```bash
ssh moodlelab.duckdns.org
sudo journalctl --no-pager | grep -i "Forzando wizard\|Clonando Moodle\|Configurando base de datos"
```
Si aparecen estos mensajes más de una vez con timestamps distintos, confirma que cloud-init volvió a correr el `runcmd` completo dentro del mismo ciclo de vida de la VM. Con el fix idempotente aplicado, esto ya no debería ser destructivo, pero sirve para monitorear si el comportamiento sigue ocurriendo.

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
- [ ] Validar el ciclo completo con `use_snapshots=true` (detener servicios → snapshot → teardown → spin-up con `true`) para confirmar que el fix idempotente cubre igual de bien ese escenario.
- [ ] Investigar la causa raíz de por qué cloud-init se re-dispara solo (sin urgencia, ya no es destructivo).
- [ ] Agregar el swapfile de forma permanente en `cloud-init.yml`.
- [ ] Reactivar el cron de `teardown.yml` una vez estabilizado el flujo (si quedó comentado).