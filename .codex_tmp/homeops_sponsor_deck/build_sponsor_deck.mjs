import fs from "node:fs/promises";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const ROOT = "C:/Users/User/Documents/Codex/2026-06-16/rental management/rental_facility_management";
const TMP = `${ROOT}/.codex_tmp/homeops_sponsor_deck`;
const OUT = `${ROOT}/HomeOps360_Sponsor_Presentation.pptx`;
const LOGO = `${ROOT}/web/icons/Icon-512.png`;
const RENDER = `${TMP}/rendered`;
const LAYOUT = `${TMP}/layout`;

const C = {
  bg: "#F6F9FC",
  white: "#FFFFFF",
  navy: "#0E1B33",
  navy2: "#172945",
  teal: "#10C8B0",
  tealPale: "#DDF8F4",
  blue: "#2E6BFF",
  bluePale: "#E7EFFF",
  ink: "#0E1B33",
  muted: "#54617A",
  rule: "#D7E0EB",
  soft: "#EDF2F7",
  orange: "#FFB45C",
};

async function writeBlob(path, blob) {
  await fs.writeFile(path, new Uint8Array(await blob.arrayBuffer()));
}

function rect(slide, name, x, y, w, h, fill, line = "none", radius = null) {
  const shape = slide.shapes.add({
    geometry: radius ? "roundRect" : "rect",
    name,
    position: { left: x, top: y, width: w, height: h },
    fill,
    line: { style: "solid", fill: line, width: line === "none" ? 0 : 1 },
    ...(radius ? { borderRadius: radius } : {}),
  });
  return shape;
}

function circle(slide, name, x, y, d, fill, line = "none") {
  return slide.shapes.add({
    geometry: "ellipse",
    name,
    position: { left: x, top: y, width: d, height: d },
    fill,
    line: { style: "solid", fill: line, width: line === "none" ? 0 : 1 },
  });
}

function line(slide, name, x, y, w, h, fill) {
  return rect(slide, name, x, y, w, h, fill);
}

function text(slide, name, value, x, y, w, h, options = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    name,
    position: { left: x, top: y, width: w, height: h },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = value;
  shape.text.style = {
    fontSize: options.fontSize ?? 21.33,
    typeface: options.typeface ?? "Aptos",
    color: options.color ?? C.ink,
    bold: options.bold ?? false,
    alignment: options.align ?? "left",
    verticalAlignment: options.valign ?? "top",
    autoFit: "none",
    wrap: "square",
  };
  return shape;
}

async function brand(slide, page, onDark = false, label = "SPONSOR PRESENTATION") {
  const logo = await fs.readFile(LOGO);
  slide.images.add({
    blob: logo,
    contentType: "image/png",
    alt: "HomeOps360 brand mark",
    fit: "contain",
    position: { left: 56, top: 34, width: 34, height: 34 },
  });
  text(slide, `brand-${page}`, "HomeOps", 100, 36, 108, 31, { fontSize: 20, bold: true, typeface: "Aptos Display", color: onDark ? C.white : C.navy });
  text(slide, `brand360-${page}`, "360", 206, 36, 64, 31, { fontSize: 20, bold: true, typeface: "Aptos Display", color: C.teal });
  text(slide, `section-${page}`, label, 850, 42, 374, 18, { fontSize: 12, bold: true, color: onDark ? "#B8C7DD" : C.muted, align: "right" });
  text(slide, `page-${page}`, String(page).padStart(2, "0"), 1170, 682, 54, 18, { fontSize: 11, color: onDark ? "#8FA4C3" : "#8290A6", align: "right" });
}

function titleBlock(slide, titleValue, subtitleValue = "") {
  text(slide, "slide-title", titleValue, 56, 100, 1168, 66, { fontSize: 46.67, bold: true, typeface: "Aptos Display" });
  if (subtitleValue) text(slide, "slide-subtitle", subtitleValue, 56, 174, 1168, 34, { fontSize: 21.33, color: C.muted });
}

