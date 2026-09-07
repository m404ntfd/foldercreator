param()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppName = 'J&M Apparel Shirt Design Folder Builder'
$script:AppVersion = [version]'2.2.0'
$processExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$processName = [System.IO.Path]::GetFileNameWithoutExtension($processExecutable)
$script:ProgramDirectory = if ($processName -in @('powershell', 'powershell_ise', 'pwsh')) { $PSScriptRoot } else { Split-Path -Parent $processExecutable }
$script:DataDirectory = Join-Path $env:APPDATA 'ShirtDesignFolderBuilder'
$script:SettingsPath = Join-Path $script:DataDirectory 'settings.json'
$script:CacheDirectory = Join-Path $script:DataDirectory 'Cache'
$script:BrandCatalogDirectory = Join-Path $script:DataDirectory 'BrandCatalog'
$script:Settings = $null
$script:CreateColorChoices = @()

function New-DefaultSettings {
    return [pscustomobject]@{
        Version = 2
        DefaultDirectory = [Environment]::GetFolderPath('MyDocuments')
        GitHubOwner = 'm404ntfd'
        GitHubRepository = 'foldercreator'
        UpdateAssetName = 'ShirtFolderSetup.exe'
        CheckForUpdatesOnLaunch = $true
        Categories = @(
            [pscustomobject]@{
                Id = 1
                Name = 'General'
                Subcategories = @([pscustomobject]@{ Id = 1; Name = 'General' })
            }
        )
        SizeFolders = @(
            'Adult - S', 'Adult - M', 'Adult - L', 'Adult - XL', 'Adult - 2XL',
            'Adult - 3XL', 'Child - S', 'Child - M', 'Child - L'
        )
        FolderTemplate = @(
            'Colors Offered',
            'Final Print Files\{SIZE FILE SET}',
            'Final Print Canva Files\{SIZE FILE SET}',
            'Final TIFFs\{SIZE FILE SET}',
            'Online Images\Shirt Only',
            'Online Images\With People',
            'Original PNG or JPG'
        )
        BrandCatalog = @()
        CreatedDesigns = @()
    }
}

function Ensure-ArrayProperty($Object, [string]$Name) {
    if ($null -eq $Object.$Name) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue @() -Force
    } else {
        $Object.$Name = @($Object.$Name)
    }
}

function Ensure-SettingProperty($Object, [string]$Name, $DefaultValue) {
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $DefaultValue
    }
}

function Load-Settings {
    if (-not (Test-Path -LiteralPath $script:DataDirectory)) {
        New-Item -ItemType Directory -Path $script:DataDirectory -Force | Out-Null
    }
    if (Test-Path -LiteralPath $script:SettingsPath) {
        try {
            $loaded = Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Ensure-ArrayProperty $loaded 'Categories'
            Ensure-ArrayProperty $loaded 'SizeFolders'
            Ensure-ArrayProperty $loaded 'FolderTemplate'
            Ensure-ArrayProperty $loaded 'BrandCatalog'
            Ensure-ArrayProperty $loaded 'CreatedDesigns'
            Ensure-SettingProperty $loaded 'GitHubOwner' 'm404ntfd'
            Ensure-SettingProperty $loaded 'GitHubRepository' 'foldercreator'
            Ensure-SettingProperty $loaded 'UpdateAssetName' 'ShirtFolderSetup.exe'
            Ensure-SettingProperty $loaded 'CheckForUpdatesOnLaunch' $true
            if ([string]::IsNullOrWhiteSpace([string]$loaded.GitHubOwner)) { $loaded.GitHubOwner = 'm404ntfd' }
            if ([string]::IsNullOrWhiteSpace([string]$loaded.GitHubRepository)) { $loaded.GitHubRepository = 'foldercreator' }
            if ([string]$loaded.UpdateAssetName -eq 'ShirtFolderProgram.zip') { $loaded.UpdateAssetName = 'ShirtFolderSetup.exe' }
            foreach ($category in $loaded.Categories) { Ensure-ArrayProperty $category 'Subcategories' }
            foreach ($brand in $loaded.BrandCatalog) {
                Ensure-ArrayProperty $brand 'Colors'
                if ([string]::IsNullOrWhiteSpace([string]$brand.Id)) {
                    $brand | Add-Member -NotePropertyName Id -NotePropertyValue ([guid]::NewGuid().ToString('N')) -Force
                }
                foreach ($color in $brand.Colors) {
                    if ([string]::IsNullOrWhiteSpace([string]$color.Id)) {
                        $color | Add-Member -NotePropertyName Id -NotePropertyValue ([guid]::NewGuid().ToString('N')) -Force
                    }
                }
            }
            return $loaded
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "The settings file could not be read. Default settings will be used.`r`n`r`n$($_.Exception.Message)",
                $script:AppName,
                'OK',
                'Warning'
            ) | Out-Null
        }
    }
    return New-DefaultSettings
}

