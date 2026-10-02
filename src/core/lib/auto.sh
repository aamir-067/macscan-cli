# shellcheck shell=bash
# Decisions for automatic (scheduled) runs.

app_list(){ find /Applications /Users/*/Applications -maxdepth 2 -name "*.app" -not -path "*.app/*" 2>/dev/null | sort; }

low_battery(){
  local b pct; b=$(pmset -g batt 2>/dev/null)
  echo "$b" | grep -q "Battery Power" || return 1
  pct=$(echo "$b" | grep -o '[0-9]*%' | head -1 | tr -d %)
  [ -n "$pct" ] && [ "$pct" -lt "$AUTO_MIN_BATTERY" ]
}
