#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_config

MASTER="${1:-$MASTER_DIR}"
OUT="$MASTER/index.html"

html_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

html_escape_string() {
  printf '%s' "$1" | html_escape
}

metadata_value() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  awk -v key="$key" '
    BEGIN { in_frontmatter = 0 }
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter {
      split($0, parts, ":")
      if (parts[1] == key) {
        sub("^[^:]*:[[:space:]]*", "", $0)
        gsub(/^"|"$/, "", $0)
        gsub(/^'\''|'\''$/, "", $0)
        print $0
        exit
      }
    }
  ' "$file" 2>/dev/null || true
}

updated_time() {
  local path="$1"
  [[ -e "$path" ]] || {
    printf 'unknown'
    return 0
  }
  if stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$path" >/dev/null 2>&1; then
    stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$path"
  else
    stat -c '%y' "$path" | cut -d. -f1
  fi
}

mkdir -p "$MASTER"

cat > "$OUT" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>SkillMaster Library</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #0f1117;
      color: #e2e8f0;
      line-height: 1.6;
    }
    header {
      padding: 36px 32px 24px;
      border-bottom: 1px solid #1e2535;
      background: #111827;
    }
    h1 { margin: 0 0 8px; font-size: 32px; }
    header p { margin: 0; color: #94a3b8; }
    main { max-width: 1100px; margin: 0 auto; padding: 28px 32px 48px; }
    .toolbar { margin-bottom: 18px; }
    input {
      width: 100%;
      max-width: 420px;
      padding: 10px 12px;
      border: 1px solid #2d3748;
      border-radius: 8px;
      background: #151b27;
      color: #e2e8f0;
      font-size: 14px;
    }
    .skill {
      border: 1px solid #1e2d3d;
      background: #151b27;
      border-radius: 8px;
      margin-bottom: 12px;
      overflow: hidden;
    }
    .skill-header {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 16px;
      padding: 18px 20px;
      align-items: center;
    }
    .skill h2 { margin: 0 0 4px; font-size: 17px; }
    .desc { color: #94a3b8; font-size: 14px; margin: 0 0 6px; }
    .meta { color: #64748b; font-size: 12px; font-family: "SF Mono", monospace; }
    .actions { display: flex; gap: 8px; }
    button {
      border: 1px solid #2d4a6b;
      border-radius: 6px;
      padding: 8px 11px;
      background: #0d1320;
      color: #e2e8f0;
      cursor: pointer;
      font-weight: 700;
    }
    button:hover { border-color: #76e3a0; color: #76e3a0; }
    details { border-top: 1px solid #1e2d3d; }
    summary { cursor: pointer; padding: 10px 20px; color: #76e3a0; font-size: 13px; }
    pre {
      margin: 0;
      padding: 18px 20px 24px;
      overflow-x: auto;
      background: #0d1320;
      color: #cbd5e1;
      font-size: 13px;
      line-height: 1.55;
    }
    textarea { display: none; }
    .empty { color: #64748b; padding: 24px 0; }
  </style>
</head>
<body>
<header>
  <h1>SkillMaster Library</h1>
  <p>Local skills from your master folder. View any skill and copy its full markdown.</p>
</header>
<main>
  <div class="toolbar">
    <input id="filter" type="search" placeholder="Search skills" oninput="filterSkills()" />
  </div>
HTML

count=0
while IFS= read -r skill_dir; do
  skill_name="$(basename "$skill_dir")"
  is_excluded_skill "$skill_name" && continue

  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue
  skill_content="$(cat "$skill_file" 2>/dev/null || true)"
  [[ -n "$skill_content" || -f "$skill_file" ]] || continue
  title="$(metadata_value "$skill_file" "name")"
  description="$(metadata_value "$skill_file" "description")"
  [[ -n "$title" ]] || title="$skill_name"
  [[ -n "$description" ]] || description="No description provided."
  count=$((count + 1))
  id="skill_$count"

  {
    printf '<article class="skill" data-search="%s %s %s">\n' \
      "$(html_escape_string "$skill_name")" \
      "$(html_escape_string "$title")" \
      "$(html_escape_string "$description")"
    printf '  <div class="skill-header">\n'
    printf '    <div>\n'
    printf '      <h2>%s</h2>\n' "$(html_escape_string "$title")"
    printf '      <p class="desc">%s</p>\n' "$(html_escape_string "$description")"
    printf '      <div class="meta">%s · Updated %s</div>\n' \
      "$(html_escape_string "$skill_name/SKILL.md")" \
      "$(html_escape_string "$(updated_time "$skill_file")")"
    printf '    </div>\n'
    printf '    <div class="actions"><button type="button" onclick="copySkill('\''%s'\'', this)">Copy</button></div>\n' "$id"
    printf '  </div>\n'
    printf '  <details><summary>View skill</summary><pre>'
    html_escape_string "$skill_content"
    printf '</pre></details>\n'
    printf '  <textarea id="%s">' "$id"
    html_escape_string "$skill_content"
    printf '</textarea>\n'
    printf '</article>\n'
  } >> "$OUT"
done < <(find "$MASTER" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ "$count" -eq 0 ]]; then
  cat >> "$OUT" <<'HTML'
  <p class="empty">No skills found yet.</p>
HTML
fi

cat >> "$OUT" <<'HTML'
</main>
<script>
function copySkill(id, button) {
  const textarea = document.getElementById(id);
  const text = textarea.value;
  const done = () => {
    const old = button.textContent;
    button.textContent = "Copied";
    window.setTimeout(() => { button.textContent = old; }, 1200);
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(done).catch(() => fallbackCopy(text, done));
  } else {
    fallbackCopy(text, done);
  }
}

function fallbackCopy(text, done) {
  const scratch = document.createElement("textarea");
  scratch.value = text;
  document.body.appendChild(scratch);
  scratch.select();
  document.execCommand("copy");
  document.body.removeChild(scratch);
  done();
}

function filterSkills() {
  const query = document.getElementById("filter").value.toLowerCase();
  document.querySelectorAll(".skill").forEach((skill) => {
    skill.style.display = skill.dataset.search.toLowerCase().includes(query) ? "" : "none";
  });
}
</script>
</body>
</html>
HTML

log_msg "Regenerated skill index page at $OUT with $count skills"
printf 'Generated %s with %s skills\n' "$OUT" "$count"
