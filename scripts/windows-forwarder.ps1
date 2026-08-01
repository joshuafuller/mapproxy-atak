param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("install", "start", "stop", "status")]
    [string]$Action,

    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

function Get-CaddyCommand {
    $command = Get-Command caddy.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $packagePath = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\CaddyServer.Caddy_*\caddy.exe"
    $package = Get-ChildItem -Path $packagePath -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($package) {
        return $package.FullName
    }

    throw "Caddy is not installed. Run 'make windows-forwarder-install' first."
}

switch ($Action) {
    "install" {
        try {
            $installed = Get-CaddyCommand
            Write-Host "Caddy is already installed: $installed"
            return
        }
        catch {
            # Continue to the package installation below.
        }
        winget install --exact --id CaddyServer.Caddy --accept-package-agreements --accept-source-agreements
    }
    "start" {
        if (-not $ConfigPath -or -not (Test-Path -LiteralPath $ConfigPath)) {
            throw "Generated Caddyfile not found. Run 'make configure-windows-forwarder HOST=<LAN-IP>' first."
        }
        $caddy = Get-CaddyCommand
        & $caddy validate --config $ConfigPath --adapter caddyfile
        if (Get-Process caddy -ErrorAction SilentlyContinue) {
            & $caddy reload --config $ConfigPath --adapter caddyfile
        }
        else {
            & $caddy start --config $ConfigPath --adapter caddyfile
        }
    }
    "stop" {
        if (-not (Get-Process caddy -ErrorAction SilentlyContinue)) {
            Write-Host "Windows forwarder is already stopped."
            return
        }
        $caddy = Get-CaddyCommand
        & $caddy stop
    }
    "status" {
        $process = Get-Process caddy -ErrorAction SilentlyContinue
        if (-not $process) {
            Write-Host "Windows forwarder is stopped."
            exit 1
        }
        $process | Select-Object Id, ProcessName, StartTime
    }
}
