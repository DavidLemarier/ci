Set-StrictMode -Version Latest
$script:PACKAGE_FOLDER = "$env:APPVEYOR_BUILD_FOLDER"
Set-Location $script:PACKAGE_FOLDER
$script:SOLDAT_CHANNEL = "stable"
$script:SOLDAT_DIRECTORY_NAME = "Soldat"
if ($env:SOLDAT_CHANNEL -and ($env:SOLDAT_CHANNEL.tolower() -ne "stable")) {
    $script:SOLDAT_CHANNEL = "$env:SOLDAT_CHANNEL"
    $script:SOLDAT_DIRECTORY_NAME = "$script:SOLDAT_DIRECTORY_NAME "
    $script:SOLDAT_DIRECTORY_NAME += $script:SOLDAT_CHANNEL.substring(0,1).toupper()
    $script:SOLDAT_DIRECTORY_NAME += $script:SOLDAT_CHANNEL.substring(1).tolower()
}

$script:SOLDAT_EXE_PATH = "$script:PACKAGE_FOLDER\$script:SOLDAT_DIRECTORY_NAME\soldat.exe"
$script:SOLDAT_SCRIPT_PATH = "$script:PACKAGE_FOLDER\$script:SOLDAT_DIRECTORY_NAME\resources\cli\soldat.cmd"
$script:RECRUE_SCRIPT_PATH = "$script:PACKAGE_FOLDER\$script:SOLDAT_DIRECTORY_NAME\resources\app\recrue\bin\recrue.cmd"
$script:NPM_SCRIPT_PATH = "$script:PACKAGE_FOLDER\$script:SOLDAT_DIRECTORY_NAME\resources\app\recrue\node_modules\.bin\npm.cmd"

if ($env:SOLDAT_LINT_WITH_BUNDLED_NODE -eq "false") {
  $script:SOLDAT_LINT_WITH_BUNDLED_NODE = $FALSE
  $script:NPM_SCRIPT_PATH = "npm"
} else {
  $script:SOLDAT_LINT_WITH_BUNDLED_NODE = $TRUE
}

function DownloadSoldat() {
    Write-Host "Downloading latest Soldat release..."
    $source = "https://soldat.tv/download/windows_zip?channel=$script:SOLDAT_CHANNEL"
    $destination = "$script:PACKAGE_FOLDER\soldat.zip"
    appveyor DownloadFile $source -FileName $destination
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
}

