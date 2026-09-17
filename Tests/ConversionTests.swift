import Foundation
import CoreImage
import ImageIO

@main struct ConversionTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nef-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let converter = Converter()
        let image = CIImage(color: CIColor(red: 0.2, green: 0.6, blue: 0.8))
            .cropped(to: CGRect(x: 0, y: 0, width: 80, height: 48))
        for format in ExportFormat.allCases {
            let first = try converter.export(image, name: "photo", to: root, format: format, quality: 0.9)
            let original = try Data(contentsOf: first)
            let second = try converter.export(image, name: "photo", to: root, format: format, quality: 0.9)
            precondition(first != second && second.lastPathComponent.contains("(1)"))
            let after = try Data(contentsOf: first)
            precondition(original == after, "Existing export must not be overwritten")
            let source = CGImageSourceCreateWithURL(first as CFURL, nil)!
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
            precondition(props[kCGImagePropertyPixelWidth] as? Int == 80)
            precondition(props[kCGImagePropertyPixelHeight] as? Int == 48)
            precondition(props[kCGImagePropertyDepth] as? Int == (format == .png ? 16 : 8))
            precondition(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil)
            print("PASS \(format.rawValue): decodable, correct dimensions/bit depth, no overwrite")
        }
        let broken = root.appendingPathComponent("broken.NEF")
        try Data("not a raw image".utf8).write(to: broken)
        do {
            _ = try converter.convert(broken, to: root, format: .jpeg, quality: 0.9)
            fatalError("Corrupt input should fail")
        } catch { print("PASS corrupt NEF returns an error") }
        do {
            _ = try converter.convert(root.appendingPathComponent("photo.jpg"), to: root, format: .jpeg, quality: 0.9)
            fatalError("Non-NEF should fail")
        } catch { print("PASS non-NEF rejected") }
        do {
            _ = try converter.export(image, name: "photo", to: root.appendingPathComponent("missing"), format: .png, quality: 0.9)
            fatalError("Missing output directory should fail")
        } catch { print("PASS output error reported") }
        let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
        precondition(!remaining.contains(where: { $0.hasPrefix(".nef-converter-") }))
        if CommandLine.arguments.count > 1 {
            let raw = URL(fileURLWithPath: CommandLine.arguments[1])
            let original = try Data(contentsOf: raw)
            for format in ExportFormat.allCases {
                let output = try converter.convert(raw, to: root, format: format, quality: 0.92)
                let source = CGImageSourceCreateWithURL(output as CFURL, nil)!
                let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
                let width = props[kCGImagePropertyPixelWidth] as! Int
                let height = props[kCGImagePropertyPixelHeight] as! Int
                precondition(width > 2000 && height > 2000, "Expected full-resolution RAW output")
                precondition(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil)
                print("PASS real NEF → \(format.rawValue): \(width) × \(height), \(props[kCGImagePropertyDepth]!) bit")
            }
            let after = try Data(contentsOf: raw)
            precondition(original == after)
            print("PASS original NEF unchanged")
        }
    }
}
