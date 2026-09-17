# NEF Converter

A local Mac app for batch-converting Nikon NEF photos into full-resolution JPEG or 16-bit PNG. No uploads, accounts, or extra runtime required.

## Download and run

Once a release is published, open this repository's **Releases** section and download `NEF-Converter-v1.0.0-macOS-universal.zip`. The GitHub **Source code** archives contain the project, not a ready-to-run app.

Unzip the download and open **NEF Converter.app**. You can move it into Applications. The universal download contains both Apple Silicon and Intel builds and requires macOS 12 or later. Camera support depends on your installed macOS version.

This app is not Apple Developer ID signed or notarized, so macOS may block a downloaded copy. Build from source below if you prefer. Only open software you trust; Apple's [instructions for opening an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) explain the system's approval process.

## Use

1. Open **NEF Converter.app**.
2. Drop NEF files into the window, or click **Choose Photos**.
3. Choose JPEG (adjustable quality) or PNG (lossless, 16-bit).
4. Choose an output folder and click **Convert Photos**.

Originals are never modified. When a name already exists, exports get a numbered suffix. Conversion runs one photo at a time to limit memory usage. **Stop After Current** finishes the active image and leaves the rest unconverted. Errors appear beside individual photos, and the batch continues.

The app develops the RAW sensor data with Apple's Core Image RAW decoder at its default rendering settings, then exports in sRGB with the decoded orientation. It does not extract the embedded JPEG preview. Appearance may differ from Nikon's in-camera JPEG or Nikon editing software. Full EXIF/IPTC/GPS metadata and Nikon editing sidecars are not copied. PNG export is lossless relative to the rendered image; it does not retain editable RAW sensor data.

Camera models and compression modes must be supported by the installed macOS RAW decoder. Unsupported or damaged files show a readable error. This is a Mac-only app; Windows and Linux are not supported.

## Rebuild

Requires a Mac with a current Swift compiler, supplied by Apple's Xcode or Command Line Tools. No third-party packages are required. The build targets macOS 12 or newer.

Download this repository using **Code → Download ZIP** and unzip it, or clone it with Git. Open Terminal in the project folder. If developer tools are not installed, run `xcode-select --install` and complete Apple's installer. Then run:

```sh
bash build.sh
open "build/NEF Converter.app"
```

The default build is for the Mac you're using. To compile for both Apple Silicon and Intel, use `bash build.sh --universal`.

## Test

```sh
bash test.sh
# Optional end-to-end test with your own full-resolution NEF:
bash test.sh "/path/to/photo.NEF"
```

The tests check JPEG/PNG decoding, dimensions and bit depth, duplicate filenames, invalid input, output errors, and preservation of the source file. The optional NEF test expects both output dimensions to exceed 2,000 pixels. A public Nikon fixture was previously verified at 4256 × 2832 pixels; personal and third-party photos are not included in this repository.

## Package a release

```sh
bash package.sh
```

This creates the universal app ZIP and a SHA-256 checksum in `dist/`. Upload those two files to a GitHub Release. `build/`, `dist/`, and photo files are excluded from Git. The package is locally signed; this script does not perform Developer ID signing or notarization.

## Command line

The app executable also supports automation:

```sh
"build/NEF Converter.app/Contents/MacOS/NEFConverter" --convert "/path/photo.NEF" JPEG "/path/output"
```

Use `PNG` for 16-bit PNG output. The output directory must already exist.

## Decoder reference

[Apple CIRAWFilter documentation](https://developer.apple.com/documentation/coreimage/cirawfilter)

## License

[MIT](LICENSE)
