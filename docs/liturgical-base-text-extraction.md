# OpenBook base liturgy import

The bundled Divine Liturgy texts come from the three approved OpenBook pages:

- `https://www.openbook.gr/theia-leitoyrgia-iwannou-chrysostomou/`
- `https://www.openbook.gr/theia-leitoyrgia-tou-megalou-vasileiou/`
- `https://www.openbook.gr/theia-leitoyrgia-twn-proigiasmenwn-dwrwn/`

Their linked PDFs are stored under `data/sources/liturgical/openbook`. Rebuild
the canonical and app-bundled JSON with:

```sh
python3 scripts/liturgical/import-openbook-liturgies.py
python3 -m unittest discover -s tests/liturgical -p 'test_*.py'
```

The importer uses the PDFs' embedded text through local macOS PDFKit. The
Chrysostom source contains original text and a modern translation in two
columns; extraction is restricted to the original left column. No modern
translation is included in the generated JSON.

Each liturgy is split into major sections and speaker/rubric blocks. Speaker
labels are normalized only for rendering (`Ἱερεύς`, `Διάκονος`, `Χορός`,
`Ψάλτης`, `Λαός`, `Ἀναγνώστης`); the spoken Greek is not translated or placed
inside SwiftUI code.

Chrysostom and Basil contain `{{APOSTLE}}` and `{{GOSPEL}}` blocks. The
assembler asks the bundled/current `ScriptureStore` for the Gospel passage. If
the complete passage is unavailable, it displays the resolved reference and
does not use the network. Presanctified retains its own readings structure and
is not selected for Sunday Divine Liturgy.