function notes(slide, body, extraSources = []) {
  const sources = [
    "README.md (owner and tenant workflows)",
    "lib/branding/homeops_brand.dart (brand identity)",
    ...extraSources,
  ];
  slide.speakerNotes.textFrame.setText(`[Sources]\n${sources.map((source) => `- ${source}`).join("\n")}\n[/Sources]\n\n${body}`);
}

async function slide1(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.navy;
  rect(slide, "cover-blue", 0, 0, 1280, 10, C.blue);
  rect(slide, "cover-teal", 0, 10, 560, 10, C.teal);
  await brand(slide, 1, true, "SPONSOR PRESENTATION");
  text(slide, "cover-title", "Sponsor the pilot that proves HomeOps360 at portfolio scale", 72, 172, 1060, 190, { fontSize: 66.67, bold: true, typeface: "Aptos Display", color: C.white });
  text(slide, "cover-subtitle", "A focused path from working product to validated recurring business.", 76, 392, 880, 40, { fontSize: 26.67, color: "#C7D4E8" });
  line(slide, "cover-rule", 76, 489, 140, 5, C.teal);
  text(slide, "cover-meta", "HOMEOPS360  /  PILOT SPONSORSHIP  /  2026", 76, 520, 620, 24, { fontSize: 14, bold: true, color: "#8FA4C3" });
  notes(slide, "Opening: ask the sponsor to evaluate a scoped pilot—not a blind scale-up. The deck uses only repository-backed product capabilities and labels proposed commercial structures as proposals.");
}

async function slide2(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.bg;
  await brand(slide, 2, false, "THE PROBLEM");
  titleBlock(slide, "Rental operations repeat work across disconnected tools", "The pain is recurring, operational and visible every month.");
  text(slide, "problem-claim", "Teams reconcile the same information by hand—then repeat it for every property and tenant.", 70, 262, 530, 210, { fontSize: 38, bold: true, typeface: "Aptos Display" });
  line(slide, "problem-accent", 70, 505, 110, 6, C.teal);
  text(slide, "problem-meaning", "That limits portfolio scale and turns tenant service into follow-up work.", 70, 528, 500, 70, { fontSize: 21.33, color: C.muted });

  const bands = [
    ["01", "Money", "Rent, utilities, expenses and payment proof sit in separate steps.", C.tealPale, C.teal],
    ["02", "Operations", "Bills, reminders, approvals, documents and reports require repeated admin.", C.bluePale, C.blue],
    ["03", "Experience", "Requests and status updates scatter across messages and channels.", C.soft, C.navy],
  ];
  bands.forEach(([n, heading, body, fill, accent], i) => {
    const y = 250 + i * 132;
    rect(slide, `problem-band-${i}`, 660, y, 564, 108, fill);
    rect(slide, `problem-band-accent-${i}`, 660, y, 8, 108, accent);
    text(slide, `problem-num-${i}`, n, 690, y + 22, 48, 28, { fontSize: 16, bold: true, color: accent });
    text(slide, `problem-head-${i}`, heading, 750, y + 18, 170, 32, { fontSize: 25, bold: true, typeface: "Aptos Display" });
    text(slide, `problem-body-${i}`, body, 750, y + 54, 430, 46, { fontSize: 18.67, color: C.muted });
  });
  notes(slide, "The problem framing is qualitative and grounded in the recurring owner, billing, payment-proof, utility and tenant-service workflows implemented in the repository.", ["lib/rentflow/rentflow_app.dart and related modules (owner workflows)"]);
}

