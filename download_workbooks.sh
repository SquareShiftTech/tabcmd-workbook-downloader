#!/bin/bash
#
# download_workbooks.sh
#
# Automates downloading all Tableau workbooks using tabcmd
#

### CONFIGURATION ###
TABLEAU_SERVER="https://prod-apsoutheast-b.online.tableau.com"
SITE_ID="<site_id>"
USERNAME="<user_name>"
PASSWORD_FILE="$HOME/.tabcmd_pw.txt"

### STEP 0: Login (one-time password setup if not already done) ###
if [ ! -f "$PASSWORD_FILE" ]; then
  echo "Please enter Tableau password for $USERNAME:"
  read -s PASSWORD
  echo "$PASSWORD" > "$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
fi

echo "== Logging in to Tableau =="
tabcmd login \
  -s "$TABLEAU_SERVER" \
  -t "$SITE_ID" \
  -u "$USERNAME" \
  --password-file "$PASSWORD_FILE" \
  --no-prompt

### STEP 1: List available workbooks ###
echo "== Fetching workbook list =="
tabcmd list workbooks --details > workbooks_raw.txt 2>&1

### STEP 2: Extract workbook name + contentUrl ###
echo "== Parsing workbook list =="
grep "<WorkbookItem " workbooks_raw.txt \
  | sed -E "s/.*<WorkbookItem [^ ]+ '([^']+)' contentUrl='([^']+)'.*/\1,\2/" \
  > workbooks_map.csv

echo "Sample parsed entries:"
head -5 workbooks_map.csv

### STEP 3: Download workbooks (TWBX preferred, fallback to TWB) ###
echo "== Downloading workbooks =="
while IFS=, read -r display url; do
  safe_name=$(echo "$display" | tr ' /:&()#?*[]{}$' '_' )
  echo "Downloading: $display  (contentUrl=$url)"

  tabcmd get "/workbooks/${url}.twbx" -f "${safe_name}.twbx" \
  || tabcmd get "/workbooks/${url}.twb" -f "${safe_name}.twb"
done < workbooks_map.csv

echo "== Done. All workbooks saved locally. =="
