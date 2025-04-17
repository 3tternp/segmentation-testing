#!/bin/bash

# === 🛡️ AUTHORIZATION BANNER ===
clear
echo "======================================================="
echo "🛑  Authorized Use Only - Network Segmentation Scanner"
echo "======================================================="
echo "This tool is for authorized segmentation testing only."
echo "Unauthorized use is prohibited and subject to penalties."
echo
read -rp "Do you have authorization to proceed? (yes/no): " consent
[[ "$consent" != "yes" ]] && { echo "❌ Aborted."; exit 1; }

# === 📥 USER INPUT ===
read -rp "Enter target IP(s), space separated (e.g., 192.168.1.1 10.0.0.1): " -a TARGETS
read -rp "Enter custom port(s), comma-separated (e.g., 22,80,443) or leave blank to skip: " CUSTOM_PORTS

# === 📁 OUTPUT FILES ===
timestamp=$(date +%F_%T | tr ':' '-')
CSV_REPORT="report_$timestamp.csv"
HTML_REPORT="report_$timestamp.html"
JSON_REPORT="report_$timestamp.json"
LOGFILE="log_$timestamp.log"
NMAP_OPTIONS="-n -Pn --open"

# === ✅ DEP CHECK ===
command -v nmap >/dev/null || { echo "❌ nmap not installed."; exit 1; }
command -v jq >/dev/null || { echo "❌ jq not installed (required for JSON)."; exit 1; }

# === 🧪 SCAN MODES ===
declare -A SCAN_TYPES=(
  ["quick"]="-T4"
  ["custom"]="-p $CUSTOM_PORTS"
  ["fulltcp"]="-p- -T3"
  ["udp"]="-sU -T4 -p $CUSTOM_PORTS"
)

# === 📄 INIT OUTPUTS ===
echo "IP,Port,State,Protocol,ScanType" > "$CSV_REPORT"
echo "[" > "$JSON_REPORT"
echo "<html><head><title>Segmentation Report</title></head><body><h2>Segmentation Report</h2><table border='1'><tr><th>IP</th><th>Port</th><th>State</th><th>Protocol</th><th>ScanType</th></tr>" > "$HTML_REPORT"

# === 🔁 LOOP ===
for TARGET in "${TARGETS[@]}"; do
  for TYPE in "${!SCAN_TYPES[@]}"; do
    echo -e "\n🔍 [$TYPE] Scanning $TARGET..." | tee -a "$LOGFILE"
    RESULTS=$(nmap $NMAP_OPTIONS ${SCAN_TYPES[$TYPE]} "$TARGET" | tee -a "$LOGFILE")

    echo "$RESULTS" | grep -E "^([0-9]+/udp|[0-9]+/tcp)" | while read -r line; do
      PORT=$(echo "$line" | awk '{print $1}' | cut -d/ -f1)
      PROTO=$(echo "$line" | awk '{print $1}' | cut -d/ -f2)
      STATE=$(echo "$line" | awk '{print $2}')

      # Append to CSV
      echo "$TARGET,$PORT,$STATE,$PROTO,$TYPE" >> "$CSV_REPORT"

      # Append to HTML
      COLOR=$( [[ "$STATE" == "open" ]] && echo green || echo red )
      echo "<tr><td>$TARGET</td><td>$PORT</td><td style='color:$COLOR'>$STATE</td><td>$PROTO</td><td>$TYPE</td></tr>" >> "$HTML_REPORT"

      # Append to JSON
      echo "  {\"ip\":\"$TARGET\",\"port\":\"$PORT\",\"state\":\"$STATE\",\"protocol\":\"$PROTO\",\"scan_type\":\"$TYPE\"}," >> "$JSON_REPORT"
    done
  done
done

# === 📦 CLEAN JSON ENDING ===
sed -i '$ s/},/}/' "$JSON_REPORT"
echo "]" >> "$JSON_REPORT"

# === 📦 CLOSE HTML ===
echo "</table></body></html>" >> "$HTML_REPORT"

# === ✅ DONE ===
echo -e "\n✅ Scan complete."
echo "📄 CSV:   $CSV_REPORT"
echo "🌐 HTML:  $HTML_REPORT"
echo "📦 JSON:  $JSON_REPORT"