async function slide3(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.white;
  await brand(slide, 3, false, "THE SOLUTION");
  titleBlock(slide, "HomeOps360 connects the full rental lifecycle", "One operating layer links portfolio control, monthly billing, tenant service and room discovery.");

  // Direction arrows are deliberately created before the lifecycle nodes.
  [262, 486, 710, 934].forEach((x, i) => text(slide, `flow-arrow-${i}`, "→", x, 360, 60, 60, { fontSize: 38, color: "#9AA8BB", align: "center" }));
  const nodes = [
    ["SET UP", "Properties\n& tenancies", C.tealPale, C.teal],
    ["BILL", "Rent, utilities\n& expenses", C.bluePale, C.blue],
    ["COLLECT", "Proof, approvals\n& records", C.navy, C.teal],
    ["SERVE", "Requests, status\n& documents", C.soft, C.navy],
    ["EXPAND", "Reports, listings\n& new units", C.tealPale, C.teal],
  ];
  nodes.forEach(([label, body, fill, accent], i) => {
    const x = 56 + i * 224;
    rect(slide, `flow-node-${i}`, x, 280, 190, 260, fill);
    rect(slide, `flow-top-${i}`, x, 280, 190, 7, accent);
    text(slide, `flow-label-${i}`, label, x + 22, 315, 145, 24, { fontSize: 14, bold: true, color: fill === C.navy ? "#B8C7DD" : C.muted });
    text(slide, `flow-body-${i}`, body, x + 22, 365, 150, 85, { fontSize: 25, bold: true, typeface: "Aptos Display", color: fill === C.navy ? C.white : C.navy });
  });
  rect(slide, "flow-outcome", 56, 590, 1168, 64, C.navy);
  text(slide, "flow-outcome-label", "SPONSOR TAKEAWAY", 82, 611, 210, 18, { fontSize: 12, bold: true, color: C.teal });
  text(slide, "flow-outcome-copy", "The product sits inside work that repeats—creating a natural retention loop.", 308, 603, 850, 30, { fontSize: 22, bold: true, color: C.white });
  notes(slide, "The lifecycle synthesizes actual product areas: facilities/tenancies, rent and utilities, payment proof and approvals, tenant requests/documents, reporting and Explore listings.", ["lib/explore/room_explore.dart (room marketplace)", "lib/cloud/* (invoice, OCR, auth, listings, workspace and invitation services)"]);
}

async function slide4(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.bg;
  await brand(slide, 4, false, "PRODUCT FOOTPRINT");
  titleBlock(slide, "The product already covers the critical operating loop", "Four connected experiences work from the same rental data.");

  // Relationship lines are created before the nodes so they sit behind labels.
  line(slide, "hub-line-left", 265, 390, 350, 3, C.rule);
  line(slide, "hub-line-right", 665, 390, 350, 3, C.rule);
  line(slide, "hub-line-up", 638, 255, 3, 120, C.rule);
  line(slide, "hub-line-down", 638, 455, 3, 120, C.rule);

  circle(slide, "hub", 500, 300, 280, C.navy);
  text(slide, "hub-title", "HomeOps360", 540, 350, 200, 38, { fontSize: 29, bold: true, typeface: "Aptos Display", color: C.white, align: "center" });
  text(slide, "hub-sub", "shared operating layer", 540, 397, 200, 28, { fontSize: 17.33, color: "#B8C7DD", align: "center" });

  const satellites = [
    [70, 315, 250, 150, "OWNER APP", "Portfolio, billing, approvals and reporting", C.tealPale, C.teal],
    [960, 315, 250, 150, "TENANT PORTAL", "Bills, payment proof, requests and status", C.bluePale, C.blue],
    [515, 205, 250, 92, "ADMINISTRATION", "Limits and controls", C.white, C.navy],
    [515, 505, 250, 110, "EXPLORE", "Verified room discovery\nand promotion", C.white, C.teal],
  ];
  satellites.forEach(([x, y, w, h, heading, body, fill, accent], i) => {
    rect(slide, `sat-${i}`, x, y, w, h, fill, C.rule);
    rect(slide, `sat-accent-${i}`, x, y, 7, h, accent);
    text(slide, `sat-head-${i}`, heading, x + 26, y + 22, w - 48, 24, { fontSize: 14, bold: true, color: accent });
    text(slide, `sat-body-${i}`, body, x + 26, y + 56, w - 48, h - 58, { fontSize: 17.33, color: C.muted });
  });
  notes(slide, "This is a product-capability map, not a future-state mock-up. Each satellite corresponds to implemented modules in the repository.", ["lib/admin/admin_app.dart and docs/admin-portal-deployment.md (administration)", "lib/explore/room_explore.dart (Explore)"]);
}

