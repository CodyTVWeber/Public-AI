def counts:
  . as $signals
  | ["ok", "warn", "fail", "unknown"]
  | map(. as $status | $status + " " + ([$signals[] | select(.status == $status)] | length | tostring))
  | join(" · ");

def signal_line:
  "- " + .status + " " + .name + ": " + (.value | tojson)
  + (if .baseline != null then " (baseline " + (.baseline | tojson) + ")" else "" end)
  + " · " + .rule + " · " + .reason;

def notable: map(select(.status != "ok")) | map(signal_line);

def note_lines: if .note then ["note: " + .note] else [] end;

def tick_lines($n):
  ["### tick " + ($n | tostring) + " · " + $at + " · " + .verdict, (.signals | counts)]
  + (.signals | notable) + note_lines;

def baseline_lines:
  ["### baseline · " + $at + " · " + (.strength // "weak")]
  + (.values | to_entries | map("- " + .key + " = " + (.value | tojson)));

def final_lines:
  ["## Final · " + $at + " · " + .verdict, "Window: " + .window.start + " → " + .window.end, (.signals | counts)]
  + (.signals | map(signal_line))
  + ((.evidence // []) | map("evidence: " + .))
  + ["action: " + (.action // "none")];

if $kind == "tick" then tick_lines($n)
elif $kind == "baseline" then baseline_lines
else final_lines end
| join("\n")
