export const meta = {
  name: 'r-verify',
  description: 'Refute-verify /r findings, one agent per code location',
  phases: [{ title: 'Verify' }],
}

// Called by /r step 4 with args {root, mode, exclusions, findings: [{id, file,
// line, claim, scenario, origin}]}. Returns {groups, verdicts: [{id, confidence,
// severity, evidence}]} covering every finding whose agent rendered a verdict;
// the session reports unscored ids as WEAK 25 rather than dropping them.
//
// The rubric is the single source, verbatim: /r no longer carries it, and
// paraphrase is what stops the numbers comparing across runs.
const RUBRIC = `Return, for EACH candidate, two values.

CONFIDENCE that the claim is factually correct, 0-100. Judge only whether it is
true, never whether it matters:
0    Refuted. Does not survive scrutiny, or describes something that is not
     actually the case.
25   Could not verify either way. Might be true; the evidence is absent.
50   Probably true, but one step of the argument is unconfirmed.
75   Verified against the source. You traced it and it holds.
100  Certain. Traced end to end, with the specific evidence quoted.

SEVERITY if the claim is true - high, medium, or low. Judge only the consequence,
never the likelihood of your being right:
high    incorrect behaviour, data loss, a silent wrong result, or a crash
medium  degraded behaviour, a wrong result in a narrow case, real maintenance cost
low     cosmetic, stylistic, or a nit`

const VERDICTS_SCHEMA = {
  type: "object", required: ["verdicts"],
  properties: {
    verdicts: { type: "array", items: {
      type: "object", required: ["index", "confidence", "severity", "evidence"],
      properties: {
        index: { type: "number", description: "the [i] label of the candidate this verdict is for" },
        confidence: { type: "number", minimum: 0, maximum: 100 },
        severity: { enum: ["high", "medium", "low"] },
        evidence: { type: "string" },
      },
    }},
  },
}

// args can arrive as an object or as a JSON-encoded string depending on how
// the Workflow call was made; accept both rather than silently verifying nothing.
let A = args
if (typeof A === "string") {
  try { A = JSON.parse(A) } catch (e) { A = null }
}
if (!A || typeof A !== "object") A = {}
const findings = Array.isArray(A.findings) ? A.findings : []
if (findings.length === 0) {
  return { groups: 0, verdicts: [] }
}
const root = typeof A.root === "string" && A.root ? A.root : "."
const exclusions = typeof A.exclusions === "string" ? A.exclusions : ""

// One refuter per distinct location, judging every candidate there by its [i]
// index. Grouping is not dedup: every candidate keeps its own verdict; it only
// cuts agent count by the cross-reviewer location-collision rate.
const byLoc = Object.create(null)
for (const f of findings) {
  const key = (f.file || "?") + ":" + (f.line != null ? f.line : "-")
  ;(byLoc[key] ||= []).push(f)
}
const groups = Object.values(byLoc)
const inBounds = (i, n) => Number.isInteger(i) && i >= 0 && i < n
const loc = f => (f.file || "?") + (f.line != null ? ":" + f.line : "")

const PROMPT = g =>
  "## Adversarial verifier for a code-review finding\n\n" +
  "Root you may read (strictly read-only; run nothing that mutates state): " + root + "\n" +
  "Review mode: " + (A.mode || "review") + "\n\n" +
  "## Candidates at " + loc(g[0]) + "\n" +
  g.map((f, i) =>
    "[" + i + "] Claim: " + f.claim +
    (f.scenario ? "\n    Scenario: " + f.scenario : "")
  ).join("\n") + "\n\n" +
  "Try to REFUTE each claim against the actual source. Default toward refuted\n" +
  "(low confidence) when you cannot verify. Judge each candidate independently\n" +
  "by its [i] index; candidates at one location may be distinct, duplicates, or\n" +
  "a mix, and each still gets its own verdict.\n\n" +
  RUBRIC + "\n\n" +
  (exclusions
    ? "Score 0 anything that amounts to one of these excluded kinds:\n" + exclusions + "\n\n"
    : "") +
  "Structured output only. Evidence must cite the decisive line(s)."

phase("Verify")
const out = await parallel(groups.map(g => () => {
  const short = String(g[0].file || "?").split("/").pop()
  return agent(PROMPT(g), {
    agentType: "Explore", model: "sonnet",
    label: "verify:" + short + "(" + g.length + ")", phase: "Verify",
    schema: VERDICTS_SCHEMA,
  }).then(r => {
    if (!r) return []
    const byIdx = {}
    for (const v of r.verdicts) if (inBounds(v.index, g.length)) byIdx[v.index] = v
    return g.flatMap((f, i) => byIdx[i]
      ? [{
          id: f.id,
          confidence: Math.max(0, Math.min(100, Math.round(byIdx[i].confidence))),
          severity: byIdx[i].severity,
          evidence: byIdx[i].evidence,
        }]
      : [])
  })
}))

return { groups: groups.length, verdicts: out.filter(Boolean).flat() }
