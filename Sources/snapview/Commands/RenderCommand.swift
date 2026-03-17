import ArgumentParser
import Foundation

struct RenderCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "render",
    abstract: "Render previews matching a view name or preview name."
  )

  @Argument(help: "View name or preview name to render.")
  var viewName: String

  @Option(name: .long, help: "Xcode scheme to build.")
  var scheme: String

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?
  @Option(name: .long) var device: String = "iPhone15Pro"
  @Option(name: .long) var scale: Double = 2.0
  @Option(name: .long) var output: String = ".snapview"
  @Option(name: .long) var simulator: String?
  @Flag(name: .long) var rtl = false
  @Option(name: .long) var locale: String = "en_US"
  @Flag(name: .long) var verbose = false

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace, testTarget: testTarget
    )

    // Verify init was run
    let rendererPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRenderer.swift"
    guard FileManager.default.fileExists(atPath: rendererPath) else {
      throw CleanExit.message("[snapview:error] Not initialized. Run: snapview init --scheme \(scheme)")
    }

    let (width, height) = Self.deviceDimensions(device)

    // Step 1: Scan for previews
    print("[1/4] Scanning for #Preview blocks matching \"\(viewName)\"...")
    let allEntries = Self.scanProject(sourceRoot: projectInfo.sourceRoot, appName: projectInfo.appName)
    let matched = PreviewMatcher.match(viewName: viewName, entries: allEntries)

    guard !matched.isEmpty else {
      throw CleanExit.message("[snapview:error] No #Preview found for \"\(viewName)\" in project sources.")
    }

    let names = matched.map(\.name).joined(separator: ", ")
    print("       Found: \(matched[0].filePath) → \(names)")

    // Step 2: Regenerate registry
    print("[2/4] Regenerating SnapViewRegistry.swift (\(matched.count) entries)...")
    let allImports = matched.flatMap { entry in
      let fullPath = "\(projectInfo.sourceRoot)/\(projectInfo.appName)/\(entry.filePath)"
      let source = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
      return ImportScanner.scan(source: source)
    }
    let registry = RegistryGenerator.generate(entries: matched, imports: allImports, appModule: projectInfo.moduleName)
    let registryPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRegistry.swift"
    try registry.write(toFile: registryPath, atomically: true, encoding: .utf8)

    // Step 3: Build & run
    print("[3/4] Building & running test...")
    let startTime = Date()
    try BuildRunner.run(options: .init(
      scheme: scheme, project: projectInfo, viewNames: matched.map(\.name),
      scale: scale, width: width, height: height,
      rtl: rtl, locale: locale, simulator: simulator, verbose: verbose
    ))
    let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))

    // Step 4: Extract PNGs
    let outputDir = "\(projectInfo.sourceRoot)/\(output)"
    let paths = try PNGExtractor.extract(to: outputDir)
    print("[4/4] Done (\(elapsed)s).\n")

    for path in paths {
      print("  \(path)")
    }
  }

  // MARK: - Shared Utilities

  static func deviceDimensions(_ device: String) -> (Double, Double) {
    switch device {
    case "iPhone15Pro": return (393, 852)
    case "iPhoneSE": return (375, 667)
    case "iPadPro": return (1024, 1366)
    default:
      if device.hasPrefix("custom:") {
        let parts = device.dropFirst(7).split(separator: "x").compactMap { Double($0) }
        if parts.count == 2 { return (parts[0], parts[1]) }
      }
      return (393, 852)
    }
  }

  static func scanProject(sourceRoot: String, appName: String) -> [PreviewEntry] {
    let fm = FileManager.default
    let appDir = "\(sourceRoot)/\(appName)"
    guard let enumerator = fm.enumerator(atPath: appDir) else { return [] }

    var entries: [PreviewEntry] = []
    while let file = enumerator.nextObject() as? String {
      guard file.hasSuffix(".swift") else { continue }
      let fullPath = "\(appDir)/\(file)"
      guard let source = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }
      let fileEntries = PreviewScanner.scan(source: source, filePath: file)
      entries.append(contentsOf: fileEntries)
    }
    return entries
  }
}
