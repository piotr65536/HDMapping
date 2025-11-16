#!/bin/bash

# Performance measurement script for HDMapping on Linux
# BASH equivalent of measure_execution_fast.ps1

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PATH="./lidar_odometry_step_1"
DEFAULT_TIMEOUT=3600
DEFAULT_TIME=0

# Function to display usage
usage() {
    echo "Usage: $0 REVISION [OPTIONS]"
    echo "  REVISION          Required. Revision identifier for output file naming"
    echo "  -p, --path PATH   Executable path (default: $DEFAULT_PATH)"
    echo "  -t, --timeout N   Timeout in seconds (default: $DEFAULT_TIMEOUT)"
    echo "  -T, --time N      Time in minutes to run before forced termination (0 = use timeout)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Example: $0 v1.0.0 --path ./bin/lidar_odometry_step_1 --time 30"
    exit 1
}

# Parse command line arguments
REVISION=""
EXECUTABLE_PATH="$DEFAULT_PATH"
TIMEOUT="$DEFAULT_TIMEOUT"
TIME_MINUTES="$DEFAULT_TIME"

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--path)
            EXECUTABLE_PATH="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -T|--time)
            TIME_MINUTES="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$REVISION" ]]; then
                REVISION="$1"
                shift
            else
                echo -e "${RED}ERROR: Unknown argument: $1${NC}"
                usage
            fi
            ;;
    esac
done

# Validate required arguments
if [[ -z "$REVISION" ]]; then
    echo -e "${RED}ERROR: REVISION is required${NC}"
    usage
fi

# Validate numeric arguments
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}ERROR: TIMEOUT must be a positive integer${NC}"
    exit 1
fi

