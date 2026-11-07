import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { URL } from "node:url";
import { readJson, resolveRoot, ensureWithinRoot, isoNow } from "./util.mjs";
import { repositoryPaths } from "./repository.mjs";
import { transitionRecord } from "./queue.mjs";

function json(response, status, body) {
  response.writeHead(status, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
  response.end(JSON.stringify(body));
}

async function readBody(request) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function safeAssetPath(relativePath) {
  if (!relativePath) throw new Error("Asset path is required.");
  const absolute = ensureWithinRoot(resolveRoot(relativePath));
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) throw new Error("Asset was not found.");
  return absolute;
}

function reviewHtml() {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Klimax Saint Portrait Review</title>
<style>
:root{color-scheme:light dark;--gold:#c99a22;--ink:#191712;--paper:#f4efe4;--line:#a98b4d55}
*{box-sizing:border-box}body{margin:0;font:15px system-ui;background:var(--paper);color:var(--ink)}
header{position:sticky;top:0;z-index:2;padding:18px 24px;background:#f4efe4e8;backdrop-filter:blur(18px);border-bottom:1px solid var(--line)}
h1{margin:0 0 10px;font:700 26px Georgia}.filters{display:flex;gap:8px;flex-wrap:wrap}
button,select,input,textarea{font:inherit}.filters button,.action{border:1px solid var(--line);background:#fff9;border-radius:8px;padding:8px 12px}
.filters button.active{background:var(--gold);color:white}main{padding:22px;display:grid;gap:18px}
.record{border:1px solid var(--line);background:#fff8;border-radius:8px;padding:18px}
.summary{display:grid;grid-template-columns:minmax(180px,240px) 1fr;gap:20px}.images{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px}
.image{min-width:0}.image img{width:100%;aspect-ratio:3/4;object-fit:cover;border-radius:6px;background:#ddd}
.label{font-size:12px;color:#756b58;margin:5px 0}.meta{display:grid;grid-template-columns:150px 1fr;gap:5px 10px}
.meta dt{font-weight:700}.meta dd{margin:0;overflow-wrap:anywhere}.actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}
.action.approve{background:#287b4f;color:white}.action.reject{background:#8d302d;color:white}
details{margin-top:12px}pre{white-space:pre-wrap;background:#0001;padding:12px;border-radius:6px;max-height:360px;overflow:auto}
textarea{width:100%;min-height:72px;padding:8px;border-radius:6px;border:1px solid var(--line)}
@media(max-width:700px){.summary{grid-template-columns:1fr}.meta{grid-template-columns:1fr}.meta dt{margin-top:8px}}
</style>
</head>
<body>
<header><h1>Saint portrait review</h1><div id="progress"></div><div class="filters" id="filters"></div></header>
<main id="records"></main>
<script>
const statuses=["ready","missing-source","missing-metadata","generated","qa-review","human-review","rejected","failed","approved"];
let selected="human-review";
const filters=document.getElementById("filters"), records=document.getElementById("records");
for(const status of statuses){const b=document.createElement("button");b.textContent=status;b.onclick=()=>{selected=status;load()};b.dataset.status=status;filters.appendChild(b)}
function image(path,label){return path?\`<div class="image"><div class="label">\${label}</div><img loading="lazy" src="/asset?path=\${encodeURIComponent(path)}"></div>\`:""}
async function action(id,name){const notes=document.querySelector(\`#notes-\${CSS.escape(id)}\`)?.value||"";const response=await fetch(\`/api/records/\${encodeURIComponent(id)}/action\`,{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({action:name,notes})});const body=await response.json();if(!response.ok)alert(body.error);await load()}
async function load(){
 document.querySelectorAll(".filters button").forEach(b=>b.classList.toggle("active",b.dataset.status===selected));
 const response=await fetch("/api/records?status="+encodeURIComponent(selected));const data=await response.json();
 document.getElementById("progress").textContent=\`\${data.progress.approved} approved · \${data.progress.completedProtected} existing protected · \${data.progress.total} total\`;
 records.innerHTML=data.records.map(r=>{
  const attempt=r.attempts?.at(-1);const refs=attempt?.request?.styleReferences||[];
  const candidates=(r.attempts||[]).filter(a=>a.candidatePath);
  return \`<article class="record"><h2>\${r.canonicalName}</h2><div class="summary"><div class="images">
   \${image(r.identitySourceImagePath,"Identity source")}
   \${candidates.map((candidate,index)=>image(candidate.candidatePath,\`Attempt \${index+1} · \${candidate.status}\`)).join("")}
   \${refs.slice(0,3).map((ref,i)=>image(ref.imagePath,\`Style reference \${i+1}\`)).join("")}
  </div><div><dl class="meta">
   <dt>Saint ID</dt><dd>\${r.saintId}</dd><dt>Status</dt><dd>\${r.queueStatus}</dd>
   <dt>Role</dt><dd>\${r.religiousRoleOrCategory||"Review required"}</dd>
   <dt>Required attributes</dt><dd>\${(r.requiredVisualAttributes||[]).join(", ")||"Review required"}</dd>
   <dt>Style</dt><dd>\${r.styleVersion}</dd><dt>Prompt</dt><dd>\${r.generationPromptVersion}</dd>
   <dt>Estimated cost</dt><dd>$\${(attempt?.estimatedCost?.estimatedUsd||0).toFixed(4)}</dd>
   <dt>QA</dt><dd>\${attempt?.qa?.deterministic?.status||"Not run"}</dd>
  </dl><textarea id="notes-\${r.saintId}" placeholder="Reviewer notes"></textarea>
  <div class="actions"><button class="action approve" onclick="action('\${r.saintId}','approve')">Approve</button>
  <button class="action reject" onclick="action('\${r.saintId}','reject')">Reject</button>
  <button class="action" onclick="action('\${r.saintId}','regenerate')">Regenerate</button>
  <button class="action" onclick="action('\${r.saintId}','metadata-incorrect')">Metadata incorrect</button>
  <button class="action" onclick="action('\${r.saintId}','source-unsuitable')">Source unsuitable</button></div>
  <details><summary>Prompt and attempt history</summary><pre>\${JSON.stringify({prompt:attempt?.request?.prompt,qa:attempt?.qa,attempts:r.attempts},null,2)}</pre></details>
  </div></div></article>\`}).join("")||"<p>No records in this filter.</p>";
}
load();
</script></body></html>`;
}

function recordsResponse(status) {
  const manifest = readJson(repositoryPaths.manifest);
  const records = manifest.records.filter((record) => !status || record.queueStatus === status);
  return {
    records,
    progress: {
      total: manifest.records.length,
      approved: manifest.records.filter((record) => record.queueStatus === "approved").length,
      completedProtected: manifest.records.filter((record) => record.portraitStatus === "existing-protected").length
    }
  };
}

function performReviewAction(saintId, action, notes) {
  const manifest = readJson(repositoryPaths.manifest);
  const record = manifest.records.find((entry) => entry.saintId === saintId);
  if (!record) throw new Error("Saint was not found.");
  const attempt = record.attempts?.at(-1);
  const note = notes?.trim() ? { at: isoNow(), text: notes.trim(), action } : null;
  const reviewerNotes = [...(record.reviewerNotes ?? []), ...(note ? [note] : [])];
  if (action === "approve") {
    if (!attempt?.candidatePath) throw new Error("There is no generated candidate to approve.");
    return transitionRecord(saintId, "approved", {
      reason: "human-approved",
      patch: {
        reviewerStatus: "approved",
        reviewerNotes,
        approvedAssetPath: attempt.candidatePath,
        approvedTimestamp: isoNow(),
        portraitStatus: "approved"
      }
    });
  }
  if (action === "reject") {
    return transitionRecord(saintId, "rejected", {
      reason: notes || "human-rejected",
      patch: { reviewerStatus: "rejected", reviewerNotes }
    });
  }
  if (action === "regenerate") {
    if (!notes?.trim()) throw new Error("Regeneration requires reviewer notes.");
    return transitionRecord(saintId, "ready", {
      reason: "regeneration-requested",
      patch: { reviewerStatus: "regenerate", reviewerNotes }
    });
  }
  if (action === "metadata-incorrect") {
    return transitionRecord(saintId, "missing-metadata", {
      reason: notes || "metadata-incorrect",
      patch: { reviewerStatus: "metadata-incorrect", reviewerNotes }
    });
  }
  if (action === "source-unsuitable") {
    return transitionRecord(saintId, "missing-source", {
      reason: notes || "source-unsuitable",
      patch: { reviewerStatus: "source-unsuitable", reviewerNotes }
    });
  }
  throw new Error(`Unknown review action: ${action}`);
}

export function createReviewServer() {
  return http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url, "http://127.0.0.1");
      if (request.method === "GET" && url.pathname === "/") {
        response.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
        response.end(reviewHtml());
        return;
      }
      if (request.method === "GET" && url.pathname === "/asset") {
        const absolutePath = safeAssetPath(url.searchParams.get("path"));
        const extension = path.extname(absolutePath).toLowerCase();
        response.writeHead(200, {
          "content-type": extension === ".webp" ? "image/webp" : extension === ".jpg" || extension === ".jpeg" ? "image/jpeg" : "image/png",
          "cache-control": "private, max-age=60"
        });
        fs.createReadStream(absolutePath).pipe(response);
        return;
      }
      if (request.method === "GET" && url.pathname === "/api/records") {
        json(response, 200, recordsResponse(url.searchParams.get("status")));
        return;
      }
      const match = url.pathname.match(/^\/api\/records\/([^/]+)\/action$/);
      if (request.method === "POST" && match) {
        const body = await readBody(request);
        const result = performReviewAction(decodeURIComponent(match[1]), body.action, body.notes);
        json(response, 200, { ok: true, status: result.record.queueStatus });
        return;
      }
      json(response, 404, { error: "Not found." });
    } catch (error) {
      json(response, 400, { error: error.message });
    }
  });
}

export async function startReviewServer({ port = 4178, host = "127.0.0.1" } = {}) {
  const server = createReviewServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, resolve);
  });
  return server;
}
