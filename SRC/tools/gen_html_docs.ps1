param(
    [string]$RepoRoot = ".",
    [string]$OutDir = "../DOC/HTML"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $RepoRoot))
$OutDir = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutDir))

if (-not $OutDir.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Output directory must stay inside repo root: $OutDir"
}

function Normalize-Slash {
    param([string]$Path)
    return ($Path -replace "\\", "/")
}

function Get-RelativePathCompat {
    param(
        [string]$FromDirectory,
        [string]$ToPath
    )

    $from = [System.IO.Path]::GetFullPath($FromDirectory)
    if (-not $from.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
        $from = $from + [System.IO.Path]::DirectorySeparatorChar
    }
    $to = [System.IO.Path]::GetFullPath($ToPath)
    $fromUri = New-Object System.Uri $from
    $toUri = New-Object System.Uri $to
    return (Normalize-Slash ([System.Uri]::UnescapeDataString($fromUri.MakeRelativeUri($toUri).ToString())))
}

function Get-RepoRelativePath {
    param([string]$FullPath)
    return (Get-RelativePathCompat -FromDirectory $RepoRoot -ToPath $FullPath)
}

function ConvertTo-OutputRelativePath {
    param([string]$SourceRelativePath)

    $src = Normalize-Slash $SourceRelativePath
    if ($src -eq "DOC/INDEX.md") {
        return "index.html"
    }
    if ($src.StartsWith("DOC/")) {
        $src = $src.Substring(4)
    }
    return ([System.IO.Path]::ChangeExtension($src, ".html") -replace "\\", "/")
}

function ConvertTo-AssetOutputRelativePath {
    param([string]$SourceRelativePath)

    $src = Normalize-Slash $SourceRelativePath
    if ($src.StartsWith("DOC/")) {
        return $src.Substring(4)
    }
    return $src
}