function Save-Settings {
    if (-not (Test-Path -LiteralPath $script:DataDirectory)) {
        New-Item -ItemType Directory -Path $script:DataDirectory -Force | Out-Null
    }
    $json = $script:Settings | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($script:SettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Set-UpdateStatus([string]$Text, [System.Drawing.Color]$Color = [System.Drawing.Color]::DimGray) {
    if ($null -ne $lblUpdateStatus) {
        $lblUpdateStatus.Text = $Text
        $lblUpdateStatus.ForeColor = $Color
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Start-AppUpdate($Release) {
    $assetName = [string]$script:Settings.UpdateAssetName
    $asset = @($Release.assets) | Where-Object { [string]$_.name -eq $assetName } | Select-Object -First 1
    if ($null -eq $asset) {
        throw "The latest release does not contain an asset named '$assetName'. Upload the Windows installer to the GitHub release using that exact filename, or change the asset name in Update Settings."
    }

    $stage = Join-Path $env:TEMP ("ShirtFolderUpdate_" + [guid]::NewGuid().ToString('N'))
    if ([System.IO.Path]::GetExtension($assetName) -ieq '.exe') {
        New-Item -ItemType Directory -Path $stage -Force -ErrorAction Stop | Out-Null
        $installerPath = Join-Path $stage $assetName
        Set-UpdateStatus 'Downloading Windows installer...' ([System.Drawing.Color]::FromArgb(36, 99, 166))
        Invoke-WebRequest -Uri ([string]$asset.browser_download_url) -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
        Unblock-File -LiteralPath $installerPath -ErrorAction SilentlyContinue
        Set-UpdateStatus 'Starting installer...'
        Start-Process -FilePath $installerPath -Verb RunAs
        $form.Close()
        return
    }

    $zipPath = Join-Path $stage 'update.zip'
    $extractPath = Join-Path $stage 'extracted'
    New-Item -ItemType Directory -Path $extractPath -Force -ErrorAction Stop | Out-Null
    Set-UpdateStatus 'Downloading update...' ([System.Drawing.Color]::FromArgb(36, 99, 166))
    Invoke-WebRequest -Uri ([string]$asset.browser_download_url) -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

    $sourcePath = $extractPath
    $nested = Join-Path $extractPath 'ShirtDesignFolderBuilder'
    if (Test-Path -LiteralPath $nested -PathType Container) { $sourcePath = $nested }
    if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'ShirtDesignFolderBuilder.ps1'))) {
        throw 'The release ZIP does not contain ShirtDesignFolderBuilder.ps1 in the expected location.'
    }

    $helperPath = Join-Path $stage 'Apply-ShirtFolderUpdate.ps1'
    $helperScript = @'
param(
    [string]$Source,
    [string]$Destination,
    [string]$Stage,
    [int]$AppProcessId
)
try {
    Wait-Process -Id $AppProcessId -Timeout 30 -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Destination -Recurse -Force
    Start-Process -FilePath (Join-Path $Destination 'Launch Shirt Design Folder Builder.bat')
    Start-Sleep -Seconds 2
} finally {
    Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue
}
'@
    [System.IO.File]::WriteAllText($helperPath, $helperScript, [System.Text.UTF8Encoding]::new($false))
    $processId = [System.Diagnostics.Process]::GetCurrentProcess().Id
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$helperPath`" -Source `"$sourcePath`" -Destination `"$($script:ProgramDirectory)`" -Stage `"$stage`" -AppProcessId $processId"
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden
    $form.Close()
}

function Check-GitHubUpdates([bool]$Automatic = $false) {
    $owner = ([string]$script:Settings.GitHubOwner).Trim()
    $repository = ([string]$script:Settings.GitHubRepository).Trim()
    if (-not $owner -or -not $repository) {
        Set-UpdateStatus "Automatic updates are not configured. Current version: $($script:AppVersion)"
        if (-not $Automatic) {
            [System.Windows.Forms.MessageBox]::Show('Enter the GitHub owner and repository, save the settings, and try again.', $script:AppName, 'OK', 'Information') | Out-Null
        }
        return
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Set-UpdateStatus 'Checking GitHub for updates...' ([System.Drawing.Color]::FromArgb(36, 99, 166))
        $uri = "https://api.github.com/repos/$owner/$repository/releases/latest"
        $headers = @{ 'User-Agent' = 'ShirtDesignFolderBuilder'; 'Accept' = 'application/vnd.github+json' }
        $release = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        $tagText = (([string]$release.tag_name).Trim() -replace '^[vV]', '')
        try { $latestVersion = [version]$tagText } catch { throw "The latest GitHub release tag '$($release.tag_name)' is not a version number. Use a tag such as v2.1.0." }

        if ($latestVersion -le $script:AppVersion) {
            Set-UpdateStatus "You have the latest version ($($script:AppVersion))." ([System.Drawing.Color]::FromArgb(34, 120, 74))
            if (-not $Automatic) { [System.Windows.Forms.MessageBox]::Show("You have the latest version ($($script:AppVersion)).", $script:AppName, 'OK', 'Information') | Out-Null }
            return
        }

        Set-UpdateStatus "Version $latestVersion is available." ([System.Drawing.Color]::FromArgb(36, 99, 166))
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "A new version is available.`r`n`r`nInstalled: $($script:AppVersion)`r`nAvailable: $latestVersion`r`n`r`nDownload, install, and restart now?",
            $script:AppName,
            'YesNo',
            'Information'
        )
        if ($answer -eq 'Yes') { Start-AppUpdate $release }
    } catch {
        Set-UpdateStatus "Update check failed: $($_.Exception.Message)" ([System.Drawing.Color]::FromArgb(170, 55, 55))
        if (-not $Automatic) {
            [System.Windows.Forms.MessageBox]::Show("The update check could not be completed.`r`n`r`n$($_.Exception.Message)", $script:AppName, 'OK', 'Error') | Out-Null
        }
    }
}

function Format-Number([int]$Number) {
    if ($Number -lt 100) { return $Number.ToString('00') }
    return $Number.ToString()
}

function Sanitize-DesignName([string]$Name) {
    $clean = $Name.Trim()
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $clean = $clean.Replace([string]$char, '')
    }
    $clean = $clean.Trim().TrimEnd('.')
    return $clean
}

function Expand-FolderTemplate {
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($entryObject in @($script:Settings.FolderTemplate)) {
        $entry = ([string]$entryObject).Trim().TrimStart('\').TrimEnd('\')
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        if ($entry -match '\{SIZE FILE SET\}') {
            foreach ($sizeObject in @($script:Settings.SizeFolders)) {
                $size = ([string]$sizeObject).Trim()
                if (-not [string]::IsNullOrWhiteSpace($size)) {
                    $result.Add($entry.Replace('{SIZE FILE SET}', $size))
                }
            }
        } else {
            $result.Add($entry)
        }
    }
    return @($result | Select-Object -Unique)
}

function Get-NextDesignNumber([int]$CategoryId, [int]$SubcategoryId, [string]$Destination) {
    $highest = 0
    foreach ($design in @($script:Settings.CreatedDesigns)) {
        if ([int]$design.CategoryId -eq $CategoryId -and [int]$design.SubcategoryId -eq $SubcategoryId) {
            if ([int]$design.DesignNumber -gt $highest) { $highest = [int]$design.DesignNumber }
        }
    }

    if (Test-Path -LiteralPath $Destination -PathType Container) {
        $cat = [regex]::Escape((Format-Number $CategoryId))
        $sub = [regex]::Escape((Format-Number $SubcategoryId))
        $pattern = "^$cat-$sub-(\d+)\s+-\s+"
        Get-ChildItem -LiteralPath $Destination -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -match $pattern) {
                $value = [int]$Matches[1]
                if ($value -gt $highest) { $highest = $value }
            }
        }
    }
    return $highest + 1
}

function Get-SelectedCategory {
    if ($cmbCategory.SelectedIndex -lt 0) { return $null }
    return @($script:Settings.Categories)[$cmbCategory.SelectedIndex]
}

function Get-SelectedSubcategory {
    $category = Get-SelectedCategory
    if ($null -eq $category -or $cmbSubcategory.SelectedIndex -lt 0) { return $null }
    return @($category.Subcategories)[$cmbSubcategory.SelectedIndex]
}

function Update-CreateSubcategories {
    $cmbSubcategory.Items.Clear()
    $category = Get-SelectedCategory
    if ($null -ne $category) {
        foreach ($subcategory in @($category.Subcategories)) {
            [void]$cmbSubcategory.Items.Add("$(Format-Number ([int]$subcategory.Id)) - $($subcategory.Name)")
        }
    }
    if ($cmbSubcategory.Items.Count -gt 0) { $cmbSubcategory.SelectedIndex = 0 }
    Update-Preview
}

function Update-CreateCategories {
    $cmbCategory.Items.Clear()
    foreach ($category in @($script:Settings.Categories)) {
        [void]$cmbCategory.Items.Add("$(Format-Number ([int]$category.Id)) - $($category.Name)")
    }
    if ($cmbCategory.Items.Count -gt 0) { $cmbCategory.SelectedIndex = 0 }
    Update-CreateSubcategories
}

function ConvertTo-SafeFilePart([string]$Name) {
    $safe = [string]$Name
    foreach ($character in [System.IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace([string]$character, '_') }
    $safe = $safe.Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'Color' }
    return $safe
}

function Get-SelectedBrand {
    if ($lstBrands.SelectedIndex -lt 0) { return $null }
    return @($script:Settings.BrandCatalog)[$lstBrands.SelectedIndex]
}

function Get-SelectedBrandColor {
    $brand = Get-SelectedBrand
    if ($null -eq $brand -or $lstBrandColors.SelectedIndex -lt 0) { return $null }
    return @($brand.Colors)[$lstBrandColors.SelectedIndex]
}

function Get-CatalogColorPath($Brand, $Color) {
    return Join-Path (Join-Path $script:BrandCatalogDirectory ([string]$Brand.Id)) ([string]$Color.FileName)
}

function Refresh-BrandColors {
    $lstBrandColors.Items.Clear()
    $brand = Get-SelectedBrand
    if ($null -ne $brand) {
        foreach ($color in @($brand.Colors)) {
            $path = Get-CatalogColorPath $brand $color
            $status = if (Test-Path -LiteralPath $path -PathType Leaf) { '' } else { ' (file missing)' }
            [void]$lstBrandColors.Items.Add("$($color.Name)$status")
        }
    }
    if ($lstBrandColors.Items.Count -gt 0) { $lstBrandColors.SelectedIndex = 0 }
}

function Refresh-BrandCatalog {
    $selectedBrand = if ($lstBrands.SelectedIndex -ge 0) { Get-SelectedBrand } else { $null }
    $selectedBrandId = if ($null -ne $selectedBrand) { [string]$selectedBrand.Id } else { '' }
    $lstBrands.Items.Clear()
    $selectedIndex = -1
    for ($index = 0; $index -lt @($script:Settings.BrandCatalog).Count; $index++) {
        $brand = @($script:Settings.BrandCatalog)[$index]
        [void]$lstBrands.Items.Add([string]$brand.Name)
        if ([string]$brand.Id -eq $selectedBrandId) { $selectedIndex = $index }
    }
    if ($selectedIndex -ge 0) { $lstBrands.SelectedIndex = $selectedIndex }
    elseif ($lstBrands.Items.Count -gt 0) { $lstBrands.SelectedIndex = 0 }
    else { Refresh-BrandColors }
    Refresh-CreateColorChoices
}

function Refresh-CreateColorChoices {
    if ($null -eq $clbDesignColors) { return }
    $checkedIds = @{}
    for ($index = 0; $index -lt $script:CreateColorChoices.Count; $index++) {
        if ($clbDesignColors.GetItemChecked($index)) {
            $choice = $script:CreateColorChoices[$index]
            $checkedIds["$($choice.BrandId)|$($choice.ColorId)"] = $true
        }
    }

    $script:CreateColorChoices = @()
    $clbDesignColors.Items.Clear()
    foreach ($brand in @($script:Settings.BrandCatalog | Sort-Object Name)) {
        foreach ($color in @($brand.Colors | Sort-Object Name)) {
            $choice = [pscustomobject]@{
                BrandId = [string]$brand.Id
                BrandName = [string]$brand.Name
                ColorId = [string]$color.Id
                ColorName = [string]$color.Name
                FileName = [string]$color.FileName
            }
            $script:CreateColorChoices += $choice
            $newIndex = $clbDesignColors.Items.Add("$($choice.BrandName) — $($choice.ColorName)")
            if ($checkedIds.ContainsKey("$($choice.BrandId)|$($choice.ColorId)")) { $clbDesignColors.SetItemChecked($newIndex, $true) }
        }
    }
}

function Get-CheckedColorChoices {
    $selected = @()
    foreach ($index in @($clbDesignColors.CheckedIndices)) {
        if ([int]$index -lt $script:CreateColorChoices.Count) { $selected += $script:CreateColorChoices[([int]$index)] }
    }
    return @($selected)
}

function Update-Preview {
    if ($null -eq $lblPreview) { return }
    $category = Get-SelectedCategory
    $subcategory = Get-SelectedSubcategory
    $name = Sanitize-DesignName $txtDesignName.Text
    if ($null -eq $category -or $null -eq $subcategory) {
        $lblPreview.Text = 'Add a category and subcategory in Settings.'
        return
    }
    $destination = $script:Settings.DefaultDirectory
    $number = Get-NextDesignNumber ([int]$category.Id) ([int]$subcategory.Id) $destination
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Name Here' }
    $lblPreview.Text = "$(Format-Number ([int]$category.Id))-$(Format-Number ([int]$subcategory.Id))-$(Format-Number $number) - $name"
}

function Create-DesignFolders([string]$Destination) {
    $category = Get-SelectedCategory
    $subcategory = Get-SelectedSubcategory
    $name = Sanitize-DesignName $txtDesignName.Text

    if ($null -eq $category -or $null -eq $subcategory) {
        [System.Windows.Forms.MessageBox]::Show('Please select a category and subcategory.', $script:AppName, 'OK', 'Warning') | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        [System.Windows.Forms.MessageBox]::Show('Please enter a design name.', $script:AppName, 'OK', 'Warning') | Out-Null
        $txtDesignName.Focus()
        return
    }
    if ([string]::IsNullOrWhiteSpace($Destination)) {
        [System.Windows.Forms.MessageBox]::Show('Please choose a destination folder.', $script:AppName, 'OK', 'Warning') | Out-Null
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force -ErrorAction Stop | Out-Null
        }
        $number = Get-NextDesignNumber ([int]$category.Id) ([int]$subcategory.Id) $Destination
        $folderName = "$(Format-Number ([int]$category.Id))-$(Format-Number ([int]$subcategory.Id))-$(Format-Number $number) - $name"
        $masterPath = Join-Path $Destination $folderName
        if (Test-Path -LiteralPath $masterPath) { throw "A folder named '$folderName' already exists." }

        New-Item -ItemType Directory -Path $masterPath -ErrorAction Stop | Out-Null
        foreach ($relativePath in Expand-FolderTemplate) {
            New-Item -ItemType Directory -Path (Join-Path $masterPath $relativePath) -Force -ErrorAction Stop | Out-Null
        }

        $selectedColors = @(Get-CheckedColorChoices)
        $colorsCopied = 0
        $colorsMissing = 0
        if ($selectedColors.Count -gt 0) {
            $colorsOfferedPath = Join-Path $masterPath 'Colors Offered'
            New-Item -ItemType Directory -Path $colorsOfferedPath -Force -ErrorAction Stop | Out-Null
            foreach ($choice in $selectedColors) {
                $sourcePath = Join-Path (Join-Path $script:BrandCatalogDirectory ([string]$choice.BrandId)) ([string]$choice.FileName)
                if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
                    $extension = [System.IO.Path]::GetExtension($sourcePath)
                    $destinationName = "$(ConvertTo-SafeFilePart $choice.BrandName) - $(ConvertTo-SafeFilePart $choice.ColorName)$extension"
                    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $colorsOfferedPath $destinationName) -Force -ErrorAction Stop
                    $colorsCopied++
                } else {
                    $colorsMissing++
                }
            }
        }

        $record = [pscustomobject]@{
            CategoryId = [int]$category.Id
            Category = [string]$category.Name
            SubcategoryId = [int]$subcategory.Id
            Subcategory = [string]$subcategory.Name
            DesignNumber = $number
            Name = $name
            Path = $masterPath
            Colors = @($selectedColors | ForEach-Object { "$($_.BrandName) — $($_.ColorName)" })
            Created = (Get-Date).ToString('s')
        }
        $script:Settings.CreatedDesigns = @($script:Settings.CreatedDesigns) + $record
        Save-Settings
        Refresh-CreatedDesigns
        $txtDesignName.Clear()
        Update-Preview

        $colorSummary = if ($selectedColors.Count -eq 0) { 'No shirt color files selected.' } else { "Shirt color files copied: $colorsCopied" }
        if ($colorsMissing -gt 0) { $colorSummary += "`r`nMissing catalog files skipped: $colorsMissing" }
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Folder set created successfully:`r`n`r`n$masterPath`r`n`r`n$colorSummary`r`n`r`nOpen it now?",
            $script:AppName,
            'YesNo',
            'Information'
        )
        if ($answer -eq 'Yes') { Start-Process explorer.exe -ArgumentList @("`"$masterPath`"") }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("The folder set could not be created.`r`n`r`n$($_.Exception.Message)", $script:AppName, 'OK', 'Error') | Out-Null
    }
}

