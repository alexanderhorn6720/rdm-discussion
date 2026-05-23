---
thread: 185
author: wc
type: checklist
mode: verify
created: 2026-05-23
related: [184]
status: active
---

# Thread/185 — Migración a NUC 14 Pro+ (checklist + CC verify scripts)

## §0. Contexto

PC actual: Ryzen 7000, 16GB RAM, c:/ único disco. Sostén actual de
desarrollo RDM. Lenta para multi-CC concurrente.

PC nueva: ASUS NUC 14 Pro+ (Core Ultra 9 185H, 16 cores + NPU, RAM
TBD por Alex 32-96GB).

Objetivo: migrar dev environment + datos personales sin pérdidas
antes de arrancar Run 184. Tiempo estimado: 2-3h focused.

Decisión Alex 2026-05-23: cambiar AHORA, antes del Run 184.

---

## §1. Paso 0 — CRÍTICO NO-NEGOCIABLE (antes de tocar nada)

🔴 Si pierdes esto, NO HAY recovery posible.

| # | Item | Acción | Verificar |
|---|---|---|---|
| 0.1 | **Password manager export** (Bitwarden / 1Password / similar) | Export vault encriptado a OneDrive | Abrir export en visor, contar entradas vs original |
| 0.2 | **2FA / Authenticator backup** | Exportar QRs / backup codes de TODAS las cuentas críticas: Anthropic, GitHub, Cloudflare, Google, MercadoPago, banca, Microsoft | Guardar 2 copias: OneDrive + USB físico |
| 0.3 | **Recovery codes GitHub + Anthropic** | Settings → Security → Recovery codes (descargar nuevos si no los tienes) | OneDrive + USB físico |
| 0.4 | **Microsoft account / Office activation** | Verificar product key Windows 11 Pro de la NUC (vino con licencia) + Office si compraste | Anotado en password manager |

**No avances si 0.1-0.4 no están hechos.** Todo lo demás se puede
recuperar; estos no.

---

## §2. Paso 1 — Audit estado actual (CC ejecuta en PC vieja)

CC debe correr esto desde `c:/dev/rdm/dev/discussion/` en la PC vieja
y commitear resultado a `reports/migration-audit-2026-05-23.md`.

### §2.1 Repos en c:/dev — verificar todo está en GitHub

```powershell
# Script: scripts/migration-audit-repos.ps1
$repos = Get-ChildItem c:/dev -Recurse -Directory -Filter ".git" -Depth 3 |
  ForEach-Object { $_.Parent.FullName }

foreach ($repo in $repos) {
  Write-Host "=== $repo ===" -ForegroundColor Cyan
  Push-Location $repo

  # Estado uncommitted
  $status = git status --porcelain
  if ($status) {
    Write-Host "⚠️  UNCOMMITTED CHANGES:" -ForegroundColor Yellow
    $status
  }

  # Commits sin push
  $unpushed = git log --branches --not --remotes --oneline
  if ($unpushed) {
    Write-Host "⚠️  UNPUSHED COMMITS:" -ForegroundColor Yellow
    $unpushed
  }

  # Branches locales no en remote
  $localBranches = git branch --format='%(refname:short)'
  $remoteBranches = git branch -r --format='%(refname:short)' | ForEach-Object { $_ -replace 'origin/', '' }
  $orphans = Compare-Object $localBranches $remoteBranches -PassThru |
    Where-Object { $_.SideIndicator -eq '<=' }
  if ($orphans) {
    Write-Host "⚠️  LOCAL-ONLY BRANCHES:" -ForegroundColor Yellow
    $orphans
  }

  Pop-Location
}
```

**Acción si encuentra issues:**
- Uncommitted: decide si descartar o commit + push
- Unpushed: `git push` antes de migrar
- Local-only branches: evaluar si son worktrees activos o basura

### §2.2 OneDrive sync status

```powershell
# Script: scripts/migration-audit-onedrive.ps1
$onedrive = "$env:USERPROFILE\OneDrive"

# Archivos modificados en últimos 7 días que NO están sincronizados
Get-ChildItem $onedrive -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
  Where-Object { $_.Attributes -notmatch "Offline" -and $_.Attributes -notmatch "ReparsePoint" } |
  Select-Object FullName, LastWriteTime, Length |
  Format-Table -AutoSize

# Status icon de OneDrive: 
# Verde check = sincronizado
# Azul flechas = en progreso
# Rojo X = error
Write-Host "VERIFICAR MANUAL: icono OneDrive en system tray debe estar VERDE"
```

