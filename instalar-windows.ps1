# Videos con Claude - instalador para Windows.
#
# Una linea, en PowerShell:
#   irm https://raw.githubusercontent.com/prcontreras23/videos-para-claude/main/instalar-windows.ps1 | iex
# O, con el repo ya bajado:
#   powershell -ExecutionPolicy Bypass -File instalar-windows.ps1
#
# Instala, paso por paso, todo lo que hace falta para hacer videos
# con Claude Code: Git, Node, Python, ffmpeg, whisper y su modelo, Claude Code, los
# plugins y skills de video, los MCP, y la carpeta del proyecto lista para trabajar.
# Lo que ya esta instalado se respeta; se puede correr otra vez sin problema.

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Repo    = "prcontreras23/videos-para-claude"
$Destino = if ($env:VIDEOS_DIR) { $env:VIDEOS_DIR } else { Join-Path $env:USERPROFILE "videos" }
$Total   = 9
$script:Fallas = @()

function Verde($m) { Write-Host "  [OK] $m" -ForegroundColor Green }
function Rojo($m)  { Write-Host "  [X]  $m" -ForegroundColor Red }
function Gris($m)  { Write-Host "  $m" -ForegroundColor DarkGray }
function Paso($n, $m) { Write-Host ""; Write-Host "Paso $n de $Total - $m" -ForegroundColor White }
function Falla($m) { Rojo $m; $script:Fallas += $m }
function Tiene($c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function Pregunta($m) { Read-Host "  $m" }
function Si($m) { $r = Read-Host "  $m [Enter = si, n = no]"; return ($r -ne "n" -and $r -ne "N") }
function Ruta {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
  foreach ($d in @("$env:USERPROFILE\.local\bin", "$env:APPDATA\npm", "$env:LOCALAPPDATA\whisper-cpp")) {
    if ((Test-Path $d) -and ($env:Path -notlike "*$d*")) { $env:Path = "$d;$env:Path" }
  }
}
function RutaUsuario($d) {
  $u = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($u -notlike "*$d*") { [Environment]::SetEnvironmentVariable("Path", ($u.TrimEnd(';') + ";$d"), "User") }
  Ruta
}
function Winget($id, $nombre) {
  Gris "Instalando $nombre..."
  winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements --scope user 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
  }
  Ruta
}

Write-Host ""
Write-Host "Videos con Claude - instalador para Windows" -ForegroundColor White
Gris "Se instala en: $Destino"

# ------------------------------------------------ 1. La computadora y el paquete
Paso 1 "Revisar la computadora"
$os = (Get-CimInstance Win32_OperatingSystem).Caption
Verde "$os ($env:PROCESSOR_ARCHITECTURE)"
$libre = [math]::Round((Get-PSDrive ($env:USERPROFILE.Substring(0,1))).Free / 1GB)
if ($libre -lt 6) {
  Rojo "Quedan $libre GB libres; hacen falta unos 6 GB."
  if (-not (Si "Sigo de todos modos?")) { exit 1 }
} else { Verde "$libre GB libres" }
if (-not (Tiene winget)) {
  Rojo "Falta winget (Instalador de aplicaciones). Instalelo desde la Microsoft Store: 'App Installer', y corra esto otra vez."
  exit 1
}
Verde "winget"

$aqui = if ($PSScriptRoot) { $PSScriptRoot } else { "" }
if ($aqui -and (Test-Path (Join-Path $aqui "plantilla"))) {
  $Fuente = $aqui
} else {
  $Fuente = Join-Path $env:USERPROFILE ".videos-claude-fuente"
  Gris "Bajando el paquete de GitHub..."
  $zip = Join-Path $env:TEMP "videos-claude.zip"
  $ok = $false
  foreach ($url in @("https://github.com/$Repo/archive/refs/heads/main.zip", "https://codeload.github.com/$Repo/zip/refs/heads/main")) {
    try { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing; $ok = $true; break } catch {}
  }
  if (-not $ok) { Rojo "No se pudo bajar el paquete. Revise el internet e intente otra vez."; exit 1 }
  if (Test-Path $Fuente) { Remove-Item -Recurse -Force $Fuente }
  $tmp = Join-Path $env:TEMP "videos-claude-zip"
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  Move-Item (Get-ChildItem $tmp | Select-Object -First 1).FullName $Fuente
}
Verde "Paquete listo"