function Refresh-SettingsLists {
    $lstCategories.Items.Clear()
    foreach ($category in @($script:Settings.Categories)) {
        [void]$lstCategories.Items.Add("$(Format-Number ([int]$category.Id)) - $($category.Name)")
    }
    if ($lstCategories.Items.Count -gt 0) { $lstCategories.SelectedIndex = 0 }
    $txtDefaultDirectory.Text = [string]$script:Settings.DefaultDirectory
    $txtSizes.Lines = @($script:Settings.SizeFolders)
    $txtTemplate.Lines = @($script:Settings.FolderTemplate)
}

function Refresh-SettingsSubcategories {
    $lstSubcategories.Items.Clear()
    if ($lstCategories.SelectedIndex -ge 0) {
        $category = @($script:Settings.Categories)[$lstCategories.SelectedIndex]
        foreach ($subcategory in @($category.Subcategories)) {
            [void]$lstSubcategories.Items.Add("$(Format-Number ([int]$subcategory.Id)) - $($subcategory.Name)")
        }
    }
    if ($lstSubcategories.Items.Count -gt 0) { $lstSubcategories.SelectedIndex = 0 }
}

function Refresh-CreatedDesigns {
    $gridCreated.Rows.Clear()
    foreach ($design in @($script:Settings.CreatedDesigns | Sort-Object Created -Descending)) {
        $exists = if (Test-Path -LiteralPath ([string]$design.Path)) { 'Yes' } else { 'No' }
        [void]$gridCreated.Rows.Add(
            "$(Format-Number ([int]$design.CategoryId))-$(Format-Number ([int]$design.SubcategoryId))-$(Format-Number ([int]$design.DesignNumber))",
            [string]$design.Name,
            [string]$design.Category,
            [string]$design.Subcategory,
            [string]$design.Path,
            $exists,
            [string]$design.Created
        )
    }
}

function Clear-CreatedDesignHistoryAndCache {
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Clear the Created Designs list and temporary app cache files?`r`n`r`nYour actual design folders, files, brand/color catalog, categories, subcategories, and folder template will NOT be deleted.",
        $script:AppName,
        'YesNo',
        'Warning'
    )
    if ($answer -ne 'Yes') { return }

    try {
        $historyCount = @($script:Settings.CreatedDesigns).Count
        $script:Settings.CreatedDesigns = @()
        Save-Settings

        $cacheItemsRemoved = 0
        if (Test-Path -LiteralPath $script:CacheDirectory -PathType Container) {
            $cacheItemsRemoved += @(Get-ChildItem -LiteralPath $script:CacheDirectory -Force -ErrorAction SilentlyContinue).Count
            Remove-Item -LiteralPath $script:CacheDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }

        Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'ShirtFolderUpdate_*' -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $_.FullName)) { $cacheItemsRemoved++ }
        }

        Refresh-CreatedDesigns
        Update-Preview
        [System.Windows.Forms.MessageBox]::Show(
            "Cleanup complete.`r`n`r`nHistory entries cleared: $historyCount`r`nCache items removed: $cacheItemsRemoved`r`n`r`nNo design folders or design files were deleted.",
            $script:AppName,
            'OK',
            'Information'
        ) | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("The cleanup could not be completed.`r`n`r`n$($_.Exception.Message)", $script:AppName, 'OK', 'Error') | Out-Null
    }
}

function Get-SelectedCreatedDesign {
    if ($gridCreated.SelectedRows.Count -eq 0) { return $null }
    $path = [string]$gridCreated.SelectedRows[0].Cells['Path'].Value
    return @($script:Settings.CreatedDesigns) | Where-Object { [string]$_.Path -eq $path } | Select-Object -First 1
}

function New-Button([string]$Text, [int]$X, [int]$Y, [int]$Width = 130, [int]$Height = 34) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.FlatStyle = 'Flat'
    $button.UseMnemonic = $false
    $button.AutoEllipsis = $true
    $button.BackColor = [System.Drawing.Color]::FromArgb(36, 99, 166)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    return $button
}

function New-Label([string]$Text, [int]$X, [int]$Y, [int]$Width = 300, [int]$Height = 24) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    return $label
}

$script:Settings = Load-Settings

$form = New-Object System.Windows.Forms.Form
$form.Text = $script:AppName
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(1020, 820)
$form.MinimumSize = New-Object System.Drawing.Size(620, 640)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Show
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(244, 248, 252)
$programIconPath = Join-Path $script:ProgramDirectory 'JM-Folder-Creator.ico'
if (Test-Path -LiteralPath $programIconPath) {
    try { $form.Icon = New-Object System.Drawing.Icon($programIconPath) } catch { }
}

$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.ColumnCount = 1
$layout.RowCount = 3
$layout.Margin = New-Object System.Windows.Forms.Padding(0)
$layout.Padding = New-Object System.Windows.Forms.Padding(0)
[void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$form.Controls.Add($layout)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Fill'
$header.Margin = New-Object System.Windows.Forms.Padding(0)
$header.BackColor = [System.Drawing.Color]::FromArgb(24, 62, 105)

$menuStrip = New-Object System.Windows.Forms.MenuStrip
$menuStrip.Dock = 'Top'
$menuStrip.BackColor = [System.Drawing.Color]::White
$menuSettings = New-Object System.Windows.Forms.ToolStripMenuItem
$menuSettings.Text = 'Settings'
$menuCategories = New-Object System.Windows.Forms.ToolStripMenuItem
$menuCategories.Text = 'Categories && Subcategories'
$menuBrands = New-Object System.Windows.Forms.ToolStripMenuItem
$menuBrands.Text = 'Brands && Colors'
$menuFolderTemplate = New-Object System.Windows.Forms.ToolStripMenuItem
$menuFolderTemplate.Text = 'Folder Template'
$menuPresetLocation = New-Object System.Windows.Forms.ToolStripMenuItem
$menuPresetLocation.Text = 'Preset Location'
$menuUpdates = New-Object System.Windows.Forms.ToolStripMenuItem
$menuUpdates.Text = 'Updates'
[void]$menuSettings.DropDownItems.Add($menuCategories)
[void]$menuSettings.DropDownItems.Add($menuBrands)
[void]$menuSettings.DropDownItems.Add($menuFolderTemplate)
[void]$menuSettings.DropDownItems.Add($menuPresetLocation)
[void]$menuSettings.DropDownItems.Add($menuUpdates)
[void]$menuStrip.Items.Add($menuSettings)
$layout.Controls.Add($menuStrip, 0, 0)
$form.MainMenuStrip = $menuStrip

$title = New-Label 'SHIRT DESIGN FOLDER BUILDER' 24 10 700 34
$title.Font = New-Object System.Drawing.Font('Segoe UI', 17, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::White
$header.Controls.Add($title)
$subtitle = New-Label 'Create organized, numbered design folders in seconds' 27 50 700 25
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(207, 226, 245)
$header.Controls.Add($subtitle)
$layout.Controls.Add($header, 0, 1)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.Padding = New-Object System.Drawing.Point(18, 7)
$tabs.Margin = New-Object System.Windows.Forms.Padding(0)
$layout.Controls.Add($tabs, 0, 2)

# CREATE TAB
$tabCreate = New-Object System.Windows.Forms.TabPage
$tabCreate.Text = 'Create Folder Set'
$tabCreate.BackColor = $form.BackColor
$tabCreate.AutoScroll = $true
$tabs.TabPages.Add($tabCreate)

$createGroup = New-Object System.Windows.Forms.GroupBox
$createGroup.Text = 'New Shirt Design'
$createGroup.Location = New-Object System.Drawing.Point(28, 24)
$createGroup.Size = New-Object System.Drawing.Size(880, 445)
$createGroup.Anchor = 'Top,Left,Right'
$tabCreate.Controls.Add($createGroup)

$createGroup.Controls.Add((New-Label 'Category' 28 42 350))
$cmbCategory = New-Object System.Windows.Forms.ComboBox
$cmbCategory.DropDownStyle = 'DropDownList'
$cmbCategory.Location = New-Object System.Drawing.Point(28, 68)
$cmbCategory.Size = New-Object System.Drawing.Size(385, 30)
$createGroup.Controls.Add($cmbCategory)

$createGroup.Controls.Add((New-Label 'Subcategory' 455 42 350))
$cmbSubcategory = New-Object System.Windows.Forms.ComboBox
$cmbSubcategory.DropDownStyle = 'DropDownList'
$cmbSubcategory.Location = New-Object System.Drawing.Point(455, 68)
$cmbSubcategory.Size = New-Object System.Drawing.Size(385, 30)
$createGroup.Controls.Add($cmbSubcategory)

$createGroup.Controls.Add((New-Label 'Design Name' 28 122 500))
$txtDesignName = New-Object System.Windows.Forms.TextBox
$txtDesignName.Location = New-Object System.Drawing.Point(28, 148)
$txtDesignName.Size = New-Object System.Drawing.Size(812, 30)
$txtDesignName.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$createGroup.Controls.Add($txtDesignName)

$createGroup.Controls.Add((New-Label 'Folder name preview' 28 200 300))
$lblPreview = New-Label '' 28 226 812 43
$lblPreview.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$lblPreview.ForeColor = [System.Drawing.Color]::FromArgb(24, 62, 105)
$lblPreview.BorderStyle = 'FixedSingle'
$lblPreview.BackColor = [System.Drawing.Color]::White
$lblPreview.Padding = New-Object System.Windows.Forms.Padding(8)
$createGroup.Controls.Add($lblPreview)

$lblDefaultPath = New-Label '' 28 287 812 42
$lblDefaultPath.ForeColor = [System.Drawing.Color]::DimGray
$createGroup.Controls.Add($lblDefaultPath)

$lblDesignColors = New-Label 'Brand colors available for this design' 28 333 500 24
$createGroup.Controls.Add($lblDesignColors)
$clbDesignColors = New-Object System.Windows.Forms.CheckedListBox
$clbDesignColors.CheckOnClick = $true
$clbDesignColors.Location = New-Object System.Drawing.Point(28, 360)
$clbDesignColors.Size = New-Object System.Drawing.Size(650, 84)
$clbDesignColors.IntegralHeight = $false
$clbDesignColors.BorderStyle = 'FixedSingle'
$clbDesignColors.BackColor = [System.Drawing.Color]::White
$createGroup.Controls.Add($clbDesignColors)
$btnSelectAllColors = New-Button 'Select All' 696 360 144 36
$btnClearColors = New-Button 'Clear Selections' 696 405 144 36
$btnClearColors.BackColor = [System.Drawing.Color]::FromArgb(78, 91, 87)
$createGroup.Controls.AddRange(@($btnSelectAllColors, $btnClearColors))

$btnCreateDefault = New-Button 'Create in Preset Location' 28 348 255 48
$btnChooseCreate = New-Button 'Choose Location & Create' 302 348 255 48
$btnOpenDefault = New-Button 'Open Preset Location' 576 348 200 48
$btnOpenDefault.BackColor = [System.Drawing.Color]::FromArgb(78, 91, 87)
$btnManageCategories = New-Button 'Manage Categories' 28 405 180 30
$btnManageCategories.BackColor = [System.Drawing.Color]::FromArgb(78, 91, 87)

$createButtonsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$createButtonsLayout.Location = New-Object System.Drawing.Point(22, 468)
$createButtonsLayout.Size = New-Object System.Drawing.Size(824, 108)
$createButtonsLayout.Anchor = 'Top,Left,Right'
$createButtonsLayout.ColumnCount = 2
$createButtonsLayout.RowCount = 2
$createButtonsLayout.Margin = New-Object System.Windows.Forms.Padding(0)
$createButtonsLayout.Padding = New-Object System.Windows.Forms.Padding(0)
$createButtonsLayout.GrowStyle = [System.Windows.Forms.TableLayoutPanelGrowStyle]::FixedSize
[void]$createButtonsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
[void]$createButtonsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
[void]$createButtonsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
[void]$createButtonsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
foreach ($button in @($btnCreateDefault, $btnChooseCreate, $btnOpenDefault, $btnManageCategories)) {
    $button.Dock = 'Fill'
    $button.Margin = New-Object System.Windows.Forms.Padding(6)
}
$createButtonsLayout.Controls.Add($btnCreateDefault, 0, 0)
$createButtonsLayout.Controls.Add($btnChooseCreate, 1, 0)
$createButtonsLayout.Controls.Add($btnOpenDefault, 0, 1)
$createButtonsLayout.Controls.Add($btnManageCategories, 1, 1)
$createGroup.Controls.Add($createButtonsLayout)

$lblHint = New-Label 'Tip: Manage brands, color files, categories, sizes, and locations under Settings.' 35 620 850 32
$lblHint.ForeColor = [System.Drawing.Color]::DimGray
$tabCreate.Controls.Add($lblHint)

# CREATED DESIGNS TAB
$tabCreated = New-Object System.Windows.Forms.TabPage
$tabCreated.Text = 'Created Designs'
$tabCreated.BackColor = $form.BackColor
$tabs.TabPages.Add($tabCreated)

$gridCreated = New-Object System.Windows.Forms.DataGridView
$gridCreated.Location = New-Object System.Drawing.Point(20, 20)
$gridCreated.Size = New-Object System.Drawing.Size(900, 445)
$gridCreated.Anchor = 'Top,Bottom,Left,Right'
$gridCreated.AllowUserToAddRows = $false
$gridCreated.AllowUserToDeleteRows = $false
$gridCreated.ReadOnly = $true
$gridCreated.MultiSelect = $false
$gridCreated.SelectionMode = 'FullRowSelect'
$gridCreated.AutoSizeColumnsMode = 'Fill'
$gridCreated.BackgroundColor = [System.Drawing.Color]::White
[void]$gridCreated.Columns.Add('Code', 'Code')
[void]$gridCreated.Columns.Add('DesignName', 'Design Name')
[void]$gridCreated.Columns.Add('Category', 'Category')
[void]$gridCreated.Columns.Add('Subcategory', 'Subcategory')
[void]$gridCreated.Columns.Add('Path', 'Path')
[void]$gridCreated.Columns.Add('Exists', 'Exists')
[void]$gridCreated.Columns.Add('Created', 'Created')
$gridCreated.Columns['Code'].FillWeight = 55
$gridCreated.Columns['DesignName'].FillWeight = 95
$gridCreated.Columns['Path'].FillWeight = 180
$gridCreated.Columns['Exists'].FillWeight = 35
$gridCreated.Columns['Created'].FillWeight = 65
$tabCreated.Controls.Add($gridCreated)

$createdButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$createdButtons.Location = New-Object System.Drawing.Point(20, 485)
$createdButtons.Size = New-Object System.Drawing.Size(900, 90)
$createdButtons.Anchor = 'Bottom,Left,Right'
$tabCreated.Controls.Add($createdButtons)
$btnOpenDesign = New-Button 'Open Folder' 0 0 130 38
$btnRenameDesign = New-Button 'Rename Design' 0 0 145 38
$btnRepairDesign = New-Button 'Create Missing Folders' 0 0 190 38
$btnRemoveRecord = New-Button 'Remove From List' 0 0 160 38
$btnRemoveRecord.BackColor = [System.Drawing.Color]::FromArgb(139, 70, 63)
$btnRefreshCreated = New-Button 'Refresh' 0 0 110 38
$btnRefreshCreated.BackColor = [System.Drawing.Color]::FromArgb(78, 91, 87)
$btnClearHistoryCache = New-Button 'Clear History & Cache' 0 0 190 38
$btnClearHistoryCache.BackColor = [System.Drawing.Color]::FromArgb(139, 70, 63)
$createdButtons.Controls.AddRange(@($btnOpenDesign, $btnRenameDesign, $btnRepairDesign, $btnRemoveRecord, $btnRefreshCreated, $btnClearHistoryCache))

# SETTINGS TAB
$tabSettings = New-Object System.Windows.Forms.TabPage
$tabSettings.Text = 'Settings'
$tabSettings.BackColor = $form.BackColor
$tabs.TabPages.Add($tabSettings)

$settingsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$settingsLayout.Dock = 'Fill'
$settingsLayout.ColumnCount = 1
$settingsLayout.RowCount = 2
$settingsLayout.Margin = New-Object System.Windows.Forms.Padding(0)
[void]$settingsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$settingsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$settingsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 56)))
$tabSettings.Controls.Add($settingsLayout)