function Encode-Html {
    param([string]$Text)
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Text
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrEmpty($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Get-Slug {
    param(
        [string]$Text,
        [hashtable]$Seen
    )

    $slug = $Text.ToLowerInvariant()
    $slug = $slug -replace '`([^`]+)`', '$1'
    $slug = $slug -replace "\[[^\]]+\]\([^)]+\)", ""
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = "section"
    }

    $base = $slug
    $n = 2
    while ($Seen.ContainsKey($slug)) {
        $slug = "$base-$n"
        $n++
    }
    $Seen[$slug] = $true
    return $slug
}

$MarkdownSources = @()
$readme = Join-Path $RepoRoot "README.md"
if (Test-Path -LiteralPath $readme) {
    $MarkdownSources += Get-Item -LiteralPath $readme
}

$docRoot = Join-Path $RepoRoot "DOC"
if (Test-Path -LiteralPath $docRoot) {
    $MarkdownSources += Get-ChildItem -LiteralPath $docRoot -Recurse -File -Filter "*.md" |
        Where-Object { $_.FullName -notlike (Join-Path $OutDir "*") }
}

$MarkdownSources = $MarkdownSources | Sort-Object FullName

$MarkdownOutputBySource = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($source in $MarkdownSources) {
    $rel = Get-RepoRelativePath $source.FullName
    $MarkdownOutputBySource[$rel] = ConvertTo-OutputRelativePath $rel
}

function Resolve-SourceRelativeLink {
    param(
        [string]$Target,
        [string]$SourceRelativePath
    )

    $targetNoAngles = $Target.Trim()
    if ($targetNoAngles.StartsWith("<") -and $targetNoAngles.EndsWith(">")) {
        $targetNoAngles = $targetNoAngles.Substring(1, $targetNoAngles.Length - 2)
    }

    if ($targetNoAngles -match "^(https?:|mailto:|#)") {
        return $targetNoAngles
    }

    $fragment = ""
    $pathPart = $targetNoAngles
    $hashAt = $targetNoAngles.IndexOf("#")
    if ($hashAt -ge 0) {
        $pathPart = $targetNoAngles.Substring(0, $hashAt)
        $fragment = $targetNoAngles.Substring($hashAt)
    }

    if ([string]::IsNullOrWhiteSpace($pathPart)) {
        return $targetNoAngles
    }

    $sourceDirRel = Normalize-Slash (Split-Path -Parent $SourceRelativePath)
    if ($sourceDirRel -eq ".") {
        $sourceDirRel = ""
    }

    $baseFull = if ([string]::IsNullOrWhiteSpace($sourceDirRel)) {
        $RepoRoot
    } else {
        Join-Path $RepoRoot ($sourceDirRel -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    }

    $targetFull = [System.IO.Path]::GetFullPath((Join-Path $baseFull ($pathPart -replace "/", [System.IO.Path]::DirectorySeparatorChar)))
    if (-not $targetFull.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $targetNoAngles
    }

    $targetRel = Get-RepoRelativePath $targetFull
    if ((Test-Path -LiteralPath $targetFull -PathType Leaf) -and $MarkdownOutputBySource.ContainsKey($targetRel)) {
        return $MarkdownOutputBySource[$targetRel] + $fragment
    }

    if ($targetRel.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase)) {
        return (ConvertTo-OutputRelativePath $targetRel) + $fragment
    }

    if (Test-Path -LiteralPath $targetFull -PathType Container) {
        $indexRel = Normalize-Slash (Join-Path $targetRel "INDEX.md")
        if ($MarkdownOutputBySource.ContainsKey($indexRel)) {
            return $MarkdownOutputBySource[$indexRel] + $fragment
        }

        $dirOut = ConvertTo-AssetOutputRelativePath $targetRel
        if ([string]::IsNullOrWhiteSpace($dirOut)) {
            return "index.html" + $fragment
        }
        return (Normalize-Slash (Join-Path $dirOut "index.html")) + $fragment
    }

    return (ConvertTo-AssetOutputRelativePath $targetRel) + $fragment
}

function Resolve-HtmlHref {
    param(
        [string]$Target,
        [string]$SourceRelativePath,
        [string]$OutputRelativePath
    )

    $targetOut = Resolve-SourceRelativeLink -Target $Target -SourceRelativePath $SourceRelativePath
    if ($targetOut -match "^(https?:|mailto:|#)") {
        return $targetOut
    }

    $fragment = ""
    $pathPart = $targetOut
    $hashAt = $targetOut.IndexOf("#")
    if ($hashAt -ge 0) {
        $pathPart = $targetOut.Substring(0, $hashAt)
        $fragment = $targetOut.Substring($hashAt)
    }

    $currentOutFull = Join-Path $OutDir ($OutputRelativePath -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    $currentOutDir = Split-Path -Parent $currentOutFull
    $targetOutFull = Join-Path $OutDir ($pathPart -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    return (Get-RelativePathCompat -FromDirectory $currentOutDir -ToPath $targetOutFull) + $fragment
}

$script:InlineTokenSerial = 0

function Convert-InlineMarkdown {
    param(
        [string]$Text,
        [string]$SourceRelativePath,
        [string]$OutputRelativePath
    )

    $tokens = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $addToken = {
        param([string]$Html)
        $token = "@@RYORS_HTML_TOKEN_$($script:InlineTokenSerial)@@"
        $script:InlineTokenSerial++
        $tokens[$token] = $Html
        return $token
    }

    $working = $Text
    $working = [regex]::Replace($working, '`([^`]+)`', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        & $addToken ("<code>" + (Encode-Html $m.Groups[1].Value) + "</code>")
    })

    $working = [regex]::Replace($working, "!\[([^\]]*)\]\(([^)]+)\)", [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $alt = Encode-Html $m.Groups[1].Value
        $href = Resolve-HtmlHref -Target $m.Groups[2].Value -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath
        $imgHtml = '<img src="{0}" alt="{1}">' -f @((Encode-Html $href), $alt)
        & $addToken $imgHtml
    })

    $working = [regex]::Replace($working, "\[([^\]]+)\]\(([^)]+)\)", [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $label = Encode-Html $m.Groups[1].Value
        $href = Resolve-HtmlHref -Target $m.Groups[2].Value -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath
        $linkHtml = '<a href="{0}">{1}</a>' -f @((Encode-Html $href), $label)
        & $addToken $linkHtml
    })

    $html = Encode-Html $working
    $html = [regex]::Replace($html, "\*\*([^*]+)\*\*", '<strong>$1</strong>')
    $html = [regex]::Replace($html, "(?<!\*)\*([^*]+)\*(?!\*)", '<em>$1</em>')

    foreach ($key in $tokens.Keys) {
        $html = $html.Replace($key, $tokens[$key])
    }

    return $html
}

function Test-TableSeparator {
    param([string]$Line)
    return ($Line -match "^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$")
}

function Split-MarkdownTableRow {
    param([string]$Line)
    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith("|")) {
        $trimmed = $trimmed.Substring(1)
    }
    if ($trimmed.EndsWith("|")) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - 1)
    }
    return @($trimmed -split "\|")
}

