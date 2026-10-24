param([ValidateSet('install','dev','check','build','preview','qa')][string]$Task = 'dev')
$ErrorActionPreference = 'Stop'
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
$taskCandidates = @()
$taskSystemNode = Get-Command node.exe -ErrorAction SilentlyContinue
if ($taskSystemNode) { $taskCandidates += $taskSystemNode.Source }
$taskBundledNode = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
if (Test-Path -LiteralPath $taskBundledNode) { $taskCandidates += $taskBundledNode }
$taskNode = $null
foreach ($taskCandidate in $taskCandidates) {
  $taskVersion = [version]((& $taskCandidate --version).TrimStart('v'))
  if (($taskVersion.Major -eq 20 -and $taskVersion -ge [version]'20.19.0') -or
      ($taskVersion.Major -eq 22 -and $taskVersion -ge [version]'22.12.0') -or
      $taskVersion.Major -gt 22) { $taskNode = $taskCandidate; break }
}
if (!$taskNode) { throw 'Node.js 20.19+ or 22.12+ is required. Node.js 24 LTS is recommended.' }
$taskNpm = (Get-Command npm.cmd -ErrorAction Stop).Source
$taskOriginalPath = $env:PATH
Push-Location $taskProjectRoot
try {
  $env:PATH = (Split-Path -Parent $taskNode) + [IO.Path]::PathSeparator + $taskOriginalPath
  Write-Host "Untouch Telegram: $Task, Node $(& $taskNode --version)"
  if ($Task -eq 'install') {
    $taskNpmVersion = [version](& $taskNpm --version)
    if ($taskNpmVersion.Major -lt 11) {
      # npm 10 crashes while resolving the current Vite optional peer graph.
      # Run a pinned installer without changing the global npm installation.
      & (Get-Command npx.cmd -ErrorAction Stop).Source --yes npm@11.21.1 install --ignore-scripts --no-fund
    } else { & $taskNpm install --ignore-scripts --no-fund }
  } else { & $taskNpm run $Task }
  $taskExitCode = $LASTEXITCODE
} finally {
  $env:PATH = $taskOriginalPath
  Pop-Location
}
exit $taskExitCode