$settingsTabs = New-Object System.Windows.Forms.TabControl
$settingsTabs.Dock = 'Fill'
$settingsTabs.Margin = New-Object System.Windows.Forms.Padding(0)
$settingsLayout.Controls.Add($settingsTabs, 0, 0)

$settingsFooter = New-Object System.Windows.Forms.Panel
$settingsFooter.Dock = 'Fill'
$settingsFooter.BackColor = [System.Drawing.Color]::FromArgb(226, 236, 247)
$settingsFooter.Margin = New-Object System.Windows.Forms.Padding(0)
$btnReturnToCreate = New-Button '← Return to Create Screen' 22 10 220 38
$settingsFooter.Controls.Add($btnReturnToCreate)
$settingsLayout.Controls.Add($settingsFooter, 0, 1)

$tabCat = New-Object System.Windows.Forms.TabPage
$tabCat.Text = 'Categories'
$tabCat.AutoScroll = $true
$settingsTabs.TabPages.Add($tabCat)
$tabCat.Controls.Add((New-Label 'Categories (AA)' 25 22 360))
$lstCategories = New-Object System.Windows.Forms.ListBox
$lstCategories.Location = New-Object System.Drawing.Point(25, 50)
$lstCategories.Size = New-Object System.Drawing.Size(375, 350)
$tabCat.Controls.Add($lstCategories)
$lblSubcategoryHeading = New-Label 'Subcategories for selected category (BB)' 465 22 410
$tabCat.Controls.Add($lblSubcategoryHeading)
$lstSubcategories = New-Object System.Windows.Forms.ListBox
$lstSubcategories.Location = New-Object System.Drawing.Point(465, 50)
$lstSubcategories.Size = New-Object System.Drawing.Size(375, 350)
$tabCat.Controls.Add($lstSubcategories)
$btnAddCategory = New-Button 'Add' 25 420 105
$btnRenameCategory = New-Button 'Rename' 140 420 110
$btnDeleteCategory = New-Button 'Delete' 260 420 110
$btnDeleteCategory.BackColor = [System.Drawing.Color]::FromArgb(139, 70, 63)
$btnAddSubcategory = New-Button 'Add' 465 420 105
$btnRenameSubcategory = New-Button 'Rename' 580 420 110
$btnDeleteSubcategory = New-Button 'Delete' 700 420 110
$btnDeleteSubcategory.BackColor = [System.Drawing.Color]::FromArgb(139, 70, 63)
$tabCat.Controls.AddRange(@($btnAddCategory, $btnRenameCategory, $btnDeleteCategory, $btnAddSubcategory, $btnRenameSubcategory, $btnDeleteSubcategory))
$lblCategoryIds = New-Label 'IDs are assigned automatically and remain fixed so existing design codes never change.' 25 474 820 30
$tabCat.Controls.Add($lblCategoryIds)

$tabBrands = New-Object System.Windows.Forms.TabPage
$tabBrands.Text = 'Brands & Colors'
$tabBrands.AutoScroll = $true
$settingsTabs.TabPages.Add($tabBrands)
$lblBrandsHeading = New-Label 'Shirt brands' 25 22 360
$tabBrands.Controls.Add($lblBrandsHeading)
$lstBrands = New-Object System.Windows.Forms.ListBox
$lstBrands.Location = New-Object System.Drawing.Point(25, 50)
$lstBrands.Size = New-Object System.Drawing.Size(375, 350)
$tabBrands.Controls.Add($lstBrands)
$lblBrandColorsHeading = New-Label 'Color files for selected brand' 465 22 410
$tabBrands.Controls.Add($lblBrandColorsHeading)
$lstBrandColors = New-Object System.Windows.Forms.ListBox
$lstBrandColors.Location = New-Object System.Drawing.Point(465, 50)
$lstBrandColors.Size = New-Object System.Drawing.Size(390, 350)
$tabBrands.Controls.Add($lstBrandColors)
$btnAddBrand = New-Button 'Add Brand' 25 420 115
$btnRenameBrand = New-Button 'Rename' 150 420 105
$btnDeleteBrand = New-Button 'Delete' 265 420 105
$btnDeleteBrand.BackColor = [System.Drawing.Color]::FromArgb(139, 70, 63)
$btnUploadColors = New-Button 'Upload Color Files' 465 420 165
$btnRenameColor = New-Button 'Rename Color' 640 420 135
$btnReplaceColor = New-Button 'Replace File' 465 464 130
$btnOpenColor = New-Button 'Open File' 605 464 115
$btnOpenColor.BackColor = [System.Drawing.Color]::FromArgb(78, 91, 87)
$btnDeleteColor = New-Button 'Delete Color' 730 464 125
$btnDeleteColor.BackColor = [System.Drawing.Color]::FromArgb(139, 70, 63)
$tabBrands.Controls.AddRange(@($btnAddBrand, $btnRenameBrand, $btnDeleteBrand, $btnUploadColors, $btnRenameColor, $btnReplaceColor, $btnOpenColor, $btnDeleteColor))
$lblBrandCatalogHelp = New-Label 'Uploaded files are stored in the app catalog. Select one or more brand colors on the Create screen to copy them into Colors Offered.' 25 525 830 52
$tabBrands.Controls.Add($lblBrandCatalogHelp)

