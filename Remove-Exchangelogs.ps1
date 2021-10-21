#region Variables 
# Cleanup logs older than the set of days in numbers
$Days = 14

# Path of the logs that you like to cleanup
$IISLogPath = "C:\inetpub\logs\LogFiles\"
$ExchangeLoggingPath = "C:\Program Files\Microsoft\Exchange Server\V15\Logging\"
$ETLLoggingPath = "C:\Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\ETLTraces\"
$ETLLoggingPath2 = "C:\Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\Logs\"
$UnifiedContentPath = "C:\Program Files\Microsoft\Exchange Server\V15\TransportRoles\data\Temp\UnifiedContent"
#endregion

#region Functions
# Test if evelated Shell
Function Confirm-Administrator() 
{
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 
    {
        return $true
    } 
    else 
    {
        return $false
    }
}

# Get size of all logfiles
Function Get-LogfileSize() 
{
    PARAM(
        [Parameter(Mandatory=$true)]
            [String[]]$TargetFolder
    )
    PROCESS {
        if (Test-Path $TargetFolder) 
        {
            $Now = Get-Date
            $LastWrite = $Now.AddDays(-$days)
            $Files = Get-ChildItem $TargetFolder -Recurse | 
                Where-Object { $_.Name -like "*.log" -or $_.Name -like "*.blg" -or $_.Name -like "*.etl" } |
                Where-Object { $_.lastWriteTime -le "$lastwrite" }
            $SizeGB = ($Files | Measure-Object -Sum Length).Sum / 1GB
            $SizeGBRounded = [math]::Round($SizeGB,2)
            return $SizeGBRounded
        }
        else
        {
            Write-Output "The folder $TargetFolder doesn't exist! Check the folder path!"
        }    
    }

}
Function Get-UnifiedContentfileSize() 
{
    PARAM(
        [Parameter(Mandatory=$true)]
            [String[]]$TargetFolder
    )
    PROCESS {
        if (Test-Path $TargetFolder) 
        {
            $Now = Get-Date
            $LastWrite = $Now.AddDays(-$days)
            $Files = Get-ChildItem $TargetFolder -Recurse | 
                Where-Object { $_.lastWriteTime -le "$lastwrite" }
            $SizeGB = ($Files | Measure-Object -Sum Length).Sum / 1GB
            $SizeGBRounded = [math]::Round($SizeGB,2)
            return $SizeGBRounded
        }
        else 
        {
            Write-Output "The folder $TargetFolder doesn't exist! Check the folder path!"
        }
    }
}
# Remove the logs
Function Remove-Logfiles() 
{
    PARAM(
        [Parameter(Mandatory=$true)]
            [String[]]$TargetFolder
    )
    PROCESS {
        if (Test-Path $TargetFolder) 
        {
            $Now = Get-Date
            $LastWrite = $Now.AddDays(-$days)
            $Files = Get-ChildItem $TargetFolder -Recurse | Where-Object { $_.Name -like "*.log" -or $_.Name -like "*.blg" -or $_.Name -like "*.etl" } | Where-Object { $_.lastWriteTime -le "$lastwrite" }
            $FileCount = $Files.Count
            $Files | Remove-Item -force -ea 0
            return $FileCount
        }
        Else 
        {
            Write-Output "The folder $TargetFolder doesn't exist! Check the folder path!"
        }
    }
}

Function Remove-UnifiedContent() 
{
    PARAM(
        [Parameter(Mandatory=$true)]
            [String[]]$TargetFolder
    )
    PROCESS {
        if (Test-Path $TargetFolder) 
        {
            $Now = Get-Date
            $LastWrite = $Now.AddDays(-$days)
            $Files = Get-ChildItem $TargetFolder -Recurse | 
                Where-Object { $_.lastWriteTime -le "$lastwrite" }
            $FileCount = $Files.Count
            $Files | 
                Remove-Item -force -ea 0
            return $FileCount
        }
        else 
        {
            Write-Output "The folder $TargetFolder doesn't exist! Check the folder path!"
        }
    }
}
#endregion Functions

if (-not (Confirm-Administrator)) 
{
    Write-Output $msgNewLine
    Write-Warning "This script needs to be executed in elevated mode. Start the Exchange Management Shell as an Administrator and try again."
    $Error.Clear()
    Start-Sleep -Seconds 2
    exit
}

# Get logs and traces and write some stats
$IISLogSize = Get-LogfileSize $IISLogPath
$ExchangeLogSize = Get-LogfileSize -TargetFolder $ExchangeLoggingPath
$ETL1LogSize = Get-LogfileSize -TargetFolder $ETLLoggingPath
$ETL2LogSize = Get-LogfileSize -TargetFolder $ETLLoggingPath2
$UnifiedContentSize = Get-UnifiedContentfileSize -TargetFolder $UnifiedContentPath
$TotalLogSize = $IISLogSize + $ExchangeLogSize + $ETL1LogSize + $ETL2LogSize + $UnifiedContentSize

Write-Output "Total Log and Trace File Size is $TotalLogSize GB"

#Ask if script should realy delete the logs
$Confirmation = Read-Host "Delete Exchange Server log and trace files? [y/n]"

while($Confirmation -notmatch "[yYnN]") 
{
    if ($Confirmation -match "[nN]")
    {
        exit
    }
    $Confirmation = Read-Host "Delete Exchange Server log and trace files? [y/n]"
}

# Delete logs (if confirmed) and write some stats
if ($Confirmation -match "[yY]") 
{
    $DeleteIISFiles = Remove-Logfiles -TargetFolder $IISLogPath
    $DeleteExchangeLogs = Remove-Logfiles-TargetFolder  $ExchangeLoggingPath
    $DeleteETL1Logs = Remove-Logfiles -TargetFolder $ETLLoggingPath
    $DeleteETL2Logs = Remove-Logfiles -TargetFolder $ETLLoggingPath2
    $DeleteUnifiedContent = Remove-UnifiedContent -TargetFolder $UnifiedContentPath
    $TotalDeletedFiles = $DeleteIISFiles + $DeleteExchangeLogs + $DeleteETL1Logs + $DeleteETL2Logs + $DeleteUnifiedContent
    Write-Output "$TotalDeletedFiles files deleted"
}