# RondaVizinho - instalacao em uma linha (Windows 10/11).
# No PowerShell (pode ser sem admin; ele pede elevacao sozinho):
#   irm https://rondavizinho.com.br/get.ps1 | iex
#
# O que ele faz: baixa o codigo, extrai para "Program Files\RondaVizinho" e
# roda o instalador (Python + ffmpeg + servico) - ao final abre o assistente
# no navegador, que acha seu DVR e configura tudo passo a passo. (Os DADOS -
# config e fotos - ficam em ProgramData\Vigia, separados do codigo.)
#
# ATENCAO (manutencao): este arquivo e consumido por "irm | iex", que NAO
# entende BOM nem encoding - mantenha 100%% ASCII (sem acentos).
#
# Variaveis de ambiente (testes/avancado): RONDA_ZIP (origem do codigo),
# RONDA_DEST (pasta de instalacao), RONDA_DADOS (pasta de dados/config),
# RONDA_SEM_TAREFAS=1 (nao agenda nada).
$ErrorActionPreference = "Stop"
$URL_ESTE = "https://rondavizinho.com.br/get.ps1"
$zipUrl = if ($env:RONDA_ZIP) { $env:RONDA_ZIP }
          else { "https://github.com/pedrocalixto/rondavizinho/archive/refs/heads/master.zip" }
$dest = if ($env:RONDA_DEST) { $env:RONDA_DEST }
        else { Join-Path $env:ProgramFiles "RondaVizinho" }

Write-Host ""
Write-Host "  RondaVizinho - o vigia inteligente da sua rua" -ForegroundColor Blue
Write-Host ""

# eleva a administrador se preciso (reabre este mesmo comando elevado)
$ehAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $ehAdmin) {
    Write-Host "Preciso de permissao de administrador - confirme na janela que vai abrir."
    $cmd = "`$env:RONDA_ZIP='$($env:RONDA_ZIP)'; `$env:RONDA_DEST='$($env:RONDA_DEST)'; " +
           "`$env:RONDA_DADOS='$($env:RONDA_DADOS)'; " +
           "`$env:RONDA_SEM_TAREFAS='$($env:RONDA_SEM_TAREFAS)'; irm '$URL_ESTE' | iex"
    # -NoExit mantem a janela elevada aberta ao fim (o leigo ve o resultado ou o erro)
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd
    return
}

# baixa o codigo
$tmpZip = Join-Path $env:TEMP "rondavizinho.zip"
$tmpDir = Join-Path $env:TEMP "rondavizinho-extraido"
Write-Host "Baixando o RondaVizinho..."
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
} catch {
    Write-Host ""
    Write-Host "Nao consegui baixar o codigo. Verifique sua internet e tente de novo;" -ForegroundColor Yellow
    Write-Host "se persistir, abra uma issue em:" -ForegroundColor Yellow
    Write-Host "  https://github.com/pedrocalixto/rondavizinho/issues" -ForegroundColor Yellow
    return
}

# extrai e instala em $dest (dados/config ficam em ProgramData, nao sao tocados)
if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
$raiz = Get-ChildItem $tmpDir -Directory | Select-Object -First 1   # pasta repo-master do zip
if (Test-Path $dest) {
    # atualizacao: para as tarefas antes de trocar o codigo. cmd /c isola o
    # schtasks do $ErrorActionPreference='Stop' (se a tarefa nao existe, o erro
    # nativo derrubaria o script) e engole a saida.
    foreach ($t in "VigiaVizinhanca", "VigiaWeb") {
        cmd /c "schtasks /End /TN $t >nul 2>&1"
    }
    Remove-Item $dest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item (Join-Path $raiz.FullName "*") $dest -Recurse -Force
Remove-Item $tmpZip, $tmpDir -Recurse -Force

# delega ao instalador do proprio codigo (esse sim, UTF-8 com BOM e acentos)
$argumentos = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $dest "windows\install.ps1"))
if ($env:RONDA_SEM_TAREFAS -eq "1") { $argumentos += "-SemTarefas" }
if ($env:RONDA_DADOS) { $argumentos += @("-Dados", $env:RONDA_DADOS) }
& powershell @argumentos
# SEM 'exit' aqui: um exit explicito fecha a janela mesmo com -NoExit, e o
# usuario perderia a mensagem final / os erros. -NoExit mantem a janela aberta.
Write-Host ""
Write-Host "Pode fechar esta janela quando terminar de ler." -ForegroundColor DarkGray