$tabFolders = New-Object System.Windows.Forms.TabPage
$tabFolders.Text = 'Folder Template'
$tabFolders.AutoScroll = $true
$settingsTabs.TabPages.Add($tabFolders)
$tabFolders.Controls.Add((New-Label 'Size File Set — one folder per line' 24 20 395))
$txtSizes = New-Object System.Windows.Forms.TextBox
$txtSizes.Multiline = $true
$txtSizes.ScrollBars = 'Vertical'
$txtSizes.Location = New-Object System.Drawing.Point(24, 50)
$txtSizes.Size = New-Object System.Drawing.Size(395, 380)
$txtSizes.Font = New-Object System.Drawing.Font('Consolas', 10)
$tabFolders.Controls.Add($txtSizes)
$tabFolders.Controls.Add((New-Label 'Folder Template — one relative folder path per line' 455 20 410))
$txtTemplate = New-Object System.Windows.Forms.TextBox
$txtTemplate.Multiline = $true
$txtTemplate.ScrollBars = 'Both'
$txtTemplate.WordWrap = $false
$txtTemplate.Location = New-Object System.Drawing.Point(455, 50)
$txtTemplate.Size = New-Object System.Drawing.Size(410, 380)
$txtTemplate.Font = New-Object System.Drawing.Font('Consolas', 10)
$tabFolders.Controls.Add($txtTemplate)
$tabFolders.Controls.Add((New-Label 'Use {SIZE FILE SET} anywhere in a path to create every size folder at that location.' 24 445 840 30))
$btnSaveTemplate = New-Button 'Save Folder Template' 24 486 190 38
$btnResetTemplate = New-Button 'Restore Original Template' 230 486 205 38
$btnResetTemplate.BackColor = [System.Drawing.Color]::FromArgb(78, 91, 87)
$tabFolders.Controls.AddRange(@($btnSaveTemplate, $btnResetTemplate))

$tabLocation = New-Object System.Windows.Forms.TabPage
$tabLocation.Text = 'Preset Location'
$tabLocation.AutoScroll = $true
$settingsTabs.TabPages.Add($tabLocation)
$tabLocation.Controls.Add((New-Label 'Default directory for new master design folders' 28 30 600))
$txtDefaultDirectory = New-Object System.Windows.Forms.TextBox
$txtDefaultDirectory.Location = New-Object System.Drawing.Point(28, 62)
$txtDefaultDirectory.Size = New-Object System.Drawing.Size(680, 30)
$tabLocation.Controls.Add($txtDefaultDirectory)
$btnBrowseDefault = New-Button 'Browse...' 725 58 120 36
$btnSaveDefault = New-Button 'Save Preset Location' 28 116 185 38
$tabLocation.Controls.AddRange(@($btnBrowseDefault, $btnSaveDefault))
$tabLocation.Controls.Add((New-Label 'The “Create in Preset Location” button uses this directory. You can still choose a different location for any individual design.' 28 177 820 50))

$tabUpdates = New-Object System.Windows.Forms.TabPage
$tabUpdates.Text = 'Updates'
$tabUpdates.AutoScroll = $true
$settingsTabs.TabPages.Add($tabUpdates)
$lblCurrentVersion = New-Label "Current program version: $($script:AppVersion)" 28 24 600 28
$tabUpdates.Controls.Add($lblCurrentVersion)
$lblGitHubOwner = New-Label 'GitHub owner or username' 28 72 350
$tabUpdates.Controls.Add($lblGitHubOwner)
$txtGitHubOwner = New-Object System.Windows.Forms.TextBox
$txtGitHubOwner.Location = New-Object System.Drawing.Point(28, 100)
$txtGitHubOwner.Size = New-Object System.Drawing.Size(390, 30)
$tabUpdates.Controls.Add($txtGitHubOwner)
$lblGitHubRepository = New-Label 'GitHub repository name' 455 72 350
$tabUpdates.Controls.Add($lblGitHubRepository)
$txtGitHubRepository = New-Object System.Windows.Forms.TextBox
$txtGitHubRepository.Location = New-Object System.Drawing.Point(455, 100)
$txtGitHubRepository.Size = New-Object System.Drawing.Size(390, 30)
$tabUpdates.Controls.Add($txtGitHubRepository)
$lblUpdateAssetName = New-Label 'Release installer asset filename' 28 154 400
$tabUpdates.Controls.Add($lblUpdateAssetName)
$txtUpdateAssetName = New-Object System.Windows.Forms.TextBox
$txtUpdateAssetName.Location = New-Object System.Drawing.Point(28, 182)
$txtUpdateAssetName.Size = New-Object System.Drawing.Size(390, 30)
$tabUpdates.Controls.Add($txtUpdateAssetName)
$chkUpdatesOnLaunch = New-Object System.Windows.Forms.CheckBox
$chkUpdatesOnLaunch.Text = 'Check for updates automatically when the program launches'
$chkUpdatesOnLaunch.Location = New-Object System.Drawing.Point(28, 234)
$chkUpdatesOnLaunch.Size = New-Object System.Drawing.Size(520, 30)
$tabUpdates.Controls.Add($chkUpdatesOnLaunch)
$btnSaveUpdateSettings = New-Button 'Save Update Settings' 28 286 190 40
$btnCheckUpdates = New-Button 'Check for Updates Now' 236 286 210 40
$tabUpdates.Controls.AddRange(@($btnSaveUpdateSettings, $btnCheckUpdates))
$lblUpdateStatus = New-Label '' 28 350 817 70
$lblUpdateStatus.BorderStyle = 'FixedSingle'
$lblUpdateStatus.BackColor = [System.Drawing.Color]::White
$lblUpdateStatus.Padding = New-Object System.Windows.Forms.Padding(8)
$tabUpdates.Controls.Add($lblUpdateStatus)
$lblUpdateReleaseHelp = New-Label 'GitHub releases must use version tags such as v2.1.0 and include an installer with the exact filename entered above.' 28 438 820 48
$tabUpdates.Controls.Add($lblUpdateReleaseHelp)

