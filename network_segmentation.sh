#!/bin/bash

# === CONFIGURATION ===
TARGET_FILE="targets.txt"
PORT_FILE="ports.txt"
CSV_REPORT="report.csv"
HTML_REPORT="report.html"
LOGFILE="log_$(date +%F_%T).log"
NMAP_OPTIONS="-n -Pn --open"

# === DEP CHECK ===
command -v nmap >/dev/null || { echo "nmap not found."; exit 1; }

# === LOAD TARGETS & PORTS ===
TARGETS=($(grep -Ev '^#|^$' "$TARGET_FILE"))
PORTS=$(paste -sd, "$PORT_FILE")

# === STYLES ===
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# === INIT CSV & HTML ===
echo "IP,Port,Status" > "$CSV_REPORT"
echo "<html><head><title>Network Segmentation Report</title></head><body><h2>Network Segmentation Report</h2><table border='1'><tr><th>IP</th><th>Port</th><th>Status</th></tr>" > "$HTML_REPORT"

# === MENU ===
clear
echo "=============================="
echo "🧪 Network Segmentation Scanner"
echo "=============================="
echo "Choose Scan Type:"
echo "1) Quick Scan (top 1000 ports)"
echo "2) Custom Ports (from ports.txt)"
echo "3) Full TCP Scan (slow)"
read -rp "Enter your choice [1-3]: " choice

case "$choice" in
  1)
    SCAN_ARGS="-T4"
    ;;
  2)
    SCAN_ARGS="-p $PORTS"
    ;;
  3)
    SCAN_ARGS="-p- -T3"
    ;;
  *)
    echo "Invalid choice"; exit 1
    ;;
esac

echo -e "\n🔍 Starting scan...\n"

# === MAIN LOOP ===
for TARGET in "${TARGETS[@]}"; do
    echo -e "\n[*] Scanning $TARGET..." | tee -a "$LOGFILE"

    RESULTS=$(nmap $NMAP_OPTIONS $SCAN_ARGS "$TARGET" | tee -a "$LOGFILE")

    echo "$RESULTS" | grep "^PORT" -A 100 | grep -E "open|closed" | while read -r line; do
        PORT=$(echo "$line" | awk '{print $1}')
        STATE=$(echo "$line" | awk '{print $2}')
        IP=$(echo "$TARGET")

        # CSV
        echo "$IP,$PORT,$STATE" >> "$CSV_REPORT"

        # HTML
        HTML_ROW="<tr><td>$IP</td><td>$PORT</td><td style='color:$( [[ $STATE == "open" ]] && echo green || echo red );'>$STATE</td></tr>"
        echo "$HTML_ROW" >> "$HTML_REPORT"

        # Console output
        if [[ $STATE == "open" ]]; then
            echo -e "${GREEN}[+] $IP:$PORT is OPEN${NC}"
        else
            echo -e "${RED}[-] $IP:$PORT is CLOSED${NC}"
        fi
    done
done

# === END REPORTS ===
echo "</table></body></html>" >> "$HTML_REPORT"

echo -e "\n✅ Scan complete. Reports saved to:"
echo "   - $CSV_REPORT"
echo "   - $HTML_REPORT"

