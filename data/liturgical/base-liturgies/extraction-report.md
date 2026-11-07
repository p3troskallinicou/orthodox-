# OpenBook liturgy import report

The three canonical JSON files were generated from the PDFs linked by the
approved OpenBook pages. Extraction used local macOS PDFKit embedded text.

- Chrysostom: 29-page two-column PDF; pages 3–29, original left column only.
- Basil: 22-page original Greek PDF.
- Presanctified: 22-page original Greek PDF.

Output is split into liturgical sections and speaker/rubric blocks. No
liturgical body text is hardcoded in Swift. Chrysostom and Basil readings
sections contain `{{APOSTLE}}` and `{{GOSPEL}}`; Presanctified keeps the source
readings structure and is not selected by the Sunday resolver.
