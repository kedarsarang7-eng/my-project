# Phase 8 Decision: OCR (useScanOCR) for mobileShop

## Decision

**DENY** — Remove the `ocrFocus` value for `mobileShop`. Do NOT grant `useScanOCR`.

## Rationale

The mobileShop vertical focuses on IMEI tracking and manual serial entry; OCR scanning adds complexity without matching user workflows, and the capability `useScanOCR` is not granted in the mobileShop capability set (Phase 0 confirmed its absence). Removing the `ocrFocus` value aligns the configuration with the actual capability grants and prevents the UI from implying OCR functionality that does not exist for this vertical.

## Changes Applied

- `lib/core/config/business_capabilities.dart` — `_getOcrFocus`: removed `case BusinessType.mobileShop` from the `electronics`/`computerShop` group; mobileShop now falls through to the `default` branch returning `''` (empty string), exposing no OCR hint.

## Requirements Covered

- 11.1: A documented decision resolving `useScanOCR` for mobileShop with a rationale of at least one complete sentence (≥10 words).
- 11.2: Where OCR is denied, no `ocrFocus` value or any UI/label/config entry implying OCR exists for mobileShop is exposed.
