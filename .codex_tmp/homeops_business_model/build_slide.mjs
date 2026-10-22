import fs from "node:fs/promises";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const ROOT = "C:/Users/User/Documents/Codex/2026-06-16/rental management/rental_facility_management";
const OUT = `${ROOT}/HomeOps360_Business_Model.pptx`;
const TMP = `${ROOT}/.codex_tmp/homeops_business_model`;
const LOGO = `${ROOT}/web/icons/Icon-512.png`;

async function writeBlob(path, blob) {
  await fs.writeFile(path, new Uint8Array(await blob.arrayBuffer()));
}

function addRect(slide, name, left, top, width, height, fill) {
  return slide.shapes.add({
    geometry: "rect",
    name,
    position: { left, top, width, height },
    fill,
    line: { style: "solid", fill: "none", width: 0 },
  });
}

function addLine(slide, name, left, top, width, color, weight = 1) {
  return slide.shapes.add({
    geometry: "rect",
    name,
    position: { left, top, width, height: weight },
    fill: color,
    line: { style: "solid", fill: "none", width: 0 },
  });
}

function addText(slide, name, text, left, top, width, height, opts = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    name,
    position: { left, top, width, height },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontSize: opts.fontSize ?? 21.33,
    typeface: opts.typeface ?? "Aptos",
    color: opts.color ?? "#0E1B33",
    bold: opts.bold ?? false,
    alignment: opts.alignment ?? "left",
    verticalAlignment: opts.verticalAlignment ?? "top",
    autoFit: "none",
    wrap: "square",
  };
  return shape;
}

