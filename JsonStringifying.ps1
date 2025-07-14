param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile
)

function Show-Menu {
    Write-Host "`n=== JSON Transformer ===" -ForegroundColor Cyan
    Write-Host "1. Stringify JSON (escape quotes and format as string) -> .txt"
    Write-Host "2. Minify JSON (remove whitespace) -> .json"
    Write-Host "3. Pretty Print JSON (format with indentation) -> .json"
    Write-Host "4. Convert to Base64 -> .b64/.txt"
    Write-Host "5. URL Encode JSON -> .txt"
    Write-Host "6. Escape for C# string literal -> .cs/.txt"
    Write-Host "7. Convert to JavaScript variable -> .js"
    Write-Host "8. Convert to XML -> .xml"
    Write-Host "0. Exit"
    Write-Host "=========================" -ForegroundColor Cyan
}

function Test-JsonFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: File '$FilePath' not found!" -ForegroundColor Red
        return $false
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        $null = $content | ConvertFrom-Json
        return $true
    }
    catch {
        Write-Host "Error: Invalid JSON file!" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Get-OutputFileName {
    param(
        [string]$InputFile,
        [string]$Suffix,
        [string]$Extension
    )
    
    $directory = Split-Path $InputFile -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    
    return Join-Path $directory "$baseName$Suffix$Extension"
}

function Stringify-Json {
    param([string]$JsonContent)
    
    # Escape quotes and backslashes, then wrap in quotes
    $escaped = $JsonContent -replace '\\', '\\\\' -replace '"', '\"' -replace "`r`n", '\n' -replace "`n", '\n'
    return "`"$escaped`""
}

function Minify-Json {
    param([string]$JsonContent)
    
    try {
        $jsonObject = $JsonContent | ConvertFrom-Json
        return ($jsonObject | ConvertTo-Json -Compress -Depth 100)
    }
    catch {
        Write-Host "Error minifying JSON: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function PrettyPrint-Json {
    param([string]$JsonContent)
    
    try {
        $jsonObject = $JsonContent | ConvertFrom-Json
        return ($jsonObject | ConvertTo-Json -Depth 100)
    }
    catch {
        Write-Host "Error formatting JSON: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function ConvertTo-Base64 {
    param([string]$JsonContent)
    
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonContent)
    return [System.Convert]::ToBase64String($bytes)
}

function ConvertTo-UrlEncoded {
    param([string]$JsonContent)
    
    return [System.Web.HttpUtility]::UrlEncode($JsonContent)
}

function ConvertTo-CSharpString {
    param([string]$JsonContent)
    
    # Escape for C# string literal with proper formatting
    $escaped = $JsonContent -replace '\\', '\\\\' -replace '"', '\"' -replace "`r`n", '\r\n' -replace "`n", '\n' -replace "`r", '\r' -replace "`t", '\t'
    
    # Create verbatim string (easier to read)
    $verbatimString = $JsonContent -replace '"', '""'
    
    # Build the C# code string manually to avoid here-string issues
    $csharpCode = "// Option 1: Verbatim string (recommended for JSON)`r`n"
    $csharpCode += "string jsonString = @`"$verbatimString`";`r`n`r`n"
    $csharpCode += "// Option 2: Escaped string literal`r`n"
    $csharpCode += "string jsonStringEscaped = `"$escaped`";"
    
    return $csharpCode
}

function ConvertTo-JavaScript {
    param([string]$JsonContent)
    
    try {
        $jsonObject = $JsonContent | ConvertFrom-Json
        $minifiedJson = $jsonObject | ConvertTo-Json -Compress -Depth 100
        
        # Build JavaScript code manually to avoid here-string issues
        $jsCode = "// JSON as JavaScript object`r`n"
        $jsCode += "const jsonData = $minifiedJson;`r`n`r`n"
        $jsCode += "// JSON as string variable`r`n"
        $jsCode += "const jsonString = ``$minifiedJson``;`r`n`r`n"
        $jsCode += "// Export for Node.js (uncomment if needed)`r`n"
        $jsCode += "// module.exports = jsonData;"
        
        return $jsCode
    }
    catch {
        Write-Host "Error converting to JavaScript: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function ConvertTo-Xml {
    param([string]$JsonContent)
    
    try {
        $jsonObject = $JsonContent | ConvertFrom-Json
        
        # Create XML document
        $xmlDoc = New-Object System.Xml.XmlDocument
        $root = $xmlDoc.CreateElement("root")
        $xmlDoc.AppendChild($root) | Out-Null
        
        # Convert JSON object to XML (simplified conversion)
        function Add-JsonToXml {
            param($JsonObj, $XmlParent, $XmlDoc)
            
            if ($JsonObj -is [PSCustomObject]) {
                $JsonObj.PSObject.Properties | ForEach-Object {
                    $element = $XmlDoc.CreateElement($_.Name)
                    if ($_.Value -is [PSCustomObject] -or $_.Value -is [Array]) {
                        Add-JsonToXml $_.Value $element $XmlDoc
                    } else {
                        $element.InnerText = $_.Value.ToString()
                    }
                    $XmlParent.AppendChild($element) | Out-Null
                }
            } elseif ($JsonObj -is [Array]) {
                for ($i = 0; $i -lt $JsonObj.Count; $i++) {
                    $element = $XmlDoc.CreateElement("item")
                    $element.SetAttribute("index", $i)
                    if ($JsonObj[$i] -is [PSCustomObject] -or $JsonObj[$i] -is [Array]) {
                        Add-JsonToXml $JsonObj[$i] $element $XmlDoc
                    } else {
                        $element.InnerText = $JsonObj[$i].ToString()
                    }
                    $XmlParent.AppendChild($element) | Out-Null
                }
            }
        }
        
        Add-JsonToXml $jsonObject $root $xmlDoc
        
        # Format XML with indentation
        $stringWriter = New-Object System.IO.StringWriter
        $xmlWriter = New-Object System.Xml.XmlTextWriter($stringWriter)
        $xmlWriter.Formatting = [System.Xml.Formatting]::Indented
        $xmlDoc.WriteContentTo($xmlWriter)
        
        return $stringWriter.ToString()
    }
    catch {
        Write-Host "Error converting to XML: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Main script execution
if (-not (Test-JsonFile $InputFile)) {
    exit 1
}

$jsonContent = Get-Content $InputFile -Raw

do {
    Show-Menu
    $choice = Read-Host "`nEnter your choice"
    
    switch ($choice) {
        "1" {
            Write-Host "`nStringifying JSON..." -ForegroundColor Yellow
            $result = Stringify-Json $jsonContent
            $outputFile = Get-OutputFileName $InputFile "_stringified" ".txt"
            $result | Out-File $outputFile -Encoding UTF8
            Write-Host "Stringified JSON saved to: $outputFile" -ForegroundColor Green
        }
        
        "2" {
            Write-Host "`nMinifying JSON..." -ForegroundColor Yellow
            $result = Minify-Json $jsonContent
            if ($result) {
                $outputFile = Get-OutputFileName $InputFile "_minified" ".json"
                $result | Out-File $outputFile -Encoding UTF8
                Write-Host "Minified JSON saved to: $outputFile" -ForegroundColor Green
            }
        }
        
        "3" {
            Write-Host "`nPretty printing JSON..." -ForegroundColor Yellow
            $result = PrettyPrint-Json $jsonContent
            if ($result) {
                $outputFile = Get-OutputFileName $InputFile "_pretty" ".json"
                $result | Out-File $outputFile -Encoding UTF8
                Write-Host "Pretty printed JSON saved to: $outputFile" -ForegroundColor Green
            }
        }
        
        "4" {
            Write-Host "`nConverting to Base64..." -ForegroundColor Yellow
            $result = ConvertTo-Base64 $jsonContent
            $outputFile = Get-OutputFileName $InputFile "_base64" ".b64"
            $result | Out-File $outputFile -Encoding UTF8
            Write-Host "Base64 encoded JSON saved to: $outputFile" -ForegroundColor Green
        }
        
        "5" {
            Write-Host "`nURL encoding JSON..." -ForegroundColor Yellow
            Add-Type -AssemblyName System.Web
            $result = ConvertTo-UrlEncoded $jsonContent
            $outputFile = Get-OutputFileName $InputFile "_urlencoded" ".txt"
            $result | Out-File $outputFile -Encoding UTF8
            Write-Host "URL encoded JSON saved to: $outputFile" -ForegroundColor Green
        }
        
        "6" {
            Write-Host "`nConverting to C# string literal..." -ForegroundColor Yellow
            $result = ConvertTo-CSharpString $jsonContent
            $outputFile = Get-OutputFileName $InputFile "_csharp" ".cs"
            $result | Out-File $outputFile -Encoding UTF8
            Write-Host "C# code saved to: $outputFile" -ForegroundColor Green
        }
        
        "7" {
            Write-Host "`nConverting to JavaScript..." -ForegroundColor Yellow
            $result = ConvertTo-JavaScript $jsonContent
            if ($result) {
                $outputFile = Get-OutputFileName $InputFile "_javascript" ".js"
                $result | Out-File $outputFile -Encoding UTF8
                Write-Host "JavaScript code saved to: $outputFile" -ForegroundColor Green
            }
        }
        
        "8" {
            Write-Host "`nConverting to XML..." -ForegroundColor Yellow
            $result = ConvertTo-Xml $jsonContent
            if ($result) {
                $outputFile = Get-OutputFileName $InputFile "_converted" ".xml"
                $result | Out-File $outputFile -Encoding UTF8
                Write-Host "XML file saved to: $outputFile" -ForegroundColor Green
            }
        }
        
        "0" {
            Write-Host "Goodbye!" -ForegroundColor Green
            break
        }
        
        default {
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
        }
    }
    
    if ($choice -ne "0") {
        Read-Host "`nPress Enter to continue"
    }
    
} while ($choice -ne "0")