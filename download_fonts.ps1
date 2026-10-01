# Force PowerShell to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$null = New-Item -ItemType Directory -Force -Path 'assets/fonts'

# URL of the main Nunito variable font
$url = "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf"
$path = "assets/fonts/Nunito.ttf"

try {
    Write-Host "Downloading Nunito variable font from $url..."
    Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction Stop
    
    $size = (Get-Item $path).Length
    if ($size -gt 5000) {
        Write-Host "Success: Nunito.ttf ($size bytes)"
    } else {
        Remove-Item $path
        Write-Host "Failed: file is too small ($size bytes)"
    }
} catch {
    Write-Host "Error downloading Nunito: $_"
    if (Test-Path $path) { Remove-Item $path }
}