async function slide5(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.white;
  await brand(slide, 5, false, "STAKEHOLDER VALUE");
  titleBlock(slide, "Every stakeholder gets a clearer outcome", "The sponsor is not funding another dashboard—it is funding better operating behavior.");

  const cols = [
    ["OWNERS", "O", C.teal, "Control more units\nwith less admin"],
    ["PROPERTY AGENTS", "A", C.blue, "Standardise repeatable\nportfolio work"],
    ["TENANTS", "T", C.navy, "Understand what is due\nand what happens next"],
  ];
  cols.forEach(([heading, initial, color, promise], i) => {
    const x = 290 + i * 310;
    circle(slide, `stake-circle-${i}`, x, 240, 54, color);
    text(slide, `stake-initial-${i}`, initial, x, 251, 54, 32, { fontSize: 23, bold: true, color: C.white, align: "center" });
    text(slide, `stake-head-${i}`, heading, x + 72, 244, 210, 26, { fontSize: 14, bold: true, color });
    text(slide, `stake-promise-${i}`, promise, x, 305, 275, 75, { fontSize: 25, bold: true, typeface: "Aptos Display" });
  });

  const rows = [
    ["DAILY VALUE", "Portfolio visibility", "One repeatable process", "Self-service clarity"],
    ["PROOF", "Approvals and reporting", "Structured records", "Bills and status"],
    ["EXPANSION", "More units and features", "More managed portfolios", "Marketplace engagement"],
  ];
  rows.forEach((row, r) => {
    const y = 420 + r * 72;
    line(slide, `matrix-rule-${r}`, 56, y, 1168, 1, C.rule);
    text(slide, `matrix-label-${r}`, row[0], 70, y + 22, 190, 24, { fontSize: 13, bold: true, color: C.muted });
    for (let c = 1; c <= 3; c++) text(slide, `matrix-${r}-${c}`, row[c], 290 + (c - 1) * 310, y + 18, 275, 32, { fontSize: 18.67, color: C.muted });
  });
  notes(slide, "Stakeholder outcomes are derived from the role-specific workflows in the app and database schema. The slide avoids quantified impact claims until a pilot produces evidence.", ["supabase/migrations/202606290001_initial_rental_schema.sql (owner, agent and tenant roles)"]);
}

