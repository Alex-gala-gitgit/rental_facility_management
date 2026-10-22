import fs from "node:fs/promises";
import { FileBlob, PresentationFile } from "@oai/artifact-tool";

const ROOT = "C:/Users/User/Documents/Codex/2026-06-16/rental management/rental_facility_management";
const TMP = `${ROOT}/.codex_tmp/homeops_business_model_deck`;
const STARTER = `${TMP}/template-starter.pptx`;
const OUT = `${ROOT}/HomeOps360_Business_Model_Deck.pptx`;
const RENDER = `${TMP}/final-rendered`;
const LAYOUT = `${TMP}/final-layout`;

const C = {
  bg: "#F7FAFC",
  white: "#FFFFFF",
  teal: "#10C8B0",
  blue: "#2E6BFF",
  navy: "#0E1B33",
  muted: "#54617A",
  rule: "#D9E1EA",
  band: "#DDF8F4",
};

async function writeBlob(path, blob) {
  await fs.writeFile(path, new Uint8Array(await blob.arrayBuffer()));
}

function byName(slide, name) {
  const item = slide.shapes.items.find((candidate) => candidate.name === name);
  if (!item) throw new Error(`Missing inherited shape ${name}`);
  return item;
}

function setPos(item, left, top, width, height) {
  item.position = { left, top, width, height };
}

function setText(slide, name, value, left, top, width, height) {
  const item = byName(slide, name);
  item.text = value;
  setPos(item, left, top, width, height);
}

function setRect(slide, name, left, top, width, height, fill) {
  const item = byName(slide, name);
  setPos(item, left, top, width, height);
  item.fill = fill;
  item.line = { style: "solid", fill: "none", width: 0 };
}

function clearText(slide, name) {
  byName(slide, name).text = "";
}

function commonChrome(slide, page, eyebrow = "BUSINESS MODEL") {
  setText(slide, "brand-homeops", "HomeOps", 102, 32, 116, 35);
  setText(slide, "brand-360", "360", 202, 32, 52, 35);
  setText(slide, "eyebrow", eyebrow, 915, 37, 309, 23);
  setText(slide, "assumption-note", `HomeOps360 • ${String(page).padStart(2, "0")}`, 56, 691, 1168, 15);
  const logo = slide.images.items[0];
  logo.position = { left: 56, top: 32, width: 38, height: 38 };
}

function standardFrame(slide, page, title, subtitle, eyebrow = "BUSINESS MODEL") {
  commonChrome(slide, page, eyebrow);
  setText(slide, "title", title, 56, 99, 1168, 61);
  setText(slide, "subtitle", subtitle, 56, 169, 1168, 32);
  setRect(slide, "title-rule", 56, 227, 1168, 2, C.rule);

  setRect(slide, "customer-region", 56, 261, 331, 355, C.white);
  setRect(slide, "platform-region", 456, 261, 368, 355, C.navy);
  setRect(slide, "revenue-region", 893, 261, 331, 355, C.white);
  setRect(slide, "customer-accent", 56, 261, 331, 7, C.teal);
  setRect(slide, "platform-accent", 456, 261, 368, 7, C.blue);
  setRect(slide, "revenue-accent", 893, 261, 331, 7, C.blue);
  setRect(slide, "flywheel-band", 56, 643, 1168, 43, C.band);

  setText(slide, "step-01", "01", 80, 294, 56, 31);
  setText(slide, "who-pays", "", 80, 331, 253, 32);
  setText(slide, "payer-heading", "", 80, 373, 269, 83);
  setText(slide, "payer-body", "", 80, 461, 269, 139);
  setText(slide, "step-02", "02", 482, 294, 56, 31);
  setText(slide, "operating-layer", "", 482, 331, 293, 32);
  setText(slide, "platform-heading", "", 482, 373, 301, 83);
  setText(slide, "platform-body", "", 482, 453, 301, 155);
  setText(slide, "step-03", "03", 920, 294, 56, 31);
  setText(slide, "how-monetizes", "", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "", 920, 373, 269, 83);
  setText(slide, "revenue-body", "", 920, 453, 269, 155);
  setText(slide, "arrow-one", "", 392, 405, 59, 53);
  setText(slide, "arrow-two", "", 829, 405, 59, 53);
  setText(slide, "flywheel-label", "", 75, 654, 221, 19);
  setText(slide, "flywheel-copy", "", 304, 651, 891, 24);
}

function setNotes(slide, note) {
  slide.speakerNotes.textFrame.setText(
    `[Sources]\n- README.md (owner and tenant workflows)\n- lib/branding/homeops_brand.dart (HomeOps360 identity and brand colors)\n- lib/explore/room_explore.dart (Explore room marketplace and promoted listings)\n- docs/admin-portal-deployment.md (owner limits and feature controls)\n[/Sources]\n\n${note}`
  );
}

