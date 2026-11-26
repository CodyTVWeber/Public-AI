def numeric: type == "number";

def key_set:
  if type == "array" then map(tostring)
  elif type == "object" then keys
  else [] end;

def rule_text($rule):
  ([$rule.kind, ($rule | if has("limit") then .limit elif has("value") then .value else empty end | tostring)]
    + (if $rule.allow_noise_abs != null then ["noise<" + ($rule.allow_noise_abs | tostring)] else [] end))
  | join(" ");

def bounds($rule; $base):
  def scaled($n): if $n == null then null else $base * $n end;
  if $rule.kind == "max_ratio" then {dir: "max", hard: scaled($rule.limit), soft: scaled($rule.warn)}
  elif $rule.kind == "max_abs" then {dir: "max", hard: $rule.limit, soft: $rule.warn}
  else {dir: "min", hard: $rule.limit, soft: $rule.warn} end;

def breaches($b; $cur; $limit):
  $limit != null and (if $b.dir == "max" then $cur > $limit else $cur < $limit end);

def raw_status($b; $cur):
  if breaches($b; $cur; $b.hard) then "fail"
  elif breaches($b; $cur; $b.soft) then "warn"
  else "ok" end;

def within_noise($rule; $cur; $base):
  $rule.allow_noise_abs != null and ($base | numeric) and (($cur - $base) | fabs) < $rule.allow_noise_abs;

def verdict($status; $reason): {status: $status, reason: $reason};

def breach_reason($s; $b):
  if $s == "ok" then "within limit"
  elif $s == "warn" then "beyond warn bound " + ($b.soft | tostring)
  else "beyond limit " + ($b.hard | tostring) end;

def numeric_verdict($rule; $cur; $base):
  if ($cur | numeric | not) then verdict("unknown"; "current value is not a number")
  elif $rule.kind == "max_ratio" and ($base | numeric | not) then verdict("unknown"; "no numeric baseline")
  elif ($rule.limit | numeric | not) then verdict("unknown"; "rule has no numeric limit")
  else
    bounds($rule; $base) as $b
    | raw_status($b; $cur) as $s
    | if $s != "ok" and within_noise($rule; $cur; $base) then verdict("ok"; "delta within noise")
      else verdict($s; breach_reason($s; $b)) end
  end;

def keys_verdict($cur; $base):
  if ($base | type) != "array" and ($base | type) != "object" then verdict("unknown"; "no baseline signatures")
  else ($cur | key_set) - ($base | key_set) | if length == 0 then verdict("ok"; "no unseen keys") else verdict("fail"; "unseen: " + join(", ")) end end;

def equals_verdict($rule; $cur):
  if $cur == $rule.value then verdict("ok"; "equals expected") else verdict("fail"; "expected " + ($rule.value | tostring)) end;

def evaluate($rule; $cur; $base):
  if $cur == null then verdict("unknown"; "no current value")
  elif $rule.kind == "forbid_new_keys" then keys_verdict($cur; $base)
  elif $rule.kind == "equals" then equals_verdict($rule; $cur)
  elif ["max_ratio", "max_abs", "min_abs"] | index($rule.kind) then numeric_verdict($rule; $cur; $base)
  else verdict("unknown"; "unknown rule kind") end;

def signal($rule; $cur; $base):
  evaluate($rule; $cur[$rule.name]; $base[$rule.name])
  + {name: $rule.name, value: $cur[$rule.name], baseline: $base[$rule.name], rule: rule_text($rule)};

def overall($signals):
  if ($signals | length) == 0 then "unknown"
  elif any($signals[]; .status == "fail") then "degraded"
  elif any($signals[]; .status == "unknown") then "unknown"
  else "healthy" end;

[$rules[0][] | signal(.; $current[0]; $baseline[0])] as $signals
| {verdict: overall($signals), signals: ($signals | map({name, status, value, baseline, rule, reason}))}
