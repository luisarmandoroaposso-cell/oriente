# Diagnostico de pantallazo azul IRQL_NOT_LESS_OR_EQUAL (0xA) tras cambio de SSD
# Solo lectura: no modifica nada. Ejecutar en PowerShell como Administrador.
# Genera el reporte en el Escritorio: diagnostico-bsod.txt

$out = Join-Path ([Environment]::GetFolderPath('Desktop')) 'diagnostico-bsod.txt'
function Sec($t) { "`n==================== $t ====================" }

& {
    Sec 'SISTEMA'
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, LastBootUpTime | Format-List
    Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory | Format-List
    Get-CimInstance Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate | Format-List

    Sec 'PANTALLAZOS AZULES REGISTRADOS (ultimos 60 dias)'
    Get-WinEvent -FilterHashtable @{LogName='System'; Id=1001; StartTime=(Get-Date).AddDays(-60)} -ErrorAction SilentlyContinue |
        Where-Object { $_.ProviderName -match 'BugCheck|WER' } |
        Select-Object TimeCreated, Message | Format-List

    Sec 'APAGADOS INESPERADOS (Kernel-Power 41, ultimos 60 dias)'
    Get-WinEvent -FilterHashtable @{LogName='System'; Id=41; StartTime=(Get-Date).AddDays(-60)} -ErrorAction SilentlyContinue |
        Select-Object TimeCreated | Format-Table -AutoSize

    Sec 'ERRORES DE HARDWARE WHEA (RAM/CPU/PCIe)'
    Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'} -MaxEvents 20 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, Message | Format-List

    Sec 'ERRORES DE DISCO / CONTROLADORA (ultimos 60 dias)'
    Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2,3; StartTime=(Get-Date).AddDays(-60)} -ErrorAction SilentlyContinue |
        Where-Object { $_.ProviderName -match 'disk|stornvme|storahci|iaStor|Ntfs|volmgr|secnvme' } |
        Select-Object -First 30 TimeCreated, ProviderName, Id, Message | Format-List

    Sec 'MINIDUMPS'
    Get-ChildItem C:\Windows\Minidump -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
    Get-Item C:\Windows\MEMORY.DMP -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize

    Sec 'DISCOS FISICOS Y SALUD'
    Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, HealthStatus, OperationalStatus, FirmwareVersion, Size | Format-Table -AutoSize
    Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue |
        Select-Object DeviceId, Temperature, TemperatureMax, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours | Format-Table -AutoSize

    Sec 'DRIVERS DE ALMACENAMIENTO EN USO'
    Get-CimInstance Win32_PnPSignedDriver |
        Where-Object { $_.DeviceClass -in 'SCSIADAPTER','HDC','DISKDRIVE' } |
        Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate, InfName | Format-Table -AutoSize

    Sec 'DRIVERS DE TERCEROS SOSPECHOSOS (clonacion / almacenamiento)'
    Get-CimInstance Win32_SystemDriver |
        Where-Object { $_.PathName -match 'acronis|tib|snapman|macrium|pssnap|samsung|secnvme|iaStor|rst|aomei|ambakdrv|easeus|minitool' } |
        Select-Object Name, State, StartMode, PathName | Format-Table -AutoSize

    Sec 'PROGRAMAS DE CLONACION INSTALADOS'
    Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'Acronis|Macrium|Magician|Data Migration|AOMEI|EaseUS|MiniTool|Clonezilla|Paragon|True Image' } |
        Select-Object DisplayName, DisplayVersion, InstallDate | Format-Table -AutoSize

    Sec 'MEMORIA RAM'
    Get-CimInstance Win32_PhysicalMemory |
        Select-Object BankLabel, DeviceLocator, Manufacturer, PartNumber, Capacity, Speed, ConfiguredClockSpeed | Format-Table -AutoSize

    Sec 'RESULTADO DE PRUEBAS DE MEMORIA ANTERIORES'
    Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-MemoryDiagnostics-Results'} -MaxEvents 5 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Message | Format-List

    Sec 'CHKDSK C: /scan (solo lectura, en linea)'
    chkdsk C: /scan 2>&1

    Sec 'DISM /CheckHealth (solo lectura)'
    DISM /Online /Cleanup-Image /CheckHealth 2>&1

    Sec 'SFC /verifyonly (solo lectura)'
    sfc /verifyonly 2>&1
} *>&1 | Out-String -Width 300 | Set-Content -Path $out -Encoding UTF8

Write-Host "`nListo. Reporte guardado en: $out" -ForegroundColor Green
