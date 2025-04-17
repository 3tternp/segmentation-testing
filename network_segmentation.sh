#!/bin/bash

# === CONFIGURATION ===
PORT_FILE="ports.txt"
CSV_REPORT="report.csv"
HTML_REPORT="report.html"
JSON_REPORT="report.json"
LOGFILE="log_$(date +%F_%T).log"
NMAP_BASE_OPTIONS="-n -Pn"
CUSTOM_PORTS=$(paste -sd, "$PORT_FILE")
UDP_PORTS="53,67,123,161,500,514,520"  # Add more if needed
ENABLE_JSON=true
PARALLEL=true
MAX_JOBS=4

# === DEPENDENCY CHECK ===
command -v nmap >/dev/null || { echo "❌ nmap not found. Please install nmap."; exit 1; }
command -v jq >/dev/null || ENABLE_JSON=false  # Optional: jq needed for JSON parsing

# === STYLES ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# === LEGAL WARNING ===
clear
echo -e "${YELLOW}"
echo "======================================================="
echo "🚨 WARNING: AUTHORIZED USE ONLY"
echo "This tool is intended for authorized network segmentation testing only."
echo "Unauthorized use against networks you do not own or have explicit"
echo "permission to test is illegal and unethical."
echo "======================================================="
echo -e "${NC}"
read -rp "Do you have authorization to run this scan? (yes/no): " consent
[[ "$consent" != "yes" ]] && { echo "❌ Scan aborted."; exit 1; }

# === USER INPUT ===
read -rp "📥 Enter target IP or subnet (e.g., 192.168.1.1 or 192.168.1.0/24): " TARGET
[[ -z "$TARGET" ]] && { echo "❌ No target provided."; exit 1; }

# === INIT REPORTS ===
echo "IP,Port,Status,ScanType,Protocol" > "$CSV_REPORT"
echo "<html><head><title>Network Segmentation Report</title></head><body><h2>Network Segmentation Report</h2><table border='1'><tr><th>IP</th><th>Port</th><th>Status</th><th>Scan Type</th><th>Protocol</th></tr>" > "$HTML_REPORT"
$ENABLE_JSON && echo "[" > "$JSON_REPORT"

# === SCAN & LOG FUNCTION ===
scan_and_log() {
    local ip=$1
    local scan_type=$2
    local scan_args=$3
    local protocol=$4

    echo -e "\n🔎 Scanning $ip ($scan_type - $protocol)..." | tee -a "$LOGFILE"

    nmap $NMAP_BASE_OPTIONS $scan_args "$ip" -oG - | awk '/Ports:/{print}' | while IFS= read -r line; do
        PORTS_FIELD=$(echo "$line" | grep -oP 'Ports: \K.*')
        IFS=',' read -ra PORT_ENTRIES <<< "$PORTS_FIELD"

        for entry in "${PORT_ENTRIES[@]}"; do
            port=$(echo "$entry" | awk -F/ '{print $1}')
            state=$(echo "$entry" | awk -F/ '{print $2}')
            [[ -z "$port" || -z "$state" ]] && continue

            echo "$ip,$port,$state,$scan_type,$protocol" >> "$CSV_REPORT"

            COLOR=$( [[ "$state" == "open" ]] && echo "green" || echo "red" )
            echo "<tr><td>$ip</td><td>$port</td><td style='color:$COLOR;'>$state</td><td>$scan_type</td><td>$protocol</td></tr>" >> "$HTML_REPORT"

            if [[ "$state" == "open" ]]; then
                echo -e "${GREEN}[+] $ip:$port is OPEN ($scan_type - $protocol)${NC}"
            else
                echo -e "${RED}[-] $ip:$port is CLOSED ($scan_type - $protocol)${NC}"
            fi

            $ENABLE_JSON && echo "  {\"ip\": \"$ip\", \"port\": \"$port\", \"state\": \"$state\", \"scan_type\": \"$scan_type\", \"protocol\": \"$protocol\"}," >> "$JSON_REPORT"
        done
    done
}

# === PARALLEL WRAPPER ===
run_scan() {
    scan_and_log "$1" "$2" "$3" "$4" &
    if $PARALLEL; then
        while (( $(jobs -r | wc -l) >= MAX_JOBS )); do sleep 1; done
    else
        wait
    fi
}

# === ICMP DISCOVERY ===
echo -e "\n🌐 Performing ping sweep (if ICMP allowed)..."
nmap -sn "$TARGET" -oG - | awk '/Up$/{print $2}' | while read -r alive_host; do
    echo -e "${GREEN}[ICMP] $alive_host is up${NC}"
done

# === SCAN TYPES TO EXECUTE ===
run_scan "$TARGET" "Top 1000 TCP Ports" "-T4" "tcp"
run_scan "$TARGET" "Custom TCP Ports" "-p $CUSTOM_PORTS -T4" "tcp"
run_scan "$TARGET" "Full TCP Port Scan" "-p- -T3" "tcp"
run_scan "$TARGET" "Firewall Evasion" "-p $CUSTOM_PORTS --data-length 50 --randomize-hosts --max-rate 20 --source-port 53 -T2" "tcp"
run_scan "$TARGET" "UDP Scan" "-sU -p $UDP_PORTS -T3" "udp"

wait

# === FINALIZE REPORTS ===
echo "</table></body></html>" >> "$HTML_REPORT"
$ENABLE_JSON && sed -i '$ s/},/}/' "$JSON_REPORT" && echo "]" >> "$JSON_REPORT"

echo -e "\n✅ All scans completed. Reports saved to:"
echo "   - $CSV_REPORT"
echo "   - $HTML_REPORT"
$ENABLE_JSON && echo "   - $JSON_REPORT"
