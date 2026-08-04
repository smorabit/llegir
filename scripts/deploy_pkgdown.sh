#!/usr/bin/env bash
# rebuilds the pkgdown site locally (needs the local hdWGCNA test object,
# which is why this cannot run in GitHub Actions) and pushes the output
# to the gh-pages branch via the worktree at ../llegir-gh-pages
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
worktree_dir="$repo_root/../llegir-gh-pages"

if [ ! -d "$worktree_dir" ]; then
    echo "worktree not found at $worktree_dir -- run:"
    echo "  git worktree add ../llegir-gh-pages gh-pages"
    exit 1
fi

cd "$repo_root"
Rscript -e 'pkgdown::build_site(preview = FALSE)'

# pkgdown auto-publishes every root-level *.md file it doesn't already claim
# as README/LICENSE/NEWS, which would otherwise leak CLAUDE.md/STYLE.md (and
# their full body text via the search index) onto the public site
site_dir="$repo_root/pkgdown_site"
rm -f "$site_dir/CLAUDE.md" "$site_dir/CLAUDE.html" "$site_dir/STYLE.md" "$site_dir/STYLE.html"
jq 'map(select(
    (.path | type == "string" and (contains("CLAUDE.html") or contains("STYLE.html"))) | not
))' "$site_dir/search.json" > "$site_dir/search.json.tmp"
mv "$site_dir/search.json.tmp" "$site_dir/search.json"
grep -v "CLAUDE.html\|STYLE.html" "$site_dir/sitemap.xml" > "$site_dir/sitemap.xml.tmp"
mv "$site_dir/sitemap.xml.tmp" "$site_dir/sitemap.xml"

# pkgdown::build_site() never writes .nojekyll itself, so it has to be
# re-added here on every deploy or GitHub Pages tries to run Jekyll over
# the site and mangles the reference/articles output
touch "$site_dir/.nojekyll"

rsync -a --delete --exclude .git "$site_dir/" "$worktree_dir/"

cd "$worktree_dir"
git add -A
if git diff --cached --quiet; then
    echo "no changes to deploy"
    exit 0
fi
git commit -m "deploy: rebuild pkgdown site $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git push origin gh-pages
