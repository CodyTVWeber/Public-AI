def required_columns: ["signal", "kind", "criteria", "source", "query", "baseline", "threshold", "cadence", "failure", "action"];
def kinds: ["works", "error", "data", "health", "latency", "queue", "alert", "flag", "downstream", "kpi", "probe"];
def rule_kinds: ["max_ratio", "max_abs", "min_abs", "equals", "forbid_new_keys"];

def trim: gsub("^\\s+|\\s+$"; "");
def cells: split("|") | .[1:-1] | map(trim);
def column_key($header): required_columns | map(select(. as $k | $header | ascii_downcase | startswith($k))) | first;

def violation($rule; $detail): {rule: $rule, detail: $detail};

def parse_rows:
  (.[0] | cells) as $head
  | ($head | map(column_key(.))) as $keys
  | {keys: $keys, rows: [.[2:][] | cells as $c | [range(0; $keys | length)] | map({key: $keys[.], value: ($c[.] // "")}) | map(select(.key != null)) | from_entries]};

def missing_columns($keys): required_columns - $keys | map(violation("missing-column"; .));

def cell_problems($row):
  [required_columns[] as $k | select($row[$k] != null)
    | if $row[$k] == "" then violation("empty-cell"; $row.signal + ": " + $k)
      elif ($row[$k] | test("<[A-Za-z][^<>]*>|^TBD$|^TODO$"; "i")) then violation("placeholder"; $row.signal + ": " + $k)
      else empty end];

def kind_problems($row):
  if ($row.kind // "") == "" or (kinds | index($row.kind)) then []
  else [violation("bad-kind"; $row.signal + ": " + $row.kind)] end;

def threshold_problems($row):
  if ($row.threshold // "") == "" or (rule_kinds | index($row.threshold | split(" ")[0] | split(",")[0])) then []
  else [violation("bad-threshold"; $row.signal + ": " + $row.threshold)] end;

def criteria_of($rows): [$rows[].criteria // "" | split("[ ,;]+"; null)[] | select(. != "")] | unique;

def coverage_problems($rows):
  criteria_of($rows) as $covered
  | [$criteria[] | select(. as $id | $covered | index($id) | not) | violation("uncovered-criterion"; .)];

def kind_present($rows; $kind): any($rows[]; .kind == $kind);

def kind_requirements($rows):
  (if kind_present($rows; "error") then [] else [violation("no-error-signal"; "at least one error signal")] end)
  + (if $touches_data and (kind_present($rows; "data") | not) then [violation("no-data-signal"; "the change touches data")] else [] end);

def table_problems:
  parse_rows as $t
  | missing_columns($t.keys)
  + ([$t.rows[] | cell_problems(.) + kind_problems(.) + threshold_problems(.)] | add // [])
  + coverage_problems($t.rows)
  + kind_requirements($t.rows);

split("\n") | map(select(length > 0)) | if length < 2 then [violation("no-table"; "no signals table")] else table_problems end
