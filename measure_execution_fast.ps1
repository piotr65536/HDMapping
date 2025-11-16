# Performance Measurement Script for HDMapping
#
# Usage:
#   .\measure_execution_fast.ps1 -REVISION <revision_name> -DATA_SET_PATH <path_to_dataset> [-PATH <exe_path>] [-TIME <minutes>]
#
# Examples:
#   .\measure_execution_fast.ps1 -REVISION "optimized" -PATH ".\build\bin\lidar_odometry_step_1.exe" -DATA_SET_PATH ".\datasets" 
#   .\measure_execution_fast.ps1 -REVISION "test" -PATH ".\build\bin\lidar_odometry_step_1.exe" -DATA_SET_PATH "C:\data" -TIME 30
#
# Parameters:
#   -REVISION: Name/identifier for this test run (mandatory)
#   -PATH: Path to the executable (mandatory, default: ./lidar_odometry_step_1.exe)
#   -DATA_SET_PATH: Path to the dataset directory (mandatory)
#   -TIME: Force termination after N minutes (optional, default: 0 = no limit)

param(
    [Parameter(Mandatory=$true)]
    [string]$REVISION,
    
    [Parameter(Mandatory=$true)]
    [string]$PATH = "./lidar_odometry_step_1.exe",
   
    [Parameter(Mandatory=$true)]
    [string]$DATA_SET_PATH,
    
    [Parameter(Mandatory=$false)]
    [int]$TIME = 0  # Time in minutes to run before forced termination 
)

# Define the executable and arguments
# Convert to absolute path to handle relative paths correctly
$executable = (Resolve-Path $PATH -ErrorAction SilentlyContinue).Path
if (-not $executable) {
    # If Resolve-Path fails, try to construct the absolute path manually
    if ([System.IO.Path]::IsPathRooted($PATH)) {
        $executable = $PATH
    } else {
        $executable = Join-Path (Get-Location) $PATH
    }
}

$arguments = @(
    "$DATA_SET_PATH\mosaic\DEMO-2\reel_0005_20250804-103810-20250805T043152Z-1-001\reel_0005_20250804-103810\lidar\",
    "$DATA_SET_PATH\mosaic\DEMO-2\reel_0005_20250804-103810-20250805T043152Z-1-001\reel_0005_20250804-103810\lidar\lidar_odometry_result_0\HDMapping_params_0.85.0_2025-08-05_12-38.toml",
    "$DATA_SET_PATH\mosaic\DEMO-2\reel_0005_20250804-103810-20250805T043152Z-1-001\reel_0005_20250804-103810\lidar\$REVISION"
)

$TIMEOUT = 3600

# Calculate effective timeout
$effectiveTimeout = if ($TIME -gt 0) { $TIME * 60 } else { $TIMEOUT }

# Output CSV file with TIME parameter value
$outputFile = "${REVISION}_TIME${TIME}.csv"

# Initialize CSV file with header
"elapsed_time,total_seconds,hours,minutes" | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Starting FAST execution measurement for revision: $REVISION"
Write-Host "Dataset path: $DATA_SET_PATH"
Write-Host "Executable path: $executable"
if ($TIME -gt 0) {
    Write-Host "Forced termination after: $TIME minutes ($effectiveTimeout seconds)"
} else {
    Write-Host "Timeout: $TIMEOUT seconds"
}
Write-Host "Output will be saved to: $outputFile"

# Validate executable path exists
if (-not (Test-Path $executable)) {
    Write-Host "ERROR: Executable not found at path: $executable" -ForegroundColor Red
    Write-Host "Please check the path and try again." -ForegroundColor Red
    
    # Try to find the executable in common locations
    $possiblePaths = @(
        ".\lidar_odometry_step_1.exe",
        ".\bin\lidar_odometry_step_1.exe",
        ".\Release\lidar_odometry_step_1.exe",
        "..\Release\lidar_odometry_step_1.exe",
        "..\bin\lidar_odometry_step_1.exe"
    )
    
    Write-Host "`nLooking for executable in common locations:" -ForegroundColor Yellow
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Host "  FOUND: $path" -ForegroundColor Green
        } else {
            Write-Host "  Not found: $path" -ForegroundColor Gray
        }
    }
    
    exit 1
}

Write-Host "Executable found and accessible." -ForegroundColor Green

# Validate dataset path exists
if (-not (Test-Path $DATA_SET_PATH)) {
    Write-Host "ERROR: Dataset path not found: $DATA_SET_PATH" -ForegroundColor Red
    Write-Host "Please check the DATA_SET_PATH parameter and try again." -ForegroundColor Red
    exit 1
}

Write-Host "Dataset path found and accessible." -ForegroundColor Green

