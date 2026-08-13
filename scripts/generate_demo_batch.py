#!/usr/bin/env python3
"""
Generate a demo SFTP batch with professional emails + PDF attachments.

Usage:
    cd scripts && source .venv/bin/activate && python generate_demo_batch.py [COUNT] [--company NAME] [--from EMAIL] [--output DIR]

Defaults to 50 emails for TicoMailWorks.

Output:
    scripts/demo_batch/  (ready to upload to SFTP)
"""

import argparse
import base64
import os
import random
import shutil
import uuid
from datetime import datetime, timedelta

from fpdf import FPDF

DEFAULT_COUNT = 50
DEFAULT_COMPANY = "Tico Mail Works"
DEFAULT_FROM = "noreply@ticomailworks.commmate.com"
DEFAULT_OUTPUT = os.path.join(os.path.dirname(__file__), "demo_batch")

BATCH_ID = str(uuid.uuid4())

def build_recipients(count):
    recipients = ["schimuneck.matias@gmail.com"]
    for i in range(1, count):
        recipients.append(f"schimuneck.matias+demo{i}@gmail.com")
    return recipients

CUSTOMER_NAMES = [
    "María García López", "Carlos Rodríguez Mora", "Ana Sofía Jiménez",
    "José Luis Hernández", "Laura Fernández Ruiz", "Diego Morales Vargas",
    "Valentina Castro Solano", "Andrés Rojas Campos", "Gabriela Vega Méndez",
    "Fernando Arias Navarro", "Isabella Cordero Blanco", "Roberto Salazar Monge",
    "Camila Durán Aguilar", "Eduardo Brenes Soto", "Daniela Chaves Ureña",
    "Alejandro Montero Picado", "Lucía Ramírez Alfaro", "Sebastián Mora Quesada",
    "Paula Herrera Villalobos", "Ricardo Zúñiga Araya", "Natalia Solís Esquivel",
    "Miguel Ángel Barrantes", "Valeria Céspedes Vindas", "David Calderón Fonseca",
    "Adriana Murillo Chinchilla", "Óscar Porras Sandoval", "Elena Trejos Mena",
    "Luis Alberto Guzmán", "Mariana Acuña Badilla", "Jorge Madrigal Valverde",
    "Andrea Camacho Corrales", "Tomás Ledezma Ulate", "Sofía Bonilla Arce",
    "Rafael Cascante Pereira", "Carolina Gamboa Segura", "Esteban Molina Retana",
    "Diana Salas Zeledón", "Francisco Delgado Piedra", "Vanessa Arguedas Sáenz",
    "Manuel Quirós Orozco", "Melissa Solano Abarca", "Rodrigo Elizondo Chacón",
    "Paola Hidalgo Mesén", "Sergio Varela Granados", "Alejandra Paniagua Bermúdez",
    "Cristian Leiva Robles", "Nicole Montes de Oca", "Arturo Sanabria Lobo",
    "Karina Bogantes Gutiérrez", "Fabián Arguello Venegas",
]

SCENARIOS = [
    {
        "category": "Hospital Billing",
        "company": "Hospital Clínica Bíblica",
        "subject_tpl": "Your Medical Statement — {ref}",
        "doc_title": "Patient Statement",
        "color": "#1a5276",
        "accent": "#2e86c1",
    },
    {
        "category": "Insurance",
        "company": "INS — Instituto Nacional de Seguros",
        "subject_tpl": "Insurance Policy Document — {ref}",
        "doc_title": "Policy Certificate",
        "color": "#1b4f72",
        "accent": "#2874a6",
    },
    {
        "category": "Utility Bill",
        "company": "ICE — Instituto Costarricense de Electricidad",
        "subject_tpl": "Your Monthly Electricity Bill — {ref}",
        "doc_title": "Monthly Bill",
        "color": "#196f3d",
        "accent": "#27ae60",
    },
    {
        "category": "Banking",
        "company": "Banco Nacional de Costa Rica",
        "subject_tpl": "Account Statement — {ref}",
        "doc_title": "Account Statement",
        "color": "#7d3c98",
        "accent": "#a569bd",
    },
    {
        "category": "Government",
        "company": "Municipalidad de San José",
        "subject_tpl": "Municipal Tax Notice — {ref}",
        "doc_title": "Tax Notice",
        "color": "#b9770e",
        "accent": "#d4ac0d",
    },
]

