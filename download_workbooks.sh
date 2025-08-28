#!/bin/bash
#
# download_workbooks.sh
#

### STEP 0: Collect inputs interactively ###
read -p "Enter Tableau Server URL (default: http://localhost): " TABLEAU_SERVER
TABLEAU_SERVER=${TABLEAU_SERVER:-http://localhost}

read -p "Enter Tableau Username: " USERNAME
read -s -p "Enter Tableau Password: " PASSWORD
echo
read -p "Enter Site Name (leave empty for 'default'): " SITE_ID

# If site is empty, use 'default'
if [ -z "$SITE_ID" ]; then
  SITE_ID="default"
fi

# Create folder for site downloads
OUTPUT_DIR="./${SITE_ID}"
mkdir -p "$OUTPUT_DIR"

# Store password securely in a temp file
PASSWORD_FILE="$OUTPUT_DIR/tabcmd_pw.txt"
echo -n "$PASSWORD" > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

### STEP 1: Login ###
echo "== Logging in to Tableau =="
./tabcmd login \
  -s "$TABLEAU_SERVER" \
  -t "$SITE_ID" \
  -u "$USERNAME" \
  --password-file "$PASSWORD_FILE" \
  --no-prompt

### STEP 2: List available workbooks ###
echo "== Fetching workbook list =="
./tabcmd list workbooks --details > "$OUTPUT_DIR/workbooks_raw.txt" 2>&1

### STEP 3: Parse workbook list ###
echo "== Parsing workbook list =="
grep "<WorkbookItem " "$OUTPUT_DIR/workbooks_raw.txt" \
  | sed -E "s/.*<WorkbookItem [^ ]+ '([^']+)' contentUrl='([^']+)'.*/\1,\2/" \
  > "$OUTPUT_DIR/workbooks_map.csv"

echo "Sample parsed entries:"
head -5 "$OUTPUT_DIR/workbooks_map.csv"

### STEP 4: Download workbooks ###
echo "== Downloading workbooks =="
while IFS=, read -r display url; do
  safe_name=$(echo "$display" | tr ' /:&()#?*[]{}$' '_' )
  echo "Downloading: $display (contentUrl=$url)"

  ./tabcmd get "/workbooks/${url}.twbx" -f "$OUTPUT_DIR/${safe_name}.twbx" \
  || ./tabcmd get "/workbooks/${url}.twb" -f "$OUTPUT_DIR/${safe_name}.twb"
done < "$OUTPUT_DIR/workbooks_map.csv"

echo "== Done. All workbooks saved in $OUTPUT_DIR =="

# Cleanup password file
rm -f "$PASSWORD_FILE"
./tabcmd logout
