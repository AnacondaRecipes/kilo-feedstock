// Collect licence notices for everything the kilo executable embeds, into
// $SRC_DIR/third-party-licenses (meta.yaml license_file):
//
//   bun/  the notices of the conda bun build the executable is made from,
//         copied from that package's info/licenses (the executable is bun with
//         the bundle appended).
//   npm/  the compiled-in npm closure, taken from upstream's own SBOM graph
//         (packages/opencode/script/kilocode/sbom.ts: CLI + console workspaces
//         from bun.lock), one directory per package with its licence files,
//         plus MANIFEST.tsv listing every package and its declared licence.
//
// Fails if a package declares a licence not covered by meta.yaml's `license`
// expression, so a version bump that adds one has to update the recipe.
//
// usage: bun collect-licenses.ts <target>   (linux-x64, darwin-arm64, windows-x64, ...)
import fs from "node:fs"
import path from "node:path"
import { pathToFileURL } from "node:url"

const target = process.argv[2]
if (!target) throw new Error("usage: collect-licenses.ts <target>")
const src = process.env.SRC_DIR!
const buildPrefix = process.env.BUILD_PREFIX!
const out = path.join(src, "third-party-licenses")

// npm `license` values -> the SPDX terms used in meta.yaml.
const COVERED: Record<string, string> = {
  "MIT": "MIT",
  "ISC": "ISC",
  "Apache-2.0": "Apache-2.0",
  "apache-2.0": "Apache-2.0",
  "BSD-2-Clause": "BSD-2-Clause",
  "BSD-3-Clause": "BSD-3-Clause",
  "BSD": "BSD-2-Clause", // duck: 2-clause text
  "BlueOak-1.0.0": "BlueOak-1.0.0",
  "Unlicense": "Unlicense",
  "0BSD": "0BSD",
  "CC0-1.0": "CC0-1.0",
  "CC-BY-3.0": "CC-BY-3.0",
  "CC-BY-4.0": "CC-BY-4.0",
  "(MIT AND Zlib)": "MIT AND Zlib",
  "(AFL-2.1 OR BSD-3-Clause)": "(AFL-2.1 OR BSD-3-Clause)",
  "(MPL-2.0 OR Apache-2.0)": "(MPL-2.0 OR Apache-2.0)",
  "(MIT OR GPL-3.0-or-later)": "(MIT OR GPL-3.0-or-later)",
  "(MIT OR CC0-1.0)": "(MIT OR CC0-1.0)",
  "(BSD-3-Clause OR GPL-2.0)": "(BSD-3-Clause OR GPL-2.0-only)",
}
// Packages that declare no licence; checked by hand. Notice files: khroma ships
// its own; openauth's comes from a pinned source (meta.yaml).
const UNDECLARED: Record<string, string> = {
  "khroma": "MIT",
  "@openauthjs/openauth": "MIT",
}
const NOTICE = /^(licen[cs]e|copying|notice|patents|authors)/i

fs.rmSync(out, { recursive: true, force: true })

// --- bun: notices of the exact conda bun build in the build env ------------
const meta = path.join(buildPrefix, "conda-meta")
const bunMeta = fs.readdirSync(meta).find((f) => /^bun-\d.*\.json$/.test(f))
if (!bunMeta) throw new Error(`no bun package in ${meta}`)
const pkgDir = JSON.parse(fs.readFileSync(path.join(meta, bunMeta), "utf8")).extracted_package_dir
const bunLicenses = path.join(pkgDir ?? "", "info", "licenses")
if (!pkgDir || !fs.existsSync(bunLicenses)) throw new Error(`bun licences not found (${bunLicenses})`)
fs.cpSync(bunLicenses, path.join(out, "bun"), { recursive: true })

// --- npm: upstream's SBOM closure for this target --------------------------
const sbom = await import(pathToFileURL(path.join(src, "packages/opencode/script/kilocode/sbom.ts")).href)
const graph = await sbom.graph({ target: sbom.target(`@kilocode/cli-${target}`), subject: "pkg:generic/kilo" })

// Installed package directories: bun's isolated linker keeps each package at
// node_modules/.bun/<name with / as +>@<version>[+hash]/node_modules/<name>.
const store = path.join(src, "node_modules", ".bun")
const entries = fs.existsSync(store) ? fs.readdirSync(store) : []
function locate(name: string, version: string): string | undefined {
  const prefix = `${name.replace("/", "+")}@${version}`
  for (const e of entries) {
    if (e !== prefix && !e.startsWith(prefix + "+")) continue
    const dir = path.join(store, e, "node_modules", name)
    if (fs.existsSync(path.join(dir, "package.json"))) return dir
  }
  const hoisted = path.join(src, "node_modules", name)
  try {
    if (JSON.parse(fs.readFileSync(path.join(hoisted, "package.json"), "utf8")).version === version) return hoisted
  } catch {}
}

const seen = new Set<string>()
const rows: string[] = ["package\tversion\tlicense\tnotice_files"]
const uncovered: string[] = []
let copied = 0
let absent = 0
for (const c of graph.components) {
  if (!c.purl?.startsWith("pkg:npm") || c.delivery !== "contained") continue
  const id = `${c.name}@${c.version}`
  if (seen.has(id)) continue
  seen.add(id)
  const dir = locate(c.name, c.version)
  // Optional platform packages for other targets/libcs are in the closure but
  // not installed here, so they are not in this executable.
  if (!dir) {
    absent++
    continue
  }
  let license = (c.licenses ?? []).join(" AND ")
  if (!license) {
    license = UNDECLARED[c.name] ?? ""
    if (!license) uncovered.push(`${id}: no licence declared`)
  } else {
    for (const l of c.licenses) if (!(l in COVERED)) uncovered.push(`${id}: ${l}`)
    license = c.licenses.map((l: string) => COVERED[l] ?? l).join(" AND ")
  }
  const files = fs.readdirSync(dir).filter((f) => NOTICE.test(f) && fs.statSync(path.join(dir, f)).isFile())
  if (files.length) {
    const dest = path.join(out, "npm", id.replace(/^@/, "").replace("/", "__"))
    fs.mkdirSync(dest, { recursive: true })
    for (const f of files) fs.copyFileSync(path.join(dir, f), path.join(dest, f))
    copied++
  }
  rows.push([c.name, c.version, license, files.join(" ")].join("\t"))
}
if (uncovered.length) {
  throw new Error(
    "licences not covered by meta.yaml (update `license` and COVERED in collect-licenses.ts):\n  " +
      uncovered.join("\n  "),
  )
}
fs.mkdirSync(path.join(out, "npm"), { recursive: true })
fs.writeFileSync(path.join(out, "npm", "MANIFEST.tsv"), rows.join("\n") + "\n")
console.log(
  `collect-licenses: bun ${fs.readdirSync(path.join(out, "bun"), { recursive: true }).length} entries; ` +
    `npm ${rows.length - 1} packages (${copied} with notice files, ${absent} not installed for ${target})`,
)
