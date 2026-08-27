#!/usr/bin/env node
/**
 * Build the GitHub Pages product site from site/ templates + docs/ markdown.
 * Docs markdown remains the source of truth; this only renders HTML copies.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import yaml from "js-yaml";
import { marked } from "marked";
import { gfmHeadingId } from "marked-gfm-heading-id";

marked.use(gfmHeadingId({}));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const SITE_SRC = path.join(ROOT, "site");
const DOCS_SRC = path.join(ROOT, "docs");
const OUT = path.join(ROOT, "_site");

const REPO = "https://github.com/to-ge-da/hermes-self-hosted";
const RAW_BASE = `${REPO}/blob/main`;

/** Project Pages base path; override with SITE_BASE=/ for local preview. */
const SITE_BASE = normalizeBase(process.env.SITE_BASE ?? "/hermes-self-hosted/");

const INSTALL_DOCS = [
  { file: "INSTALLATION.md", title: "Installation", summary: "Ordered self-hosted install path" },
  { file: "BOOTSTRAP.md", title: "Bootstrap", summary: "First-boot host setup" },
  { file: "SSH-KEYS.md", title: "SSH keys", summary: "SSH keys for admin and hermes" },
  { file: "HARDENING.md", title: "Hardening", summary: "Security hardening after bootstrap" },
  { file: "NETWORK.md", title: "Network", summary: "Static IP and DNS" },
  { file: "hermes/install.md", title: "Install Hermes Agent", summary: "Official installer as hermes" },
  { file: "FILE-TRANSFER.md", title: "File transfer", summary: "Copy files to the host" },
  { file: "MISE.md", title: "Mise", summary: "Host mise and pinned tools" },
];

const OTHER_DOCS = [
  { file: "hermes/uninstall.md", title: "Uninstall", summary: "Remove Hermes Agent" },
  { file: "hermes/profile-templates.md", title: "Profile templates", summary: "USER.md / MEMORY.md starters" },
  { file: "hermes/dashboard-service.md", title: "Dashboard service", summary: "Dashboard as a background service" },
  { file: "hermes/gateway-platforms.md", title: "Gateway platforms", summary: "Day 2 — Telegram and SimpleX" },
  { file: "hermes/README.md", title: "Hermes Agent index", summary: "Install, uninstall, dashboard, day-2 platforms, profiles" },
  { file: "forks/README.md", title: "Forks index", summary: "Cursor trees hosted here (not the install path)" },
  { file: "forks/cursor-integration-research.md", title: "Cursor integration research", summary: "Research notes" },
  { file: "forks/testing-custom-forks.md", title: "Testing custom forks", summary: "Fork testing notes" },
  { file: "GITHUB_TEMPLATES.md", title: "GitHub templates", summary: "Issue and PR templates" },
];

const ALL_DOCS = [...INSTALL_DOCS, ...OTHER_DOCS];

function normalizeBase(base) {
  if (!base || base === "/") return "/";
  let b = base.startsWith("/") ? base : `/${base}`;
  if (!b.endsWith("/")) b += "/";
  return b;
}

function href(p) {
  const clean = String(p).replace(/^\//, "");
  if (SITE_BASE === "/") return `/${clean}`;
  return `${SITE_BASE}${clean}`;
}

function asset(p) {
  return href(p);
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function writeFile(filePath, contents) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, contents);
}

function read(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function loadDonations() {
  const raw = read(path.join(SITE_SRC, "donations.yml"));
  const data = yaml.load(raw) || {};
  const bitcoin = typeof data.bitcoin === "string" ? data.bitcoin.trim() : "";
  const monero = typeof data.monero === "string" ? data.monero.trim() : "";
  return { bitcoin, monero };
}

function mdToHtmlPath(relMd) {
  return `docs/${relMd.replace(/\.md$/i, ".html")}`;
}

/** Resolve a relative link from docs/<fromRelMd> to a repo-root relative path. */
function resolveFromDocs(fromRelMd, linkPath) {
  const fromDir = path.posix.dirname(fromRelMd);
  const start = path.posix.join("docs", fromDir === "." ? "" : fromDir);
  const parts = start.split("/").filter(Boolean);
  for (const seg of linkPath.split("/")) {
    if (seg === "..") parts.pop();
    else if (seg !== "." && seg !== "") parts.push(seg);
  }
  return parts.join("/");
}

function rewriteMarkdownHrefs(html, fromRelMd) {
  return html.replace(/href="([^"]+)"/g, (full, target) => {
    if (
      /^(https?:|mailto:|data:|#)/i.test(target) ||
      target.startsWith("//")
    ) {
      return full;
    }

    const hashIdx = target.indexOf("#");
    const pathPart = hashIdx === -1 ? target : target.slice(0, hashIdx);
    const hashSuffix = hashIdx === -1 ? "" : target.slice(hashIdx);
    if (!pathPart) return full;

    const repoRel = resolveFromDocs(fromRelMd, pathPart);

    if (repoRel === "README.md") {
      return `href="${href("")}${hashSuffix}"`;
    }
    if (repoRel === "AGENTS.md") {
      return `href="${RAW_BASE}/AGENTS.md${hashSuffix}"`;
    }

    if (repoRel.startsWith("docs/") && /\.md$/i.test(repoRel)) {
      const underDocs = repoRel.slice("docs/".length);
      return `href="${href(mdToHtmlPath(underDocs))}${hashSuffix}"`;
    }

    // scripts/, config/, templates/, or anything else → GitHub
    return `href="${RAW_BASE}/${repoRel}${hashSuffix}"`;
  });
}