### §2.3 Archivos sueltos críticos en c:/ (fuera de OneDrive + c:/dev)

```powershell
# Script: scripts/migration-audit-stragglers.ps1
$searchPaths = @(
  "$env:USERPROFILE\Desktop",
  "$env:USERPROFILE\Documents",
  "$env:USERPROFILE\Downloads",
  "c:\temp",
  "c:\tmp",
  "c:\backup",
  "c:\Users\Public\Documents"
)

$criticalExtensions = @(
  '.kdbx', '.pem', '.key', '.ppk', '.p12', '.pfx',  # creds/keys
  '.env', '.envrc',                                  # env configs
  '.json', '.yaml', '.toml',                         # configs probables
  '.xlsx', '.docx', '.pdf',                          # docs business
  '.db', '.sqlite',                                  # databases
  '.bak', '.backup'                                  # backups
)

foreach ($path in $searchPaths) {
  if (Test-Path $path) {
    Write-Host "=== $path ===" -ForegroundColor Cyan
    Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $criticalExtensions -contains $_.Extension } |
      Select-Object FullName, LastWriteTime, Length |
      Sort-Object LastWriteTime -Descending |
      Format-Table -AutoSize
  }
}
```

**Acción:** revisar output. Cualquier archivo modificado en últimos 30
días que NO esté en OneDrive ni en c:/dev → copiar manualmente a OneDrive
antes de seguir.

---

## §3. Paso 2 — Inventory de apps instaladas

### §3.1 Export winget (apps instaladas vía winget o Microsoft Store)

```powershell
# Crea c:/migration/winget-export.json
mkdir c:/migration -ErrorAction SilentlyContinue
winget export -o c:/migration/winget-export.json --include-versions
```

### §3.2 Export apps NO en winget (Programs and Features)

```powershell
# Lista TODO instalado
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
  Where-Object { $_.DisplayName -ne $null } |
  Sort-Object DisplayName |
  Export-Csv c:/migration/apps-installed.csv -NoTypeInformation

# Apps user-scope (HKCU)
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
  Where-Object { $_.DisplayName -ne $null } |
  Sort-Object DisplayName |
  Export-Csv c:/migration/apps-installed-user.csv -NoTypeInformation
```

### §3.3 Versiones de dev tools

```powershell
# Captura versiones exactas para replicar en NUC
@"
node: $(node --version 2>&1)
pnpm: $(pnpm --version 2>&1)
npm: $(npm --version 2>&1)
git: $(git --version 2>&1)
python: $(python --version 2>&1)
gh: $(gh --version 2>&1 | Select-Object -First 1)
wrangler: $(npx wrangler --version 2>&1 | Select-Object -First 1)
claude: $(claude --version 2>&1)
"@ | Out-File c:/migration/dev-tools-versions.txt
```

### §3.4 VS Code extensions

```powershell
code --list-extensions > c:/migration/vscode-extensions.txt
```

---

## §4. Paso 3 — Backup configs críticos

Todo a `c:/migration/configs/`:

```powershell
mkdir c:/migration/configs -ErrorAction SilentlyContinue
$dest = "c:/migration/configs"

# SSH keys (CRÍTICO)
Copy-Item -Recurse "$env:USERPROFILE\.ssh" "$dest/ssh" -ErrorAction Stop

# GitHub CLI auth
Copy-Item -Recurse "$env:USERPROFILE\AppData\Roaming\GitHub CLI" "$dest/gh-cli" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$env:USERPROFILE\AppData\Local\GitHub CLI" "$dest/gh-cli-local" -ErrorAction SilentlyContinue

# Git config global
Copy-Item "$env:USERPROFILE\.gitconfig" "$dest/.gitconfig" -ErrorAction SilentlyContinue

# VS Code user settings
Copy-Item -Recurse "$env:APPDATA\Code\User" "$dest/vscode-user" -ErrorAction SilentlyContinue

# Claude Code config
Copy-Item -Recurse "$env:USERPROFILE\.claude" "$dest/claude" -ErrorAction SilentlyContinue

# Wrangler auth (Cloudflare)
Copy-Item -Recurse "$env:USERPROFILE\.wrangler" "$dest/wrangler" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$env:APPDATA\.wrangler" "$dest/wrangler-appdata" -ErrorAction SilentlyContinue

# pnpm config
Copy-Item -Recurse "$env:APPDATA\npm" "$dest/npm" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$env:LOCALAPPDATA\pnpm" "$dest/pnpm" -ErrorAction SilentlyContinue

# PowerShell profile
if (Test-Path $PROFILE) {
  Copy-Item $PROFILE "$dest/Microsoft.PowerShell_profile.ps1"
}

# Hosts file
Copy-Item "C:\Windows\System32\drivers\etc\hosts" "$dest/hosts" -ErrorAction SilentlyContinue

# Env vars del sistema (read-only export)
[Environment]::GetEnvironmentVariables('User') | ConvertTo-Json -Depth 3 |
  Out-File "$dest/env-vars-user.json"
[Environment]::GetEnvironmentVariables('Machine') | ConvertTo-Json -Depth 3 |
  Out-File "$dest/env-vars-machine.json"

# Chrome profile path reference (NO copiar, son GB y se sincronizan via Google account)
Write-Host "Chrome profile location: $env:LOCALAPPDATA\Google\Chrome\User Data"
Write-Host "→ Sincroniza vía login Google en Chrome nuevo, NO copies"

# Browser bookmarks/passwords export manual
Write-Host "MANUAL: Chrome → chrome://settings/syncSetup → verificar sync ON"
Write-Host "MANUAL: Si no usas sync, Bookmarks → Bookmark manager → Export"
```

