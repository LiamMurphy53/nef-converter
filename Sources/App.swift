import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Photo: Identifiable {
    let id = UUID()
    let url: URL
    var status = "Ready"
    var output: URL?
    var failed = false
    var done = false
}

@MainActor final class ConversionModel: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var format: ExportFormat = .jpeg
    @Published var quality = 0.92
    @Published var folder: URL?
    @Published var running = false
    @Published var stopping = false
    @Published var completed = 0
    @Published var batchCount = 0
    @Published var message = "Your photos stay on this Mac."

    func add(_ urls: [URL]) {
        guard !running else { return }
        var known = Set(photos.map { $0.url.standardizedFileURL })
        var ignored = 0
        for url in urls {
            guard url.isFileURL, url.pathExtension.lowercased() == "nef" else { ignored += 1; continue }
            let normalized = url.standardizedFileURL
            if known.insert(normalized).inserted { photos.append(Photo(url: normalized)) }
        }
        message = ignored > 0 ? "Added NEF photos. \(ignored) other item(s) skipped." : "\(photos.count) photo(s) in your queue."
    }

    func choosePhotos() {
        let panel = NSOpenPanel()
        panel.title = "Choose Nikon RAW photos"
        panel.allowedContentTypes = [UTType(filenameExtension: "nef") ?? .rawImage]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Save converted photos"
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { folder = panel.url }
    }

    func start() {
        guard !running, !photos.isEmpty else { return }
        if folder == nil { chooseFolder() }
        guard let folder else { return }
        let jobs = photos
        let format = format
        let quality = quality
        running = true
        stopping = false
        completed = 0
        batchCount = jobs.count
        for index in photos.indices {
            photos[index].status = "Waiting"
            photos[index].failed = false
            photos[index].done = false
            photos[index].output = nil
        }
        Task {
            var succeeded = 0
            var failed = 0
            for job in jobs {
                if stopping { break }
                update(job.id, status: "Converting…")
                message = "Converting \(completed + 1) of \(batchCount)…"
                let result: Result<URL, Error> = await Task.detached(priority: .userInitiated) {
                    autoreleasepool {
                        Result { try Converter().convert(job.url, to: folder, format: format, quality: quality) }
                    }
                }.value
                switch result {
                case .success(let output):
                    succeeded += 1
                    update(job.id, status: "Saved · \(output.lastPathComponent)", output: output, done: true)
                case .failure(let error):
                    failed += 1
                    update(job.id, status: error.localizedDescription, failed: true, done: true)
                }
                completed += 1
            }
            let skipped = batchCount - completed
            if skipped > 0 {
                for index in photos.indices where !photos[index].done { photos[index].status = "Not converted" }
            }
            message = "\(succeeded) saved" + (failed > 0 ? " · \(failed) failed" : "") + (skipped > 0 ? " · \(skipped) not converted" : "") + "."
            running = false
            stopping = false
        }
    }

    private func update(_ id: UUID, status: String, output: URL? = nil, failed: Bool = false, done: Bool = false) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].status = status
        photos[index].output = output
        photos[index].failed = failed
        photos[index].done = done
    }
}

