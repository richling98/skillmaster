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
    :root {
      color-scheme: light;
      --bg: #f5f5f7;
      --surface: rgba(255, 255, 255, 0.82);
      --surface-strong: #ffffff;
      --text: #1d1d1f;
      --muted: #6e6e73;
      --quiet: #86868b;
      --line: rgba(0, 0, 0, 0.11);
      --line-soft: rgba(0, 0, 0, 0.07);
      --blue: #0066cc;
      --blue-hover: #004f9f;
      --green: #188038;
      --code-bg: #fbfbfd;
      --shadow: 0 18px 45px rgba(0, 0, 0, 0.08);
    }
    * { box-sizing: border-box; }
    html { background: var(--bg); }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 20% -10%, rgba(0, 102, 204, 0.10), transparent 34%),
        radial-gradient(circle at 90% 0%, rgba(52, 199, 89, 0.08), transparent 28%),
        var(--bg);
      color: var(--text);
      line-height: 1.45;
      -webkit-font-smoothing: antialiased;
    }
    .shell {
      width: min(1180px, calc(100% - 40px));
      margin: 0 auto;
    }
    header {
      padding: 42px 0 24px;
    }
    .masthead {
      display: grid;
      grid-template-columns: 1fr auto;
      align-items: end;
      gap: 24px;
      padding: 26px 0 12px;
    }
    .eyebrow {
      margin: 0 0 9px;
      color: var(--quiet);
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 0;
      text-transform: uppercase;
    }
    h1 {
      margin: 0;
      font-size: clamp(40px, 6vw, 72px);
      line-height: 0.95;
      letter-spacing: 0;
      font-weight: 800;
    }
    header p {
      max-width: 650px;
      margin: 16px 0 0;
      color: var(--muted);
      font-size: 18px;
    }
    .metric {
      min-width: 154px;
      padding: 18px;
      border: 1px solid var(--line-soft);
      border-radius: 8px;
      background: var(--surface);
      box-shadow: var(--shadow);
      text-align: right;
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
    }
    .metric strong {
      display: block;
      font-size: 34px;
      line-height: 1;
    }
    .metric span {
      display: block;
      margin-top: 6px;
      color: var(--quiet);
      font-size: 13px;
      font-weight: 600;
    }
    .toolbar-wrap {
      position: sticky;
      top: 0;
      z-index: 10;
      margin: 4px 0 22px;
      padding: 12px 0;
      background: rgba(245, 245, 247, 0.78);
      backdrop-filter: blur(22px);
      -webkit-backdrop-filter: blur(22px);
      border-bottom: 1px solid rgba(0, 0, 0, 0.04);
    }
    .toolbar {
      display: grid;
      grid-template-columns: minmax(220px, 460px) 1fr auto;
      gap: 12px;
      align-items: center;
    }
    .search {
      position: relative;
    }
    .search::before {
      content: "";
      position: absolute;
      left: 15px;
      top: 50%;
      width: 12px;
      height: 12px;
      border: 2px solid var(--quiet);
      border-radius: 50%;
      transform: translateY(-58%);
      pointer-events: none;
    }
    .search::after {
      content: "";
      position: absolute;
      left: 26px;
      top: 50%;
      width: 7px;
      height: 2px;
      border-radius: 2px;
      background: var(--quiet);
      transform: translateY(5px) rotate(45deg);
      pointer-events: none;
    }
    input[type="search"] {
      width: 100%;
      height: 42px;
      padding: 0 14px 0 43px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.86);
      color: var(--text);
      font-size: 14px;
      outline: none;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
      appearance: none;
    }
    input[type="search"]:focus {
      border-color: rgba(0, 102, 204, 0.55);
      box-shadow: 0 0 0 4px rgba(0, 102, 204, 0.12);
    }
    .result-count {
      color: var(--muted);
      font-size: 14px;
      font-weight: 600;
    }
    .library {
      display: grid;
      gap: 10px;
      padding: 0 0 64px;
    }
    .skill {
      border: 1px solid var(--line-soft);
      background: var(--surface-strong);
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
      transition: border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease;
    }
    .skill:hover {
      border-color: rgba(0, 102, 204, 0.24);
      box-shadow: 0 12px 28px rgba(0, 0, 0, 0.08);
      transform: translateY(-1px);
    }
    .skill-header {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 20px;
      padding: 20px 22px;
      align-items: center;
    }
    .skill h2 {
      margin: 0 0 6px;
      font-size: 19px;
      line-height: 1.2;
      letter-spacing: 0;
      font-weight: 750;
    }
    .desc {
      max-width: 820px;
      color: var(--muted);
      font-size: 14px;
      margin: 0 0 10px;
    }
    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: center;
      color: var(--quiet);
      font-size: 12px;
      font-family: "SF Mono", ui-monospace, Menlo, monospace;
    }
    .path-pill {
      max-width: 100%;
      padding: 4px 7px;
      border: 1px solid var(--line-soft);
      border-radius: 7px;
      background: var(--bg);
      overflow-wrap: anywhere;
    }
    .updated {
      color: var(--quiet);
    }
    .actions {
      display: flex;
      gap: 8px;
      align-items: center;
    }
    button {
      min-width: 78px;
      height: 38px;
      border: 1px solid transparent;
      border-radius: 8px;
      padding: 0 14px;
      background: var(--blue);
      color: #ffffff;
      cursor: pointer;
      font-size: 14px;
      font-weight: 700;
      letter-spacing: 0;
      transition: background 140ms ease, transform 140ms ease, box-shadow 140ms ease;
    }
    button:hover {
      background: var(--blue-hover);
      box-shadow: 0 8px 18px rgba(0, 102, 204, 0.22);
      transform: translateY(-1px);
    }
    button.copied {
      background: var(--green);
      box-shadow: none;
    }
    details {
      border-top: 1px solid var(--line-soft);
      background: var(--code-bg);
    }
    summary {
      cursor: pointer;
      padding: 12px 22px;
      color: var(--blue);
      font-size: 13px;
      font-weight: 700;
      list-style-position: outside;
    }
    summary:hover { color: var(--blue-hover); }
    pre {
      margin: 0;
      padding: 18px 22px 24px;
      overflow-x: auto;
      border-top: 1px solid var(--line-soft);
      background: #ffffff;
      color: #242426;
      font-size: 13px;
      line-height: 1.58;
      font-family: "SF Mono", ui-monospace, Menlo, monospace;
    }
    textarea { display: none; }
    .empty {
      padding: 38px;
      border: 1px solid var(--line-soft);
      border-radius: 8px;
      background: var(--surface-strong);
      color: var(--muted);
      text-align: center;
    }
    @media (max-width: 780px) {
      .shell { width: min(100% - 28px, 1180px); }
      header { padding-top: 22px; }
      .masthead {
        grid-template-columns: 1fr;
        align-items: start;
      }
      .metric {
        width: 100%;
        text-align: left;
      }
      .toolbar {
        grid-template-columns: 1fr;
      }
      .skill-header {
        grid-template-columns: 1fr;
        gap: 14px;
      }
      .actions button {
        width: 100%;
      }
    }
  </style>