function Convert-MarkdownDocument {
    param(
        [string]$Markdown,
        [string]$SourceRelativePath,
        [string]$OutputRelativePath
    )

    $lines = $Markdown -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $paragraph = New-Object System.Collections.Generic.List[string]
    $listType = ""
    $inFence = $false
    $fenceLang = ""
    $fenceLines = New-Object System.Collections.Generic.List[string]
    $seenSlugs = @{}
    $title = [System.IO.Path]::GetFileNameWithoutExtension($SourceRelativePath)

    function Flush-Paragraph {
        if ($paragraph.Count -gt 0) {
            $text = ($paragraph -join " ").Trim()
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $out.Add("<p>$(Convert-InlineMarkdown -Text $text -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath)</p>")
            }
            $paragraph.Clear()
        }
    }

    function Close-List {
        if (-not [string]::IsNullOrWhiteSpace($listType)) {
            $out.Add("</$listType>")
            $script:NullSink = $null
            Set-Variable -Name listType -Value "" -Scope 1
        }
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($inFence) {
            if ($line -match '^\s*```\s*$') {
                $codeText = Encode-Html ($fenceLines -join "`n")
                if ($fenceLang -eq "mermaid") {
                    $out.Add("<pre class=`"mermaid`">$codeText</pre>")
                } else {
                    $class = if ([string]::IsNullOrWhiteSpace($fenceLang)) { "" } else { ' class="language-' + (Encode-Html $fenceLang) + '"' }
                    $out.Add("<pre><code$class>$codeText</code></pre>")
                }
                $fenceLines.Clear()
                $inFence = $false
                $fenceLang = ""
            } else {
                $fenceLines.Add($line)
            }
            continue
        }

        if ($line -match '^\s*```([A-Za-z0-9_-]*)\s*$') {
            Flush-Paragraph
            Close-List
            $inFence = $true
            $fenceLang = $matches[1]
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            Flush-Paragraph
            Close-List
            continue
        }

        if ($line -match "^\s*<!--") {
            Flush-Paragraph
            Close-List
            $out.Add($line)
            continue
        }

        if ($line -match "^(#{1,6})\s+(.+?)\s*$") {
            Flush-Paragraph
            Close-List
            $level = $matches[1].Length
            $headingText = $matches[2]
            if ($level -eq 1) {
                $title = $headingText
            }
            $slug = Get-Slug -Text $headingText -Seen $seenSlugs
            $headingHtml = Convert-InlineMarkdown -Text $headingText -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath
            $out.Add("<h$level id=`"$slug`">$headingHtml</h$level>")
            continue
        }

        if ($line -match "^\s*(-{3,}|\*{3,})\s*$") {
            Flush-Paragraph
            Close-List
            $out.Add("<hr>")
            continue
        }

        if (($line -like "*|*") -and (($i + 1) -lt $lines.Count) -and (Test-TableSeparator $lines[$i + 1])) {
            Flush-Paragraph
            Close-List
            $headers = Split-MarkdownTableRow $line
            $out.Add("<table>")
            $out.Add("<thead><tr>")
            foreach ($header in $headers) {
                $out.Add("<th>$(Convert-InlineMarkdown -Text $header.Trim() -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath)</th>")
            }
            $out.Add("</tr></thead>")
            $out.Add("<tbody>")
            $i += 2
            while ($i -lt $lines.Count -and ($lines[$i] -like "*|*") -and -not [string]::IsNullOrWhiteSpace($lines[$i])) {
                $cells = Split-MarkdownTableRow $lines[$i]
                $out.Add("<tr>")
                foreach ($cell in $cells) {
                    $out.Add("<td>$(Convert-InlineMarkdown -Text $cell.Trim() -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath)</td>")
                }
                $out.Add("</tr>")
                $i++
            }
            $i--
            $out.Add("</tbody>")
            $out.Add("</table>")
            continue
        }

        if ($line -match "^\s*[-*]\s+(.+)$") {
            Flush-Paragraph
            if ($listType -ne "ul") {
                Close-List
                $listType = "ul"
                $out.Add("<ul>")
            }
            $out.Add("<li>$(Convert-InlineMarkdown -Text $matches[1] -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath)</li>")
            continue
        }

        if ($line -match "^\s*\d+\.\s+(.+)$") {
            Flush-Paragraph
            if ($listType -ne "ol") {
                Close-List
                $listType = "ol"
                $out.Add("<ol>")
            }
            $out.Add("<li>$(Convert-InlineMarkdown -Text $matches[1] -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath)</li>")
            continue
        }

        if ($line -match "^\s*>\s*(.+)$") {
            Flush-Paragraph
            Close-List
            $out.Add("<blockquote><p>$(Convert-InlineMarkdown -Text $matches[1] -SourceRelativePath $SourceRelativePath -OutputRelativePath $OutputRelativePath)</p></blockquote>")
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($listType)) {
            Close-List
        }
        $paragraph.Add($line.Trim())
    }

    if ($inFence) {
        $out.Add("<pre><code>$(Encode-Html ($fenceLines -join "`n"))</code></pre>")
    }
    Flush-Paragraph
    Close-List

    return [pscustomobject]@{
        Title = $title
        Body = ($out -join "`n")
    }
}

function Get-NavHtml {
    param([string]$OutputRelativePath)

    $currentOutFull = Join-Path $OutDir ($OutputRelativePath -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    $currentDir = Split-Path -Parent $currentOutFull
    $homeHref = Get-RelativePathCompat -FromDirectory $currentDir -ToPath (Join-Path $OutDir "index.html")
    $readmeHref = Get-RelativePathCompat -FromDirectory $currentDir -ToPath (Join-Path $OutDir "README.html")
    $guidesHref = Get-RelativePathCompat -FromDirectory $currentDir -ToPath (Join-Path $OutDir "GUIDES/INDEX.html")
    $generatedHref = Get-RelativePathCompat -FromDirectory $currentDir -ToPath (Join-Path $OutDir "GENERATED/index.html")
    $logoHref = Get-RelativePathCompat -FromDirectory $currentDir -ToPath (Join-Path $OutDir "branding/logo-r-yors.svg")
    return "<div class=`"nav-start`"><a class=`"back-link`" href=`"$homeHref`" onclick=`"if (history.length > 1) { history.back(); return false; }`">Back</a><a class=`"brand`" href=`"$homeHref`"><img class=`"brand-logo`" src=`"$logoHref`" alt=`"R-YORS logo`"><span>R-YORS Docs</span></a></div><nav><a href=`"$readmeHref`">README</a><a href=`"$guidesHref`">Guides</a><a href=`"$generatedHref`">Generated</a></nav>"
}

function Convert-ToHtmlPage {
    param(
        [string]$Title,
        [string]$Body,
        [string]$SourceRelativePath,
        [string]$OutputRelativePath,
        [datetime]$SourceModified,
        [datetime]$GeneratedAt,
        [bool]$HasMermaid
    )

    $currentOutFull = Join-Path $OutDir ($OutputRelativePath -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    $currentDir = Split-Path -Parent $currentOutFull
    $cssHref = Get-RelativePathCompat -FromDirectory $currentDir -ToPath (Join-Path $OutDir "assets/site.css")
    $sourceLabel = Encode-Html $SourceRelativePath
    $sourceModifiedLabel = Encode-Html ($SourceModified.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
    $generatedLabel = Encode-Html ($GeneratedAt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
    $titleHtml = Encode-Html $Title
    $nav = Get-NavHtml -OutputRelativePath $OutputRelativePath
    $mermaidScript = if ($HasMermaid) {
        '  <script type="module">import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs"; mermaid.initialize({ startOnLoad: true, securityLevel: "loose" });</script>'
    } else {
        ""
    }

    return @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$titleHtml - R-YORS Docs</title>
  <link rel="stylesheet" href="$cssHref">
</head>
<body>
  <header class="site-header">$nav</header>
  <main class="doc-page">
$Body
  </main>
  <footer class="site-footer">Generated from <code>$sourceLabel</code>. Source modified: <time>$sourceModifiedLabel</time>. HTML generated: <time>$generatedLabel</time>. Markdown remains canonical.</footer>
$mermaidScript
</body>
</html>
"@
}

$siteCss = @"
:root {
  color-scheme: light;
  --bg: #f7f7f4;
  --page: #ffffff;
  --ink: #181818;
  --muted: #5d625f;
  --line: #d9d7cf;
  --accent: #005f73;
  --code-bg: #111111;
  --code-ink: #eeeeee;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  background: var(--bg);
  color: var(--ink);
  font: 16px/1.55 "Segoe UI", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
}

a { color: var(--accent); }

.site-header {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: .75rem 1.25rem;
  border-bottom: 1px solid var(--line);
  background: rgba(247, 247, 244, .96);
}

.brand {
  display: inline-flex;
  align-items: center;
  gap: .45rem;
  color: var(--ink);
  font-weight: 700;
  text-decoration: none;
}

.brand-logo {
  width: 2rem;
  height: 2rem;
}

.nav-start {
  display: flex;
  align-items: center;
  gap: .85rem;
}

.back-link {
  color: var(--muted);
  text-decoration: none;
}

.back-link:hover {
  color: var(--accent);
}

nav {
  display: flex;
  flex-wrap: wrap;
  gap: .75rem;
}

nav a {
  color: var(--muted);
  text-decoration: none;
}

nav a:hover { color: var(--accent); }

.doc-page {
  width: min(1120px, calc(100vw - 2rem));
  margin: 2rem auto 3rem;
  padding: 2rem;
  border: 1px solid var(--line);
  background: var(--page);
}

h1, h2, h3, h4, h5, h6 {
  line-height: 1.2;
  margin: 1.8em 0 .55em;
}

h1 { margin-top: 0; font-size: 2.1rem; }
h2 { padding-top: .5rem; border-top: 1px solid var(--line); }

p, ul, ol, table, pre, blockquote { margin: 1rem 0; }

li + li { margin-top: .3rem; }

img {
  max-width: 100%;
  height: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: .94rem;
}

th, td {
  padding: .45rem .55rem;
  border: 1px solid var(--line);
  vertical-align: top;
}

th {
  background: #efeee8;
  text-align: left;
}

blockquote {
  padding: .2rem 1rem;
  border-left: 4px solid var(--line);
  color: var(--muted);
}

code {
  padding: .12rem .25rem;
  border-radius: 3px;
  background: #eeeeea;
  font-family: Consolas, "Cascadia Mono", monospace;
  font-size: .94em;
}

pre {
  overflow: auto;
  padding: 1rem;
  border-radius: 6px;
  background: var(--code-bg);
  color: var(--code-ink);
}

pre code {
  padding: 0;
  background: transparent;
  color: inherit;
}

pre.mermaid {
  background: #ffffff;
  color: #181818;
  border: 1px solid var(--line);
}

pre.mermaid svg {
  display: block;
  max-width: 100%;
  height: auto;
  margin: 0 auto;
}

.site-footer {
  width: min(1120px, calc(100vw - 2rem));
  margin: 0 auto 2rem;
  color: var(--muted);
  font-size: .9rem;
}

@media (max-width: 720px) {
  .site-header {
    align-items: flex-start;
    flex-direction: column;
  }

  .doc-page {
    width: 100%;
    margin-top: 0;
    padding: 1rem;
    border-left: 0;
    border-right: 0;
  }
}
"@

if (Test-Path -LiteralPath $OutDir) {
    $marker = Join-Path $OutDir ".generated-by-r-yors"
    if (Test-Path -LiteralPath $marker) {
        Get-ChildItem -LiteralPath $OutDir -Force | Remove-Item -Recurse -Force
    }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Utf8File -Path (Join-Path $OutDir ".generated-by-r-yors") -Text "Generated HTML docs. Do not hand-edit.`n"
Write-Utf8File -Path (Join-Path $OutDir "assets/site.css") -Text $siteCss

$generatedAt = Get-Date

foreach ($source in $MarkdownSources) {
    $sourceRel = Get-RepoRelativePath $source.FullName
    $outRel = $MarkdownOutputBySource[$sourceRel]
    $markdown = [System.IO.File]::ReadAllText($source.FullName)
    $doc = Convert-MarkdownDocument -Markdown $markdown -SourceRelativePath $sourceRel -OutputRelativePath $outRel
    $hasMermaid = $doc.Body.Contains('class="mermaid"')
    $html = Convert-ToHtmlPage -Title $doc.Title -Body $doc.Body -SourceRelativePath $sourceRel -OutputRelativePath $outRel -SourceModified $source.LastWriteTime -GeneratedAt $generatedAt -HasMermaid $hasMermaid
    Write-Utf8File -Path (Join-Path $OutDir ($outRel -replace "/", [System.IO.Path]::DirectorySeparatorChar)) -Text $html
}

$assetRoot = Join-Path $RepoRoot "DOC/branding"
if (Test-Path -LiteralPath $assetRoot) {
    Get-ChildItem -LiteralPath $assetRoot -Recurse -File | ForEach-Object {
        $assetRel = Get-RepoRelativePath $_.FullName
        $assetOutRel = ConvertTo-AssetOutputRelativePath $assetRel
        $assetOut = Join-Path $OutDir ($assetOutRel -replace "/", [System.IO.Path]::DirectorySeparatorChar)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $assetOut) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $assetOut -Force
    }
}

$dirsNeedingIndex = @()
foreach ($source in $MarkdownSources) {
    $rel = Get-RepoRelativePath $source.FullName
    if ($rel.StartsWith("DOC/")) {
        $dir = Normalize-Slash (Split-Path -Parent $rel)
        if (-not [string]::IsNullOrWhiteSpace($dir) -and $dir -ne "DOC" -and $dir -ne "DOC/GUIDES") {
            $dirsNeedingIndex += $dir
        }
    }
}

$dirsNeedingIndex = $dirsNeedingIndex | Sort-Object -Unique
foreach ($dirRel in $dirsNeedingIndex) {
    $indexMdRel = Normalize-Slash (Join-Path $dirRel "INDEX.md")
    if ($MarkdownOutputBySource.ContainsKey($indexMdRel)) {
        continue
    }

    $dirFull = Join-Path $RepoRoot ($dirRel -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    $dirOutRel = Normalize-Slash (Join-Path (ConvertTo-AssetOutputRelativePath $dirRel) "index.html")
    $items = Get-ChildItem -LiteralPath $dirFull -File -Filter "*.md" | Sort-Object Name
    $bodyLines = New-Object System.Collections.Generic.List[string]
    $bodyLines.Add("<h1>$(Encode-Html (Split-Path -Leaf $dirRel))</h1>")
    $bodyLines.Add("<ul>")
    foreach ($item in $items) {
        $itemRel = Get-RepoRelativePath $item.FullName
        $itemOutRel = $MarkdownOutputBySource[$itemRel]
        $dirIndexFull = Join-Path $OutDir ($dirOutRel -replace "/", [System.IO.Path]::DirectorySeparatorChar)
        $itemOutFull = Join-Path $OutDir ($itemOutRel -replace "/", [System.IO.Path]::DirectorySeparatorChar)
        $href = Get-RelativePathCompat -FromDirectory (Split-Path -Parent $dirIndexFull) -ToPath $itemOutFull
        $itemHtml = '<li><a href="{0}">{1}</a></li>' -f @((Encode-Html $href), (Encode-Html $item.Name))
        $bodyLines.Add($itemHtml)
    }
    $bodyLines.Add("</ul>")
    $body = $bodyLines -join "`n"
    $dirModified = ($items | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
    if (-not $dirModified) {
        $dirModified = (Get-Item -LiteralPath $dirFull).LastWriteTime
    }
    $html = Convert-ToHtmlPage -Title (Split-Path -Leaf $dirRel) -Body $body -SourceRelativePath $dirRel -OutputRelativePath $dirOutRel -SourceModified $dirModified -GeneratedAt $generatedAt -HasMermaid $false
    Write-Utf8File -Path (Join-Path $OutDir ($dirOutRel -replace "/", [System.IO.Path]::DirectorySeparatorChar)) -Text $html
}

Write-Host ("Generated HTML docs: {0}" -f $OutDir)
Write-Host ("Markdown pages: {0}" -f (($MarkdownSources | Measure-Object).Count))