struct ContentView: View {
    @ObservedObject var model: ConversionModel
    @State private var targeted = false
    private let accent = Color(red: 0.23, green: 0.69, blue: 0.54)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 38)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEF Converter").font(.system(size: 27, weight: .semibold))
                    Text("Nikon RAW → photos ready to share")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("LOCAL & PRIVATE").font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1).foregroundStyle(accent)
            }

            VStack(spacing: 12) {
                if model.photos.isEmpty {
                    Spacer()
                    Image(systemName: "photo.badge.plus").font(.system(size: 40, weight: .light)).foregroundStyle(accent)
                    Text("Drop your .NEF photos here").font(.system(size: 19, weight: .medium))
                    Text("One photo or a whole batch. Full resolution, every time.")
                        .foregroundStyle(.secondary)
                    Button("Choose Photos…") { model.choosePhotos() }.controlSize(.large)
                    Spacer()
                } else {
                    HStack {
                        Text("\(model.photos.count) PHOTOS").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Add Photos…") { model.choosePhotos() }
                        Button("Clear") { model.photos.removeAll(); model.message = "Your photos stay on this Mac."; model.completed = 0 }
                    }.disabled(model.running)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.photos) { photo in
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: photo.failed ? "exclamationmark.triangle" : photo.done ? "checkmark.circle.fill" : "photo")
                                        .font(.system(size: 21))
                                        .foregroundStyle(photo.failed ? Color.orange : photo.done ? accent : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(photo.url.lastPathComponent).fontWeight(.medium).lineLimit(1)
                                        Text(photo.status).font(.system(size: 11)).foregroundStyle(photo.failed ? .orange : .secondary)
                                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    if let output = photo.output {
                                        Button { NSWorkspace.shared.activateFileViewerSelecting([output]) } label: { Image(systemName: "arrow.up.right.square") }
                                            .buttonStyle(.borderless).help("Show exported photo")
                                    }
                                    Button { model.photos.removeAll { $0.id == photo.id } } label: { Image(systemName: "xmark") }
                                        .buttonStyle(.borderless).disabled(model.running).help("Remove from queue")
                                }.padding(.vertical, 12)
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(20).frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
            .background(targeted ? accent.opacity(0.12) : Color.primary.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(targeted ? accent : Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: model.photos.isEmpty ? [6, 5] : [])))
            .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
                guard !model.running else { return false }
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url { Task { @MainActor in model.add([url]) } }
                    }
                }
                return true
            }

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXPORT AS").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    Picker("Format", selection: $model.format) {
                        ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 170)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.format == .jpeg ? "JPEG QUALITY · \(Int((model.quality * 100).rounded()))%" : "LOSSLESS · 16-BIT COLOR")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    if model.format == .jpeg {
                        Slider(value: $model.quality, in: 0.5...1, step: 0.01).frame(width: 210)
                    } else {
                        Text("More color detail. Larger files.").font(.system(size: 12)).padding(.top, 5)
                    }
                }
                Spacer()
            }.disabled(model.running)

            HStack(spacing: 10) {
                Image(systemName: "folder").foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Save to").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(model.folder?.path ?? "Choose an output folder").font(.system(size: 12))
                        .lineLimit(1).truncationMode(.middle).help(model.folder?.path ?? "")
                }
                Spacer()
                Button("Choose…") { model.chooseFolder() }.disabled(model.running)
                if let folder = model.folder {
                    Button { NSWorkspace.shared.open(folder) } label: { Image(systemName: "arrow.up.right.square") }.help("Open output folder")
                }
            }.padding(12).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 9))

            if model.running { ProgressView(value: Double(model.completed), total: Double(max(1, model.batchCount))).tint(accent) }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.message).font(.system(size: 12)).lineLimit(2)
                    Text("Originals preserved · Existing exports never overwritten").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if model.running {
                    Button(model.stopping ? "Stopping…" : "Stop After Current") { model.stopping = true }.disabled(model.stopping)
                } else {
                    Button("Convert \(model.photos.isEmpty ? "Photos" : String(model.photos.count) + (model.photos.count == 1 ? " Photo" : " Photos"))") { model.start() }
                        .buttonStyle(.borderedProminent).tint(accent).controlSize(.large).disabled(model.photos.isEmpty)
                }
            }
        }.padding(28).frame(minWidth: 640, idealWidth: 720, minHeight: 620, idealHeight: 680)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = ConversionModel()
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit NEF Converter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApplication.shared.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 680),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "NEF Converter"
        window.contentView = NSHostingView(rootView: ContentView(model: model))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        model.add(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.running else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "A conversion is still running"
        alert.informativeText = "Use Stop After Current to finish the current photo before closing."
        alert.addButton(withTitle: "Keep Converting")
        alert.runModal()
        return .terminateCancel
    }
}

@main struct Main {
    @MainActor
    static func main() {
        let args = CommandLine.arguments
        if args.count >= 5, args[1] == "--convert" {
            guard let format = ExportFormat(rawValue: args[3].uppercased()) else {
                fputs("Format must be JPEG or PNG.\n", stderr); exit(2)
            }
            do {
                let url = try Converter().convert(URL(fileURLWithPath: args[2]), to: URL(fileURLWithPath: args[4]), format: format, quality: 0.92)
                print(url.path)
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}