**Sube `c:/migration/configs/` a OneDrive carpeta `Migration-NUC-2026-05-23/`**
para que esté disponible en la nueva PC.

---

## §5. Paso 4 — Secrets inventory (NO copiar plaintext)

🔴 NUNCA copies secrets a OneDrive en plaintext. Solo lista qué
necesitas re-generar/re-loguear en la nueva PC:

```markdown
# c:/migration/secrets-checklist.md

## Tokens / API Keys a re-loguear o re-generar

### Auth services
- [ ] GitHub PAT (alexanderhorn6720) → Settings → Developer settings → PATs
- [ ] Anthropic API key (Console)
- [ ] Cloudflare API token (CF dashboard → API Tokens)
- [ ] Cloudflare global API key (si lo usas)

### RDM business integrations
- [ ] Beds24 API key
- [ ] MercadoPago credentials (access token + public key + webhook secret)
- [ ] Resend API key
- [ ] ManyChat API key
- [ ] Telegram bot token (TG_BOT_TOKEN — el del bot pago)
- [ ] AirBnB session cookies (re-login manual en Chrome)

### Storage / infra
- [ ] OneDrive ya re-loguea solo con MS account
- [ ] Google Drive (si lo usas) re-login Google
- [ ] Dropbox / otros

## Donde están guardados los originales (PC vieja)
- Password manager (vault) → todo está ahí, ¿confirmado?
- `.env` files en c:/dev/rdm/dev/bot/apps/* → NO migrar plaintext, usar `wrangler secret put` desde NUC
- `.env` files locales para desarrollo → re-crear leyendo password manager

## Re-login en NUC (orden)
1. Password manager primero (sin esto, todo lo demás es manual)
2. GitHub via gh CLI: `gh auth login`
3. Cloudflare via wrangler: `npx wrangler login`
4. Anthropic: variable env o login Claude Code
5. Resto según se necesite por workstream
```

---

## §6. Paso 5 — Bootstrap NUC nueva

Cuando llegues a la NUC, en este orden:

### §6.1 Windows initial setup
- [ ] Crear cuenta MS (misma que la vieja para sync apps Store)
- [ ] Windows Update completo + reboot
- [ ] Activar Windows 11 Pro (si vino con licencia OEM auto-activa, sino product key)
- [ ] OneDrive sync — espera que baje TODO antes de seguir
- [ ] Verificar que `c:/migration/configs/` apareció (vía OneDrive)

### §6.2 Tools básicos (PowerShell as Admin)

```powershell
# Install winget (probable que ya venga, verifica)
winget --version

# Instalar Git, Node, pnpm, gh, VS Code, Chrome
winget install --id Git.Git -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id pnpm.pnpm -e
winget install --id GitHub.cli -e
winget install --id Microsoft.VisualStudioCode -e
winget install --id Google.Chrome -e
winget install --id Microsoft.PowerShell -e  # PowerShell 7

# Reboot para que PATH se aplique
Restart-Computer
```

### §6.3 Restore configs