function cover(slide) {
  standardFrame(slide, 1, "HomeOps360 business model", "A recurring-revenue platform for owners, property agents and tenants.", "BUSINESS MODEL OVERVIEW");
  setText(slide, "who-pays", "MANAGE", 80, 331, 253, 32);
  setText(slide, "payer-heading", "Operate\nportfolios", 80, 373, 269, 83);
  setText(slide, "operating-layer", "ENGAGE", 482, 331, 293, 32);
  setText(slide, "platform-heading", "Connect monthly\nworkflows", 482, 373, 301, 83);
  setText(slide, "how-monetizes", "MONETIZE", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "Earn recurring\nrevenue", 920, 373, 269, 83);
  setText(slide, "arrow-one", "→", 392, 405, 59, 53);
  setText(slide, "arrow-two", "→", 829, 405, 59, 53);
  setText(slide, "flywheel-label", "CORE THESIS", 75, 647, 221, 19);
  setText(slide, "flywheel-copy", "Recurring workflows create retention; managed-unit growth creates expansion.", 304, 644, 891, 24);
  setNotes(slide, "Opening: HomeOps360 is positioned as the operating layer for recurring rental workflows. Commercial packaging remains proposed until pilot validation.");
}

function problem(slide) {
  standardFrame(slide, 2, "Rental operations break when workflows live in separate tools", "Owners and agents repeat the same reconciliation, follow-up and reporting work every month.", "THE PROBLEM");
  setText(slide, "who-pays", "MONEY", 80, 331, 253, 32);
  setText(slide, "payer-heading", "No single view\nof cash flow", 80, 373, 269, 83);
  setText(slide, "payer-body", "Rent, utilities, expenses and payment proof require manual checking.", 80, 461, 269, 139);
  setText(slide, "operating-layer", "OPERATIONS", 482, 331, 293, 32);
  setText(slide, "platform-heading", "Admin repeats\nevery month", 482, 373, 301, 83);
  setText(slide, "platform-body", "Bills, reminders, approvals, documents and reports are disconnected.", 482, 453, 301, 155);
  setText(slide, "how-monetizes", "EXPERIENCE", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "Tenant service\nbecomes reactive", 920, 373, 269, 83);
  setText(slide, "revenue-body", "Requests, invoices and payment updates scatter across channels.", 920, 453, 269, 155);
  setText(slide, "flywheel-label", "BUSINESS IMPACT", 75, 654, 221, 19);
  setText(slide, "flywheel-copy", "Fragmentation limits portfolio scale and weakens the tenant experience.", 304, 651, 891, 24);
  setNotes(slide, "Problem statements are qualitative and derived from the workflows implemented in the repository; no external market statistics are asserted.");
}

function solution(slide) {
  standardFrame(slide, 3, "HomeOps360 unifies the full rental cycle in one workspace", "The platform connects owner control, tenant self-service and room discovery.", "THE SOLUTION");
  setText(slide, "who-pays", "MANAGE", 80, 331, 253, 32);
  setText(slide, "payer-heading", "Owner & agent\ncontrol centre", 80, 373, 269, 83);
  setText(slide, "payer-body", "Properties • tenancies\nBills • utilities\nExpenses • reports", 80, 461, 269, 139);
  setText(slide, "operating-layer", "OPERATE", 482, 331, 293, 32);
  setText(slide, "platform-heading", "One connected\noperating layer", 482, 373, 301, 83);
  setText(slide, "platform-body", "Monthly workflows stay visible, structured and auditable in one place.", 482, 453, 301, 155);
  setText(slide, "how-monetizes", "ENGAGE", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "Tenant portal\nplus Explore", 920, 373, 269, 83);
  setText(slide, "revenue-body", "Invoices • payment proof\nRequests • status\nVerified room listings", 920, 453, 269, 155);
  setText(slide, "arrow-one", "→", 392, 405, 59, 53);
  setText(slide, "arrow-two", "→", 829, 405, 59, 53);
  setText(slide, "flywheel-label", "PLATFORM ROLE", 75, 654, 221, 19);
  setText(slide, "flywheel-copy", "A shared system of record connects the portfolio to every monthly interaction.", 304, 651, 891, 24);
  setNotes(slide, "Solution scope reflects current repository capabilities and implemented product flows.");
}