if ! [[ "$TIME_MINUTES" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}ERROR: TIME must be a positive integer${NC}"
    exit 1
fi

# Calculate effective timeout
if [[ "$TIME_MINUTES" -gt 0 ]]; then
    EFFECTIVE_TIMEOUT=$((TIME_MINUTES * 60))
else
    EFFECTIVE_TIMEOUT="$TIMEOUT"
fi

# Convert to absolute path
if [[ "$EXECUTABLE_PATH" = /* ]]; then
    # Already absolute path
    EXECUTABLE="$EXECUTABLE_PATH"
else
    # Convert relative to absolute
    EXECUTABLE="$(cd "$(dirname "$EXECUTABLE_PATH")" && pwd)/$(basename "$EXECUTABLE_PATH")"
fi

# Define arguments (adjust these paths for your Linux setup)
# Expand tilde to home directory
ARGUMENTS=(
    "$HOME/data/mosaic/DEMO-2/reel_0005_20250804-103810-20250805T043152Z-1-001/reel_0005_20250804-103810/lidar/"
    "$HOME/data/mosaic/DEMO-2/reel_0005_20250804-103810-20250805T043152Z-1-001/reel_0005_20250804-103810/lidar/lidar_odometry_result_0/HDMapping_params_0.85.0_2025-08-05_12-38.toml"
    "$HOME/data/mosaic/DEMO-2/reel_0005_20250804-103810-20250805T043152Z-1-001/reel_0005_20250804-103810/lidar/lidar_odometry_result_1"
)

# Output files
OUTPUT_FILE="${REVISION}_total_time.csv"
STDOUT_FILE="./stdout"

# Initialize CSV file with header
echo "elapsed_time" > "$OUTPUT_FILE"

echo -e "${CYAN}Starting FAST execution measurement for revision: $REVISION${NC}"
echo -e "${CYAN}Executable path: $EXECUTABLE${NC}"
if [[ "$TIME_MINUTES" -gt 0 ]]; then
    echo -e "${CYAN}Forced termination after: $TIME_MINUTES minutes ($EFFECTIVE_TIMEOUT seconds)${NC}"
else
    echo -e "${CYAN}Timeout: $TIMEOUT seconds${NC}"
fi
echo -e "${CYAN}Output will be saved to: $OUTPUT_FILE${NC}"

# Validate executable exists and is executable
if [[ ! -f "$EXECUTABLE" ]]; then
    echo -e "${RED}ERROR: Executable not found at path: $EXECUTABLE${NC}"
    echo -e "${RED}Please check the path and try again.${NC}"
    
    # Try to find the executable in common locations
    echo -e "${YELLOW}\nLooking for executable in common locations:${NC}"
    POSSIBLE_PATHS=(
        "./lidar_odometry_step_1"
        "./bin/lidar_odometry_step_1"
        "./build/bin/lidar_odometry_step_1"
        "../bin/lidar_odometry_step_1"
        "../build/bin/lidar_odometry_step_1"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            echo -e "  ${GREEN}FOUND: $path${NC}"
        else
            echo -e "  ${GRAY}Not found: $path${NC}"
        fi
    done
    
    exit 1
fi

if [[ ! -x "$EXECUTABLE" ]]; then
    echo -e "${RED}ERROR: File exists but is not executable: $EXECUTABLE${NC}"
    echo -e "${YELLOW}Try: chmod +x $EXECUTABLE${NC}"
    exit 1
fi

echo -e "${GREEN}Executable found and accessible.${NC}"

# Start timing
START_TIME=$(date +%s.%N)

# Cleanup function
cleanup() {
    if [[ -n "$PROCESS_PID" ]] && kill -0 "$PROCESS_PID" 2>/dev/null; then
        echo -e "\n${YELLOW}Terminating process (PID: $PROCESS_PID)...${NC}"
        kill -TERM "$PROCESS_PID" 2>/dev/null
        sleep 2
        if kill -0 "$PROCESS_PID" 2>/dev/null; then
            echo -e "${RED}Force killing process...${NC}"
            kill -KILL "$PROCESS_PID" 2>/dev/null
        fi
    fi
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

echo -e "${CYAN}Starting process with minimal intervention...${NC}"
echo -e "${GRAY}stdout will be captured to: $STDOUT_FILE${NC}"

# Execute command with output redirection
echo -e "${GRAY}Executing: \"$EXECUTABLE\" ${ARGUMENTS[*]}${NC}"
echo -e "${GRAY}Redirecting stdout to: $STDOUT_FILE${NC}"

# Validate input arguments exist
for arg in "${ARGUMENTS[@]}"; do
    if [[ ! -e "$arg" ]]; then
        echo -e "${YELLOW}WARNING: Argument path does not exist: $arg${NC}"
    fi
done

# Start the process in background
echo -e "${GRAY}Starting: \"$EXECUTABLE\" \"${ARGUMENTS[0]}\" \"${ARGUMENTS[1]}\" \"${ARGUMENTS[2]}\"${NC}"
"$EXECUTABLE" "${ARGUMENTS[@]}" > "$STDOUT_FILE" 2>&1 &
PROCESS_PID=$!

# Check if process started successfully
sleep 1
if ! kill -0 "$PROCESS_PID" 2>/dev/null; then
    echo -e "${RED}ERROR: Process failed to start or exited immediately${NC}"
    if [[ -f "$STDOUT_FILE" ]]; then
        echo -e "${YELLOW}Checking stdout file for error messages:${NC}"
        cat "$STDOUT_FILE"
    fi
    exit 1
fi

echo -e "${GREEN}Process running... (PID: $PROCESS_PID)${NC}"
echo -e "${YELLOW}Monitoring with minimal intervention...${NC}"

# Monitor process
LAST_CHECK_TIME=$START_TIME
EXIT_CODE=0

while kill -0 "$PROCESS_PID" 2>/dev/null; do
    # Check timeout using integer arithmetic instead of bc
    CURRENT_TIME=$(date +%s)
    START_TIME_INT=${START_TIME%.*}
    ELAPSED=$((CURRENT_TIME - START_TIME_INT))
    
    if [[ "$ELAPSED" -gt "$EFFECTIVE_TIMEOUT" ]]; then
        if [[ "$TIME_MINUTES" -gt 0 ]]; then
            echo -e "\n${RED}FORCED TERMINATION: Process reached $TIME_MINUTES minute limit!${NC}"
        else
            echo -e "\n${RED}TIMEOUT: Process exceeded maximum allowed time!${NC}"
        fi
        kill -TERM "$PROCESS_PID" 2>/dev/null
        sleep 2
        if kill -0 "$PROCESS_PID" 2>/dev/null; then
            kill -KILL "$PROCESS_PID" 2>/dev/null
        fi
        EXIT_CODE=124  # Timeout exit code
        break
    fi
    
    # Show periodic progress
    if [[ $((ELAPSED % 30)) -eq 0 ]] && [[ "$ELAPSED" -ne $((${LAST_CHECK_TIME%.*} - START_TIME_INT)) ]]; then
        echo -e "${GRAY}Process still running... Elapsed: ${ELAPSED}s${NC}"
        LAST_CHECK_TIME=$(date +%s.%N)
    fi
    
    # Sleep for 5 seconds - minimal intervention
    sleep 5
done

# Wait for process to complete and get exit code if it wasn't killed
if kill -0 "$PROCESS_PID" 2>/dev/null; then
    wait "$PROCESS_PID" 2>/dev/null
    EXIT_CODE=$?
fi

# Calculate total execution time
END_TIME=$(date +%s)
START_TIME_INT=${START_TIME%.*}
TOTAL_SECONDS=$((END_TIME - START_TIME_INT))

echo -e "\n${CYAN}Process completed. Processing stdout file...${NC}"

# Process the stdout file for elapsed times
ELAPSED_TIMES=()

if [[ -f "$STDOUT_FILE" ]]; then
    STDOUT_SIZE=$(stat -f%z "$STDOUT_FILE" 2>/dev/null || stat -c%s "$STDOUT_FILE" 2>/dev/null)
    echo -e "${GRAY}stdout file size: $STDOUT_SIZE bytes${NC}"
    
    if [[ "$STDOUT_SIZE" -gt 0 ]]; then
        LINE_COUNT=$(wc -l < "$STDOUT_FILE")
        echo -e "${GRAY}Processing $LINE_COUNT lines from stdout file...${NC}"
        
        # Extract elapsed times using grep and regex
        while IFS= read -r line; do
            if [[ "$line" =~ optimizing\ worker_data\ \[[0-9]+\]\ of\ [0-9]+\ acc_distance:\ [0-9.]+\ elapsed\ time:\ ([0-9.]+) ]]; then
                elapsed_time="${BASH_REMATCH[1]}"
                ELAPSED_TIMES+=("$elapsed_time")
                echo -e "${GREEN}Found elapsed time: $elapsed_time${NC}"
            fi
        done < "$STDOUT_FILE"
    else
        echo -e "${RED}stdout file is empty!${NC}"
    fi
else
    echo -e "${RED}stdout file not found!${NC}"
fi

# Save elapsed times to CSV
if [[ ${#ELAPSED_TIMES[@]} -gt 0 ]]; then
    printf '%s\n' "${ELAPSED_TIMES[@]}" >> "$OUTPUT_FILE"
    echo -e "${GREEN}Saved ${#ELAPSED_TIMES[@]} elapsed time measurements to $OUTPUT_FILE${NC}"
else
    echo -e "${YELLOW}WARNING: No elapsed time measurements found!${NC}"
    echo -e "${YELLOW}Check the stdout file: $STDOUT_FILE${NC}"
fi

# Check exit code
if [[ "$EXIT_CODE" -eq 0 ]]; then
    echo -e "${GREEN}Process completed successfully${NC}"
else
    echo -e "${YELLOW}Process completed with exit code: $EXIT_CODE${NC}"
fi

# Display execution summary
echo ""
echo -e "${CYAN}=== EXECUTION SUMMARY ===${NC}"
echo -e "${CYAN}Total execution time: $TOTAL_SECONDS seconds${NC}"
echo -e "${CYAN}Results saved to: $OUTPUT_FILE${NC}"

# Count captured measurements
if [[ -f "$OUTPUT_FILE" ]]; then
    CAPTURED_COUNT=$(($(wc -l < "$OUTPUT_FILE") - 1))  # Subtract header line
    echo -e "${CYAN}Captured $CAPTURED_COUNT elapsed time measurements${NC}"
    
    if [[ "$CAPTURED_COUNT" -eq 0 ]]; then
        echo -e "${YELLOW}WARNING: No elapsed time measurements were captured!${NC}"
        echo -e "${YELLOW}Please verify that the program outputs the expected pattern:${NC}"
        echo -e "${YELLOW}optimizing worker_data [162] of 10680 acc_distance: 0.92238 elapsed time: 1.20694${NC}"
    fi
fi
