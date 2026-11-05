//
//  ContentView.swift
//  WavChopper
//
//  Created by Gary Morgan on 05/11/2026.
//
import SwiftUI
import UniformTypeIdentifiers

// MARK: - UI

struct ContentView: View {
    @State private var isTargeted = false
    @State private var log: [String] = ["Drop a .wav file here."]
    @State private var sizeChoice = 2048

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(WavSlicer.sizes, id: \.self) { size in
                    Button {
                        sizeChoice = size
                    } label: {
                        Text("\(size)")
                            .fontWeight(sizeChoice == size ? .bold : .regular)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(sizeChoice == size ? .accentColor : .gray)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                    .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                VStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                    Text("Drop .wav file(s) here")
                        .font(.headline)
                }
                .foregroundStyle(.secondary)
            }
            .frame(height: 140)

            ScrollView {
                Text(log.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 120)
        }
        .padding()
        .frame(width: 420)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let size = sizeChoice
                let message: String
                do {
                    message = try WavSlicer.process(url: url, size: size)
                } catch {
                    message = "✗ \(url.lastPathComponent): \(error.localizedDescription)"
                }
                DispatchQueue.main.async { log.append(message) }
            }
        }
    }
}

// MARK: - Chopper

enum ChopError: LocalizedError {
    case notWav
    case unsupported(String)
    case noMatchingSize(frames: Int)
    case notDivisible(frames: Int, size: Int)

    var errorDescription: String? {
        switch self {
        case .notWav: return "Not a valid RIFF/WAVE file."
        case .unsupported(let s): return "Unsupported WAV: \(s)"
        case .noMatchingSize(let f):
            return "\(f) samples isn't a multiple of 128/256/512/1024/2048."
        case .notDivisible(let f, let s):
            return "\(f) samples doesn't divide evenly into \(s)-sample cycles."
        }
    }
}

enum WavSlicer {
    static let sizes = [128, 256, 512, 1024, 2048]

    struct Wav {
        var fmt: Data        // raw fmt chunk payload (copied verbatim into each output)
        var blockAlign: Int  // bytes per sample frame (all channels)
        var data: Data       // raw PCM bytes
    }

    /// Returns a human-readable summary line.
    static func process(url: URL, size: Int) throws -> String {
        let wav = try parse(Data(contentsOf: url))
        let frames = wav.data.count / wav.blockAlign

        guard frames >= size, frames % size == 0 else {
            throw ChopError.notDivisible(frames: frames, size: size)
        }

        let count = frames / size
        let base = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent()
            .appendingPathComponent("\(base)_\(size)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let width = max(3, String(count).count)
        let chunkBytes = size * wav.blockAlign

        for i in 0..<count {
            let slice = wav.data.subdata(in: (i * chunkBytes)..<((i + 1) * chunkBytes))
            let name = "\(base)_\(size)_" + String(format: "%0\(width)d", i + 1) + ".wav"
            try makeWav(fmt: wav.fmt, data: slice).write(to: folder.appendingPathComponent(name))
        }
        return "✓ \(url.lastPathComponent): \(count) × \(size) samples → \(folder.lastPathComponent)/"
    }

    // MARK: Parsing / writing

    private static func le16(_ d: Data, _ o: Int) -> Int {
        Int(d[d.startIndex + o]) | Int(d[d.startIndex + o + 1]) << 8
    }
    private static func le32(_ d: Data, _ o: Int) -> Int {
        le16(d, o) | le16(d, o + 2) << 16
    }

    static func parse(_ d: Data) throws -> Wav {
        guard d.count >= 12,
              String(decoding: d[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: d[8..<12], as: UTF8.self) == "WAVE" else { throw ChopError.notWav }

        var fmt: Data?
        var pcm: Data?
        var pos = 12
        while pos + 8 <= d.count {
            let id = String(decoding: d[pos..<pos + 4], as: UTF8.self)
            let size = le32(d, pos + 4)
            let body = pos + 8
            let end = min(body + size, d.count)
            if id == "fmt " { fmt = Data(d[body..<end]) }
            if id == "data" { pcm = Data(d[body..<end]) }
            pos = body + size + (size & 1)
        }

        guard let fmt, fmt.count >= 16, let pcm else { throw ChopError.notWav }
        let tag = le16(fmt, 0)
        guard [1, 3, 0xFFFE].contains(tag) else {
            throw ChopError.unsupported("compressed format (tag \(tag))")
        }
        let blockAlign = le16(fmt, 12)
        guard blockAlign > 0 else { throw ChopError.notWav }
        return Wav(fmt: fmt, blockAlign: blockAlign, data: pcm)
    }

    static func makeWav(fmt: Data, data: Data) -> Data {
        var out = Data()
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; out.append(Data(bytes: &x, count: 4)) }
        let fmtPad = fmt.count & 1, dataPad = data.count & 1

        out.append(contentsOf: Array("RIFF".utf8))
        u32(4 + 8 + fmt.count + fmtPad + 8 + data.count + dataPad)
        out.append(contentsOf: Array("WAVE".utf8))
        out.append(contentsOf: Array("fmt ".utf8))
        u32(fmt.count)
        out.append(fmt)
        if fmtPad == 1 { out.append(0) }
        out.append(contentsOf: Array("data".utf8))
        u32(data.count)
        out.append(data)
        if dataPad == 1 { out.append(0) }
        return out
    }
}

#Preview {
    ContentView()
}
