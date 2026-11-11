# Saint quote image sharing

The native gallery uses the reviewed tall portrait treatment for paired cards. Gallery and feed sharing controls sit below the unchanged heart. The opened reader includes sharing in its top toolbar so its existing bottom controls retain their spacing. Quotes, categories, sources, favorites and photo assets are unchanged.

Selecting Share opens a native preview with Story/Image, enlargement, a close control and Share Image. Both formats retain the complete stored Greek quotation, matching saint/portrait and the exact supplied Orthodox+ cross/wordmark. Exports omit categories, app controls and Instagram UI. Story is1080×1920 with a dark blurred backdrop; Image is1080×1776 clean card artwork. Adaptive text fitting fails visibly instead of truncating text that cannot fit. The original logo is added as a new asset without altering existing assets.

Share Image generates a temporary PNG attachment and presents UIActivityViewController. iOS supplies compatible installed destinations. Cancellation returns to the image preview; temporary PNGs are removed when the activity sheet closes. No application or recipient is chosen automatically, and no success toast claims delivery. This does not add analytics, accounts, dependencies, URL schemes, app IDs, project settings or workflows.

Save to Files and compatible sharing/copy activities are supplied by iOS. Save to Photos is excluded if the app lacks an existing Photos privacy declaration: this change does not introduce a Photos permission. Dedicated Instagram/Facebook Stories handoff is not configured; it still requires current official platform requirements and separately approved Meta/configuration setup. Generating a Story-format image does not guarantee a Story composer destination.

## Appetize review

1. Open Logos > Saint Quotes. Review tall paired cards, categories and both unselected/selected hearts.
2. Share from a gallery card, including Evmenios0009/0010, Iakovos0006 and Porfyrios0023/0027. Check the quote, portrait/name and small logo.
3. Switch Story/Image, enlarge and close. Test a short quote and Paisios0054 (the longest stored quote) for complete Greek text and branding clearance.
4. Open a quote reader and share from its top toolbar. Dismiss sharing and verify the same quote and favorite state are retained.
5. Open the vertical feed, swipe, double-tap to favorite, share and cancel. Filters/navigation should keep working.
6. On the native system sheet inspect image attachment, Copy/Save to Files where available, cancellation and safe-area positioning.

Appetize can verify simulator layout and presentation. WhatsApp, Viber, Messenger, Messages and Instagram destinations depend on installed extensions and are not guaranteed in a simulator. Actual receiving-app delivery and physical-device accessibility still need iPhone testing. No upload to Appetize is performed automatically.

Only the original backup branch is preserved: `backup/original-before-additions-2026-11-08` at `5f8ccf302c6eb8520cb40bc3c09e0961eb1ac6f4`. No additional backup branch/tag is created.

Gallery controls are a separate top-trailing overlay above the card-open button. Decorative gallery artwork and borders explicitly opt out of hit testing, while the card-open label retains its own full rectangular hit area. Heart/share positions remain10px inset with an8px gap; sharing is presented from the stable gallery ScrollView. Long-quotation readability uses a transparent-to-dark gradient beginning above the text and extending smoothly into the lower image, replacing the former solid rectangle. Native interaction must be rechecked in Appetize; a successful build alone does not verify taps.