random.seed(42)

def ref_number():
    return f"TMW-{random.randint(100000, 999999)}"


def amount():
    return f"CRC {random.randint(15000, 850000):,.2f}"


def due_date():
    d = datetime.now() + timedelta(days=random.randint(7, 45))
    return d.strftime("%B %d, %Y")


def build_html_body(scenario, customer, ref, amt, due):
    cat = scenario["category"]
    company = scenario["company"]
    color = scenario["color"]
    accent = scenario["accent"]

    return f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#f4f4f7;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f7;padding:40px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">

  <!-- Header -->
  <tr>
    <td style="background:{color};padding:32px 40px;">
      <h1 style="color:#ffffff;margin:0;font-size:22px;font-weight:600;">{company}</h1>
      <p style="color:rgba(255,255,255,0.8);margin:8px 0 0;font-size:13px;">{cat} — Document Delivery</p>
    </td>
  </tr>

  <!-- Body -->
  <tr>
    <td style="padding:40px;">
      <p style="color:#333;font-size:15px;line-height:1.6;margin:0 0 20px;">
        Dear <strong>{customer}</strong>,
      </p>
      <p style="color:#555;font-size:14px;line-height:1.6;margin:0 0 24px;">
        Please find attached your <strong>{scenario['doc_title']}</strong> for your records.
        Below is a summary of the key details:
      </p>

      <!-- Details table -->
      <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 28px;border:1px solid #e8e8e8;border-radius:6px;overflow:hidden;">
        <tr style="background:#f8f9fa;">
          <td style="padding:12px 16px;font-size:13px;color:#666;border-bottom:1px solid #e8e8e8;">Reference</td>
          <td style="padding:12px 16px;font-size:13px;color:#333;font-weight:600;border-bottom:1px solid #e8e8e8;text-align:right;">{ref}</td>
        </tr>
        <tr>
          <td style="padding:12px 16px;font-size:13px;color:#666;border-bottom:1px solid #e8e8e8;">Amount</td>
          <td style="padding:12px 16px;font-size:13px;color:#333;font-weight:600;border-bottom:1px solid #e8e8e8;text-align:right;">{amt}</td>
        </tr>
        <tr style="background:#f8f9fa;">
          <td style="padding:12px 16px;font-size:13px;color:#666;border-bottom:1px solid #e8e8e8;">Due Date</td>
          <td style="padding:12px 16px;font-size:13px;color:#333;font-weight:600;border-bottom:1px solid #e8e8e8;text-align:right;">{due}</td>
        </tr>
        <tr>
          <td style="padding:12px 16px;font-size:13px;color:#666;">Document</td>
          <td style="padding:12px 16px;font-size:13px;color:{accent};font-weight:600;text-align:right;">📎 See attached PDF</td>
        </tr>
      </table>

      <p style="color:#555;font-size:14px;line-height:1.6;margin:0 0 28px;">
        If you have any questions about this document, please don't hesitate to contact us.
        This email was delivered securely through TicoMailWorks.
      </p>

      <!-- CTA -->
      <table cellpadding="0" cellspacing="0">
        <tr>
          <td style="background:{accent};border-radius:6px;padding:12px 28px;">
            <span style="color:#ffffff;font-size:14px;font-weight:600;text-decoration:none;">View Your Account Online</span>
          </td>
        </tr>
      </table>
    </td>
  </tr>

  <!-- Footer -->
  <tr>
    <td style="background:#f8f9fa;padding:24px 40px;border-top:1px solid #e8e8e8;">
      <p style="color:#999;font-size:12px;line-height:1.5;margin:0;">
        This is an automated message sent on behalf of <strong>{company}</strong>
        via TicoMailWorks document delivery platform.<br>
        Powered by CommMate &bull; Secure Email Dispatch
      </p>
    </td>
  </tr>