function layout({ title, description, active, body, path: pagePath }) {
  const fullTitle = title === "Hermes Self-Hosted" ? title : `${title} · Hermes Self-Hosted`;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(fullTitle)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <link rel="canonical" href="${href(pagePath)}">
  <meta name="color-scheme" content="dark">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=Spline+Sans:wght@400;500;600&family=Syne:wght@600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${asset("assets/css/site.css")}">
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <header class="site-header">
    <div class="wrap nav">
      <a class="brand" href="${href("")}">
        <span class="brand-mark" aria-hidden="true"></span>
        <span class="brand-name">Hermes Self-Hosted</span>
      </a>
      <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="site-nav">Menu</button>
      <ul class="nav-links" id="site-nav">
        <li><a href="${href("")}"${active === "home" ? ' aria-current="page"' : ""}>Home</a></li>
        <li><a href="${href("docs/")}"${active === "docs" ? ' aria-current="page"' : ""}>Docs</a></li>
        <li><a href="${href("host.html")}"${active === "host" ? ' aria-current="page"' : ""}>Get a host</a></li>
        <li><a href="${href("")}#donate">Donate</a></li>
        <li><a href="${REPO}">GitHub</a></li>
      </ul>
    </div>
  </header>
  <main id="main">
${body}
  </main>
  <footer class="site-footer">
    <div class="wrap">
      <p>Early-stage. One Hermes Agent instance on Debian — local machine or local VM.</p>
      <div class="footer-links">
        <a href="${href("docs/INSTALLATION.html")}">Install path</a>
        <a href="${href("host.html")}">Host interest</a>
        <a href="${href("")}#donate">Donate</a>
        <a href="${REPO}">Repository</a>
      </div>
    </div>
  </footer>
  <script src="${asset("assets/js/site.js")}" defer></script>
</body>
</html>
`;
}

function renderDonationsSection(donations) {
  const coins = [];
  if (donations.bitcoin) {
    coins.push({ id: "btc", label: "Bitcoin", address: donations.bitcoin });
  }
  if (donations.monero) {
    coins.push({ id: "xmr", label: "Monero (XMR)", address: donations.monero });
  }

  let body;
  if (coins.length === 0) {
    body = `<p class="donate-empty">BTC and XMR addresses are not published yet. When the owner adds them in <code>site/donations.yml</code>, they will show here with one-click copy.</p>`;
  } else {
    body = `<div class="donate-list">
${coins
  .map(
    (c) => `      <div class="donate-row">
        <div class="donate-label">${escapeHtml(c.label)}</div>
        <p class="donate-address" id="addr-${c.id}">${escapeHtml(c.address)}</p>
        <button type="button" class="btn-copy" data-copy="${escapeHtml(c.address)}" aria-label="Copy ${escapeHtml(c.label)} address">Copy</button>
      </div>`
  )
  .join("\n")}
    </div>`;
  }

  return `    <section class="section" id="donate">
      <div class="wrap">
        <div class="section-head">
          <p class="eyebrow">Support</p>
          <h2>Donations</h2>
          <p>No pricing on the preinstalled host yet. If this work helps you, Bitcoin and Monero are welcome.</p>
        </div>
        <p class="donate-note">No payment processor. Send only to the addresses shown below.</p>
${body}
      </div>
    </section>`;
}

function buildHome(donations) {
  const body = `
    <section class="hero">
      <div class="hero-plane" aria-hidden="true"></div>
      <div class="wrap hero-copy">
        <p class="hero-brand">Hermes <span>Self-Hosted</span></p>
        <h1>One Debian host. One Hermes Agent. An ordered path to get there.</h1>
        <p class="hero-lead">Bootstrap, harden, and install the official Nous Research agent on a local machine or local VM. Early-stage — not a finished platform product.</p>
        <div class="btn-row">
          <a class="btn btn-primary" href="${href("docs/INSTALLATION.html")}">DIY install docs</a>
          <a class="btn btn-ghost" href="${href("host.html")}">Get a host with Hermes</a>
        </div>
      </div>
      <div class="hero-terminal" aria-hidden="true">
        <div><span class="ok">✓</span> mise host tools</div>
        <div><span class="ok">✓</span> bootstrap · hermes user</div>
        <div><span class="ok">✓</span> hardening · key-only SSH</div>
        <div><span class="cmd">$</span> hermes gateway status</div>
        <div class="ok">active (running)</div>
      </div>
    </section>

    <section class="section" id="paths">
      <div class="wrap">
        <div class="section-head">
          <p class="eyebrow">Two ways in</p>
          <h2>Install it yourself, or ask about a ready host</h2>
          <p>Same stack either way: Debian, OpenRouter for models, one instance per machine.</p>
        </div>
        <div class="path-grid">
          <article class="path">
            <p class="path-kicker">DIY</p>
            <h3>Follow the install path</h3>
            <p>Use the repo scripts and docs on your own Debian host. The markdown in <code>docs/</code> is the source of truth — mirrored here, not rewritten into marketing.</p>
            <a class="btn btn-primary" href="${href("docs/INSTALLATION.html")}">Start with INSTALLATION</a>
          </article>
          <article class="path">
            <p class="path-kicker">Host</p>
            <h3>A machine with Hermes already on it</h3>
            <p>Interest list only — no shop and no price list yet. Say what you need; donations are the money path that exists today.</p>
            <a class="btn btn-ghost" href="${href("host.html")}">Register interest</a>
          </article>
        </div>
      </div>
    </section>

    <section class="section" id="scope">
      <div class="wrap">
        <div class="section-head">
          <p class="eyebrow">Honest scope</p>
          <h2>What this repo covers today</h2>
          <p>Trust the docs over the pitch. If it is not in the install path, it is not claimed here.</p>
        </div>
        <div class="scope-list">
          <div class="scope in">
            <h3>Covered</h3>
            <ul>
              <li>Fresh Debian Server, local machine or local VM</li>
              <li>Bootstrap (YAML config, hermes user, linger)</li>
              <li>Hardening, SSH keys, static network</li>
              <li>mise host tools, Playwright OS libs</li>
              <li>Official Hermes installer, gateway user unit, dashboard service</li>
              <li>Models via OpenRouter (external API)</li>
            </ul>
          </div>
          <div class="scope out">
            <h3>Not covered yet</h3>
            <ul>
              <li>VPS and Amazon EC2 runbooks</li>
              <li>Multi-instance on one host</li>
              <li>Local model inference</li>
              <li>A finished commercial storefront</li>
            </ul>
          </div>
        </div>
      </div>
    </section>

    <section class="section" id="path">
      <div class="wrap">
        <div class="section-head">
          <p class="eyebrow">Install path</p>
          <h2>The ordered steps on a fresh VM</h2>
          <p>Detail pages live under Docs. Linked guides expand a step — they are not a second checklist.</p>
        </div>
        <ol class="steps">
          <li><div><strong>Clone the repo</strong><span>On the host, with git and curl available.</span></div></li>
          <li><div><strong>Mise host tools</strong><span>System-wide mise + pinned yq.</span></div></li>
          <li><div><strong>Bootstrap</strong><span>YAML config → hermes user, packages, SSH key, linger.</span></div></li>
          <li><div><strong>Hardening</strong><span>Recommended; reboot; key-only SSH afterward.</span></div></li>
          <li><div><strong>Network</strong><span>Static IP / DNS as needed.</span></div></li>
          <li><div><strong>Install Hermes Agent</strong><span>Official installer as the hermes user.</span></div></li>
          <li><div><strong>Playwright libs + gateway</strong><span>OS deps, then gateway user unit.</span></div></li>
        </ol>
        <p style="margin-top:1.5rem"><a class="btn btn-ghost" href="${href("docs/")}">Browse all docs</a></p>
      </div>
    </section>

${renderDonationsSection(donations)}
`;

  return layout({
    title: "Hermes Self-Hosted",
    description:
      "Prepare a Debian host and install one Hermes Agent instance. DIY docs or register interest in a preinstalled host.",
    active: "home",
    path: "",
    body,
  });
}

function buildHostPage(donations) {
  const issueUrl = `${REPO}/issues/new?labels=task&title=${encodeURIComponent("[host interest] Preinstalled Hermes host")}`;
  const body = `
    <section class="section" style="border-bottom:0;padding-bottom:2rem">
      <div class="wrap">
        <div class="section-head">
          <p class="eyebrow">Paid SKU · early</p>
          <h2>A host with Hermes already installed</h2>
          <p>Same scope as the DIY path: one instance, Debian, local-style deployment. Pricing is not published yet — this page is interest and contact only.</p>
        </div>
        <div class="contact-panel">
          <p>Tell the owner what you need (region, whether you bring hardware, timeline). No checkout, no invented price.</p>
          <p><a class="btn btn-primary" href="${issueUrl}">Open a GitHub interest issue</a></p>
          <p class="contact-alt">Prefer email once addresses are public, or support the project via <a href="${href("")}#donate">donations</a> (Bitcoin / Monero) — that is the money path available today.</p>
        </div>
      </div>
    </section>
${renderDonationsSection(donations)}
`;

  return layout({
    title: "Get a host",
    description: "Register interest in a Debian host with Hermes Agent preinstalled. No pricing yet — donations welcome.",
    active: "host",
    path: "host.html",
    body,
  });
}

function docsNavHtml(currentRel) {
  const group = (label, items) => {
    const lis = items
      .map((d) => {
        const p = mdToHtmlPath(d.file);
        const cur = d.file === currentRel ? ' aria-current="page"' : "";
        return `        <li><a href="${href(p)}"${cur}>${escapeHtml(d.title)}</a></li>`;
      })
      .join("\n");
    return `      <h2>${label}</h2>\n      <ul>\n${lis}\n      </ul>`;
  };

  return `<aside class="docs-nav" aria-label="Documentation">
      <p style="margin:0 0 1rem"><a href="${href("docs/")}">Docs home</a></p>
${group("Install path", INSTALL_DOCS)}
${group("Other", OTHER_DOCS)}
    </aside>`;
}

function buildDocsIndex() {
  const item = (d) =>
    `        <li><a href="${href(mdToHtmlPath(d.file))}"><span class="docs-index-title">${escapeHtml(d.title)}</span><span class="docs-index-path">${escapeHtml(d.file)} — ${escapeHtml(d.summary)}</span></a></li>`;

  const body = `
    <div class="wrap docs-layout">
${docsNavHtml("")}
      <div class="doc-article">
        <p class="eyebrow">Documentation</p>
        <h1>Install docs</h1>
        <p class="donate-note">Rendered from the repo’s <code>docs/</code> markdown. Edit the <code>.md</code> files — not these HTML pages — when the procedure changes.</p>
        <h2>Ordered install path</h2>
        <ul class="docs-index-list">
${INSTALL_DOCS.map(item).join("\n")}
        </ul>
        <h2>Other docs</h2>
        <ul class="docs-index-list">
${OTHER_DOCS.map(item).join("\n")}
        </ul>
      </div>
    </div>`;

  return layout({
    title: "Docs",
    description: "Hermes Self-Hosted install documentation, rendered from the repository markdown.",
    active: "docs",
    path: "docs/",
    body,
  });
}

function buildDocPage(relMd, title) {
  const srcPath = path.join(DOCS_SRC, relMd);
  const md = read(srcPath);
  let html = marked.parse(md, { async: false });
  html = rewriteMarkdownHrefs(html, relMd);

  const body = `
    <div class="wrap docs-layout">
${docsNavHtml(relMd)}
      <article class="doc-article prose">
        <p class="doc-meta">Source: <a href="${RAW_BASE}/docs/${relMd}">docs/${escapeHtml(relMd)}</a></p>
${html}
      </article>
    </div>`;

  return layout({
    title,
    description: `${title} — Hermes Self-Hosted documentation.`,
    active: "docs",
    path: mdToHtmlPath(relMd),
    body,
  });
}

function copyAssets() {
  const cssSrc = path.join(SITE_SRC, "assets/css/site.css");
  const jsSrc = path.join(SITE_SRC, "assets/js/site.js");
  writeFile(path.join(OUT, "assets/css/site.css"), read(cssSrc));
  writeFile(path.join(OUT, "assets/js/site.js"), read(jsSrc));
}

function cleanOut() {
  fs.rmSync(OUT, { recursive: true, force: true });
  ensureDir(OUT);
}

function main() {
  cleanOut();
  const donations = loadDonations();

  writeFile(path.join(OUT, "index.html"), buildHome(donations));
  writeFile(path.join(OUT, "host.html"), buildHostPage(donations));
  writeFile(path.join(OUT, "docs/index.html"), buildDocsIndex());

  for (const doc of ALL_DOCS) {
    const outRel = mdToHtmlPath(doc.file);
    writeFile(path.join(OUT, outRel), buildDocPage(doc.file, doc.title));
  }

  copyAssets();

  // GitHub Pages: avoid Jekyll processing of the uploaded artifact
  writeFile(path.join(OUT, ".nojekyll"), "");

  console.log(`Built ${OUT} (base=${SITE_BASE})`);
  console.log(
    `Donations: btc=${donations.bitcoin ? "set" : "empty"} xmr=${donations.monero ? "set" : "empty"}`
  );
}

main();