function Update-ResponsiveLayout {
    if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) { return }

    $createWidth = [Math]::Max(520, $tabCreate.ClientSize.Width - 56)
    $createGroup.Width = $createWidth
    $innerWidth = [Math]::Max(464, $createWidth - 56)

    if ($tabCreate.ClientSize.Width -ge 820) {
        $columnGap = 42
        $columnWidth = [Math]::Floor(($innerWidth - $columnGap) / 2)
        $rightX = 28 + $columnWidth + $columnGap

        $createGroup.Controls[0].Location = New-Object System.Drawing.Point(28, 42)
        $cmbCategory.Location = New-Object System.Drawing.Point(28, 68)
        $cmbCategory.Width = $columnWidth
        $createGroup.Controls[2].Location = New-Object System.Drawing.Point($rightX, 42)
        $cmbSubcategory.Location = New-Object System.Drawing.Point($rightX, 68)
        $cmbSubcategory.Width = $columnWidth
        $createGroup.Controls[4].Location = New-Object System.Drawing.Point(28, 122)
        $txtDesignName.Location = New-Object System.Drawing.Point(28, 148)
        $txtDesignName.Width = $innerWidth
        $createGroup.Controls[6].Location = New-Object System.Drawing.Point(28, 200)
        $lblPreview.Location = New-Object System.Drawing.Point(28, 226)
        $lblPreview.Width = $innerWidth
        $lblDefaultPath.Location = New-Object System.Drawing.Point(28, 287)
        $lblDefaultPath.Width = $innerWidth

        $lblDesignColors.Location = New-Object System.Drawing.Point(28, 329)
        $clbDesignColors.Location = New-Object System.Drawing.Point(28, 356)
        $clbDesignColors.Size = New-Object System.Drawing.Size(([Math]::Max(270, $innerWidth - 162)), 84)
        $btnSelectAllColors.Location = New-Object System.Drawing.Point(($clbDesignColors.Right + 18), 356)
        $btnClearColors.Location = New-Object System.Drawing.Point(($clbDesignColors.Right + 18), 404)

        $createButtonsLayout.Location = New-Object System.Drawing.Point(22, 456)
        $createButtonsLayout.Width = [Math]::Max(300, $createGroup.ClientSize.Width - 44)
        $createButtonsLayout.Height = 108
        $createGroup.Height = 586
        $lblHint.Location = New-Object System.Drawing.Point(35, 625)
    } else {
        $createGroup.Controls[0].Location = New-Object System.Drawing.Point(28, 36)
        $cmbCategory.Location = New-Object System.Drawing.Point(28, 62)
        $cmbCategory.Width = $innerWidth
        $createGroup.Controls[2].Location = New-Object System.Drawing.Point(28, 105)
        $cmbSubcategory.Location = New-Object System.Drawing.Point(28, 131)
        $cmbSubcategory.Width = $innerWidth
        $createGroup.Controls[4].Location = New-Object System.Drawing.Point(28, 174)
        $txtDesignName.Location = New-Object System.Drawing.Point(28, 200)
        $txtDesignName.Width = $innerWidth
        $createGroup.Controls[6].Location = New-Object System.Drawing.Point(28, 247)
        $lblPreview.Location = New-Object System.Drawing.Point(28, 273)
        $lblPreview.Width = $innerWidth
        $lblDefaultPath.Location = New-Object System.Drawing.Point(28, 329)
        $lblDefaultPath.Width = $innerWidth

        $lblDesignColors.Location = New-Object System.Drawing.Point(28, 374)
        $clbDesignColors.Location = New-Object System.Drawing.Point(28, 401)
        $clbDesignColors.Size = New-Object System.Drawing.Size(([Math]::Max(270, $innerWidth - 162)), 84)
        $btnSelectAllColors.Location = New-Object System.Drawing.Point(($clbDesignColors.Right + 18), 401)
        $btnClearColors.Location = New-Object System.Drawing.Point(($clbDesignColors.Right + 18), 449)

        $createButtonsLayout.Location = New-Object System.Drawing.Point(22, 501)
        $createButtonsLayout.Width = [Math]::Max(300, $createGroup.ClientSize.Width - 44)
        $createButtonsLayout.Height = 112
        $createGroup.Height = 631
        $lblHint.Location = New-Object System.Drawing.Point(35, 670)
    }
    $lblHint.Width = [Math]::Max(460, $tabCreate.ClientSize.Width - 70)

    $createdButtons.Width = [Math]::Max(450, $tabCreated.ClientSize.Width - 40)
    $createdButtons.Height = if ($tabCreated.ClientSize.Width -lt 760) { 135 } else { 90 }
    $createdButtons.Top = [Math]::Max(180, $tabCreated.ClientSize.Height - $createdButtons.Height - 20)
    $gridCreated.Width = [Math]::Max(450, $tabCreated.ClientSize.Width - 40)
    $gridCreated.Height = [Math]::Max(120, $createdButtons.Top - 40)

    $settingsWidth = [Math]::Max(520, $settingsTabs.ClientSize.Width - 50)
    if ($settingsTabs.ClientSize.Width -ge 820) {
        $catColumnWidth = [Math]::Floor(($settingsWidth - 65) / 2)
        $catRightX = 25 + $catColumnWidth + 65
        $lstCategories.Location = New-Object System.Drawing.Point(25, 50)
        $lstCategories.Size = New-Object System.Drawing.Size($catColumnWidth, 350)
        $lblSubcategoryHeading.Location = New-Object System.Drawing.Point($catRightX, 22)
        $lstSubcategories.Location = New-Object System.Drawing.Point($catRightX, 50)
        $lstSubcategories.Size = New-Object System.Drawing.Size($catColumnWidth, 350)
        $btnAddCategory.Location = New-Object System.Drawing.Point(25, 420)
        $btnRenameCategory.Location = New-Object System.Drawing.Point(140, 420)
        $btnDeleteCategory.Location = New-Object System.Drawing.Point(260, 420)
        $btnAddSubcategory.Location = New-Object System.Drawing.Point($catRightX, 420)
        $btnRenameSubcategory.Location = New-Object System.Drawing.Point(($catRightX + 115), 420)
        $btnDeleteSubcategory.Location = New-Object System.Drawing.Point(($catRightX + 235), 420)
        $lblCategoryIds.Location = New-Object System.Drawing.Point(25, 474)
        $tabCat.AutoScrollMinSize = New-Object System.Drawing.Size(0, 530)
    } else {
        $listWidth = [Math]::Max(470, $settingsTabs.ClientSize.Width - 70)
        $lstCategories.Location = New-Object System.Drawing.Point(25, 50)
        $lstCategories.Size = New-Object System.Drawing.Size($listWidth, 235)
        $btnAddCategory.Location = New-Object System.Drawing.Point(25, 300)
        $btnRenameCategory.Location = New-Object System.Drawing.Point(140, 300)
        $btnDeleteCategory.Location = New-Object System.Drawing.Point(260, 300)
        $lblSubcategoryHeading.Location = New-Object System.Drawing.Point(25, 355)
        $lstSubcategories.Location = New-Object System.Drawing.Point(25, 383)
        $lstSubcategories.Size = New-Object System.Drawing.Size($listWidth, 235)
        $btnAddSubcategory.Location = New-Object System.Drawing.Point(25, 633)
        $btnRenameSubcategory.Location = New-Object System.Drawing.Point(140, 633)
        $btnDeleteSubcategory.Location = New-Object System.Drawing.Point(260, 633)
        $lblCategoryIds.Location = New-Object System.Drawing.Point(25, 686)
        $tabCat.AutoScrollMinSize = New-Object System.Drawing.Size(0, 740)
    }

    if ($settingsTabs.ClientSize.Width -ge 840) {
        $folderColumnWidth = [Math]::Floor(($settingsWidth - 36) / 2)
        $folderRightX = 24 + $folderColumnWidth + 36
        $txtSizes.Location = New-Object System.Drawing.Point(24, 50)
        $txtSizes.Size = New-Object System.Drawing.Size($folderColumnWidth, 380)
        $tabFolders.Controls[2].Location = New-Object System.Drawing.Point($folderRightX, 20)
        $txtTemplate.Location = New-Object System.Drawing.Point($folderRightX, 50)
        $txtTemplate.Size = New-Object System.Drawing.Size($folderColumnWidth, 380)
        $tabFolders.Controls[4].Location = New-Object System.Drawing.Point(24, 445)
        $btnSaveTemplate.Location = New-Object System.Drawing.Point(24, 486)
        $btnResetTemplate.Location = New-Object System.Drawing.Point(230, 486)
        $tabFolders.AutoScrollMinSize = New-Object System.Drawing.Size(0, 545)
    } else {
        $folderWidth = [Math]::Max(470, $settingsTabs.ClientSize.Width - 70)
        $txtSizes.Location = New-Object System.Drawing.Point(24, 50)
        $txtSizes.Size = New-Object System.Drawing.Size($folderWidth, 245)
        $tabFolders.Controls[2].Location = New-Object System.Drawing.Point(24, 320)
        $txtTemplate.Location = New-Object System.Drawing.Point(24, 350)
        $txtTemplate.Size = New-Object System.Drawing.Size($folderWidth, 245)
        $tabFolders.Controls[4].Location = New-Object System.Drawing.Point(24, 612)
        $btnSaveTemplate.Location = New-Object System.Drawing.Point(24, 653)
        $btnResetTemplate.Location = New-Object System.Drawing.Point(230, 653)
        $tabFolders.AutoScrollMinSize = New-Object System.Drawing.Size(0, 715)
    }

    if ($settingsTabs.ClientSize.Width -ge 840) {
        $brandColumnWidth = [Math]::Floor(($settingsWidth - 65) / 2)
        $brandRightX = 25 + $brandColumnWidth + 65
        $lstBrands.Location = New-Object System.Drawing.Point(25, 50)
        $lstBrands.Size = New-Object System.Drawing.Size($brandColumnWidth, 350)
        $lblBrandColorsHeading.Location = New-Object System.Drawing.Point($brandRightX, 22)
        $lstBrandColors.Location = New-Object System.Drawing.Point($brandRightX, 50)
        $lstBrandColors.Size = New-Object System.Drawing.Size($brandColumnWidth, 350)
        $btnAddBrand.Location = New-Object System.Drawing.Point(25, 420)
        $btnRenameBrand.Location = New-Object System.Drawing.Point(150, 420)
        $btnDeleteBrand.Location = New-Object System.Drawing.Point(265, 420)
        $btnUploadColors.Location = New-Object System.Drawing.Point($brandRightX, 420)
        $btnRenameColor.Location = New-Object System.Drawing.Point(($brandRightX + 175), 420)
        $btnReplaceColor.Location = New-Object System.Drawing.Point($brandRightX, 464)
        $btnOpenColor.Location = New-Object System.Drawing.Point(($brandRightX + 140), 464)
        $btnDeleteColor.Location = New-Object System.Drawing.Point(($brandRightX + 265), 464)
        $lblBrandCatalogHelp.Location = New-Object System.Drawing.Point(25, 525)
        $lblBrandCatalogHelp.Width = [Math]::Max(470, $settingsTabs.ClientSize.Width - 70)
        $tabBrands.AutoScrollMinSize = New-Object System.Drawing.Size(0, 595)
    } else {
        $brandListWidth = [Math]::Max(470, $settingsTabs.ClientSize.Width - 70)
        $lstBrands.Location = New-Object System.Drawing.Point(25, 50)
        $lstBrands.Size = New-Object System.Drawing.Size($brandListWidth, 210)
        $btnAddBrand.Location = New-Object System.Drawing.Point(25, 275)
        $btnRenameBrand.Location = New-Object System.Drawing.Point(150, 275)
        $btnDeleteBrand.Location = New-Object System.Drawing.Point(265, 275)
        $lblBrandColorsHeading.Location = New-Object System.Drawing.Point(25, 330)
        $lstBrandColors.Location = New-Object System.Drawing.Point(25, 358)
        $lstBrandColors.Size = New-Object System.Drawing.Size($brandListWidth, 225)
        $btnUploadColors.Location = New-Object System.Drawing.Point(25, 598)
        $btnRenameColor.Location = New-Object System.Drawing.Point(200, 598)
        $btnReplaceColor.Location = New-Object System.Drawing.Point(25, 642)
        $btnOpenColor.Location = New-Object System.Drawing.Point(165, 642)
        $btnDeleteColor.Location = New-Object System.Drawing.Point(290, 642)
        $lblBrandCatalogHelp.Location = New-Object System.Drawing.Point(25, 696)
        $lblBrandCatalogHelp.Width = $brandListWidth
        $tabBrands.AutoScrollMinSize = New-Object System.Drawing.Size(0, 770)
    }

    $availableSettingsWidth = [Math]::Max(470, $settingsTabs.ClientSize.Width - 70)
    $txtDefaultDirectory.Width = [Math]::Max(300, $availableSettingsWidth - 137)
    $btnBrowseDefault.Left = $txtDefaultDirectory.Right + 17
    $tabLocation.Controls[4].Width = $availableSettingsWidth
    $lblUpdateStatus.Width = $availableSettingsWidth
    $lblUpdateReleaseHelp.Width = $availableSettingsWidth

    if ($settingsTabs.ClientSize.Width -ge 820) {
        $updateColumnWidth = [Math]::Floor(($availableSettingsWidth - 37) / 2)
        $updateRightX = 28 + $updateColumnWidth + 37
        $lblGitHubOwner.Location = New-Object System.Drawing.Point(28, 72)
        $txtGitHubOwner.Location = New-Object System.Drawing.Point(28, 100)
        $txtGitHubOwner.Width = $updateColumnWidth
        $lblGitHubRepository.Location = New-Object System.Drawing.Point($updateRightX, 72)
        $txtGitHubRepository.Location = New-Object System.Drawing.Point($updateRightX, 100)
        $txtGitHubRepository.Width = $updateColumnWidth
        $lblUpdateAssetName.Location = New-Object System.Drawing.Point(28, 154)
        $txtUpdateAssetName.Location = New-Object System.Drawing.Point(28, 182)
        $txtUpdateAssetName.Width = $updateColumnWidth
        $chkUpdatesOnLaunch.Location = New-Object System.Drawing.Point(28, 234)
        $chkUpdatesOnLaunch.Width = $availableSettingsWidth
        $btnSaveUpdateSettings.Location = New-Object System.Drawing.Point(28, 286)
        $btnCheckUpdates.Location = New-Object System.Drawing.Point(236, 286)
        $lblUpdateStatus.Location = New-Object System.Drawing.Point(28, 350)
        $lblUpdateReleaseHelp.Location = New-Object System.Drawing.Point(28, 438)
        $tabUpdates.AutoScrollMinSize = New-Object System.Drawing.Size(0, 505)
    } else {
        $lblGitHubOwner.Location = New-Object System.Drawing.Point(28, 65)
        $txtGitHubOwner.Location = New-Object System.Drawing.Point(28, 93)
        $txtGitHubOwner.Width = $availableSettingsWidth
        $lblGitHubRepository.Location = New-Object System.Drawing.Point(28, 140)
        $txtGitHubRepository.Location = New-Object System.Drawing.Point(28, 168)
        $txtGitHubRepository.Width = $availableSettingsWidth
        $lblUpdateAssetName.Location = New-Object System.Drawing.Point(28, 215)
        $txtUpdateAssetName.Location = New-Object System.Drawing.Point(28, 243)
        $txtUpdateAssetName.Width = $availableSettingsWidth
        $chkUpdatesOnLaunch.Location = New-Object System.Drawing.Point(28, 290)
        $chkUpdatesOnLaunch.Width = $availableSettingsWidth
        $btnSaveUpdateSettings.Location = New-Object System.Drawing.Point(28, 335)
        $btnCheckUpdates.Location = New-Object System.Drawing.Point(236, 335)
        $lblUpdateStatus.Location = New-Object System.Drawing.Point(28, 392)
        $lblUpdateReleaseHelp.Location = New-Object System.Drawing.Point(28, 480)
        $tabUpdates.AutoScrollMinSize = New-Object System.Drawing.Size(0, 545)
    }
}