# ------------------------------------------------ 2. Programas base
Paso 2 "Git, Node, Python y ffmpeg"
Ruta
if (-not (Tiene git))    { Winget "Git.Git" "Git" }
if (-not (Tiene node))   { Winget "OpenJS.NodeJS.LTS" "Node" }
$pyOk = $false
try { $v = & py -3 -c "import sys;print(sys.version_info[1])" 2>$null; if ([int]$v -ge 10) { $pyOk = $true } } catch {}
if (-not $pyOk)          { Winget "Python.Python.3.12" "Python 3.12" }
if (-not (Tiene ffmpeg)) { Winget "Gyan.FFmpeg" "ffmpeg" }
foreach ($h in @("git", "node", "npm", "ffmpeg", "py")) {
  if (Tiene $h) { Verde $h } else { Falla "$h no quedo instalado" }
}

# ------------------------------------------------ 3. whisper.cpp
Paso 3 "whisper (voz a texto)"
$whDir = Join-Path $env:LOCALAPPDATA "whisper-cpp"
if (Tiene whisper-cli) {
  Verde "whisper ya estaba"
} else {
  Gris "Bajando whisper.cpp (version oficial de GitHub)..."
  try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/ggml-org/whisper.cpp/releases/latest" -UseBasicParsing
    $asset = $rel.assets | Where-Object { $_.name -eq "whisper-bin-x64.zip" } | Select-Object -First 1
    $wz = Join-Path $env:TEMP "whisper-bin-x64.zip"
    Invoke-WebRequest $asset.browser_download_url -OutFile $wz -UseBasicParsing
    $wt = Join-Path $env:TEMP "whisper-bin"
    if (Test-Path $wt) { Remove-Item -Recurse -Force $wt }
    Expand-Archive $wz -DestinationPath $wt -Force
    $exe = Get-ChildItem $wt -Recurse -Filter "whisper-cli.exe" | Select-Object -First 1
    if (Test-Path $whDir) { Remove-Item -Recurse -Force $whDir }
    New-Item -ItemType Directory -Force -Path $whDir | Out-Null
    Copy-Item (Join-Path $exe.DirectoryName "*") $whDir -Recurse -Force
    RutaUsuario $whDir
  } catch {}
  if (Tiene whisper-cli) { Verde "whisper" } else { Falla "whisper no quedo instalado" }
}

# ------------------------------------------------ 4. Claude Code
Paso 4 "Claude Code"
if (Tiene claude) {
  Verde "Claude Code ya estaba"
} else {
  Gris "Instalando Claude Code (instalador oficial)..."
  try { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression | Out-Null } catch {}
  RutaUsuario "$env:USERPROFILE\.local\bin"
  if (Tiene claude) { Verde "Claude Code instalado" } else { Falla "Claude Code no quedo instalado: https://claude.com/claude-code" }
}

# ------------------------------------------------ 5. Plugins y skills
Paso 5 "Plugins y skills de video para Claude"
if (Tiene claude) {
  foreach ($m in @("anthropics/claude-plugins-official", "remotion-dev/claude-code-plugin", "bradautomates/claude-video")) {
    claude plugin marketplace add $m 2>&1 | Out-Null
  }
  foreach ($p in @("remotion@remotion", "watch@claude-video", "frontend-design@claude-plugins-official")) {
    $n = $p.Split("@")[0]
    claude plugin install $p 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -or ((claude plugin list 2>$null) -match $n)) { Verde "plugin $n" } else { Falla "plugin $n" }
  }
  Gris "Skills de Remotion (remotion-dev/skills)..."
  npx.cmd -y skills add remotion-dev/skills -g -a claude-code -s '*' -y --copy 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { Verde "skills remotion-*" } else { Falla "skills de Remotion" }
} else {
  Falla "Sin Claude Code no se pueden poner los plugins; corra el instalador otra vez cuando este."
}

# ------------------------------------------------ 6. MCP y servicios
Paso 6 "MCP y servicios (voz, transcripcion, clips)"
if (Tiene claude) {
  claude mcp remove whisper -s user 2>&1 | Out-Null
  claude mcp add --scope user whisper -- cmd /c npx -y whisper-mcp 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { Verde "MCP whisper (transcribir audios desde Claude)" } else { Falla "MCP whisper" }

  Write-Host ""
  Gris "La voz se hace en ElevenLabs. Hay dos formas:"
  Gris "  a) En la web elevenlabs.io con Claude en Chrome (no hace falta clave)."
  Gris "  b) Con el MCP de ElevenLabs, que necesita una clave de API (elevenlabs.io -> Developers -> API Keys)."
  $clave = Pregunta "Si tiene la clave de ElevenLabs, peguela aqui (Enter para saltar)"
  if ($clave) {
    if (-not (Tiene uvx)) { Winget "astral-sh.uv" "uv" }
    claude mcp remove elevenlabs -s user 2>&1 | Out-Null
    claude mcp add --scope user elevenlabs -e "ELEVENLABS_API_KEY=$clave" -- uvx elevenlabs-mcp 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Verde "MCP elevenlabs" } else { Falla "MCP elevenlabs" }
  } else { Gris "Sin MCP de ElevenLabs: la voz se genera en la web." }
  $clave = $null

  Write-Host ""
  if (Si "Instalo Higgsfield (clips animados con IA; es de pago y es el ultimo recurso)?") {
    npm.cmd install -g @higgsfield/cli 2>&1 | Out-Null
    $a = $LASTEXITCODE
    npx.cmd -y skills add higgsfield-ai/skills -g -a claude-code -s '*' -y --copy 2>&1 | Out-Null
    if ($a -eq 0 -and $LASTEXITCODE -eq 0) { Verde "Higgsfield CLI y skills (entrar luego con: higgsfield auth login)" } else { Falla "Higgsfield" }
  }
}