async function slide6(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.bg;
  await brand(slide, 6, false, "BUSINESS MODEL");
  titleBlock(slide, "Recurring workflows create a scalable revenue model", "Start with a simple SaaS offer; expand only where usage creates real value.");

  text(slide, "stack-label", "PROPOSED REVENUE STACK", 70, 245, 430, 24, { fontSize: 13, bold: true, color: C.muted });
  rect(slide, "stack-3", 70, 300, 610, 95, C.soft);
  text(slide, "stack-3-head", "Future services", 98, 322, 220, 30, { fontSize: 25, bold: true, typeface: "Aptos Display" });
  text(slide, "stack-3-body", "Payments and partner services—only after validation", 335, 326, 315, 26, { fontSize: 18.67, color: C.muted });
  rect(slide, "stack-2", 70, 410, 610, 105, C.bluePale);
  text(slide, "stack-2-head", "Growth add-ons", 98, 437, 220, 30, { fontSize: 25, bold: true, typeface: "Aptos Display", color: C.blue });
  text(slide, "stack-2-body", "Promoted Explore listings and premium features", 335, 441, 315, 26, { fontSize: 18.67, color: C.muted });
  rect(slide, "stack-1", 70, 530, 610, 120, C.navy);
  text(slide, "stack-1-head", "Core subscription", 98, 562, 240, 34, { fontSize: 29, bold: true, typeface: "Aptos Display", color: C.white });
  text(slide, "stack-1-body", "Tier by managed units, active tenants and enabled features", 350, 562, 300, 54, { fontSize: 18.67, color: "#C7D4E8" });

  text(slide, "motion-label", "LAND-AND-EXPAND MOTION", 760, 245, 420, 24, { fontSize: 13, bold: true, color: C.muted });
  const motion = [
    ["1", "Land", "Win an owner or agent with one portfolio"],
    ["2", "Embed", "Run billing, proof and tenant workflows monthly"],
    ["3", "Expand", "Add units, features, listings and validated services"],
  ];
  motion.forEach(([n, head, body], i) => {
    const y = 300 + i * 120;
    circle(slide, `motion-circle-${i}`, 760, y, 50, i === 0 ? C.teal : i === 1 ? C.blue : C.navy);
    text(slide, `motion-num-${i}`, n, 760, y + 10, 50, 26, { fontSize: 19, bold: true, color: C.white, align: "center" });
    text(slide, `motion-head-${i}`, head, 835, y + 3, 210, 32, { fontSize: 25, bold: true, typeface: "Aptos Display" });
    text(slide, `motion-body-${i}`, body, 835, y + 42, 330, 62, { fontSize: 18.67, color: C.muted });
  });
  rect(slide, "model-note", 760, 650, 430, 35, C.tealPale);
  text(slide, "model-note-text", "Pricing and fee economics will be validated in the pilot.", 782, 657, 385, 20, { fontSize: 15, bold: true, color: "#067F72" });
  notes(slide, "The revenue architecture is proposed. No price points, revenue forecasts or payment-fee economics are claimed without pilot evidence.", ["lib/explore/room_explore.dart (promoted listing capability)", "docs/admin-portal-deployment.md (limits and feature controls)"]);
}

async function slide7(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.white;
  await brand(slide, 7, false, "PILOT READINESS");
  titleBlock(slide, "The product foundation is ready for a structured pilot", "Sponsorship accelerates proof, onboarding and measurement—not basic product discovery.");

  rect(slide, "readiness-left", 56, 245, 430, 405, C.navy);
  text(slide, "readiness-kicker", "WHAT EXISTS TODAY", 88, 280, 250, 24, { fontSize: 13, bold: true, color: C.teal });
  text(slide, "readiness-claim", "The core operating loop is already implemented.", 88, 335, 330, 150, { fontSize: 38, bold: true, typeface: "Aptos Display", color: C.white });
  text(slide, "readiness-small", "The pilot can focus on customer value, workflow fit and willingness to pay.", 88, 530, 330, 80, { fontSize: 20, color: "#C7D4E8" });

  const evidence = [
    ["ROLE-BASED WORKSPACE", "Owner, agent and tenant experiences with isolated data access"],
    ["MONEY WORKFLOWS", "Invoices, utilities, proof submission, approvals and records"],
    ["TENANT + MARKETPLACE", "Requests, status, invitations and verified room discovery"],
    ["PLATFORM CONTROL", "Administration, usage limits, feature controls and operational reporting"],
  ];
  evidence.forEach(([head, body], i) => {
    const y = 252 + i * 98;
    circle(slide, `ready-check-${i}`, 555, y + 6, 34, i % 2 === 0 ? C.teal : C.blue);
    text(slide, `ready-checkmark-${i}`, "✓", 555, y + 10, 34, 20, { fontSize: 16, bold: true, color: C.white, align: "center" });
    text(slide, `ready-head-${i}`, head, 615, y, 490, 24, { fontSize: 14, bold: true, color: i % 2 === 0 ? "#067F72" : C.blue });
    text(slide, `ready-body-${i}`, body, 615, y + 32, 520, 48, { fontSize: 19, color: C.muted });
    if (i < 3) line(slide, `ready-rule-${i}`, 555, y + 90, 600, 1, C.rule);
  });
  rect(slide, "ready-bottom", 555, 650, 600, 34, C.tealPale);
  text(slide, "ready-bottom-text", "Pilot scope should test value and adoption under real operating conditions.", 575, 658, 560, 18, { fontSize: 14, bold: true, color: "#067F72" });
  notes(slide, "Readiness means the core product foundation exists; it does not claim that every deployment, pricing or scale risk is solved. The pilot is intended to validate those remaining questions.", ["docs/supabase-free-production-security.md (security and isolation)", "lib/admin/admin_app.dart (administration)", "lib/cloud/* (cloud workflows)"]);
}