function stakeholders(slide) {
  standardFrame(slide, 4, "One platform creates value for every rental stakeholder", "Each participant gets a focused experience while working from shared operational data.", "CUSTOMER VALUE");
  setText(slide, "who-pays", "OWNERS", 80, 331, 253, 32);
  setText(slide, "payer-heading", "Control more\nwith less admin", 80, 373, 269, 83);
  setText(slide, "payer-body", "Portfolio visibility\nPayment approvals\nCash-flow reporting", 80, 461, 269, 139);
  setText(slide, "operating-layer", "PROPERTY AGENTS", 482, 331, 293, 32);
  setText(slide, "platform-heading", "Standardise\nrepeatable work", 482, 373, 301, 83);
  setText(slide, "platform-body", "One process for units, tenants, bills, documents and follow-up.", 482, 453, 301, 155);
  setText(slide, "how-monetizes", "TENANTS", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "Clear bills.\nClear next steps.", 920, 373, 269, 83);
  setText(slide, "revenue-body", "Bills and payment proof\nRequest tracking\nRoom discovery", 920, 453, 269, 155);
  setText(slide, "flywheel-label", "NETWORK VALUE", 75, 654, 221, 19);
  setText(slide, "flywheel-copy", "Shared data reduces handoffs and strengthens trust across the rental relationship.", 304, 651, 891, 24);
  setNotes(slide, "Stakeholder benefits are grounded in the owner, agent and tenant roles represented in the app and database schema.");
}

function workflow(slide) {
  standardFrame(slide, 5, "Monthly workflows make HomeOps360 hard to replace", "The product earns retention by supporting work that repeats across every managed unit.", "OPERATING MODEL");
  setText(slide, "who-pays", "SET UP", 80, 331, 253, 32);
  setText(slide, "payer-heading", "Create the\nportfolio record", 80, 373, 269, 83);
  setText(slide, "payer-body", "Properties • units\nTenancies • rent\nPayment details", 80, 461, 269, 139);
  setText(slide, "operating-layer", "RUN MONTHLY", 482, 331, 293, 32);
  setText(slide, "platform-heading", "Bill, collect\nand reconcile", 482, 373, 301, 83);
  setText(slide, "platform-body", "Invoices • utilities\nPayment proof • approvals\nExpenses • documents", 482, 453, 301, 155);
  setText(slide, "how-monetizes", "IMPROVE", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "Retain tenants.\nExpand units.", 920, 373, 269, 83);
  setText(slide, "revenue-body", "Portfolio reporting\nTenant service\nNew listings and units", 920, 453, 269, 155);
  setText(slide, "arrow-one", "→", 392, 405, 59, 53);
  setText(slide, "arrow-two", "→", 829, 405, 59, 53);
  setText(slide, "flywheel-label", "RETENTION ENGINE", 75, 654, 221, 19);
  setText(slide, "flywheel-copy", "More managed units create more recurring workflows and more reasons to stay.", 304, 651, 891, 24);
  setNotes(slide, "The sequence synthesizes product workflows visible across the owner app, tenant experience, invoice portal and Explore marketplace.");
}

function summary(slide) {
  standardFrame(slide, 6, "HomeOps360 converts rental workflows into recurring revenue", "Owners pay to run the portfolio; usage and adjacent services expand account value.", "BUSINESS MODEL");
  setText(slide, "who-pays", "WHO PAYS", 80, 331, 253, 32);
  setText(slide, "payer-heading", "Owners &\nproperty agents", 80, 373, 269, 83);
  setText(slide, "payer-body", "Manage more units with less admin:\n\n• Portfolio operations\n• Billing and reporting", 80, 461, 269, 139);
  setText(slide, "operating-layer", "CORE PRODUCT", 482, 331, 293, 32);
  setText(slide, "platform-heading", "One workspace for\nthe rental cycle", 482, 373, 301, 83);
  setText(slide, "platform-body", "OWNER APP\nPortfolio • billing • approvals\nTENANT + EXPLORE\nProof • requests • listings", 482, 453, 301, 155);
  setText(slide, "how-monetizes", "MONETIZATION", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "SaaS first.\nUsage expands.", 920, 373, 269, 83);
  setText(slide, "revenue-body", "1  Tiered subscription\n2  Promoted listings\n3  Future service fees", 920, 453, 269, 155);
  setText(slide, "arrow-one", "→", 392, 405, 59, 53);
  setText(slide, "arrow-two", "→", 829, 405, 59, 53);
  setText(slide, "flywheel-label", "LAND AND EXPAND", 75, 654, 221, 19);
  setText(slide, "flywheel-copy", "Acquire an owner → embed monthly workflows → expand units, features and services.", 304, 651, 891, 24);
  setNotes(slide, "The monetization model is proposed. Exact packaging and pricing are not defined in the repository and should be validated with pilot customers.");
}

