#!/bin/sh
set -eu
MARKDOWN=pandoc
IFS='	'

# Create tab separated file with filename, title, creation date, last update
index_tsv() {
	for f in "$1"/*.md
	do
		created=$(git log --pretty='format:%aI' "$f" 2> /dev/null | head -1)
		updated=$(git log --pretty='format:%aI' "$f" 2> /dev/null | head -1)
		title=$(sed -n '/^# /{s/# //p; q}' "$f")
		printf '%s\t%s\t%s\t%s\n' "$f" "${title:="No Title"}" "${created:="draft"}" "${updated:="draft"}"
	done
}

index_html() {
	# Print header
	title=$(sed -n '/^# /{s/# //p; q}' index.md)
	sed "s/{{TITLE}}/$title/" header.html

	# Intro text
	$MARKDOWN index.md

	# Posts
	while read -r f title created updated; do
		if [ "$created" = "draft" ] && [ "$2" = "hide-drafts" ]; then continue; fi
		link=$(echo "$f" | sed -E 's|.*/(.*).md|\1.html|')
		created=$(echo "$created" | sed -E 's/T.*//')
	 	echo "$created &mdash; <a href=\"$link\">$title</a><br/>"
	done < "$1"
}

rss_xml() {
  uri=$(sed -rn '/rss.xml/ s/.*href="([^"]*)".*/\1/ p' header.html)
  host=$(echo "$uri" | sed -r 's|.*//([^/]+).*|\1|')

  cat <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <title>Volodymyr Vasylyna's Website</title>
  <link>$uri</link>
  <description>Volodymyr Vasylyna's Website and Blog</description>
  <lastBuildDate>$(date -u +"%a, %d %b %Y %H:%M:%S %z")</lastBuildDate>
  <language>en-us</language>
EOF

  while read -r f title created updated; do
    if [ "$created" = "draft" ]; then continue; fi

    day=$(echo "$created" | sed 's/T.*//')
    content=$($MARKDOWN "$f")

    cat <<EOF
  <item>
    <title>$title</title>
    <link>$(echo "$f" | sed -E 's|posts/(.*).md|\1.html|')</link>
    <pubDate>$(date -d "$created" +"%a, %d %b %Y %H:%M:%S %z")</pubDate>
    <description><![CDATA[$content]]></description>
  </item>
EOF
  done < "$1"

  echo '</channel></rss>'
}

rss_xml build/posts.tsv > build/rss.xml


write_page() {
	filename=$1
	target=$(echo "$filename" | sed -r 's|\w+/(.*).md|build/\1.html|')
	created=$(echo "$3" | sed 's/T.*//')
	updated=$(echo "$4" | sed 's/T.*//')
	dates_text="Written on ${created}."
	if [ "$created" != "$updated" ]; then
		dates_text="$dates_text Last updated on ${updated}."
	fi
	title=$2

	$MARKDOWN "$filename" | \
		sed "$ a <small>$dates_text</small>" | \
		cat header.html - |\
		sed "s/{{TITLE}}/$title/" \
		> "$target"
}

rm -fr build && mkdir build

# Blog posts
index_tsv posts | sort -rt "	" -k 3 > build/posts.tsv
index_html build/posts.tsv hide-drafts > build/index.html
index_html build/posts.tsv show-drafts > build/index-with-drafts.html
atom_xml build/posts.tsv > build/atom.xml
while read -r f title created updated; do
	write_page "$f" "$title" "$created" "$updated"
done < build/posts.tsv

# Pages
index_tsv pages > build/pages.tsv
while read -r f title created updated; do
	write_page "$f" "$title" "$created" "$updated"
done < build/pages.tsv

# Static files
cp -r posts/*/ build