# ------------------------------------------------ 7. Proyecto
Paso 7 "Carpeta del proyecto de videos"
if (Test-Path (Join-Path $Destino "package.json")) {
  Verde "Ya existe $Destino; no se toca lo que hay (solo se completan dependencias)"
} else {
  New-Item -ItemType Directory -Force -Path $Destino | Out-Null
  Copy-Item (Join-Path $Fuente "plantilla\*") $Destino -Recurse -Force
  Copy-Item (Join-Path $Fuente "plantilla\.gitignore") $Destino -Force -ErrorAction SilentlyContinue
  Verde "Proyecto copiado a $Destino"
}
foreach ($d in @("models", "out", "tmp", "guiones")) { New-Item -ItemType Directory -Force -Path (Join-Path $Destino $d) | Out-Null }
Push-Location $Destino
if (Tiene git) { git init -q 2>&1 | Out-Null }
Gris "Instalando Remotion (npm install)..."
npm.cmd install --no-audit --no-fund 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Verde "Remotion" } else { Falla "npm install en $Destino" }
Gris "Bajando el Chrome de Remotion (para capturas y render)..."
npx.cmd remotion browser ensure 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Verde "Chrome de Remotion" } else { Falla "Chrome de Remotion" }
Gris "numpy para los scripts de voz..."
py -3 -m pip install --user -q numpy 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Verde "numpy" } else { Falla "numpy (py -3 -m pip install --user numpy)" }
Pop-Location

# ------------------------------------------------ 8. Modelo de whisper
Paso 8 "Modelo de voz a texto (whisper, espanol)"
$models = Join-Path $Destino "models"
$hay = Get-ChildItem $models -Filter "ggml-*.bin" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($hay) {
  Verde "Ya hay modelo: $($hay.Name)"
} else {
  Gris "medium = el que se usa (1.5 GB, mas preciso) - small = mas liviano (466 MB)"
  $r = Pregunta "Cual bajo? [Enter = medium, s = small]"
  $M = if ($r -eq "s" -or $r -eq "S") { "small" } else { "medium" }
  Gris "Bajando ggml-$M.bin (unos minutos)..."
  $part = Join-Path $models "ggml-$M.bin.part"
  try {
    Invoke-WebRequest "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$M.bin" -OutFile $part -UseBasicParsing
    Move-Item $part (Join-Path $models "ggml-$M.bin") -Force
    Verde "Modelo $M"
  } catch { Remove-Item $part -ErrorAction SilentlyContinue; Falla "Modelo de whisper" }
}

# ------------------------------------------------ 9. Prueba
Paso 9 "Prueba final"
Push-Location $Destino
npx.cmd remotion still Prueba out/prueba.png --frame=60 2>&1 | Out-Null
if (Test-Path "out\prueba.png") { Verde "Remotion renderiza (out\prueba.png)" } else { Falla "La prueba de render no salio (npx remotion still Prueba out/prueba.png)" }
Pop-Location
whisper-cli --help 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Verde "whisper responde" } else { Falla "whisper-cli no responde" }

Write-Host ""
if ($script:Fallas.Count -eq 0) {
  Write-Host "Todo quedo instalado." -ForegroundColor Green
} else {
  Write-Host "Quedo instalado, con $($script:Fallas.Count) pendiente(s):" -ForegroundColor Yellow
  foreach ($f in $script:Fallas) { Write-Host "  - $f" }
  Write-Host "  Puede correr el instalador otra vez; lo que ya esta no se repite."
}
Write-Host @"

Para empezar (en una ventana NUEVA de PowerShell):
  cd "$Destino"; claude

  Y pidale el video que quiere: un tutorial, una promo, un video con subtitulos...
  Claude sigue el metodo de CLAUDE.md: guion -> material -> voz -> render.

  Vista previa:  cd "$Destino"; npm run dev
  Para la voz en la web: instale Claude en Chrome (https://claude.ai/chrome) y entre a elevenlabs.io.

"@
