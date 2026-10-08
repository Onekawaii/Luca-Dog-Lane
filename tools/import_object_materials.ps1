param([string]$Repository = 'C:\Users\jmgar\Downloads\SpiralFieldGame')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$assetRoot = Join-Path $Repository 'assets\materials'
$downloadRoot = Join-Path ([IO.Path]::GetTempPath()) ('spiral-materials-' + [Guid]::NewGuid().ToString('N'))
if (!(Test-Path -LiteralPath $assetRoot)) { New-Item -ItemType Directory -Path $assetRoot | Out-Null }
New-Item -ItemType Directory -Path $downloadRoot | Out-Null
$materialIds = @('Wood066', 'Rock035', 'Grass005', 'Fabric030', 'Bricks005', 'Metal049A')
$archiveHashes = @{
    Wood066='DF2226DFEC75777B4E4AD9DB0694CFAF9A04588DCB8A4F9B4687D79FD3355C51'
    Rock035='C5E4DBD7D5555734498834C1E09B799EF3D1F00C61FE08C0D953B93A8FB1BB95'
    Grass005='58A7FB7F32C44A86879483325B62781D04E0AB8F70B0F70EDE36C8F1726F8A22'
    Fabric030='82D4D00CCF901CF4707C5489005945AB8574933FC60437E26C6737F0436699E0'
    Bricks005='5D7B5584245FFA94EB74B9173C412E33A7CB012B75632A5125B426F9FF9FA0F6'
    Metal049A='4F6A79E535261AB55CC6FEEFED0037124885720CE7B781FC2EFA3FA22792AF42'
}
foreach ($materialId in $materialIds) {
    $catalog = Invoke-RestMethod ("https://ambientcg.com/api/v2/full_json?id=$materialId&include=downloadData")
    $asset = $catalog.foundAssets | Where-Object assetId -eq $materialId | Select-Object -First 1
    if (!$asset) { throw "Missing official material $materialId" }
    $download = $asset.downloadFolders.default.downloadFiletypeCategories.zip.downloads | Where-Object attribute -eq '1K-JPG' | Select-Object -First 1
    if (!$download) { throw "Missing 1K-JPG package $materialId" }
    $archivePath = Join-Path $downloadRoot $download.fileName
    Invoke-WebRequest -Uri $download.downloadLink -OutFile $archivePath
    if ((Get-Item -LiteralPath $archivePath).Length -ne $download.size) { throw "Archive length mismatch: $materialId" }
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $archiveHashes[$materialId]) { throw "Pinned archive hash mismatch: $materialId" }
    Write-Output ("SOURCE {0} {1} SHA256={2}" -f $materialId, $download.downloadLink, (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash)
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($suffix in @('Color', 'NormalGL', 'Roughness')) {
            $expectedName = "${materialId}_1K-JPG_${suffix}.jpg"
            $entry = $archive.Entries | Where-Object Name -eq $expectedName | Select-Object -First 1
            if (!$entry) { throw "Missing map $expectedName" }
            $destination = Join-Path $assetRoot $expectedName
            if (Test-Path -LiteralPath $destination) { throw "Refusing to overwrite existing material $destination" }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $false)
            Write-Output ("IMPORTED {0} SHA256={1}" -f $expectedName, (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash)
        }
    } finally { $archive.Dispose() }
}
Write-Output "Material acquisition complete; archives preserved at $downloadRoot"
