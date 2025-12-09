import fitz  # PyMuPDF (install with: pip install pymupdf)

# Open the PDF
pdf_path = "issuepaper-contingecymodelingenhancements_copy.pdf"
doc = fitz.open(pdf_path)

# Figure 2 is on page 11 (index 10)
page = doc[10]

# Define the crop rectangle for Figure 2
# These coordinates capture the Security Framework diagram
crop_rect = fitz.Rect(80, 360, 540, 680)

# Create a new PDF for the output
output_pdf = fitz.open()

# Extract at high resolution (3x scaling)
mat = fitz.Matrix(3, 3)
pix = page.get_pixmap(clip=crop_rect, matrix=mat)

# Create new page sized to match the extracted image
new_page = output_pdf.new_page(width=pix.width, height=pix.height)

# Insert the image
new_page.insert_image(new_page.rect, pixmap=pix)

# Save the output PDF
output_pdf.save("Figure2_Security_Framework.pdf")
output_pdf.close()
doc.close()

print("Figure 2 extracted successfully to Figure2_Security_Framework.pdf")