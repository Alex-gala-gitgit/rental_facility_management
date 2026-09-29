from __future__ import annotations

import math
from pathlib import Path

from reportlab.lib.colors import HexColor, white
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "HomeOps360_Application_Workflow.pdf"
LOGO = ROOT / "web" / "icons" / "Icon-192.png"
FONT_BODY = ROOT / "assets" / "fonts" / "Manrope-Variable.ttf"
FONT_DISPLAY = ROOT / "assets" / "fonts" / "Outfit-Variable.ttf"

PAGE_W, PAGE_H = landscape(A4)

NAVY = HexColor("#0E1B33")
BLUE = HexColor("#2E6BFF")
BLUE_DARK = HexColor("#1648C7")
TEAL = HexColor("#10C8B0")
ORANGE = HexColor("#FF9F32")
PURPLE = HexColor("#795CFF")
GREEN = HexColor("#16A36A")
RED = HexColor("#D94F5C")
INK = HexColor("#172033")
MUTED = HexColor("#61708A")
LINE = HexColor("#DDE5F1")
WASH = HexColor("#F4F7FC")
PALE_BLUE = HexColor("#EAF1FF")
PALE_TEAL = HexColor("#E7FAF6")
PALE_ORANGE = HexColor("#FFF3E4")
PALE_PURPLE = HexColor("#F0ECFF")
PALE_GREEN = HexColor("#EAF8F1")
PALE_RED = HexColor("#FCECEF")


def register_fonts() -> None:
    pdfmetrics.registerFont(TTFont("Manrope", str(FONT_BODY)))
    pdfmetrics.registerFont(TTFont("Outfit", str(FONT_DISPLAY)))


BODY = ParagraphStyle(
    "body", fontName="Manrope", fontSize=8.6, leading=11.2, textColor=INK
)
BODY_MUTED = ParagraphStyle(
    "body-muted", fontName="Manrope", fontSize=8.2, leading=10.8, textColor=MUTED
)
BODY_WHITE = ParagraphStyle(
    "body-white", fontName="Manrope", fontSize=8.7, leading=11.4, textColor=white
)
SMALL = ParagraphStyle(
    "small", fontName="Manrope", fontSize=7.3, leading=9.2, textColor=MUTED
)
CARD_TITLE = ParagraphStyle(
    "card-title", fontName="Outfit", fontSize=11.2, leading=13, textColor=NAVY
)
CARD_TITLE_WHITE = ParagraphStyle(
    "card-title-white", fontName="Outfit", fontSize=11.2, leading=13, textColor=white
)
CENTER_BODY = ParagraphStyle(
    "center-body",
    parent=BODY,
    alignment=TA_CENTER,
)
CENTER_SMALL = ParagraphStyle(
    "center-small",
    parent=SMALL,
    alignment=TA_CENTER,
)


def draw_paragraph(c, text, x, y, width, height, style=BODY):
    p = Paragraph(text, style)
    _, used_h = p.wrap(width, height)
    p.drawOn(c, x, y + height - used_h)
    return used_h


def wrap_lines(text: str, width: float, font: str, size: float) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if pdfmetrics.stringWidth(trial, font, size) <= width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_centered_text(c, text, x, y, width, height, font="Manrope", size=8.5, color=INK):
    lines = wrap_lines(text, width - 14, font, size)
    leading = size + 2.2
    total_h = len(lines) * leading
    cursor_y = y + (height + total_h) / 2 - leading + 1
    c.setFillColor(color)
    c.setFont(font, size)
    for line in lines:
        c.drawCentredString(x + width / 2, cursor_y, line)
        cursor_y -= leading


def draw_round_box(
    c,
    x,
    y,
    width,
    height,
    title,
    body="",
    fill=white,
    stroke=LINE,
    accent=None,
    title_style=CARD_TITLE,
    body_style=BODY_MUTED,
    radius=12,
):
    c.setFillColor(fill)
    c.setStrokeColor(stroke)
    c.setLineWidth(0.8)
    c.roundRect(x, y, width, height, radius, fill=1, stroke=1)
    if accent:
        c.setFillColor(accent)
        c.roundRect(x, y, 5, height, radius, fill=1, stroke=0)
        c.rect(x + 2, y, 4, height, fill=1, stroke=0)
    inset = 15 if accent else 12
    draw_paragraph(c, title, x + inset, y + height - 30, width - inset - 10, 20, title_style)
    if body:
        draw_paragraph(c, body, x + inset, y + 12, width - inset - 10, height - 43, body_style)