async function slide8(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.bg;
  await brand(slide, 8, false, "PROPOSED PILOT");
  titleBlock(slide, "A 12-week pilot answers the sponsor’s key questions", "Proposed structure: scope first, operate with real workflows, then decide from evidence.");

  line(slide, "timeline-line", 115, 392, 1030, 5, C.rule);
  const phases = [
    ["WEEKS 1–2", "Scope", "Select portfolio, users and success measures", C.teal],
    ["WEEKS 3–5", "Onboard", "Configure properties, tenants and monthly workflows", C.blue],
    ["WEEKS 6–9", "Operate", "Run billing, proof, requests and reporting", C.navy],
    ["WEEKS 10–12", "Evaluate", "Review adoption, value and willingness to pay", C.orange],
  ];
  phases.forEach(([weeks, head, body, color], i) => {
    const x = 90 + i * 295;
    circle(slide, `timeline-dot-${i}`, x + 70, 365, 60, color);
    text(slide, `timeline-index-${i}`, String(i + 1), x + 70, 379, 60, 26, { fontSize: 19, bold: true, color: C.white, align: "center" });
    text(slide, `timeline-weeks-${i}`, weeks, x, 285, 200, 24, { fontSize: 13, bold: true, color });
    text(slide, `timeline-head-${i}`, head, x, 320, 200, 34, { fontSize: 27, bold: true, typeface: "Aptos Display" });
    text(slide, `timeline-body-${i}`, body, x, 455, 225, 88, { fontSize: 18.67, color: C.muted, align: "center" });
  });
  rect(slide, "timeline-decision", 110, 590, 1060, 70, C.navy);
  text(slide, "timeline-decision-label", "DECISION GATE", 140, 614, 180, 22, { fontSize: 13, bold: true, color: C.teal });
  text(slide, "timeline-decision-copy", "Confirm packaging, operating ownership and the case for scale.", 335, 605, 760, 32, { fontSize: 23, bold: true, color: C.white });
  notes(slide, "The 12-week structure is a proposed working plan. Dates and success thresholds should be agreed with the sponsor and pilot portfolio before launch.");
}

async function slide9(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.white;
  await brand(slide, 9, false, "SPONSORSHIP CASE");
  titleBlock(slide, "Sponsorship funds the proof—not an untested scale-up", "The requested commitment is a scoped pilot budget, a real portfolio and executive access.");

  text(slide, "fund-label", "SPONSORSHIP ENABLES", 70, 250, 470, 26, { fontSize: 14, bold: true, color: C.blue });
  const enables = [
    ["01", "Pilot onboarding", "Configure real properties, tenants and workflows"],
    ["02", "Operational support", "Hosting, issue resolution and pilot coordination"],
    ["03", "Measurement", "Track adoption, workflow completion and value signals"],
    ["04", "Decision package", "Deliver findings, pricing evidence and scale options"],
  ];
  enables.forEach(([n, head, body], i) => {
    const y = 300 + i * 86;
    text(slide, `enable-n-${i}`, n, 70, y, 45, 24, { fontSize: 14, bold: true, color: C.teal });
    text(slide, `enable-h-${i}`, head, 125, y - 3, 210, 28, { fontSize: 23, bold: true, typeface: "Aptos Display" });
    text(slide, `enable-b-${i}`, body, 350, y, 285, 50, { fontSize: 17.33, color: C.muted });
    if (i < 3) line(slide, `enable-rule-${i}`, 70, y + 66, 565, 1, C.rule);
  });

  rect(slide, "sponsor-value", 700, 245, 524, 390, C.navy);
  text(slide, "sponsor-value-label", "THE SPONSOR RECEIVES", 740, 285, 400, 26, { fontSize: 14, bold: true, color: C.teal });
  text(slide, "sponsor-value-title", "A controlled path to evidence", 740, 335, 405, 70, { fontSize: 35, bold: true, typeface: "Aptos Display", color: C.white });
  text(slide, "sponsor-value-body", "• Direct visibility into pilot adoption\n\n• Influence over the outcomes tested\n\n• A documented value and scale report\n\n• A decision point before further commitment", 740, 430, 405, 165, { fontSize: 20, color: "#C7D4E8" });
  text(slide, "budget-note", "Final budget follows the agreed portfolio size, support scope and pilot responsibilities.", 70, 657, 1090, 24, { fontSize: 14, color: C.muted });
  notes(slide, "The sponsorship structure is proposed. The sponsor benefits are discussion points, not contractual commitments. A final budget requires an agreed pilot portfolio and operating scope.");
}

