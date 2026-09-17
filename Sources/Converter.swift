import Foundation
import CoreImage
import ImageIO

enum ExportFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG", png = "PNG"
    var id: String { rawValue }
    var fileExtension: String { self == .jpeg ? "jpg" : "png" }
}

struct ConversionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class Converter {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    func convert(_ source: URL, to folder: URL, format: ExportFormat, quality: Double) throws -> URL {
        guard source.pathExtension.lowercased() == "nef" else {
            throw ConversionError(message: "Choose a Nikon .NEF file.")
        }
        guard let raw = CIRAWFilter(imageURL: source), let image = raw.outputImage else {
            throw ConversionError(message: "macOS couldn’t decode this NEF. The file may be damaged, or its camera or RAW compression mode may not be supported by this version of macOS.")
        }
        return try export(image, name: source.deletingPathExtension().lastPathComponent,
                          to: folder, format: format, quality: quality)
    }

    func export(_ image: CIImage, name: String, to folder: URL, format: ExportFormat, quality: Double) throws -> URL {
        let temporary = folder.appendingPathComponent(".nef-converter-\(UUID().uuidString).\(format.fileExtension)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        if format == .jpeg {
            try context.writeJPEGRepresentation(of: image, to: temporary, colorSpace: colorSpace,
                options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): min(1, max(0, quality))])
        } else {
            try context.writePNGRepresentation(of: image, to: temporary, format: .RGBA16,
                                               colorSpace: colorSpace)
        }
        // Move only after a successful render. Never replace an existing export.
        var suffix = 0
        while true {
            let stem = suffix == 0 ? name : "\(name) (\(suffix))"
            let destination = folder.appendingPathComponent(stem).appendingPathExtension(format.fileExtension)
            do {
                try FileManager.default.moveItem(at: temporary, to: destination)
                return destination
            } catch {
                if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSFileWriteFileExistsError {
                    suffix += 1
                } else { throw error }
            }
        }
    }
}