</head>
<body>
<header>
  <div class="shell masthead">
    <div>
      <p class="eyebrow">SkillMaster</p>
      <h1>Skills Library</h1>
      <p>Browse, inspect, and copy your local AI skills from one clean surface.</p>
    </div>
    <div class="metric">
      <strong id="total-count">0</strong>
      <span>skills</span>
    </div>
  </div>
</header>
<div class="toolbar-wrap">
  <div class="shell toolbar">
    <div class="search">
      <input id="filter" type="search" placeholder="Search skills" oninput="filterSkills()" autocomplete="off" />
    </div>
    <div id="result-count" class="result-count">Showing all skills</div>
  </div>
</div>
<main class="shell">
  <section class="library" id="library">
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
    printf '      <div class="meta"><span class="path-pill">%s</span><span class="updated">Updated %s</span></div>\n' \
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
  </section>
</main>
<script>
const totalCount = document.querySelectorAll(".skill").length;
document.getElementById("total-count").textContent = totalCount;
document.getElementById("result-count").textContent = `Showing ${totalCount} ${totalCount === 1 ? "skill" : "skills"}`;

function copySkill(id, button) {
  const textarea = document.getElementById(id);
  const text = textarea.value;
  const done = () => {
    const old = button.textContent;
    button.classList.add("copied");
    button.textContent = "Copied";
    window.setTimeout(() => {
      button.textContent = old;
      button.classList.remove("copied");
    }, 1200);
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
  let visible = 0;
  document.querySelectorAll(".skill").forEach((skill) => {
    const match = skill.dataset.search.toLowerCase().includes(query);
    skill.style.display = match ? "" : "none";
    if (match) visible += 1;
  });
  const label = visible === 1 ? "skill" : "skills";
  document.getElementById("result-count").textContent = query ? `${visible} ${label} found` : `Showing ${visible} ${label}`;
}
</script>
</body>
</html>
HTML

log_msg "Regenerated skill index page at $OUT with $count skills"
printf 'Generated %s with %s skills\n' "$OUT" "$count"