# Measure total execution time
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # Simple stdout redirection to local file
    $stdoutFile = ".\stdout"
    
    Write-Host "Starting process with minimal intervention..." -ForegroundColor Cyan
    Write-Host "stdout will be captured to: $stdoutFile" -ForegroundColor Gray
    
    # Use Start-Process with direct file redirection (more reliable)
    $argumentString = $arguments -join " "
    
    Write-Host "Executing: `"$executable`" $argumentString" -ForegroundColor Gray
    Write-Host "Redirecting stdout to: $stdoutFile" -ForegroundColor Gray
    
    # Use Start-Process with output redirection
    $process = Start-Process -FilePath $executable -ArgumentList $arguments -RedirectStandardOutput $stdoutFile -NoNewWindow -PassThru
    
    # Minimal monitoring - just check for timeout
    Write-Host "Process running... (PID: $($process.Id))" -ForegroundColor Green
    Write-Host "Monitoring with minimal intervention..." -ForegroundColor Yellow
    
    while (-not $process.HasExited) {
        # Check timeout only
        if ($stopwatch.Elapsed.TotalSeconds -gt $effectiveTimeout) {
            if ($TIME -gt 0) {
                Write-Host "`nFORCED TERMINATION: Process reached $TIME minute limit!" -ForegroundColor Red
            } else {
                Write-Host "`nTIMEOUT: Process exceeded maximum allowed time!" -ForegroundColor Red
            }
            $process.Kill()
            break
        }
        
        # Sleep for 5 seconds - minimal intervention
        Start-Sleep -Seconds 5
    }
    
    # Wait for process to complete
    $process.WaitForExit()
    $stopwatch.Stop()
    
    Write-Host "`nProcess completed. Processing stdout file..." -ForegroundColor Cyan
    
    # Process the stdout file for elapsed times
    $elapsedTimes = @()
    
    if (Test-Path $stdoutFile) {
        $stdoutSize = (Get-Item $stdoutFile).Length
        Write-Host "stdout file size: $stdoutSize bytes" -ForegroundColor Gray
        
        if ($stdoutSize -gt 0) {
            $content = Get-Content $stdoutFile
            Write-Host "Processing $($content.Count) lines from stdout file..." -ForegroundColor Gray
            
            # Grep for optimizing worker_data lines and extract elapsed times
            foreach ($line in $content) {
                if ($line -match "finished at iteration \d+/\d+ optimizing worker_data \d+/\d+ with acc_distance [\d.]+\[m\] in ([\d.]+)\[s\]") {
                    $elapsedTime = $matches[1]
                    $elapsedTimes += $elapsedTime
                    Write-Host "Found elapsed time: $elapsedTime" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "stdout file is empty!" -ForegroundColor Red
        }
    } else {
        Write-Host "stdout file not found!" -ForegroundColor Red
    }
    
    # Save elapsed times to CSV with total execution time columns
    if ($elapsedTimes.Count -gt 0) {
        # Calculate total execution time
        $totalSeconds = $stopwatch.Elapsed.TotalSeconds
        $hours = [Math]::Floor($totalSeconds / 3600)
        $minutes = [Math]::Floor(($totalSeconds % 3600) / 60)
        
        # Write each elapsed time with the total execution time columns
        foreach ($elapsedTime in $elapsedTimes) {
            "$elapsedTime,$totalSeconds,$hours,$minutes" | Out-File -FilePath $outputFile -Append -Encoding UTF8
        }
        Write-Host "Saved $($elapsedTimes.Count) elapsed time measurements to $outputFile" -ForegroundColor Green
    } else {
        Write-Host "WARNING: No elapsed time measurements found!" -ForegroundColor Yellow
        Write-Host "Check the stdout file: $stdoutFile" -ForegroundColor Yellow
    }
    
    # Check exit code
    if ($process.ExitCode -eq 0) {
        Write-Host "Process completed successfully" -ForegroundColor Green
    } else {
        Write-Host "Process completed with exit code: $($process.ExitCode)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if ($process) {
        $process.Dispose()
    }
    # Keep the stdout file for manual inspection
}

# Display total execution time
$totalSeconds = $stopwatch.Elapsed.TotalSeconds
Write-Host ""
Write-Host "=== EXECUTION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total execution time: $totalSeconds seconds" -ForegroundColor Cyan
Write-Host "Results saved to: $outputFile" -ForegroundColor Cyan

# Count how many elapsed times were captured
$csvContent = Get-Content $outputFile
$dataLines = $csvContent | Select-Object -Skip 1  # Skip header
$capturedCount = $dataLines.Count

Write-Host "Captured $capturedCount elapsed time measurements" -ForegroundColor Cyan

if ($capturedCount -eq 0) {
    Write-Host "WARNING: No elapsed time measurements were captured!" -ForegroundColor Yellow
    Write-Host "Please verify that the program outputs the expected pattern:" -ForegroundColor Yellow
    Write-Host "finished at iteration 192/500 optimizing worker_data 24/10680 with acc_distance 0.43[m] in 0.70[s], delta < 1e-12" -ForegroundColor Yellow
}