# EVENTS
$form.Add_Resize({ Update-ResponsiveLayout })
$cmbCategory.Add_SelectedIndexChanged({ Update-CreateSubcategories })
$cmbSubcategory.Add_SelectedIndexChanged({ Update-Preview })
$txtDesignName.Add_TextChanged({ Update-Preview })
$btnSelectAllColors.Add_Click({
    for ($index = 0; $index -lt $clbDesignColors.Items.Count; $index++) { $clbDesignColors.SetItemChecked($index, $true) }
})
$btnClearColors.Add_Click({
    for ($index = 0; $index -lt $clbDesignColors.Items.Count; $index++) { $clbDesignColors.SetItemChecked($index, $false) }
})

$btnCreateDefault.Add_Click({ Create-DesignFolders ([string]$script:Settings.DefaultDirectory) })
$btnChooseCreate.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose where the new master design folder will be created'
    if (Test-Path -LiteralPath ([string]$script:Settings.DefaultDirectory)) { $dialog.SelectedPath = [string]$script:Settings.DefaultDirectory }
    if ($dialog.ShowDialog() -eq 'OK') { Create-DesignFolders $dialog.SelectedPath }
})
$btnOpenDefault.Add_Click({
    $path = [string]$script:Settings.DefaultDirectory
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    Start-Process explorer.exe -ArgumentList @("`"$path`"")
})

$lstBrands.Add_SelectedIndexChanged({ Refresh-BrandColors })
$btnAddBrand.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Enter the shirt brand name:', $script:AppName, '').Trim()
    if (-not $name) { return }
    if (@($script:Settings.BrandCatalog | Where-Object { [string]$_.Name -ieq $name }).Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show('A brand with that name already exists.', $script:AppName, 'OK', 'Warning') | Out-Null
        return
    }
    $brand = [pscustomobject]@{ Id = [guid]::NewGuid().ToString('N'); Name = $name; Colors = @() }
    $script:Settings.BrandCatalog = @($script:Settings.BrandCatalog) + $brand
    Save-Settings; Refresh-BrandCatalog
    $lstBrands.SelectedIndex = $lstBrands.Items.Count - 1
})
$btnRenameBrand.Add_Click({
    $brand = Get-SelectedBrand
    if ($null -eq $brand) { return }
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Enter the shirt brand name:', $script:AppName, [string]$brand.Name).Trim()
    if (-not $name) { return }
    if (@($script:Settings.BrandCatalog | Where-Object { $_ -ne $brand -and [string]$_.Name -ieq $name }).Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show('A brand with that name already exists.', $script:AppName, 'OK', 'Warning') | Out-Null
        return
    }
    $brand.Name = $name
    Save-Settings; Refresh-BrandCatalog
})
$btnDeleteBrand.Add_Click({
    $brand = Get-SelectedBrand
    if ($null -eq $brand) { return }
    $message = "Delete brand '$($brand.Name)' and all $(@($brand.Colors).Count) color file(s) from the app catalog?`r`n`r`nColor files already copied into existing design folders will not be deleted."
    if ([System.Windows.Forms.MessageBox]::Show($message, $script:AppName, 'YesNo', 'Warning') -ne 'Yes') { return }
    try {
        $brandDirectory = Join-Path $script:BrandCatalogDirectory ([string]$brand.Id)
        if (Test-Path -LiteralPath $brandDirectory) { Remove-Item -LiteralPath $brandDirectory -Recurse -Force -ErrorAction Stop }
        $script:Settings.BrandCatalog = @($script:Settings.BrandCatalog | Where-Object { $_ -ne $brand })
        Save-Settings; Refresh-BrandCatalog
    } catch { [System.Windows.Forms.MessageBox]::Show("The brand could not be deleted.`r`n`r`n$($_.Exception.Message)", $script:AppName, 'OK', 'Error') | Out-Null }
})
$btnUploadColors.Add_Click({
    $brand = Get-SelectedBrand
    if ($null -eq $brand) {
        [System.Windows.Forms.MessageBox]::Show('Add or select a brand first.', $script:AppName, 'OK', 'Information') | Out-Null
        return
    }
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Choose color files for $($brand.Name)"
    $dialog.Filter = 'Image files|*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.tif;*.tiff|All files|*.*'
    $dialog.Multiselect = $true
    if ($dialog.ShowDialog() -ne 'OK') { return }
    try {
        $brandDirectory = Join-Path $script:BrandCatalogDirectory ([string]$brand.Id)
        New-Item -ItemType Directory -Path $brandDirectory -Force -ErrorAction Stop | Out-Null
        $added = 0
        $skipped = 0
        foreach ($sourcePath in @($dialog.FileNames)) {
            $colorName = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath).Trim()
            if (-not $colorName -or @($brand.Colors | Where-Object { [string]$_.Name -ieq $colorName }).Count -gt 0) { $skipped++; continue }
            $colorId = [guid]::NewGuid().ToString('N')
            $extension = [System.IO.Path]::GetExtension($sourcePath).ToLowerInvariant()
            $fileName = "$colorId$extension"
            Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $brandDirectory $fileName) -ErrorAction Stop
            $brand.Colors = @($brand.Colors) + [pscustomobject]@{ Id = $colorId; Name = $colorName; FileName = $fileName }
            $added++
        }
        Save-Settings; Refresh-BrandColors; Refresh-CreateColorChoices
        $summary = "$added color file(s) added to $($brand.Name)."
        if ($skipped -gt 0) { $summary += "`r`n$skipped duplicate or unnamed file(s) skipped." }
        [System.Windows.Forms.MessageBox]::Show($summary, $script:AppName, 'OK', 'Information') | Out-Null
    } catch { [System.Windows.Forms.MessageBox]::Show("The color files could not be added.`r`n`r`n$($_.Exception.Message)", $script:AppName, 'OK', 'Error') | Out-Null }
})
$btnRenameColor.Add_Click({
    $brand = Get-SelectedBrand
    $color = Get-SelectedBrandColor
    if ($null -eq $brand -or $null -eq $color) { return }
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Enter the color name:', $script:AppName, [string]$color.Name).Trim()
    if (-not $name) { return }
    if (@($brand.Colors | Where-Object { $_ -ne $color -and [string]$_.Name -ieq $name }).Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show('That brand already has a color with this name.', $script:AppName, 'OK', 'Warning') | Out-Null
        return
    }
    $color.Name = $name
    Save-Settings; Refresh-BrandColors; Refresh-CreateColorChoices
})
$btnReplaceColor.Add_Click({
    $brand = Get-SelectedBrand
    $color = Get-SelectedBrandColor
    if ($null -eq $brand -or $null -eq $color) { return }
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Choose the replacement file for $($brand.Name) — $($color.Name)"
    $dialog.Filter = 'Image files|*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.tif;*.tiff|All files|*.*'
    if ($dialog.ShowDialog() -ne 'OK') { return }
    try {
        $brandDirectory = Join-Path $script:BrandCatalogDirectory ([string]$brand.Id)
        New-Item -ItemType Directory -Path $brandDirectory -Force -ErrorAction Stop | Out-Null
        $oldPath = Get-CatalogColorPath $brand $color
        $extension = [System.IO.Path]::GetExtension($dialog.FileName).ToLowerInvariant()
        $newFileName = "$($color.Id)$extension"
        $newPath = Join-Path $brandDirectory $newFileName
        Copy-Item -LiteralPath $dialog.FileName -Destination $newPath -Force -ErrorAction Stop
        if ($oldPath -ne $newPath -and (Test-Path -LiteralPath $oldPath)) { Remove-Item -LiteralPath $oldPath -Force -ErrorAction SilentlyContinue }
        $color.FileName = $newFileName
        Save-Settings; Refresh-BrandColors; Refresh-CreateColorChoices
    } catch { [System.Windows.Forms.MessageBox]::Show("The color file could not be replaced.`r`n`r`n$($_.Exception.Message)", $script:AppName, 'OK', 'Error') | Out-Null }
})
$btnOpenColor.Add_Click({
    $brand = Get-SelectedBrand
    $color = Get-SelectedBrandColor
    if ($null -eq $brand -or $null -eq $color) { return }
    $path = Get-CatalogColorPath $brand $color
    if (Test-Path -LiteralPath $path -PathType Leaf) { Start-Process -FilePath $path }
    else { [System.Windows.Forms.MessageBox]::Show('The stored color file is missing. Use Replace File to restore it.', $script:AppName, 'OK', 'Warning') | Out-Null }
})
$btnDeleteColor.Add_Click({
    $brand = Get-SelectedBrand
    $color = Get-SelectedBrandColor
    if ($null -eq $brand -or $null -eq $color) { return }
    if ([System.Windows.Forms.MessageBox]::Show("Delete '$($color.Name)' from $($brand.Name)? Existing design folders will not be changed.", $script:AppName, 'YesNo', 'Warning') -ne 'Yes') { return }
    try {
        $path = Get-CatalogColorPath $brand $color
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
        $brand.Colors = @($brand.Colors | Where-Object { $_ -ne $color })
        Save-Settings; Refresh-BrandColors; Refresh-CreateColorChoices
    } catch { [System.Windows.Forms.MessageBox]::Show("The color could not be deleted.`r`n`r`n$($_.Exception.Message)", $script:AppName, 'OK', 'Error') | Out-Null }
})

$lstCategories.Add_SelectedIndexChanged({ Refresh-SettingsSubcategories })
$btnAddCategory.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Enter the new category name:', $script:AppName, '')
    $name = $name.Trim()
    if ($name) {
        $next = 1
        if (@($script:Settings.Categories).Count -gt 0) { $next = ([int](($script:Settings.Categories | Measure-Object Id -Maximum).Maximum)) + 1 }
        $script:Settings.Categories = @($script:Settings.Categories) + [pscustomobject]@{ Id = $next; Name = $name; Subcategories = @() }
        Save-Settings; Refresh-SettingsLists; Update-CreateCategories
        $lstCategories.SelectedIndex = $lstCategories.Items.Count - 1
    }
})
$btnRenameCategory.Add_Click({
    if ($lstCategories.SelectedIndex -lt 0) { return }
    $category = @($script:Settings.Categories)[$lstCategories.SelectedIndex]
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Enter the category name:', $script:AppName, [string]$category.Name).Trim()
    if ($name) { $category.Name = $name; Save-Settings; Refresh-SettingsLists; Update-CreateCategories }
})
$btnDeleteCategory.Add_Click({
    if ($lstCategories.SelectedIndex -lt 0) { return }
    $index = $lstCategories.SelectedIndex
    $category = @($script:Settings.Categories)[$index]
    if ([System.Windows.Forms.MessageBox]::Show("Delete category '$($category.Name)' from the choices? Existing folders and history will not be deleted.", $script:AppName, 'YesNo', 'Warning') -eq 'Yes') {
        $list = New-Object System.Collections.ArrayList
        [void]$list.AddRange(@($script:Settings.Categories)); $list.RemoveAt($index)
        $script:Settings.Categories = @($list); Save-Settings; Refresh-SettingsLists; Update-CreateCategories
    }
})
$btnAddSubcategory.Add_Click({
    if ($lstCategories.SelectedIndex -lt 0) { [System.Windows.Forms.MessageBox]::Show('Select a category first.', $script:AppName) | Out-Null; return }
    $category = @($script:Settings.Categories)[$lstCategories.SelectedIndex]
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Enter the new subcategory name:', $script:AppName, '').Trim()
    if ($name) {
        $next = 1
        if (@($category.Subcategories).Count -gt 0) { $next = ([int](($category.Subcategories | Measure-Object Id -Maximum).Maximum)) + 1 }
        $category.Subcategories = @($category.Subcategories) + [pscustomobject]@{ Id = $next; Name = $name }
        Save-Settings; Refresh-SettingsSubcategories; Update-CreateCategories
        $lstSubcategories.SelectedIndex = $lstSubcategories.Items.Count - 1
    }
})
$btnRenameSubcategory.Add_Click({
    if ($lstCategories.SelectedIndex -lt 0 -or $lstSubcategories.SelectedIndex -lt 0) { return }
    $category = @($script:Settings.Categories)[$lstCategories.SelectedIndex]
    $subcategory = @($category.Subcategories)[$lstSubcategories.SelectedIndex]
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Enter the subcategory name:', $script:AppName, [string]$subcategory.Name).Trim()
    if ($name) { $subcategory.Name = $name; Save-Settings; Refresh-SettingsSubcategories; Update-CreateCategories }
})
$btnDeleteSubcategory.Add_Click({
    if ($lstCategories.SelectedIndex -lt 0 -or $lstSubcategories.SelectedIndex -lt 0) { return }
    $category = @($script:Settings.Categories)[$lstCategories.SelectedIndex]
    $index = $lstSubcategories.SelectedIndex
    $subcategory = @($category.Subcategories)[$index]
    if ([System.Windows.Forms.MessageBox]::Show("Delete subcategory '$($subcategory.Name)' from the choices? Existing folders and history will not be deleted.", $script:AppName, 'YesNo', 'Warning') -eq 'Yes') {
        $list = New-Object System.Collections.ArrayList
        [void]$list.AddRange(@($category.Subcategories)); $list.RemoveAt($index)
        $category.Subcategories = @($list); Save-Settings; Refresh-SettingsSubcategories; Update-CreateCategories
    }
})

$btnBrowseDefault.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the preset design folder location'
    if (Test-Path -LiteralPath $txtDefaultDirectory.Text) { $dialog.SelectedPath = $txtDefaultDirectory.Text }
    if ($dialog.ShowDialog() -eq 'OK') { $txtDefaultDirectory.Text = $dialog.SelectedPath }
})
$btnSaveDefault.Add_Click({
    $path = $txtDefaultDirectory.Text.Trim()
    if (-not $path) { [System.Windows.Forms.MessageBox]::Show('Enter or choose a directory.', $script:AppName) | Out-Null; return }
    try {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop | Out-Null }
        $script:Settings.DefaultDirectory = $path; Save-Settings
        $lblDefaultPath.Text = "Preset location: $path"; Update-Preview
        [System.Windows.Forms.MessageBox]::Show('Preset location saved.', $script:AppName, 'OK', 'Information') | Out-Null
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null }
})
$btnSaveTemplate.Add_Click({
    $sizes = @($txtSizes.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $template = @($txtTemplate.Lines | ForEach-Object { $_.Trim().TrimStart('\').TrimEnd('\') } | Where-Object { $_ })
    if ($sizes.Count -eq 0 -or $template.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('The size list and folder template must each contain at least one line.', $script:AppName, 'OK', 'Warning') | Out-Null; return }
    foreach ($path in $template) {
        if ([System.IO.Path]::IsPathRooted($path) -or $path -match '\.\.') { [System.Windows.Forms.MessageBox]::Show("Template paths must be relative and cannot contain '..'.`r`n`r`nInvalid: $path", $script:AppName, 'OK', 'Warning') | Out-Null; return }
    }
    $script:Settings.SizeFolders = $sizes
    $script:Settings.FolderTemplate = $template
    Save-Settings
    [System.Windows.Forms.MessageBox]::Show('Folder template saved. It will be used for new designs and when repairing missing folders.', $script:AppName, 'OK', 'Information') | Out-Null
})
$btnResetTemplate.Add_Click({
    if ([System.Windows.Forms.MessageBox]::Show('Restore the size list and folder template from the original picture?', $script:AppName, 'YesNo', 'Question') -eq 'Yes') {
        $defaults = New-DefaultSettings
        $script:Settings.SizeFolders = @($defaults.SizeFolders)
        $script:Settings.FolderTemplate = @($defaults.FolderTemplate)
        $txtSizes.Lines = @($script:Settings.SizeFolders); $txtTemplate.Lines = @($script:Settings.FolderTemplate); Save-Settings
    }
})

$btnOpenDesign.Add_Click({
    $design = Get-SelectedCreatedDesign
    if ($null -eq $design) { return }
    if (Test-Path -LiteralPath ([string]$design.Path)) { Start-Process explorer.exe -ArgumentList @("`"$($design.Path)`"") }
    else { [System.Windows.Forms.MessageBox]::Show('That folder is no longer at its recorded location.', $script:AppName, 'OK', 'Warning') | Out-Null }
})
$btnRepairDesign.Add_Click({
    $design = Get-SelectedCreatedDesign
    if ($null -eq $design) { return }
    if (-not (Test-Path -LiteralPath ([string]$design.Path))) { [System.Windows.Forms.MessageBox]::Show('That master folder is no longer at its recorded location.', $script:AppName, 'OK', 'Warning') | Out-Null; return }
    $count = 0
    foreach ($relativePath in Expand-FolderTemplate) {
        $full = Join-Path ([string]$design.Path) $relativePath
        if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null; $count++ }
    }
    [System.Windows.Forms.MessageBox]::Show("Done. $count missing folder(s) were created. Existing files and folders were not changed.", $script:AppName, 'OK', 'Information') | Out-Null
})
$btnRenameDesign.Add_Click({
    $design = Get-SelectedCreatedDesign
    if ($null -eq $design) { return }
    $newName = Sanitize-DesignName ([Microsoft.VisualBasic.Interaction]::InputBox('Enter the new design name:', $script:AppName, [string]$design.Name))
    if (-not $newName) { return }
    $oldPath = [string]$design.Path
    $parent = Split-Path -Parent $oldPath
    $folderName = "$(Format-Number ([int]$design.CategoryId))-$(Format-Number ([int]$design.SubcategoryId))-$(Format-Number ([int]$design.DesignNumber)) - $newName"
    $newPath = Join-Path $parent $folderName
    try {
        if (-not (Test-Path -LiteralPath $oldPath)) { throw 'The original folder could not be found.' }
        if ($newPath -ne $oldPath -and (Test-Path -LiteralPath $newPath)) { throw 'A folder with the new name already exists.' }
        if ($newPath -ne $oldPath) { Rename-Item -LiteralPath $oldPath -NewName $folderName -ErrorAction Stop }
        $design.Name = $newName; $design.Path = $newPath; Save-Settings; Refresh-CreatedDesigns
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null }
})
$btnRemoveRecord.Add_Click({
    $design = Get-SelectedCreatedDesign
    if ($null -eq $design) { return }
    if ([System.Windows.Forms.MessageBox]::Show('Remove this entry from the app history? The actual folder and its files will NOT be deleted.', $script:AppName, 'YesNo', 'Warning') -eq 'Yes') {
        $script:Settings.CreatedDesigns = @($script:Settings.CreatedDesigns | Where-Object { $_ -ne $design })
        Save-Settings; Refresh-CreatedDesigns; Update-Preview
    }
})
$btnRefreshCreated.Add_Click({ Refresh-CreatedDesigns })
$btnClearHistoryCache.Add_Click({ Clear-CreatedDesignHistoryAndCache })
$gridCreated.Add_CellDoubleClick({ $btnOpenDesign.PerformClick() })

