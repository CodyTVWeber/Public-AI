def trim: gsub("^ +| +$"; "");
def words: split(",") | map(trim) | map(ascii_downcase) | map(select(length > 0));
def ok_case: . == "happy" or . == "critical";
def norm_ac:
  ascii_upcase
  | if test("^AC-[0-9]+$") then . else sub("^AC"; "AC-") end;
def ac_ids: [scan("AC-?[0-9]+")] | map(norm_ac);
def too_many($n; $key; $max):
  if $n > $max then {rule: "too-many-\($key)", detail: "\($n) \($key) rows (max \($max))"}
  else empty end;
def layer_issue($r):
  ($r.layer | ascii_downcase) as $l
  | if $l == "unit" then {rule: "unit-layer", detail: "unit tests are not plan-phase verification"}
    elif $l != "system" and $l != "api" then {rule: "bad-layer", detail: "layer '\($r.layer)' is not system or api"}
    else empty end;
def writer_issue($r):
  ($r.writer | ascii_downcase) as $w
  | if $w != "test" and $w != "script" then {rule: "bad-writer", detail: "writer '\($r.writer)' is not test or script"}
    else empty end;
def cases_issue($r):
  if ($r.cases | words | length) == 0 or ($r.cases | words | any(ok_case | not)) then
    {rule: "bad-cases", detail: "cases '\($r.cases)' must be happy and/or critical"}
  else empty end;
def cell_issue($r):
  if ($r.observable | trim | length) == 0 then {rule: "empty-cell", detail: "Observable is empty"}
  elif ($r.observable | test("\\{\\{")) then {rule: "placeholder", detail: "Observable still has a fill-in"}
  elif ($r.ac | trim | length) == 0 then {rule: "empty-cell", detail: "AC is empty"}
  elif ($r | to_entries | any(.value | tostring | test("\\{\\{"))) then
    {rule: "placeholder", detail: "row still has a fill-in"}
  else empty end;
def row_issues($r): layer_issue($r), writer_issue($r), cases_issue($r), cell_issue($r);
def count(f): [.rows[] | select(f)] | length;
def caps:
  too_many(count((.layer | ascii_downcase) == "system" and (.writer | ascii_downcase) == "test"); "system"; .caps.system // 4),
  too_many(count((.layer | ascii_downcase) == "api" and (.writer | ascii_downcase) == "test"); "api"; .caps.api // 8),
  too_many(count((.writer | ascii_downcase) == "script"); "script"; .caps.script // 6);
def uncovered:
  ([.rows[].ac | ac_ids] | add // [] | unique) as $covered
  | .criteria[]
  | . as $id
  | select(($covered | index($id)) == null)
  | {rule: "uncovered-criterion", detail: "\($id) is in no AC cell"};

if .skip then []
elif (.has_heading | not) then [{rule: "missing-heading", detail: "## Verification"}]
elif (.rows | length) == 0 then [{rule: "no-table", detail: "need a table or the skip line"}]
else
  . as $in
  | [$in.rows[] | row_issues(.)] + [$in | caps] + [$in | uncovered]
end