```powershell
# Asume c:/migration/configs/ ya descargó vía OneDrive
$src = "$env:USERPROFILE\OneDrive\Migration-NUC-2026-05-23\configs"

# SSH keys (importante permisos)
Copy-Item -Recurse "$src/ssh" "$env:USERPROFILE\.ssh"
# Fix permisos SSH (Windows)
icacls "$env:USERPROFILE\.ssh\id_*" /inheritance:r /grant:r "$($env:USERNAME):F"

# Git config
Copy-Item "$src/.gitconfig" "$env:USERPROFILE\.gitconfig"

# VS Code (después de instalar VS Code y abrirlo una vez)
Copy-Item -Recurse "$src/vscode-user/*" "$env:APPDATA\Code\User\" -Force

# VS Code extensions desde lista
Get-Content "$src/vscode-extensions.txt" | ForEach-Object {
  code --install-extension $_
}

# Claude Code config
Copy-Item -Recurse "$src/claude" "$env:USERPROFILE\.claude"

# PowerShell profile
if (-not (Test-Path $PROFILE)) { New-Item -Type File -Force $PROFILE }
Copy-Item "$src/Microsoft.PowerShell_profile.ps1" $PROFILE
```

### §6.4 Re-loguear servicios

```powershell
# GitHub
gh auth login
# Selecciona: GitHub.com → HTTPS → Y → Login with web browser

# Verificar SSH funciona (si usas SSH para git)
ssh -T git@github.com  # Debe decir "Hi alexanderhorn6720!"

# Cloudflare (cuando llegues a deploys, no urgente)
# cd algun-worker; npx wrangler login
```

### §6.5 Clonar repos

```powershell
mkdir c:/dev/rdm/dev
cd c:/dev/rdm/dev
git clone https://github.com/alexanderhorn6720/rdm-bot.git bot
git clone https://github.com/alexanderhorn6720/rdm-discussion.git discussion
git clone https://github.com/alexanderhorn6720/rdm-platform.git platform
git clone https://github.com/alexanderhorn6720/rdm-data.git data
```

### §6.6 Instalar Claude Code

```powershell
# Vía npm
npm install -g @anthropic-ai/claude-code

# Verificar
claude --version

# Login (abre browser, OAuth con tu cuenta Max)
claude
# Primer launch te pide login
```

### §6.7 Apps de negocio (winget batch)

```powershell
# Usa el export de la vieja
winget import -i "$env:USERPROFILE\OneDrive\Migration-NUC-2026-05-23\winget-export.json" --accept-package-agreements --accept-source-agreements --ignore-unavailable
```

Apps NO en winget (revisar `apps-installed.csv`): instalar manual una
por una según necesidad. NO instales todo de la vieja — usa la
oportunidad para limpiar.

---

## §7. Paso 6 — Smoke test antes de Run 184

```powershell
cd c:/dev/rdm/dev/bot
pnpm install                    # baja deps, ~5 min primera vez
pnpm test --filter worker-bot   # debe pasar igual que en vieja

# Claude Code arranca
cd c:/dev/rdm/dev/discussion
claude
# /status → debe mostrar Sonnet (per-repo setting)
# Probar invocar wc-judge (si ya copiaste .claude/agents/)
```

Si los tests pasan y Claude arranca limpio en los 3 repos → **listos
para Run 184 pre-flight**.

---

## §8. Definition of done

- [ ] §1 paso 0 completo (password manager + 2FA backup)
- [ ] §2 audit ejecutado, output revisado, issues resueltos
- [ ] §3 inventory exportado a OneDrive
- [ ] §4 configs backup en OneDrive
- [ ] §5 secrets checklist generado
- [ ] §6 NUC bootstrap completo
- [ ] §7 smoke test pasa en NUC
- [ ] PC vieja queda como standby (no formatear todavía, por si algo)

---

## §9. Tiempo estimado

| Paso | Tiempo |
|---|---|
| §1 password manager + 2FA | 30 min |
| §2 audit CC (ejecuta scripts) | 15 min |
| §3-4 inventory + configs backup | 30 min |
| §5 secrets checklist | 15 min |
| §6 NUC bootstrap | 60-90 min (depende de internet) |
| §7 smoke test | 20 min |
| **Total** | **2.5-3h focused** |

---

## §10. Anti-patterns migración

- ❌ Formatear la PC vieja antes de que NUC pase smoke test
- ❌ Copiar `.env` plaintext a OneDrive (re-genera secrets vía gestores)
- ❌ Asumir Chrome sync trae todo (passwords sí, pero cookies sesión NO)
- ❌ Saltarse 2FA backup "por flojera" (es el item que más fríe si lo olvidas)
- ❌ Instalar TODO lo de la vieja en la nueva (oportunidad de limpiar)
- ❌ Arrancar Run 184 sin smoke test §7

---

## §11. Si algo sale mal

PC vieja queda intacta. Vuelves a ella, terminas Run 184 desde ahí,
re-intentas migración después. NO hay urgencia real — la NUC en caja
no se daña.

---

**END OF CHECKLIST**