$menuCategories.Add_Click({ $tabs.SelectedTab = $tabSettings; $settingsTabs.SelectedTab = $tabCat })
$menuBrands.Add_Click({ $tabs.SelectedTab = $tabSettings; $settingsTabs.SelectedTab = $tabBrands })
$menuFolderTemplate.Add_Click({ $tabs.SelectedTab = $tabSettings; $settingsTabs.SelectedTab = $tabFolders })
$menuPresetLocation.Add_Click({ $tabs.SelectedTab = $tabSettings; $settingsTabs.SelectedTab = $tabLocation })
$menuUpdates.Add_Click({ $tabs.SelectedTab = $tabSettings; $settingsTabs.SelectedTab = $tabUpdates })
$btnManageCategories.Add_Click({ $tabs.SelectedTab = $tabSettings; $settingsTabs.SelectedTab = $tabCat })
$btnReturnToCreate.Add_Click({ $tabs.SelectedTab = $tabCreate; $txtDesignName.Focus() })
$btnSaveUpdateSettings.Add_Click({
    $owner = $txtGitHubOwner.Text.Trim()
    $repository = $txtGitHubRepository.Text.Trim()
    $assetName = $txtUpdateAssetName.Text.Trim()
    if (($owner -and $owner -notmatch '^[A-Za-z0-9_.-]+$') -or ($repository -and $repository -notmatch '^[A-Za-z0-9_.-]+$')) {
        [System.Windows.Forms.MessageBox]::Show('The GitHub owner and repository may contain letters, numbers, periods, underscores, and hyphens only.', $script:AppName, 'OK', 'Warning') | Out-Null
        return
    }
    if (-not $assetName) { $assetName = 'ShirtFolderSetup.exe'; $txtUpdateAssetName.Text = $assetName }
    $script:Settings.GitHubOwner = $owner
    $script:Settings.GitHubRepository = $repository
    $script:Settings.UpdateAssetName = $assetName
    $script:Settings.CheckForUpdatesOnLaunch = [bool]$chkUpdatesOnLaunch.Checked
    Save-Settings
    Set-UpdateStatus "Update settings saved. Current version: $($script:AppVersion)" ([System.Drawing.Color]::FromArgb(34, 120, 74))
})
$btnCheckUpdates.Add_Click({
    $btnSaveUpdateSettings.PerformClick()
    Check-GitHubUpdates $false
})

Add-Type -AssemblyName Microsoft.VisualBasic
Refresh-SettingsLists
Refresh-BrandCatalog
Update-CreateCategories
Refresh-CreatedDesigns
$lblDefaultPath.Text = "Preset location: $($script:Settings.DefaultDirectory)"
$txtGitHubOwner.Text = [string]$script:Settings.GitHubOwner
$txtGitHubRepository.Text = [string]$script:Settings.GitHubRepository
$txtUpdateAssetName.Text = [string]$script:Settings.UpdateAssetName
$chkUpdatesOnLaunch.Checked = [bool]$script:Settings.CheckForUpdatesOnLaunch
Set-UpdateStatus "Current version: $($script:AppVersion). Enter your GitHub release settings to enable updates."
Update-Preview
Update-ResponsiveLayout

$form.Add_Shown({
    if ([bool]$script:Settings.CheckForUpdatesOnLaunch -and ([string]$script:Settings.GitHubOwner).Trim() -and ([string]$script:Settings.GitHubRepository).Trim()) {
        Check-GitHubUpdates $true
    }
})
[void]$form.ShowDialog()