function revenue(slide) {
  standardFrame(slide, 7, "Revenue starts with subscriptions and expands with usage", "A simple core offer creates recurring revenue; adjacent streams increase account value over time.", "REVENUE ARCHITECTURE");
  setText(slide, "who-pays", "CORE", 80, 331, 253, 32);
  setText(slide, "payer-heading", "Tiered SaaS\nsubscription", 80, 373, 269, 83);
  setText(slide, "payer-body", "Package by managed units, active tenants and enabled features.", 80, 461, 269, 139);
  setText(slide, "operating-layer", "EXPANSION", 482, 331, 293, 32);
  setText(slide, "platform-heading", "Promoted\nExplore listings", 482, 373, 301, 83);
  setText(slide, "platform-body", "Owners and agents pay for additional visibility when filling vacancies.", 482, 453, 301, 155);
  setText(slide, "how-monetizes", "OPTION VALUE", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "Future payment\nand partner fees", 920, 373, 269, 83);
  setText(slide, "revenue-body", "Validate only where the platform can create measurable transaction or service value.", 920, 453, 269, 155);
  setText(slide, "flywheel-label", "PRICING LOGIC", 75, 654, 221, 19);
  setText(slide, "flywheel-copy", "Keep entry simple; let portfolio size and product usage drive expansion.", 304, 651, 891, 24);
  setNotes(slide, "All three revenue streams are proposed. The slide intentionally excludes price points and revenue forecasts because no validated data was supplied.");
}

function pilot(slide) {
  standardFrame(slide, 8, "The pilot proves willingness to pay before the model scales", "Validate the customer, package and recurring value loop with real portfolio workflows.", "NEXT DECISION");
  setText(slide, "who-pays", "PILOT", 80, 331, 253, 32);
  setText(slide, "payer-heading", "Start with focused\nowner portfolios", 80, 373, 269, 83);
  setText(slide, "payer-body", "Onboard real properties, tenants and monthly billing workflows.", 80, 461, 269, 139);
  setText(slide, "operating-layer", "MEASURE", 482, 331, 293, 32);
  setText(slide, "platform-heading", "Track value\nand adoption", 482, 373, 301, 83);
  setText(slide, "platform-body", "Setup completion\nMonthly active workflows\nRetention and expansion signals", 482, 453, 301, 155);
  setText(slide, "how-monetizes", "DECIDE", 920, 331, 253, 32);
  setText(slide, "revenue-heading", "Confirm packaging\nthen scale", 920, 373, 269, 83);
  setText(slide, "revenue-body", "Set tier boundaries\nTest listing promotion\nPrioritise proven services", 920, 453, 269, 155);
  setText(slide, "arrow-one", "→", 392, 405, 59, 53);
  setText(slide, "arrow-two", "→", 829, 405, 59, 53);
  setText(slide, "flywheel-label", "GO / NO-GO GATE", 75, 654, 221, 19);
  setText(slide, "flywheel-copy", "Scale only after retention, willingness to pay and expansion behavior are evidenced.", 304, 651, 891, 24);
  setNotes(slide, "Recommended next step: run a pilot and use observed adoption and willingness-to-pay evidence to finalize packaging. No numeric targets are asserted without user-supplied baselines.");
}

async function main() {
  await fs.mkdir(RENDER, { recursive: true });
  await fs.mkdir(LAYOUT, { recursive: true });
  const presentation = await PresentationFile.importPptx(await FileBlob.load(STARTER));
  const slides = presentation.slides.items;
  if (slides.length !== 8) throw new Error(`Expected 8 starter slides, found ${slides.length}`);

  cover(slides[0]);
  problem(slides[1]);
  solution(slides[2]);
  stakeholders(slides[3]);
  workflow(slides[4]);
  summary(slides[5]);
  revenue(slides[6]);
  pilot(slides[7]);

  for (const [index, slide] of slides.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    await writeBlob(`${RENDER}/${stem}.png`, await presentation.export({ slide, format: "png", scale: 1 }));
    await fs.writeFile(`${LAYOUT}/${stem}.layout.json`, await (await slide.export({ format: "layout" })).text());
  }
  await writeBlob(`${TMP}/final-montage.webp`, await presentation.export({ format: "webp", montage: true, scale: 1 }));
  const snapshot = await presentation.inspect({ kind: "slide,textbox,shape,image,notes,layout", maxChars: 50000 });
  await fs.writeFile(`${TMP}/final-inspect.ndjson`, snapshot.ndjson);
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(OUT);
  console.log(`PPTX=${OUT}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
