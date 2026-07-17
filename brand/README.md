# Personal OS brand system

One visual identity for every OS page: infra today, health and whatever else
tomorrow. Each page is a standing source of truth, updated in place, never a
temporary project doc.

## How to start a new page

Copy `brand/skeleton.html` into a new folder (for example `health/index.html`),
keep the `<link rel="stylesheet" href="../brand/os.css">`, and build with the
components below. Page specific styles stay inline in that page.

## Voice and rules

- Light mode only. Calm, precise, aerospace minimalism.
- Geist for text, Geist Mono for data, paths, labels, and eyebrows.
- Never use em dashes or en dashes in copy. Commas, colons, periods.
- Every page opens with the mono eyebrow pair: `PERSONAL OS / <PAGE> 00N`
  on the left, the repo path on the right.
- Status is a colored dot plus plain words, never color alone:
  green `--go`, amber `--hold`, red `--stop`.
- Numbers, addresses, commands: always mono.
- Sections are separated by a dark hairline with a title left and a mono
  section code right (for example `FLT / INVENTORY`).

## Tokens

| Token | Value | Use |
|---|---|---|
| --paper | #FAFAF8 | page background |
| --panel | #FFFFFF | cards, framed content |
| --ink | #101014 | primary text |
| --muted | #71717A | secondary text |
| --faint | #A1A1AA | ghosted, tertiary |
| --line | #E5E5E1 | hairlines |
| --line-dark | #18181B | structural rules |
| --go / --hold / --stop | #17803D / #A16207 / #B3261E | status |

## Components in os.css

`header` + `.mast-top` + `h1` + `.mast-sub` (masthead), `.strip` (stat strip
with optional `.bar` progress), `section` + `.sec-head` (ruled sections),
`table` (inventory style), `.cols` (two column split), `.card` (framed box
with `::` bullet list), `.dot` (status), `.eyebrow`, `.mono`, `footer`.

Diagrams: inline SVG, thin strokes, mono labels, dashed for planned or
ghosted, animated dash flow for live links (respect reduced motion). See the
topology schematic in `dashboard/index.html` for the reference example.