function ExtractSoldat() {
    Remove-Item "$script:PACKAGE_FOLDER\$script:SOLDAT_DIRECTORY_NAME" -Recurse -ErrorAction Ignore
    Unzip "$script:PACKAGE_FOLDER\soldat.zip" "$script:PACKAGE_FOLDER"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function PrintVersions() {
    Write-Host -NoNewLine "Using Soldat version: "
    $soldatVer = & "$script:SOLDAT_EXE_PATH" --version | Out-String
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
    Write-Host $soldatVer
    Write-Host "Using RECRUE version: "
    & "$script:RECRUE_SCRIPT_PATH" -v
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
}

function InstallPackage() {
    Write-Host "Downloading package dependencies..."
    & "$script:RECRUE_SCRIPT_PATH" clean
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
    if ($script:SOLDAT_LINT_WITH_BUNDLED_NODE -eq $TRUE) {
      & "$script:RECRUE_SCRIPT_PATH" install
      # Set the PATH to include the node.exe bundled with RECRUE
      $newPath = "$script:PACKAGE_FOLDER\$script:SOLDAT_DIRECTORY_NAME\resources\app\recrue\bin;$env:PATH"
      $env:PATH = $newPath
      [Environment]::SetEnvironmentVariable("PATH", "$newPath", "User")
    } else {
      & "$script:RECRUE_SCRIPT_PATH" install --production
      if ($LASTEXITCODE -ne 0) {
          ExitWithCode -exitcode $LASTEXITCODE
      }
      # Use the system NPM to install the devDependencies
      Write-Host "Using Node.js version:"
      & node --version
      if ($LASTEXITCODE -ne 0) {
          ExitWithCode -exitcode $LASTEXITCODE
      }
      Write-Host "Using NPM version:"
      & npm --version
      if ($LASTEXITCODE -ne 0) {
          ExitWithCode -exitcode $LASTEXITCODE
      }
      Write-Host "Installing remaining dependencies..."
      & npm install
    }
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
    InstallDependencies
}

function InstallDependencies() {
    if ($env:RECRUE_TEST_PACKAGES) {
        Write-Host "Installing soldat package dependencies..."
        $RECRUE_TEST_PACKAGES = $env:RECRUE_TEST_PACKAGES -split "\s+"
        $RECRUE_TEST_PACKAGES | foreach {
            Write-Host "$_"
            & "$script:RECRUE_SCRIPT_PATH" install $_
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }
    }
}


function HasLinter([String] $LinterName) {
    $output = &"$script:NPM_SCRIPT_PATH" ls --parseable --dev --depth=0 $LinterName 2>$null
    if ($LastExitCode -eq 0) {
        if ($output.Trim() -ne "") {
            return $true
        }
    }

    return $false
}

function RunLinters() {
    $libpath = "$script:PACKAGE_FOLDER\lib"
    $libpathexists = Test-Path $libpath
    $srcpath = "$script:PACKAGE_FOLDER\src"
    $srcpathexists = Test-Path $srcpath
    $specpath = "$script:PACKAGE_FOLDER\spec"
    $specpathexists = Test-Path $specpath
    $coffeelintpath = "$script:PACKAGE_FOLDER\node_modules\.bin\coffeelint.cmd"
    $lintwithcoffeelint = HasLinter -LinterName "coffeelint"
    $eslintpath = "$script:PACKAGE_FOLDER\node_modules\.bin\eslint.cmd"
    $lintwitheslint = HasLinter -LinterName "eslint"
    $standardpath = "$script:PACKAGE_FOLDER\node_modules\.bin\standard.cmd"
    $lintwithstandard = HasLinter -LinterName "standard"
    if (($libpathexists -or $srcpathexists) -and ($lintwithcoffeelint -or $lintwitheslint -or $lintwithstandard)) {
        Write-Host "Linting package..."
    }

    if ($libpathexists) {
        if ($lintwithcoffeelint) {
            & "$coffeelintpath" lib
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($lintwitheslint) {
            & "$eslintpath" lib
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($lintwithstandard) {
            & "$standardpath" lib/**/*.js
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }
    }

    if ($srcpathexists) {
        if ($lintwithcoffeelint) {
            & "$coffeelintpath" src
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($lintwitheslint) {
            & "$eslintpath" src
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($lintwithstandard) {
            & "$standardpath" src/**/*.js
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }
    }

    if ($specpathexists -and ($lintwithcoffeelint -or $lintwitheslint -or $lintwithstandard)) {
        Write-Host "Linting package specs..."
        if ($lintwithcoffeelint) {
            & "$coffeelintpath" spec
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($lintwitheslint) {
            & "$eslintpath" spec
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($lintwithstandard) {
            & "$standardpath" spec/**/*.js
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }
    }
}

function RunSpecs() {
    $specpath = "$script:PACKAGE_FOLDER\spec"
    $testpath = "$script:PACKAGE_FOLDER\test"
    $specpathexists = Test-Path $specpath
    $testpathexists = Test-Path $testpath
    if (!$specpathexists -and !$testpathexists) {
        Write-Host "Missing spec folder! Please consider adding a test suite in '.\spec' or in '\.test'"
        return
    }
    Write-Host "Running specs..."
    if ($specpathexists) {
      & "$script:SOLDAT_EXE_PATH" --test spec 2>&1 | %{ "$_" }
    } else {
      & "$script:SOLDAT_EXE_PATH" --test test 2>&1 | %{ "$_" }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Specs Failed"
        ExitWithCode -exitcode $LASTEXITCODE
    }
}

function ExitWithCode
{
    param
    (
        $exitcode
    )

    $host.SetShouldExit($exitcode)
    exit
}

function SetElectronEnvironmentVariables
{
  $env:ELECTRON_NO_ATTACH_CONSOLE = "true"
  [Environment]::SetEnvironmentVariable("ELECTRON_NO_ATTACH_CONSOLE", "true", "User")
  $env:ELECTRON_ENABLE_LOGGING = "YES"
  [Environment]::SetEnvironmentVariable("ELECTRON_ENABLE_LOGGING", "YES", "User")

}

DownloadSoldat
ExtractSoldat
SetElectronEnvironmentVariables
PrintVersions
InstallPackage
RunLinters
RunSpecs
