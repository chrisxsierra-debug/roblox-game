Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       ROBLOX + GITHUB AUTOMATIC LIVE SYNC" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Checking GitHub every 10 seconds for collaborator updates..." -ForegroundColor Gray
Write-Host "When your friend pushes to GitHub, this will automatically" -ForegroundColor Gray
Write-Host "pull their changes and Rojo will sync them into Studio live!" -ForegroundColor Gray
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

while ($true) {
    try {
        git fetch origin main -q
        $local = (git rev-parse HEAD).Trim()
        $remote = (git rev-parse origin/main).Trim()
        
        if ($local -ne $remote) {
            $time = Get-Date -Format "HH:mm:ss"
            Write-Host "[$time] New update detected on GitHub! Syncing..." -ForegroundColor Yellow
            $result = git pull --rebase origin main 2>&1
            Write-Host $result -ForegroundColor Green
            Write-Host "[$time] -> Synced into Roblox Studio live via Rojo!" -ForegroundColor Cyan
            Write-Host ""
        }
    } catch {
        # Silent ignore transient network errors
    }
    Start-Sleep -Seconds 10
}