async function slide10(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = C.navy;
  rect(slide, "close-accent", 0, 0, 1280, 12, C.teal);
  await brand(slide, 10, true, "DECISION REQUEST");
  text(slide, "close-kicker", "THE DECISION", 72, 160, 220, 24, { fontSize: 14, bold: true, color: C.teal });
  text(slide, "close-title", "Sponsor the HomeOps360 pilot—and decide from evidence", 72, 210, 1080, 145, { fontSize: 60, bold: true, typeface: "Aptos Display", color: C.white });
  text(slide, "close-subtitle", "Approve the pilot scope and budget, nominate a real portfolio, and appoint an executive sponsor.", 76, 392, 980, 70, { fontSize: 25, color: "#C7D4E8" });
  line(slide, "close-rule", 76, 505, 1100, 1, "#375170");
  const actions = [
    ["01", "Agree scope", "Portfolio, users and operating boundaries"],
    ["02", "Set measures", "Adoption, workflow value and willingness to pay"],
    ["03", "Launch pilot", "A controlled 12-week path to a scale decision"],
  ];
  actions.forEach(([n, head, body], i) => {
    const x = 76 + i * 370;
    text(slide, `close-n-${i}`, n, x, 548, 48, 24, { fontSize: 13, bold: true, color: C.teal });
    text(slide, `close-h-${i}`, head, x + 54, 541, 250, 30, { fontSize: 23, bold: true, typeface: "Aptos Display", color: C.white });
    text(slide, `close-b-${i}`, body, x + 54, 582, 285, 60, { fontSize: 17.33, color: "#9FB1C9" });
  });
  notes(slide, "Close with the specific decision: approve the pilot scope and budget, nominate a pilot portfolio, and appoint an executive sponsor. Do not negotiate price from this slide; agree scope first.");
}

async function main() {
  await fs.mkdir(RENDER, { recursive: true });
  await fs.mkdir(LAYOUT, { recursive: true });
  const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });
  await slide1(presentation);
  await slide2(presentation);
  await slide3(presentation);
  await slide4(presentation);
  await slide5(presentation);
  await slide6(presentation);
  await slide7(presentation);
  await slide8(presentation);
  await slide9(presentation);
  await slide10(presentation);

  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    await writeBlob(`${RENDER}/${stem}.png`, await presentation.export({ slide, format: "png", scale: 1 }));
    await fs.writeFile(`${LAYOUT}/${stem}.layout.json`, await (await slide.export({ format: "layout" })).text());
  }
  await writeBlob(`${TMP}/montage.webp`, await presentation.export({ format: "webp", montage: true, scale: 1 }));
  const inspect = await presentation.inspect({ kind: "slide,textbox,shape,image,notes", maxChars: 60000 });
  await fs.writeFile(`${TMP}/inspect.ndjson`, inspect.ndjson);
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(OUT);
  console.log(`PPTX=${OUT}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