async function main() {
  await fs.mkdir(`${TMP}/artifact-rendered`, { recursive: true });
  const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });
  const slide = presentation.slides.add();
  slide.background.fill = "#F7FAFC";

  addRect(slide, "customer-region", 56, 261, 331, 355, "#FFFFFF");
  addRect(slide, "platform-region", 456, 261, 368, 355, "#0E1B33");
  addRect(slide, "revenue-region", 893, 261, 331, 355, "#FFFFFF");
  addRect(slide, "customer-accent", 56, 261, 331, 7, "#10C8B0");
  addRect(slide, "platform-accent", 456, 261, 368, 7, "#2E6BFF");
  addRect(slide, "revenue-accent", 893, 261, 331, 7, "#2E6BFF");
  addRect(slide, "flywheel-band", 56, 643, 1168, 43, "#DDF8F4");

  const logoBytes = await fs.readFile(LOGO);
  slide.images.add({
    blob: logoBytes,
    contentType: "image/png",
    alt: "HomeOps360 app mark",
    fit: "contain",
    position: { left: 56, top: 32, width: 38, height: 38 },
  });
  addText(slide, "brand-homeops", "HomeOps", 102, 32, 116, 35, { fontSize: 21.33, bold: true, typeface: "Aptos Display" });
  addText(slide, "brand-360", "360", 202, 32, 52, 35, { fontSize: 21.33, bold: true, color: "#2E6BFF", typeface: "Aptos Display" });
  addText(slide, "eyebrow", "BUSINESS MODEL", 995, 37, 229, 23, { fontSize: 13.33, bold: true, color: "#54617A", alignment: "right" });

  addText(slide, "title", "HomeOps360 converts rental workflows into recurring revenue", 56, 99, 1168, 61, { fontSize: 40, bold: true, typeface: "Aptos Display" });
  addText(slide, "subtitle", "Owners pay to run the portfolio; every monthly workflow deepens retention and opens expansion revenue.", 56, 169, 1168, 32, { fontSize: 21.33, color: "#54617A" });
  addLine(slide, "title-rule", 56, 227, 1168, "#D9E1EA", 2);

  addText(slide, "step-01", "01", 80, 294, 56, 31, { fontSize: 16, bold: true, color: "#10C8B0" });
  addText(slide, "who-pays", "WHO PAYS", 80, 331, 253, 32, { fontSize: 16, bold: true, color: "#54617A" });
  addText(slide, "payer-heading", "Owners &\nagents", 80, 373, 269, 83, { fontSize: 32, bold: true, typeface: "Aptos Display" });
  addText(slide, "payer-body", "Manage more units with less admin:\n\n• Properties & tenancies\n• Rent, utilities & expenses\n• Payment proof & reporting", 80, 461, 269, 139, { fontSize: 21.33, color: "#54617A" });

  addText(slide, "step-02", "02", 482, 294, 56, 31, { fontSize: 16, bold: true, color: "#10C8B0" });
  addText(slide, "operating-layer", "THE OPERATING LAYER", 482, 331, 293, 32, { fontSize: 16, bold: true, color: "#B8C7DD" });
  addText(slide, "platform-heading", "One workspace for\nthe full rental cycle", 482, 373, 301, 83, { fontSize: 32, bold: true, color: "#FFFFFF", typeface: "Aptos Display" });
  addText(slide, "platform-body", "OWNER APP\nPortfolio • billing • approvals\nTENANT PORTAL\nBills • proof • requests\nEXPLORE\nVerified room discovery", 482, 453, 301, 155, { fontSize: 21.33, color: "#DDE7F5" });

  addText(slide, "step-03", "03", 920, 294, 56, 31, { fontSize: 16, bold: true, color: "#2E6BFF" });
  addText(slide, "how-monetizes", "HOW IT MONETIZES", 920, 331, 253, 32, { fontSize: 16, bold: true, color: "#54617A" });
  addText(slide, "revenue-heading", "SaaS first.\nExpand with usage.", 920, 373, 269, 83, { fontSize: 32, bold: true, typeface: "Aptos Display" });
  addText(slide, "revenue-body", "1  Tiered subscription\n    Units • tenants • features\n2  Promoted listings\n    Paid Explore visibility\n3  Future service fees\n    Payments • partners", 920, 453, 269, 155, { fontSize: 21.33, color: "#54617A" });

  addText(slide, "arrow-one", "→", 392, 405, 59, 53, { fontSize: 37.33, color: "#A8B5C5", alignment: "center", typeface: "Aptos Display" });
  addText(slide, "arrow-two", "→", 829, 405, 59, 53, { fontSize: 37.33, color: "#A8B5C5", alignment: "center", typeface: "Aptos Display" });

  addText(slide, "flywheel-label", "LAND-AND-EXPAND ENGINE", 75, 654, 221, 19, { fontSize: 13.33, bold: true, color: "#067F72" });
  addText(slide, "flywheel-copy", "More managed units  →  more recurring workflows  →  higher retention  →  subscription expansion", 304, 651, 891, 24, { fontSize: 17.33, bold: true });
  addText(slide, "assumption-note", "Proposed monetization model; final packaging and pricing to be validated with pilot customers.", 56, 691, 1168, 15, { fontSize: 12, color: "#748197" });

  slide.speakerNotes.textFrame.setText(
    "[Sources]\n- README.md (product roles and workflows)\n- lib/branding/homeops_brand.dart (brand colors and naming)\n- lib/explore/room_explore.dart (Explore marketplace and promotion capability)\n- docs/admin-portal-deployment.md (owner limits and feature access)\n[/Sources]\n\nPricing and transaction-fee streams are proposed; the repository does not define commercial rates."
  );

  await writeBlob(`${TMP}/artifact-rendered/slide-1.png`, await presentation.export({ slide, format: "png", scale: 2 }));
  await fs.writeFile(`${TMP}/artifact-rendered/slide-1.layout.json`, await (await slide.export({ format: "layout" })).text());
  await writeBlob(`${TMP}/artifact-rendered/montage.webp`, await presentation.export({ format: "webp", montage: true, scale: 1 }));
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(OUT);
  const snapshot = await presentation.inspect({ kind: "slide,textbox,shape,image,notes", maxChars: 12000 });
  await fs.writeFile(`${TMP}/artifact-rendered/inspect.ndjson`, snapshot.ndjson);
  console.log(`PPTX=${OUT}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