</table>
</td></tr>
</table>
</body>
</html>"""


def safe_latin1(text):
    """Replace characters outside latin-1 range for Helvetica compatibility."""
    return text.encode("latin-1", errors="replace").decode("latin-1")


def build_pdf(scenario, customer, ref, amt, due, pdf_path):
    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=20)

    color_hex = scenario["color"].lstrip("#")
    r, g, b = int(color_hex[:2], 16), int(color_hex[2:4], 16), int(color_hex[4:6], 16)

    customer_safe = safe_latin1(customer)
    company_safe = safe_latin1(scenario["company"])

    # Header bar
    pdf.set_fill_color(r, g, b)
    pdf.rect(0, 0, 210, 40, "F")

    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Helvetica", "B", 18)
    pdf.set_xy(15, 10)
    pdf.cell(w=0, h=10, text=company_safe, new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.set_x(15)
    pdf.cell(w=0, h=6, text=f"{scenario['doc_title']}  |  {ref}")

    # Document body
    pdf.set_y(55)
    pdf.set_text_color(50, 50, 50)

    pdf.set_font("Helvetica", "", 10)
    pdf.cell(w=0, h=8, text=f"Date: {datetime.now().strftime('%B %d, %Y')}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)

    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(w=0, h=8, text=customer_safe, new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(w=0, h=6, text=f"Reference: {ref}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(10)

    # Divider
    pdf.set_draw_color(r, g, b)
    pdf.set_line_width(0.5)
    pdf.line(15, pdf.get_y(), 195, pdf.get_y())
    pdf.ln(8)

    # Summary section
    pdf.set_font("Helvetica", "B", 14)
    pdf.set_text_color(r, g, b)
    pdf.cell(w=0, h=10, text="Document Summary", new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(50, 50, 50)
    pdf.ln(4)

    # Table header
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_fill_color(240, 240, 245)
    pdf.cell(90, 10, "Description", border=1, fill=True)
    pdf.cell(w=90, h=10, text="Details", border=1, fill=True, new_x="LMARGIN", new_y="NEXT")

    rows = [
        ("Document Type", scenario["doc_title"]),
        ("Reference Number", ref),
        ("Recipient", customer_safe),
        ("Amount Due", amt),
        ("Due Date", due),
        ("Issuing Organization", company_safe),
        ("Delivery Method", "Secure Email - TicoMailWorks"),
        ("Status", "Original Document"),
    ]

    pdf.set_font("Helvetica", "", 10)
    for label, value in rows:
        pdf.cell(90, 9, f"  {label}", border=1)
        pdf.cell(w=90, h=9, text=f"  {value}", border=1, new_x="LMARGIN", new_y="NEXT")

    pdf.ln(12)

    # Terms / notice
    pdf.set_font("Helvetica", "B", 11)
    pdf.set_text_color(r, g, b)
    pdf.cell(w=0, h=8, text="Important Notice", new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(80, 80, 80)
    pdf.set_font("Helvetica", "", 9)
    notice = safe_latin1(
        "This document has been generated and delivered electronically through "
        "TicoMailWorks secure document delivery platform on behalf of "
        f"{scenario['company']}. The information contained herein is confidential "
        "and intended solely for the addressee. If you are not the intended "
        "recipient, please disregard this document and notify the sender. "
        f"For questions regarding this {scenario['doc_title'].lower()}, "
        f"please contact {scenario['company']} directly."
    )
    pdf.multi_cell(0, 5, notice)

    pdf.ln(10)

    # Barcode-style reference
    pdf.set_font("Courier", "", 8)
    pdf.set_text_color(150, 150, 150)
    pdf.cell(w=0, h=5, text=f"DOC-ID: {ref}  |  BATCH: {BATCH_ID[:8]}  |  GENERATED: {datetime.now().isoformat()}", new_x="LMARGIN", new_y="NEXT", align="C")

    # Footer bar
    pdf.set_fill_color(r, g, b)
    pdf.rect(0, 277, 210, 20, "F")
    pdf.set_xy(15, 280)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Helvetica", "", 8)
    pdf.cell(0, 5, "Powered by TicoMailWorks  |  Secure Document Delivery  |  CommMate Platform", align="C")

    pdf.output(pdf_path)


def build_mtr(job_id, customer, recipient, subject, html_body, mtr_path):
    build_mtr_with_config(job_id, customer, recipient, subject, html_body, mtr_path, DEFAULT_COMPANY, DEFAULT_FROM)


def build_mtr_with_config(job_id, customer, recipient, subject, html_body, mtr_path, company_name, from_email):
    body_b64 = base64.b64encode(html_body.encode("utf-8")).decode("ascii")
    xml = f"""<?xml version="1.0"?>