def draw_step(c, x, y, width, height, number, title, body="", color=BLUE):
    c.setFillColor(white)
    c.setStrokeColor(LINE)
    c.roundRect(x, y, width, height, 11, fill=1, stroke=1)
    c.setFillColor(color)
    c.circle(x + 20, y + height - 20, 11, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Outfit", 9.5)
    c.drawCentredString(x + 20, y + height - 23.2, str(number))
    draw_paragraph(c, title, x + 38, y + height - 31, width - 48, 22, CARD_TITLE)
    if body:
        draw_paragraph(c, body, x + 12, y + 10, width - 24, height - 48, BODY_MUTED)


def draw_arrow(c, x1, y1, x2, y2, color=BLUE, width=1.6):
    c.setStrokeColor(color)
    c.setFillColor(color)
    c.setLineWidth(width)
    c.line(x1, y1, x2, y2)
    angle = math.atan2(y2 - y1, x2 - x1)
    length = 7
    spread = 3.5
    bx = x2 - length * math.cos(angle)
    by = y2 - length * math.sin(angle)
    px = spread * math.sin(angle)
    py = -spread * math.cos(angle)
    path = c.beginPath()
    path.moveTo(x2, y2)
    path.lineTo(bx + px, by + py)
    path.lineTo(bx - px, by - py)
    path.close()
    c.drawPath(path, fill=1, stroke=0)


def draw_label(c, text, x, y, fill=PALE_BLUE, color=BLUE_DARK, width=None):
    c.setFont("Manrope", 7.2)
    label_w = width or pdfmetrics.stringWidth(text, "Manrope", 7.2) + 14
    c.setFillColor(fill)
    c.roundRect(x, y, label_w, 17, 8, fill=1, stroke=0)
    c.setFillColor(color)
    c.drawCentredString(x + label_w / 2, y + 5.2, text)
    return label_w


def draw_bullets(c, items, x, y, width, font_size=8.3, leading=12, color=INK):
    cursor = y
    for item in items:
        lines = wrap_lines(item, width - 15, "Manrope", font_size)
        c.setFillColor(BLUE)
        c.circle(x + 3.2, cursor - 3.2, 2.2, fill=1, stroke=0)
        c.setFillColor(color)
        c.setFont("Manrope", font_size)
        line_y = cursor
        for line in lines:
            c.drawString(x + 12, line_y - 6, line)
            line_y -= leading
        cursor = line_y - 2
    return cursor


def page_header(c, section, title, subtitle=None, number=None):
    c.setFillColor(NAVY)
    c.rect(0, PAGE_H - 7, PAGE_W, 7, fill=1, stroke=0)
    c.setFillColor(BLUE)
    c.setFont("Manrope", 8)
    c.drawString(42, PAGE_H - 34, section.upper())
    c.setFillColor(NAVY)
    c.setFont("Outfit", 25)
    c.drawString(42, PAGE_H - 64, title)
    if subtitle:
        c.setFillColor(MUTED)
        c.setFont("Manrope", 9)
        c.drawString(42, PAGE_H - 81, subtitle)
    c.setStrokeColor(LINE)
    c.line(42, 31, PAGE_W - 42, 31)
    c.setFillColor(MUTED)
    c.setFont("Manrope", 7.5)
    c.drawString(42, 18, "HomeOps360 | Application workflow overview")
    if number is not None:
        c.drawRightString(PAGE_W - 42, 18, f"{number:02d}")


def end_page(c):
    c.showPage()


def cover_page(c):
    c.setFillColor(NAVY)
    c.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    c.setFillColor(BLUE_DARK)
    c.circle(PAGE_W - 80, PAGE_H + 10, 210, fill=1, stroke=0)
    c.setFillColor(TEAL)
    c.circle(PAGE_W - 15, 10, 150, fill=1, stroke=0)
    c.setFillColor(HexColor("#21385F"))
    c.circle(PAGE_W - 250, 130, 90, fill=1, stroke=0)
    if LOGO.exists():
        c.drawImage(ImageReader(str(LOGO)), 54, PAGE_H - 112, 54, 54, mask="auto")
    c.setFillColor(white)
    c.setFont("Outfit", 18)
    c.drawString(120, PAGE_H - 87, "HomeOps360")
    c.setFillColor(HexColor("#A8B7D0"))
    c.setFont("Manrope", 9)
    c.drawString(120, PAGE_H - 103, "Property operations, billing and tenant experience")
    c.setFillColor(white)
    c.setFont("Outfit", 39)
    c.drawString(54, PAGE_H - 200, "Application Workflow")
    c.setFillColor(TEAL)
    c.setFont("Outfit", 39)
    c.drawString(54, PAGE_H - 244, "End-to-End Overview")
    c.setFillColor(HexColor("#C4CEE0"))
    c.setFont("Manrope", 12)
    c.drawString(56, PAGE_H - 283, "Owner platform | Tenant application | Cloud workflow")
    c.setStrokeColor(HexColor("#3B5277"))
    c.line(56, 125, 450, 125)
    c.setFillColor(HexColor("#A8B7D0"))
    c.setFont("Manrope", 9)
    c.drawString(56, 100, "Presentation document")
    c.drawString(56, 83, "Prepared August 2026")
    c.setFont("Manrope", 7.5)
    c.drawRightString(PAGE_W - 42, 24, "HOMEOPS360.APP")
    end_page(c)


def page_system_overview(c, n):
    page_header(
        c,
        "Executive overview",
        "One connected workflow for owners and tenants",
        "The platform connects property setup, recurring billing, payment proof, service requests and reporting.",
        n,
    )
    top = PAGE_H - 112
    card_w = 226
    gap = 18
    x0 = 42
    draw_round_box(
        c, x0, top - 148, card_w, 148,
        "Owner / Property Agent",
        "- Create properties and tenant records<br/>- Configure leases and utility packages<br/>- Issue invoices and review payments<br/>- Handle requests and financial reporting",
        fill=PALE_BLUE, stroke=PALE_BLUE, accent=BLUE,
    )
    draw_round_box(
        c, x0 + card_w + gap, top - 148, card_w, 148,
        "HomeOps360 Cloud",
        "- Authentication and session restoration<br/>- Workspace snapshots and notifications<br/>- Secure invoice and media storage<br/>- Role-based access and audit history",
        fill=PALE_TEAL, stroke=PALE_TEAL, accent=TEAL,
    )
    draw_round_box(
        c, x0 + (card_w + gap) * 2, top - 148, card_w, 148,
        "Tenant",
        "- View amount due and invoice PDF<br/>- Upload payment proof<br/>- Track approval and receipt history<br/>- Submit requests and manage profile",
        fill=PALE_PURPLE, stroke=PALE_PURPLE, accent=PURPLE,
    )
    y = 150
    stages = [
        ("1", "Set up", "Property, tenant, lease"),
        ("2", "Bill", "Rent and utilities"),
        ("3", "Deliver", "App or token URL"),
        ("4", "Pay", "Transfer and proof"),
        ("5", "Review", "Approve or reject"),
        ("6", "Report", "History and export"),
    ]
    stage_w = 112
    stage_gap = 11
    for i, (num, title, body) in enumerate(stages):
        x = 42 + i * (stage_w + stage_gap)
        draw_step(c, x, y, stage_w, 102, num, title, body, [BLUE, TEAL, PURPLE, ORANGE, GREEN, BLUE_DARK][i])
        if i < len(stages) - 1:
            draw_arrow(c, x + stage_w, y + 51, x + stage_w + stage_gap - 2, y + 51, MUTED, 1.1)
    end_page(c)


def page_end_to_end(c, n):
    page_header(
        c,
        "End-to-end lifecycle",
        "How information moves between owner, system and tenant",
        "A monthly operational cycle from property setup through approved payment.",
        n,
    )
    left = 112
    lane_w = PAGE_W - left - 42
    lane_h = 112
    base_y = 68
    lanes = [
        ("TENANT", base_y, PALE_PURPLE, PURPLE),
        ("SYSTEM", base_y + lane_h + 12, PALE_TEAL, TEAL),
        ("OWNER", base_y + (lane_h + 12) * 2, PALE_BLUE, BLUE),
    ]
    for label, y, fill, accent in lanes:
        c.setFillColor(fill)
        c.roundRect(left, y, lane_w, lane_h, 12, fill=1, stroke=0)
        c.setFillColor(accent)
        c.setFont("Outfit", 10)
        c.drawRightString(left - 14, y + lane_h / 2 - 3, label)

    owner_y = lanes[2][1]
    system_y = lanes[1][1]
    tenant_y = lanes[0][1]
    xs = [140, 265, 390, 515, 640]
    owner_nodes = ["Create property", "Assign tenant", "Issue invoice", "Review proof", "Approve payment"]
    system_nodes = ["Store setup", "Create bill", "Publish PDF", "Notify owner", "Lock record"]
    tenant_nodes = ["Accept access", "View invoice", "Transfer funds", "Upload proof", "View receipt"]
    for i, x in enumerate(xs):
        for text, y, fill in [
            (owner_nodes[i], owner_y + 28, white),
            (system_nodes[i], system_y + 28, white),
            (tenant_nodes[i], tenant_y + 28, white),
        ]:
            c.setFillColor(fill)
            c.setStrokeColor(LINE)
            c.roundRect(x, y, 104, 52, 10, fill=1, stroke=1)
            draw_centered_text(c, text, x, y, 104, 52, size=8)
        if i < len(xs) - 1:
            for y in [owner_y + 54, system_y + 54, tenant_y + 54]:
                draw_arrow(c, x + 104, y, xs[i + 1] - 6, y, MUTED, 1)
    for x, y1, y2 in [
        (192, owner_y + 28, system_y + 80),
        (317, system_y + 28, tenant_y + 80),
        (567, tenant_y + 80, system_y + 28),
        (692, system_y + 80, owner_y + 28),
    ]:
        draw_arrow(c, x, y1, x, y2, BLUE_DARK, 1.3)
    draw_label(c, "persistent cloud state", PAGE_W - 190, 41, PALE_TEAL, GREEN, 140)
    end_page(c)


def page_onboarding(c, n):
    page_header(
        c,
        "Owner setup",
        "Property, tenancy and tenant onboarding",
        "The owner establishes the operational rules once; monthly workflows reuse the saved configuration.",
        n,
    )
    steps = [
        (1, "Create property", "Ready, developing or sold status"),
        (2, "Add tenant profile", "Identity, contact and address details"),
        (3, "Upload agreement", "Owner-attached tenancy document"),
        (4, "Configure lease", "Unit, dates, rent and deposit"),
        (5, "Set utilities", "Included, fixed, meter or tenant-borne"),
        (6, "Invite tenant", "Tenant creates secure cloud access"),
    ]
    x = 42
    y = 338
    box_w = 116
    gap = 10
    for i, (num, title, body) in enumerate(steps):
        draw_step(c, x + i * (box_w + gap), y, box_w, 108, num, title, body, BLUE if i < 3 else TEAL)
        if i < len(steps) - 1:
            draw_arrow(c, x + i * (box_w + gap) + box_w, y + 54, x + (i + 1) * (box_w + gap) - 2, y + 54, MUTED, 1)
    draw_round_box(
        c, 42, 126, 242, 162, "Property lifecycle",
        "<b>Ready</b><br/>Can host active tenancy and billing.<br/><br/><b>Developing</b><br/>Tracks progression costs until ready.<br/><br/><b>Sold</b><br/>Stops future commitments and active tenancy creation.",
        fill=WASH, stroke=LINE, accent=BLUE,
    )
    draw_round_box(
        c, 300, 126, 242, 162, "Tenant profile record",
        "Full name, email, WhatsApp / phone, original address, state, city, postcode, date of birth, sex, account status, assigned property, unit and lease period.",
        fill=WASH, stroke=LINE, accent=PURPLE,
    )
    draw_round_box(
        c, 558, 126, 242, 162, "Access safeguards",
        "- Invitation links bind access to the intended tenant.<br/>- Owner and tenant workspaces remain separated.<br/>- Temporary profile lookup failures do not force a false logout.<br/>- Missing or invalid profiles fail closed.",
        fill=WASH, stroke=LINE, accent=TEAL,
    )
    end_page(c)


def page_billing(c, n):
    page_header(
        c,
        "Monthly operations",
        "From tenancy rules to a complete invoice",
        "The system produces one eligible monthly billing workflow and applies the saved package rules.",
        n,
    )
    draw_round_box(c, 42, 370, 142, 82, "New billing month", "Create one workflow for each active tenancy.", fill=PALE_BLUE, stroke=PALE_BLUE, accent=BLUE)
    draw_arrow(c, 184, 411, 220, 411)
    draw_round_box(c, 220, 370, 142, 82, "Load tenancy", "Rent, utility package, parking and tariff.", fill=WASH, stroke=LINE, accent=BLUE)
    draw_arrow(c, 362, 411, 398, 411)
    draw_round_box(c, 398, 370, 142, 82, "Utility decision", "Determine whether owner evidence is required.", fill=PALE_ORANGE, stroke=PALE_ORANGE, accent=ORANGE)

    branches = [
        (42, 220, "Included", "Charge RM 0.00 and show as included."),
        (232, 220, "Fixed / excluded", "Apply the configured recurring amount."),
        (422, 220, "Meter-based", "Save reading, kWh, tariff and evidence."),
        (612, 220, "Tenant-borne", "Tenant settles externally; no evidence."),
    ]
    for x, y, title, body in branches:
        draw_round_box(c, x, y, 160, 92, title, body, fill=white, stroke=LINE, accent=[TEAL, PURPLE, ORANGE, GREEN][branches.index((x, y, title, body))])
        draw_arrow(c, 469, 370, x + 80, y + 92, MUTED, 1)

    draw_round_box(c, 220, 75, 402, 92, "Invoice total and PDF", "Combine rent, electricity, water, internet, parking and any configured charges. The owner reviews the itemized preview, confirms evidence and generates the PDF before delivery.", fill=NAVY, stroke=NAVY, accent=TEAL, title_style=CARD_TITLE_WHITE, body_style=BODY_WHITE)
    for x, _, _, _ in branches:
        draw_arrow(c, x + 80, 220, 421, 167, MUTED, 1)
    draw_label(c, "Approved months stay immutable", 628, 118, PALE_GREEN, GREEN, 165)
    end_page(c)


def page_invoice_delivery(c, n):
    page_header(
        c,
        "Invoice delivery",
        "Two delivery routes, one secure tenant record",
        "The owner can update the tenant app, send a WhatsApp token URL, or use both routes.",
        n,
    )
    draw_round_box(c, 315, 395, 212, 70, "Owner confirms invoice", "Reviewed PDF and total due", fill=NAVY, stroke=NAVY, accent=TEAL, title_style=CARD_TITLE_WHITE, body_style=BODY_WHITE)
    draw_arrow(c, 421, 395, 229, 332)
    draw_arrow(c, 421, 395, 612, 332)

    draw_round_box(c, 94, 248, 270, 84, "Route A - Update Tenant App", "Invoice appears in Pay > Pending. Authenticated tenants skip the separate phone verification page.", fill=PALE_BLUE, stroke=PALE_BLUE, accent=BLUE)
    draw_round_box(c, 478, 248, 270, 84, "Route B - WhatsApp URL", "A tokenized URL is prepared. The tenant verifies the final four registered phone digits before access.", fill=PALE_TEAL, stroke=PALE_TEAL, accent=TEAL)

    draw_arrow(c, 229, 248, 229, 190)
    draw_arrow(c, 613, 248, 613, 190)
    draw_round_box(c, 94, 104, 270, 86, "Tenant app experience", "Open invoice PDF, review breakdown, select Pay now and return with browser Back when needed.", fill=white, stroke=LINE, accent=PURPLE)
    draw_round_box(c, 478, 104, 270, 86, "Secure portal experience", "The link normally remains valid for 72 hours. The owner can renew an expired link without changing the invoice.", fill=white, stroke=LINE, accent=ORANGE)
    draw_arrow(c, 364, 147, 478, 147, MUTED, 1)
    draw_label(c, "Same invoice record and server PDF", 309, 62, PALE_PURPLE, PURPLE, 224)
    end_page(c)


def page_payment_lifecycle(c, n):
    page_header(
        c,
        "Payment lifecycle",
        "A clear state machine with complete review history",
        "HomeOps360 records evidence and decisions; the actual bank transfer happens outside the platform.",
        n,
    )
    states = [
        (42, 348, 128, 72, "Not submitted", "Invoice not yet delivered", MUTED, WASH),
        (202, 348, 128, 72, "Pending Payment", "Tenant action required", BLUE, PALE_BLUE),
        (362, 348, 128, 72, "Pending Review", "Proof received", ORANGE, PALE_ORANGE),
        (522, 348, 128, 72, "Approved", "Locked and reported", GREEN, PALE_GREEN),
        (362, 190, 128, 72, "Rejected", "Reason returned", RED, PALE_RED),
    ]
    for x, y, w, h, title, body, accent, fill in states:
        draw_round_box(c, x, y, w, h, title, body, fill=fill, stroke=fill, accent=accent)
    draw_arrow(c, 170, 384, 202, 384, BLUE)
    draw_arrow(c, 330, 384, 362, 384, ORANGE)
    draw_arrow(c, 490, 384, 522, 384, GREEN)
    draw_arrow(c, 426, 348, 426, 262, RED)
    draw_arrow(c, 362, 226, 266, 348, BLUE)
    # Keep transition captions above the state cards so they remain readable
    # without covering the state titles.
    draw_label(c, "owner issues", 170, 426, PALE_BLUE, BLUE_DARK, 76)
    draw_label(c, "tenant submits", 326, 426, PALE_ORANGE, ORANGE, 84)
    draw_label(c, "owner approves", 486, 426, PALE_GREEN, GREEN, 86)
    draw_label(c, "owner rejects", 438, 295, PALE_RED, RED, 80)
    draw_label(c, "correct and resubmit", 267, 283, PALE_BLUE, BLUE_DARK, 100)

    draw_round_box(c, 682, 285, 118, 135, "Payment proof", "- JPG, PNG or PDF<br/>- Amount paid<br/>- Payment date<br/>- Optional reference<br/>- Original attempts retained", fill=WASH, stroke=LINE, accent=PURPLE)
    draw_round_box(c, 42, 92, 758, 70, "Approval outcome", "Approved invoices leave every pending queue, remain visible in tenant receipt history, appear in owner collection reports and cannot be edited or sent again. Rejected invoices return to tenant action while preserving the earlier attempt and rejection reason.", fill=NAVY, stroke=NAVY, accent=TEAL, title_style=CARD_TITLE_WHITE, body_style=BODY_WHITE)
    end_page(c)


def page_tenant_tabs(c, n):
    page_header(
        c,
        "Tenant experience",
        "Five tabs organized around the tenant's daily tasks",
        "The tenant sees only their own tenancy, payments, requests and profile information.",
        n,
    )
    cards = [
        (42, 310, 238, 146, "Home", "Amount due, property and unit, Pay now, active requests, yearly billing bar and monthly invoice breakdown pie.", BLUE, PALE_BLUE),
        (302, 310, 238, 146, "Explore", "Future room marketplace. The feed is currently closed for maintenance while owners and agents prepare listings.", PURPLE, PALE_PURPLE),
        (562, 310, 238, 146, "Pay", "Pending invoices, invoice PDF, payment upload, receipt history, year filter, search and expand / collapse.", TEAL, PALE_TEAL),
        (172, 124, 238, 146, "Requests", "Floating plus action, active requests, owner updates and resolved history for maintenance or assistance.", ORANGE, PALE_ORANGE),
        (432, 124, 238, 146, "Profile", "Complete personal data, edit profile, agreement viewer, language, backup, Help and Q&A, About and logout.", GREEN, PALE_GREEN),
    ]
    for x, y, w, h, title, body, accent, fill in cards:
        draw_round_box(c, x, y, w, h, title, body, fill=fill, stroke=fill, accent=accent)
    draw_label(c, "English", 685, 147, PALE_BLUE, BLUE_DARK, 70)
    draw_label(c, "Chinese", 685, 175, PALE_PURPLE, PURPLE, 70)
    draw_label(c, "Bahasa Melayu", 685, 203, PALE_TEAL, GREEN, 90)
    end_page(c)


def page_owner_platform(c, n):
    page_header(
        c,
        "Owner platform",
        "Operational control without losing audit history",
        "Full-access owners manage data; observers can review but cannot mutate financial or operational records.",
        n,
    )
    center_x, center_y = 350, 225
    c.setFillColor(NAVY)
    c.roundRect(center_x, center_y, 142, 92, 18, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Outfit", 17)
    c.drawCentredString(center_x + 71, center_y + 54, "Owner workspace")
    c.setFont("Manrope", 8)
    c.drawCentredString(center_x + 71, center_y + 34, "One operational source of truth")
    modules = [
        (44, 365, "Dashboard", "Due, collected and operational ratios", BLUE),
        (232, 365, "Properties", "Ready, developing and sold facilities", TEAL),
        (420, 365, "Tenants", "Profiles, leases and agreements", PURPLE),
        (608, 365, "Billing", "Rent, utilities, evidence and PDF", ORANGE),
        (44, 92, "Payments", "Approval, rejection and audit trail", GREEN),
        (232, 92, "Requests", "Tenant assistance workflow", ORANGE),
        (420, 92, "Reports", "Collections, costs and commitments", BLUE_DARK),
        (608, 92, "Explore", "Draft, publish and promote listings", PURPLE),
    ]
    for x, y, title, body, accent in modules:
        draw_round_box(c, x, y, 160, 82, title, body, fill=WASH, stroke=LINE, accent=accent)
        sx = x + 80
        sy = y if y > center_y else y + 82
        tx = center_x + 71
        ty = center_y + 92 if y > center_y else center_y
        draw_arrow(c, sx, sy, tx, ty, MUTED, 0.9)
    draw_label(c, "Full access", 350, 198, PALE_BLUE, BLUE_DARK, 68)
    draw_label(c, "Observer: view only", 427, 198, PALE_ORANGE, ORANGE, 102)
    end_page(c)


def page_requests_notifications(c, n):
    page_header(
        c,
        "Service operations",
        "Requests and notifications keep both sides aligned",
        "Operational events generate visible work queues rather than relying only on chat messages.",
        n,
    )
    req_steps = [
        (1, "Tenant creates", "Select plus and describe the issue"),
        (2, "Active queue", "Request appears in tenant and owner views"),
        (3, "Owner handles", "Review, respond and update status"),
        (4, "Resolved", "Move to history for future reference"),
    ]
    for i, (num, title, body) in enumerate(req_steps):
        x = 42 + i * 190
        draw_step(c, x, 338, 166, 104, num, title, body, [PURPLE, BLUE, ORANGE, GREEN][i])
        if i < 3:
            draw_arrow(c, x + 166, 390, x + 188, 390, MUTED, 1)
    draw_round_box(c, 42, 110, 360, 170, "Notification triggers", "- Monthly invoice becomes ready<br/>- Owner issues or renews an invoice<br/>- Tenant submits payment proof<br/>- Owner approves or rejects payment<br/>- Tenant creates a service request<br/>- Owner updates or resolves a request<br/>- Tenant access or profile state changes", fill=PALE_BLUE, stroke=PALE_BLUE, accent=BLUE)
    draw_round_box(c, 438, 110, 362, 170, "What each notification preserves", "- Read / unread state<br/>- Event category and source<br/>- Related tenant, invoice or request<br/>- Time of the event<br/>- Owner and tenant visibility rules<br/><br/>Realtime updates improve responsiveness while persisted history remains the source of truth.", fill=PALE_TEAL, stroke=PALE_TEAL, accent=TEAL)
    end_page(c)


def page_explore(c, n):
    page_header(
        c,
        "Explore marketplace",
        "Prepare inventory now; publish to tenants when the feed reopens",
        "Owners and property agents can manage cross-owner room listings and choose promoted placement.",
        n,
    )
    steps = [
        (1, "Create listing", "Use an existing facility or enter a new room"),
        (2, "Add details", "Photos, rent, deposit, location and availability"),
        (3, "Set status", "Draft, published, rented or archived"),
        (4, "Promote", "Featured posts sort before standard listings"),
        (5, "Tenant enquiry", "Open details and contact the publisher"),
    ]
    for i, (num, title, body) in enumerate(steps):
        x = 42 + i * 151
        draw_step(c, x, 332, 132, 112, num, title, body, [BLUE, TEAL, PURPLE, ORANGE, GREEN][i])
        if i < 4:
            draw_arrow(c, x + 132, 388, x + 148, 388, MUTED, 1)
    draw_round_box(c, 42, 122, 370, 150, "Current tenant experience", "Explore is visibly marked as under maintenance. Tenants are informed that owners can continue preparing and promoting other available properties. No incomplete marketplace experience is exposed as a working feed.", fill=PALE_ORANGE, stroke=PALE_ORANGE, accent=ORANGE)
    draw_round_box(c, 430, 122, 370, 150, "Data and publishing safeguards", "- Only signed-in owners or property agents can publish.<br/>- Publishers manage their own drafts and listings.<br/>- Signed-in tenants see published listings when reopened.<br/>- Listing images use protected storage.<br/>- Featured status affects sorting, not ownership or access.", fill=PALE_PURPLE, stroke=PALE_PURPLE, accent=PURPLE)
    end_page(c)


def page_architecture(c, n):
    page_header(
        c,
        "Data architecture",
        "Cloud continuity with local resilience",
        "Authentication, workspace data, media files and notifications remain separate but coordinated.",
        n,
    )
    layers = [
        (330, 405, 182, 54, "Owner and Tenant UI", NAVY, white),
        (230, 316, 382, 58, "Application state and business rules", BLUE, white),
        (100, 214, 196, 62, "Local persistence", PALE_BLUE, NAVY),
        (323, 214, 196, 62, "Supabase cloud workspace", PALE_TEAL, NAVY),
        (546, 214, 196, 62, "Storage and PDF portal", PALE_PURPLE, NAVY),
        (100, 112, 196, 62, "Session recovery", WASH, NAVY),
        (323, 112, 196, 62, "Realtime notifications", WASH, NAVY),
        (546, 112, 196, 62, "Role and row policies", WASH, NAVY),
    ]
    for x, y, w, h, text, fill, color in layers:
        c.setFillColor(fill)
        c.setStrokeColor(LINE if fill in [WASH, PALE_BLUE, PALE_TEAL, PALE_PURPLE] else fill)
        c.roundRect(x, y, w, h, 12, fill=1, stroke=1)
        draw_centered_text(c, text, x, y, w, h, "Outfit", 10.2, color)
    draw_arrow(c, 421, 405, 421, 374, TEAL)
    for x in [198, 421, 644]:
        draw_arrow(c, 421, 316, x, 276, MUTED, 1)
    for x in [198, 421, 644]:
        draw_arrow(c, x, 214, x, 174, MUTED, 1)
    draw_label(c, "Temporary lookup failure does not equal logout", 287, 73, PALE_GREEN, GREEN, 268)
    end_page(c)


def page_exports(c, n):
    page_header(
        c,
        "Reporting and backup",
        "Useful exports with role-specific boundaries",
        "Owner reporting is broad; tenant exports are deliberately restricted to the signed-in tenant.",
        n,
    )
    draw_round_box(c, 42, 180, 360, 278, "Owner export scope", "<b>Operational records</b><br/>Properties, tenants, tenancies, requests and payment reviews.<br/><br/><b>Financial records</b><br/>Invoices, collections, expenses, commitments and dashboard summaries.<br/><br/><b>Formats</b><br/>Detailed Excel workbook, Excel backup summary, CSV and SQLite-style backup.", fill=PALE_BLUE, stroke=PALE_BLUE, accent=BLUE)
    draw_round_box(c, 440, 180, 360, 278, "Tenant export scope", "<b>Included</b><br/>Own profile, tenancy, invoices, payments, requests and payment-review history.<br/><br/><b>Excluded</b><br/>Other tenants, owner expenses, owner commitments, private owner financial information and unrelated property records.<br/><br/><b>Formats</b><br/>Tenant Excel workbook and SQLite-style backup.", fill=PALE_TEAL, stroke=PALE_TEAL, accent=TEAL)
    draw_round_box(c, 42, 82, 758, 64, "Audit principle", "Exports provide portable copies, but the application retains the operational status transitions that explain when an invoice was issued, when proof was submitted, and how the owner decided.", fill=NAVY, stroke=NAVY, accent=PURPLE, title_style=CARD_TITLE_WHITE, body_style=BODY_WHITE)
    end_page(c)


def page_boundaries(c, n):
    page_header(
        c,
        "Product boundaries",
        "What HomeOps360 does today - and what is separately customized",
        "A clear boundary prevents users from assuming the platform performs banking or device functions that require separate integrations.",
        n,
    )
    draw_round_box(c, 42, 175, 360, 285, "Core application capabilities", "- Property and tenancy administration<br/>- Rent and utility invoice calculation<br/>- Meter reading evidence and tariff workflow<br/>- Generated and server-retrievable invoice PDF<br/>- App and WhatsApp token delivery routes<br/>- Payment-proof submission and owner review<br/>- Requests, notifications, reporting and backup<br/>- Owner-managed Explore listing preparation", fill=PALE_GREEN, stroke=PALE_GREEN, accent=GREEN)
    draw_round_box(c, 440, 175, 360, 285, "Not performed by the core app", "- Holding tenant funds<br/>- Executing a bank transfer<br/>- Confirming a bank settlement without owner review<br/>- Replacing the bank receipt or tenancy agreement<br/>- Direct Xiaomi Home or Tuya device control<br/>- Automatic hardware installation without a site assessment", fill=PALE_ORANGE, stroke=PALE_ORANGE, accent=ORANGE)
    draw_round_box(c, 42, 80, 758, 64, "Customization services", "Xiaomi Home, Tuya and meter-reading hardware installation are offered as scoped extensions. The current core app supports manual readings, evidence and bill calculation; direct device automation depends on compatible hardware, regional APIs and an agreed implementation scope.", fill=NAVY, stroke=NAVY, accent=TEAL, title_style=CARD_TITLE_WHITE, body_style=BODY_WHITE)
    end_page(c)


def closing_page(c, n):
    c.setFillColor(NAVY)
    c.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    c.setFillColor(BLUE_DARK)
    c.circle(PAGE_W - 90, PAGE_H - 20, 190, fill=1, stroke=0)
    if LOGO.exists():
        c.drawImage(ImageReader(str(LOGO)), 55, PAGE_H - 115, 58, 58, mask="auto")
    c.setFillColor(white)
    c.setFont("Outfit", 30)
    c.drawString(55, PAGE_H - 180, "One workflow. Clear accountability.")
    c.setFillColor(TEAL)
    c.setFont("Outfit", 30)
    c.drawString(55, PAGE_H - 220, "Complete operational history.")
    c.setFillColor(HexColor("#C4CEE0"))
    draw_paragraph(
        c,
        "HomeOps360 connects owner setup, tenant access, monthly billing, invoice delivery, payment evidence, approval, requests and reporting without hiding who must take the next action.",
        58,
        PAGE_H - 315,
        550,
        65,
        ParagraphStyle("closing", parent=BODY_WHITE, fontSize=12, leading=17),
    )
    draw_label(c, "Owner platform", 58, 158, HexColor("#21385F"), white, 104)
    draw_label(c, "Tenant application", 174, 158, HexColor("#21385F"), white, 112)
    draw_label(c, "Cloud continuity", 298, 158, HexColor("#21385F"), white, 105)
    c.setFillColor(HexColor("#A8B7D0"))
    c.setFont("Manrope", 8)
    c.drawString(58, 89, "homeops360.app")
    c.drawRightString(PAGE_W - 42, 24, f"{n:02d}")
    end_page(c)


def build_pdf() -> Path:
    register_fonts()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUTPUT), pagesize=(PAGE_W, PAGE_H), pageCompression=1)
    c.setTitle("HomeOps360 Application Workflow")
    c.setAuthor("HomeOps360")
    c.setSubject("Owner platform, tenant application and cloud workflow overview")
    cover_page(c)
    page_system_overview(c, 2)
    page_end_to_end(c, 3)
    page_onboarding(c, 4)
    page_billing(c, 5)
    page_invoice_delivery(c, 6)
    page_payment_lifecycle(c, 7)
    page_tenant_tabs(c, 8)
    page_owner_platform(c, 9)
    page_requests_notifications(c, 10)
    page_explore(c, 11)
    page_architecture(c, 12)
    page_exports(c, 13)
    page_boundaries(c, 14)
    closing_page(c, 15)
    c.save()
    return OUTPUT


if __name__ == "__main__":
    print(build_pdf())
