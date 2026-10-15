import Flutter
import UIKit
import VisionKit
import ImageIO
import CoreImage
import PDFKit
import UniformTypeIdentifiers

private struct ScannerFailure: Error { let code: String }

/// Native worker owns raster/PDF lifetimes. Flutter receives descriptors only.
final class ScannerEngine: NSObject, FlutterStreamHandler, VNDocumentCameraViewControllerDelegate {
    private weak var host: UIViewController?
    private let channel: FlutterMethodChannel
    private let events: FlutterEventChannel
    private let worker = DispatchQueue(label: "com.lumen.pdfscanner.worker", qos: .userInitiated)
    private let ci = CIContext(options: [.cacheIntermediates: false])
    private let root: URL
    private let documents: URL
    private var sink: FlutterEventSink?
    private var pending: FlutterResult?
    private var captureLimit = 50
    private let lock = NSLock()
    private var cancelled = false
    private var exporting = false

    init(host: FlutterViewController) throws {
        self.host = host
        channel = FlutterMethodChannel(name: "com.lumen.pdfscanner/engine", binaryMessenger: host.binaryMessenger)
        events = FlutterEventChannel(name: "com.lumen.pdfscanner/progress", binaryMessenger: host.binaryMessenger)
        root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Lumen")
        documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        super.init()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
        events.setStreamHandler(self)
    }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
    func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
    private func finish(_ result: @escaping FlutterResult, _ value: Any?) { DispatchQueue.main.async { result(value) } }
    private func fail(_ result: @escaping FlutterResult, _ error: Error) {
        let code: String
        if let e = error as? ScannerFailure { code = e.code }
        else if (error as NSError).code == NSFileWriteOutOfSpaceError { code = "storage" }
        else if (error as NSError).code == NSFileNoSuchFileError { code = "missing" }
        else { code = "operation" }
        finish(result, FlutterError(code: code, message: nil, details: nil))
    }
    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let a = call.arguments as? [String: Any] ?? [:]
        if call.method == "cancel" { lock.lock(); cancelled = true; lock.unlock(); result(nil); return }
        if call.method == "scan" { captureLimit = min(50,max(1,a["limit"] as? Int ?? 50)); scan(result); return }
        if call.method == "chooseFolder" || call.method == "privateFolder" { result("On My iPhone → PDF Scanner"); return }
        if call.method == "export" {
            lock.lock()
            if exporting { lock.unlock(); result(FlutterError(code: "busy", message: nil, details: nil)); return }
            exporting = true; cancelled = false; lock.unlock()
        }
        worker.async {
            do {
                let value: Any?
                switch call.method {
                case "initialise": value = try self.initialise()
                case "stage": value = try self.stage(a)
                case "preview": value = try self.preview(a)
                case "export": value = try self.export(a)
                case "discard", "acknowledge":
                    let dir = try self.session(a["session"] as! String)
                    try? FileManager.default.removeItem(at: dir); value = nil
                case "open", "share": try self.share(a, share: call.method == "share"); value = nil
                case "pdfPage": value = try self.pdfPage(a)
                case "rename": value = try self.rename(a)
                case "delete": try self.delete(a); value = nil
                case "usage": value = self.usage()
                case "cleanCache":
                    try? FileManager.default.removeItem(at: self.root.appendingPathComponent("previews"))
                    try? FileManager.default.removeItem(at: self.root.appendingPathComponent("shares")); value = nil
                default: throw ScannerFailure(code: "unsupported")
                }
                self.finish(result, value)
            } catch { self.fail(result, error) }
            if call.method == "export" { self.lock.lock(); self.exporting = false; self.lock.unlock() }
        }
    }
    private func safeId(_ id: String) throws -> String {
        guard id.range(of: "^[A-Za-z0-9-]{1,64}$", options: .regularExpression) != nil else { throw ScannerFailure(code: "invalid") }
        return id
    }
    private func directory(_ url: URL) throws -> URL { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
    private func session(_ id: String) throws -> URL { try directory(root.appendingPathComponent("drafts/\(safeId(id))")) }
    private func checked(_ path: String) throws -> URL {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
        guard url.path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { throw ScannerFailure(code: "invalid") }
        return url
    }
    private func initialise() throws -> [String: Any] {
        for path in ["PDFs", "Images/Processed", "Images/Originals"] { _ = try directory(documents.appendingPathComponent(path)) }
        _ = try directory(root.appendingPathComponent("receipts"))
        let jobs = (try? FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("jobs"), includingPropertiesForKeys: nil)) ?? []
        for job in jobs {
            var clean = true
            if !FileManager.default.fileExists(atPath: root.appendingPathComponent("receipts/\(job.lastPathComponent).json").path),
               let data = try? Data(contentsOf: job.appendingPathComponent("published.json")),
               let uris = try? JSONSerialization.jsonObject(with: data) as? [String] {
                for uri in uris { do { try removeUri(uri) } catch { clean = false } }
            }
            if clean { try? FileManager.default.removeItem(at: job) }
        }
        let files = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("receipts"), includingPropertiesForKeys: nil)
        let receipts: [[String: Any]] = files.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        return ["location": "On My iPhone → PDF Scanner", "receipts": receipts]
    }
    private func scan(_ result: @escaping FlutterResult) {
        guard pending == nil else { result(FlutterError(code: "busy", message: nil, details: nil)); return }
        guard VNDocumentCameraViewController.isSupported, let host else { result(FlutterError(code: "unsupported", message: nil, details: nil)); return }
        pending = result
        let controller = VNDocumentCameraViewController(); controller.delegate = self
        host.present(controller, animated: true)
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        let result = pending; pending = nil
        result?(FlutterError(code: "cancelled", message: nil, details: nil))
    }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
        let result = pending; pending = nil
        result?(FlutterError(code: "unsupported", message: nil, details: nil))
    }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        guard let result = pending else { return }; pending = nil
        guard scan.pageCount <= captureLimit else { result(FlutterError(code: "limit", message: nil, details: nil)); return }
        // VisionKit scan images are retrieved on main; each is immediately
        // staged to disk rather than accumulated as UIImage/byte batches.
        do {
            let capture = try directory(root.appendingPathComponent("capture"))
            var paths: [String] = []
            for i in 0..<scan.pageCount {
                try autoreleasepool {
                    let image = scan.imageOfPage(at: i)
                    guard let data = image.jpegData(compressionQuality: 0.95) else { throw ScannerFailure(code: "unsupported") }
                    let file = capture.appendingPathComponent("\(UUID().uuidString).jpg")
                    try data.write(to: file, options: .atomic); paths.append(file.path)
                }
            }
            result(paths)
        } catch { fail(result, error) }
    }
    private func decode(_ path: String, edge: Int = 4096) throws -> CGImage {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0, Int64(w) * Int64(h) <= 400_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: edge,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw ScannerFailure(code: "unsupported") }
        return image
    }
    private func jpeg(_ image: CGImage, _ url: URL, quality: Double = 0.92) throws {
        _ = try directory(url.deletingLastPathComponent())
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw ScannerFailure(code: "write") }
        // Re-encode without source metadata (GPS/EXIF is not copied).
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ScannerFailure(code: "write") }
    }
    private func stage(_ a: [String: Any]) throws -> [[String: Any]] {
        guard let paths = a["paths"] as? [String], paths.count <= 50, let id = a["session"] as? String else { throw ScannerFailure(code: "invalid") }
        let dir = try session(id); var pages: [[String: Any]] = []
        for path in paths {
            try autoreleasepool {
                let image = try decode(path); let id = UUID().uuidString
                let source = dir.appendingPathComponent("\(id).jpg"), thumb = dir.appendingPathComponent("\(id)-thumb.jpg")
                try jpeg(image, source, quality: 0.95)
                try jpeg(decode(source.path, edge: 256), thumb, quality: 0.82)
                pages.append(["id": id, "path": source.path, "thumb": thumb.path, "width": image.width, "height": image.height])
                let capturePath = root.appendingPathComponent("capture").path + "/"
                if URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(capturePath) {
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
                }
            }
        }
        return pages
    }
    private func render(_ p: [String: Any], edge: Int) throws -> CGImage {
        let source = try checked(p["path"] as! String)
        let image = try decode(source.path, edge: edge)
        var ciImage = CIImage(cgImage: image)
        let c = (p["corners"] as? [Double]) ?? [0,0,1,0,1,1,0,1]
        guard c.count == 8, c.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else { throw ScannerFailure(code: "invalid") }
        var area = 0.0
        for i in 0..<4 {
            let j = (i+1)%4, k = (i+2)%4
            let cross = (c[j*2]-c[i*2])*(c[k*2+1]-c[j*2+1]) - (c[j*2+1]-c[i*2+1])*(c[k*2]-c[j*2])
            guard cross > 0 else { throw ScannerFailure(code: "invalid") }
            area += c[i*2]*c[j*2+1] - c[j*2]*c[i*2+1]
        }
        guard area/2 >= 0.02 else { throw ScannerFailure(code: "invalid") }
        func vector(_ i: Int) -> CIVector { CIVector(x: c[i*2] * Double(image.width), y: (1-c[i*2+1]) * Double(image.height)) }
        ciImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: ["inputTopLeft": vector(0), "inputTopRight": vector(1), "inputBottomRight": vector(2), "inputBottomLeft": vector(3)])
        let rotation = p["rotation"] as? Int ?? 0
        guard rotation % 90 == 0 else { throw ScannerFailure(code: "invalid") }
        if rotation != 0 { ciImage = ciImage.transformed(by: CGAffineTransform(rotationAngle: -CGFloat(rotation) * .pi / 180)) }
        let filter = p["filter"] as? String ?? "original"
        if filter == "enhanced" { ciImage = ciImage.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.15, kCIInputBrightnessKey: 0.03]) }
        if filter == "greyscale" || filter == "bw" { ciImage = ciImage.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0]) }
        if filter == "bw" { ciImage = ciImage.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.5]) }
        let extent = ciImage.extent.integral
        guard extent.width > 1, extent.height > 1,
              let result = ci.createCGImage(ciImage, from: extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { throw ScannerFailure(code: "render") }
        return result
    }
    private func preview(_ p: [String: Any]) throws -> String {
        let source = try checked(p["path"] as! String)
        let url = source.deletingLastPathComponent().appendingPathComponent("preview-\(UUID().uuidString).jpg")
        try jpeg(render(p, edge: 1024), url, quality: 0.85); return url.path
    }
    private func checkCancelled() throws { lock.lock(); let stop = cancelled; lock.unlock(); if stop { throw ScannerFailure(code: "cancelled") } }
    private func progress(_ phase: String, _ completed: Int, _ total: Int) {
        DispatchQueue.main.async { self.sink?(["phase": phase, "completed": completed, "total": total]) }
    }
    private func relativeUri(_ url: URL) -> String { "local:" + String(url.path.dropFirst(documents.path.count)) }
    private func resolveUri(_ uri: String) throws -> URL {
        guard uri.hasPrefix("local:/") else { throw ScannerFailure(code: "invalid") }
        let url = documents.appendingPathComponent(String(uri.dropFirst(7))).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(documents.resolvingSymlinksInPath().path + "/") else { throw ScannerFailure(code: "invalid") }
        return url
    }
    private func publish(_ source: URL, sub: String, name: String, published: inout [String], job: URL) throws -> String {
        try checkCancelled()
        let parent = try directory(documents.appendingPathComponent(sub))
        var target = parent.appendingPathComponent(name), suffix = 2
        while FileManager.default.fileExists(atPath: target.path) {
            let ext = (name as NSString).pathExtension, stem = (name as NSString).deletingPathExtension
            target = parent.appendingPathComponent("\(stem)_\(suffix).\(ext)"); suffix += 1
        }
        let uri = relativeUri(target); published.append(uri)
        try JSONSerialization.data(withJSONObject: published).write(to: job.appendingPathComponent("published.json"), options: .atomic)
        // copyItem fails rather than overwriting if another writer races us.
        try FileManager.default.copyItem(at: source, to: target)
        return uri
    }
    private func export(_ a: [String: Any]) throws -> [String: Any] {
        guard let idValue = a["id"] as? String, let pages = a["pages"] as? [[String: Any]], !pages.isEmpty, pages.count <= 50 else { throw ScannerFailure(code: "invalid") }
        let id = try safeId(idValue)
        let committed = root.appendingPathComponent("receipts/\(id).json")
        if FileManager.default.fileExists(atPath: committed.path) {
            return try JSONSerialization.jsonObject(with: Data(contentsOf: committed)) as! [String: Any]
        }
        let job = try directory(root.appendingPathComponent("jobs/\(idValue)"))
        let prior = job.appendingPathComponent("published.json")
        if let data = try? Data(contentsOf: prior), let uris = try JSONSerialization.jsonObject(with: data) as? [String] {
            for uri in uris { try removeUri(uri) }
            try FileManager.default.removeItem(at: job)
            _ = try directory(job)
        }
        try JSONSerialization.data(withJSONObject: a).write(to: job.appendingPathComponent("request.json"), options: .atomic)
        let output = job.appendingPathComponent("output.pdf")
        let title = stem(a["title"] as? String ?? "Scan"), dpi = min(300, max(100, a["dpi"] as? Int ?? 200))
        let quality = Double(a["quality"] as? Int ?? 85) / 100
        let margin = Double(a["margin"] as? Int ?? 5) * 72 / 25.4
        var published: [String] = [], images: [String] = []
        do {
            guard let context = CGContext(output as CFURL, mediaBox: nil, [kCGPDFContextTitle: title, kCGPDFContextCreator: "PDF Scanner 0.1"] as CFDictionary) else { throw ScannerFailure(code: "write") }
            do {
                for (i,p) in pages.enumerated() {
                    try checkCancelled(); progress("Processing pages", i, pages.count)
                    try autoreleasepool {
                        let image = try render(p, edge: min(4096, Int(ceil(11.7 * Double(dpi)))))
                        var w = a["format"] as? String == "letter" ? 612.0 : 595.28
                        var h = a["format"] as? String == "letter" ? 792.0 : 841.89
                        let fit = a["format"] as? String == "fit"
                        if fit { w = Double(image.width)*72/Double(dpi); h = Double(image.height)*72/Double(dpi) }
                        else if a["landscape"] as? Bool == true { swap(&w,&h) }
                        var box = CGRect(x: 0,y: 0,width: w,height: h)
                        let data = NSData(bytes: &box,length: MemoryLayout<CGRect>.size)
                        context.beginPDFPage([kCGPDFContextMediaBox as String: data] as CFDictionary)
                        context.setFillColor(UIColor.white.cgColor); context.fill(box)
                        let inset = fit ? 0 : margin, scale = min((w-2*inset)/Double(image.width),(h-2*inset)/Double(image.height))
                        let rw = Double(image.width)*scale, rh = Double(image.height)*scale
                        context.draw(image,in: CGRect(x: (w-rw)/2,y: (h-rh)/2,width: rw,height: rh)); context.endPDFPage()
                        if a["saveImages"] as? Bool == true {
                            let file = job.appendingPathComponent("page.jpg"); try jpeg(image,file,quality: quality)
                            images.append(try publish(file,sub: "Images/Processed/\(id)",name: String(format: "page-%03d.jpg",i+1),published: &published,job: job))
                            try? FileManager.default.removeItem(at: file)
                        }
                        if a["keepOriginals"] as? Bool == true {
                            images.append(try publish(checked(p["path"] as! String),sub: "Images/Originals/\(id)",name: String(format: "page-%03d.jpg",i+1),published: &published,job: job))
                        }
                    }
                    progress("Processing pages", i+1, pages.count)
                }
                context.closePDF()
            } catch { context.closePDF(); throw error }
            try checkCancelled(); progress("Checking PDF",pages.count,pages.count)
            guard let check = PDFDocument(url: output),check.pageCount == pages.count else { throw ScannerFailure(code: "verify") }
            for i in pages.indices { guard let p = check.page(at: i), p.bounds(for: .mediaBox).width > 0 else { throw ScannerFailure(code: "verify") }; _ = p.thumbnail(of: CGSize(width: 32,height: 32),for: .mediaBox) }
            progress("Saving to your folder",pages.count,pages.count)
            let uri = try publish(output,sub: "PDFs",name: "\(title).pdf",published: &published,job: job)
            try checkCancelled()
            guard PDFDocument(url: try resolveUri(uri))?.pageCount == pages.count else { throw ScannerFailure(code: "verify") }
            let thumb = root.appendingPathComponent("thumbs/\(id).jpg"); _ = try directory(thumb.deletingLastPathComponent())
            try FileManager.default.copyItem(at: checked(pages[0]["thumb"] as! String),to: thumb)
            let bytes = (try output.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            let receipt: [String: Any] = ["id": id,"session": a["session"]!,"title": title,"uri": uri,"thumb": thumb.path,"pages": pages.count,"bytes": bytes,"createdAt": a["createdAt"]!,"location": "On My iPhone → PDF Scanner","images": images]
            try saveReceipt(id,receipt); try? FileManager.default.removeItem(at: job)
            return receipt
        } catch {
            for uri in published { try? removeUri(uri) }
            throw error
        }
    }
    private func stem(_ input: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|").union(.controlCharacters)
        let filtered = String(String.UnicodeScalarView(input.precomposedStringWithCanonicalMapping.unicodeScalars.filter { !invalid.contains($0) }))
        let value = String(filtered.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))).prefix(100))
        return value.isEmpty ? "Scan" : value
    }
    private func saveReceipt(_ id: String, _ value: [String: Any]) throws {
        let dir = try directory(root.appendingPathComponent("receipts"))
        try JSONSerialization.data(withJSONObject: value).write(to: dir.appendingPathComponent("\(safeId(id)).json"),options: .atomic)
    }
    private func share(_ a: [String: Any],share: Bool) throws {
        let source = try resolveUri(a["uri"] as! String)
        guard FileManager.default.fileExists(atPath: source.path) else { throw ScannerFailure(code: "missing") }
        let dir = try directory(root.appendingPathComponent("shares"))
        let copy = dir.appendingPathComponent("\(stem(a["title"] as! String)).pdf")
        try? FileManager.default.removeItem(at: copy); try FileManager.default.copyItem(at: source,to: copy)
        DispatchQueue.main.async {
            guard let host = self.host else { return }
            let sheet = UIActivityViewController(activityItems: [copy],applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = host.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: host.view.bounds.midX,y: host.view.bounds.midY,width: 1,height: 1)
            host.present(sheet,animated: true)
        }
    }
    private func pdfPage(_ a: [String: Any]) throws -> [String: Any] {
        guard let pdf = PDFDocument(url: try resolveUri(a["uri"] as! String)), pdf.pageCount > 0,
              let page = pdf.page(at: min(pdf.pageCount-1,max(0,a["index"] as? Int ?? 0))) else { throw ScannerFailure(code: "missing") }
        let image = page.thumbnail(of: CGSize(width: 1024,height: 1400),for: .mediaBox)
        guard let cg = image.cgImage else { throw ScannerFailure(code: "render") }
        let out = root.appendingPathComponent("previews/pdf-\(UUID().uuidString).jpg"); try jpeg(cg,out,quality: 0.85)
        return ["path": out.path,"count": pdf.pageCount]
    }
    private func rename(_ a: [String: Any]) throws -> [String: Any] {
        let source = try resolveUri(a["uri"] as! String),title = stem(a["newTitle"] as! String)
        let dest = source.deletingLastPathComponent().appendingPathComponent("\(title).pdf")
        guard !FileManager.default.fileExists(atPath: dest.path) else { throw ScannerFailure(code: "collision") }
        try FileManager.default.moveItem(at: source,to: dest)
        var result = a; result.removeValue(forKey: "newTitle"); result["title"] = title; result["uri"] = relativeUri(dest)
        try saveReceipt(a["id"] as! String,result); return result
    }
    private func removeUri(_ uri: String) throws {
        let url = try resolveUri(uri)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    private func delete(_ a: [String: Any]) throws {
        if a["deleteImages"] as? Bool == true { for uri in a["images"] as? [String] ?? [] { try removeUri(uri) } }
        try removeUri(a["uri"] as! String)
        try? FileManager.default.removeItem(at: root.appendingPathComponent("receipts/\(safeId(a["id"] as! String)).json"))
    }
    private func usage() -> [String: Any] {
        func size(_ root: URL) -> Int64 {
            guard let files = FileManager.default.enumerator(at: root,includingPropertiesForKeys: [.fileSizeKey,.isRegularFileKey]) else { return 0 }
            var total: Int64 = 0
            for case let url as URL in files { if let v = try? url.resourceValues(forKeys: [.fileSizeKey,.isRegularFileKey]), v.isRegularFile == true { total += Int64(v.fileSize ?? 0) } }
            return total
        }
        return ["privateBytes": size(root),"libraryBytes": size(documents),"location": "On My iPhone → PDF Scanner"]
    }
}