<Root>
  <JobID>{job_id}</JobID>
  <MainJobID>{BATCH_ID}</MainJobID>
  <JobName>{customer.replace(' ', '_')}.pdf</JobName>
  <JobReference>Demo Batch</JobReference>
  <Pages>1</Pages>
  <UserName>demo.operator</UserName>
  <CompanyName>{company_name}</CompanyName>
  <CompanyID>1</CompanyID>
  <DepartmentName>Document Delivery</DepartmentName>
  <BatchID>{BATCH_ID}</BatchID>
  <EmailOptions>
    <From>{from_email}</From>
    <ToEmail>{recipient}</ToEmail>
    <Subject>{subject}</Subject>
    <Body>{body_b64}</Body>
  </EmailOptions>
</Root>"""
    with open(mtr_path, "w") as f:
        f.write(xml)


def build_tkt(entries, tkt_path):
    """Build the Email.tkt pipe-delimited manifest."""
    lines = []
    for e in entries:
        lines.append("|".join([
            e["job_id"], e["customer"], e["recipient"],
            e["subject"], "1", datetime.now().isoformat(),
        ]))
    with open(tkt_path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description="Generate SFTP demo batch")
    parser.add_argument("count", nargs="?", type=int, default=DEFAULT_COUNT, help="Number of emails to generate")
    parser.add_argument("--company", default=DEFAULT_COMPANY, help="CompanyName in .mtr files")
    parser.add_argument("--from-email", default=DEFAULT_FROM, dest="from_email", help="From email address")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="Output directory")
    args = parser.parse_args()

    count = args.count
    company_name = args.company
    from_email = args.from_email
    batch_dir = args.output

    recipients = build_recipients(count)

    if os.path.exists(batch_dir):
        shutil.rmtree(batch_dir)
    os.makedirs(batch_dir)

    tkt_entries = []
    pad = len(str(count))

    for i in range(count):
        scenario = SCENARIOS[i % len(SCENARIOS)]
        customer = CUSTOMER_NAMES[i % len(CUSTOMER_NAMES)]
        recipient = recipients[i]
        ref = ref_number()
        amt = amount()
        due = due_date()

        job_id = str(uuid.uuid4())
        subject = scenario["subject_tpl"].format(ref=ref)
        base_name = f"email_{i + 1:0{pad}d}"

        html = build_html_body(scenario, customer, ref, amt, due)
        mtr_path = os.path.join(batch_dir, f"{base_name}.mtr")
        pdf_path = os.path.join(batch_dir, f"{base_name}.pdf")

        build_mtr_with_config(job_id, customer, recipient, subject, html, mtr_path, company_name, from_email)
        build_pdf(scenario, customer, ref, amt, due, pdf_path)

        tkt_entries.append({
            "job_id": job_id,
            "customer": customer,
            "recipient": recipient,
            "subject": subject,
        })

        print(f"  [{i + 1:>{pad}}/{count}] {base_name}  →  {recipient}  ({scenario['category']})")

    build_tkt(tkt_entries, os.path.join(batch_dir, "Email.tkt"))

    total_size = sum(
        os.path.getsize(os.path.join(batch_dir, f))
        for f in os.listdir(batch_dir)
    )
    file_count = len(os.listdir(batch_dir))

    print(f"\n✓ Generated {file_count} files in {batch_dir}/")
    print(f"  {count} .mtr + {count} .pdf + 1 Email.tkt = {total_size / 1024:.0f} KB total")
    print(f"  BatchID: {BATCH_ID}")
    print(f"  From:    {from_email}")
    print(f"  Company: {company_name}")


if __name__ == "__main__":
    main()
