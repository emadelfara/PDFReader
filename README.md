# PDF Reader

A free, offline-first Android PDF reader built with Flutter.

## Principles
- No ads, no subscriptions, no analytics, and no tracking SDKs.
- PDF files stay on the device.
- Lightweight PDF rendering through Android's built-in `PdfRenderer` (no bundled PDF engine).
- Arabic/English-ready interface and dark red/black theme.

## Features
- Open PDF files from device storage.
- Render pages using Android PdfRenderer.
- Page navigation and pinch-to-zoom.
- Lightweight Android builds split by CPU architecture.

## Build
The GitHub Actions workflow generates the Android platform scaffold, builds release APKs split by ABI, and uploads them as workflow artifacts.

> APK size depends on Flutter version and ABI. The project is optimized for a small download, but the under-10-MB target must be confirmed from the actual release artifacts.
