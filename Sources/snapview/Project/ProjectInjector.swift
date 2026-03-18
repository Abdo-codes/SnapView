import Foundation
import XcodeProj
import PathKit

enum ProjectInjector {

  enum Error: Swift.Error, CustomStringConvertible {
    case testTargetNotFound(String)
    case sourceBuildPhaseNotFound

    var description: String {
      switch self {
      case .testTargetNotFound(let name):
        return "[snapview:error] Test target '\(name)' not found in project."
      case .sourceBuildPhaseNotFound:
        return "[snapview:error] No Sources build phase found in test target."
      }
    }
  }

  static func inject(project: ProjectInfo) throws {
    let pbxPath = Path(project.projectPath)
    let xcodeproj = try XcodeProj(path: pbxPath)
    let pbxproj = xcodeproj.pbxproj

    // Find or create test target
    let testTarget: PBXNativeTarget
    if let existing = pbxproj.nativeTargets.first(where: { $0.name == project.testTargetName }) {
      testTarget = existing
    } else {
      FileHandle.standardError.write(Data(
        "[snapview:info] Test target '\(project.testTargetName)' not found. Creating it...\n".utf8
      ))
      testTarget = try createTestTarget(
        named: project.testTargetName,
        appName: project.appName,
        pbxproj: pbxproj
      )
    }

    // Find the test target's source directory
    let testDir = "\(project.sourceRoot)/\(project.testTargetName)"
    let fm = FileManager.default
    if !fm.fileExists(atPath: testDir) {
      try fm.createDirectory(atPath: testDir, withIntermediateDirectories: true)
    }

    // Write files to disk
    let rendererPath = "\(testDir)/SnapViewRenderer.swift"
    let registryPath = "\(testDir)/SnapViewRegistry.swift"

    try RendererTemplate.generate().write(toFile: rendererPath, atomically: true, encoding: .utf8)

    let placeholderRegistry = RegistryGenerator.generate(entries: [], imports: [], appModule: project.moduleName)
    try placeholderRegistry.write(toFile: registryPath, atomically: true, encoding: .utf8)

    // Add files to test target in pbxproj
    let testGroup: PBXGroup?
    if let existing = pbxproj.groups.first(where: { $0.path == project.testTargetName }) {
      testGroup = existing
    } else {
      testGroup = try pbxproj.rootGroup()?.addGroup(named: project.testTargetName).last
    }

    guard let targetGroup = testGroup else {
      throw Error.sourceBuildPhaseNotFound
    }

    let sourcePhase = try testTarget.sourcesBuildPhase() ?? testTarget.buildPhases
      .compactMap { $0 as? PBXSourcesBuildPhase }.first

    guard let phase = sourcePhase else {
      throw Error.sourceBuildPhaseNotFound
    }

    try ensureSourceFile(
      named: "SnapViewRenderer.swift",
      at: rendererPath,
      in: targetGroup,
      phase: phase,
      sourceRoot: project.sourceRoot
    )
    try ensureSourceFile(
      named: "SnapViewRegistry.swift",
      at: registryPath,
      in: targetGroup,
      phase: phase,
      sourceRoot: project.sourceRoot
    )

    // Ensure the scheme includes the test target in its test action
    // (must happen BEFORE xcodeproj.write — uses native XCScheme API)
    try ensureSchemeIncludesTestTarget(
      xcodeproj: xcodeproj,
      projectPath: pbxPath,
      schemeName: project.appName,
      testTargetName: project.testTargetName,
      testTarget: testTarget
    )

    try xcodeproj.write(path: pbxPath)
  }

  private static func ensureSourceFile(
    named fileName: String,
    at path: String,
    in group: PBXGroup,
    phase: PBXSourcesBuildPhase,
    sourceRoot: String
  ) throws {
    let buildFiles = phase.files ?? []
    let existingBuildFile = buildFiles.first { buildFile in
      buildFile.file?.path?.contains(fileName) == true
    }
    if existingBuildFile != nil {
      return
    }

    let groupReference = group.children
      .compactMap { $0 as? PBXFileReference }
      .first { $0.path?.contains(fileName) == true }

    let fileReference = if let groupReference {
      groupReference
    } else {
      try group.addFile(at: Path(path), sourceRoot: Path(sourceRoot))
    }

    _ = try phase.add(file: fileReference)
  }

  // MARK: - Scheme Management

  private static func ensureSchemeIncludesTestTarget(
    xcodeproj: XcodeProj,
    projectPath: Path,
    schemeName: String,
    testTargetName: String,
    testTarget: PBXNativeTarget
  ) throws {
    // Check if the scheme already has this test target
    if let existingScheme = xcodeproj.sharedData?.schemes.first(where: { $0.name == schemeName }) {
      let alreadyHasTest = existingScheme.testAction?.testables.contains { testable in
        testable.buildableReference.blueprintName == testTargetName
      } ?? false
      if alreadyHasTest { return }

      // Add test target to existing scheme
      let testRef = XCScheme.BuildableReference(
        referencedContainer: "container:\(projectPath.lastComponent)",
        blueprint: testTarget,
        buildableName: "\(testTargetName).xctest",
        blueprintName: testTargetName
      )
      let testable = XCScheme.TestableReference(
        skipped: false,
        parallelization: .none,
        buildableReference: testRef
      )
      existingScheme.testAction?.testables.append(testable)
      return
    }

    // Find app target for the launch action
    let appTarget = xcodeproj.pbxproj.nativeTargets.first { $0.name == schemeName }

    // Create scheme from scratch using XcodeProj API
    let projectFile = projectPath.lastComponent

    let appRef: XCScheme.BuildableReference?
    if let appTarget {
      appRef = XCScheme.BuildableReference(
        referencedContainer: "container:\(projectFile)",
        blueprint: appTarget,
        buildableName: "\(schemeName).app",
        blueprintName: schemeName
      )
    } else {
      appRef = nil
    }

    let testRef = XCScheme.BuildableReference(
      referencedContainer: "container:\(projectFile)",
      blueprint: testTarget,
      buildableName: "\(testTargetName).xctest",
      blueprintName: testTargetName
    )

    var buildEntries: [XCScheme.BuildAction.Entry] = []
    if let appRef {
      buildEntries.append(XCScheme.BuildAction.Entry(
        buildableReference: appRef,
        buildFor: [.running, .testing, .analyzing]
      ))
    }

    let buildAction = XCScheme.BuildAction(
      buildActionEntries: buildEntries,
      parallelizeBuild: true,
      buildImplicitDependencies: true
    )

    let testAction = XCScheme.TestAction(
      buildConfiguration: "Debug",
      macroExpansion: appRef,
      testables: [
        XCScheme.TestableReference(skipped: false, parallelization: .none, buildableReference: testRef)
      ]
    )

    let launchAction: XCScheme.LaunchAction?
    if let appRef {
      launchAction = XCScheme.LaunchAction(
        runnable: XCScheme.BuildableProductRunnable(buildableReference: appRef),
        buildConfiguration: "Debug"
      )
    } else {
      launchAction = nil
    }

    let scheme = XCScheme(
      name: schemeName,
      lastUpgradeVersion: "1600",
      version: "1.7",
      buildAction: buildAction,
      testAction: testAction,
      launchAction: launchAction
    )

    if xcodeproj.sharedData == nil {
      xcodeproj.sharedData = XCSharedData(schemes: [scheme])
    } else {
      xcodeproj.sharedData?.schemes.append(scheme)
    }
  }

  // MARK: - Test Target Creation

  private static func createTestTarget(
    named name: String,
    appName: String,
    pbxproj: PBXProj
  ) throws -> PBXNativeTarget {
    // Find the app target to set up the dependency
    guard let appTarget = pbxproj.nativeTargets.first(where: { $0.name == appName }) else {
      throw Error.testTargetNotFound("App target '\(appName)' not found")
    }

    // Get the app's bundle ID from build settings
    let appBundleID = appTarget.buildConfigurationList?.buildConfigurations.first?
      .buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String ?? "com.app.\(appName)"

    // Create build phases
    let sourcesBuildPhase = PBXSourcesBuildPhase()
    pbxproj.add(object: sourcesBuildPhase)

    let frameworksBuildPhase = PBXFrameworksBuildPhase()
    pbxproj.add(object: frameworksBuildPhase)

    // Detect settings from the app target's build configuration
    let appDebug = appTarget.buildConfigurationList?.buildConfigurations
      .first { $0.name == "Debug" }
    let sdkroot = appDebug?.buildSettings["SDKROOT"] as? String ?? "iphoneos"
    let deviceFamily = appDebug?.buildSettings["TARGETED_DEVICE_FAMILY"] as? String ?? "1,2"

    // The actual product name may differ from the target name (e.g., Arabic display names)
    // Check build settings first — productName property often returns nil
    let rawProductName = appDebug?.buildSettings["PRODUCT_NAME"] as? String
      ?? appTarget.productName
      ?? appName
    // If PRODUCT_NAME is "$(TARGET_NAME)", resolve to the actual target name
    let appProductName = rawProductName == "$(TARGET_NAME)" ? appName : rawProductName

    // Create build configurations matching the pattern from working test targets
    let testBuildSettings: BuildSettings = [
      "BUNDLE_LOADER": "$(TEST_HOST)",
      "GENERATE_INFOPLIST_FILE": "YES",
      "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"],
      "PRODUCT_BUNDLE_IDENTIFIER": "\(appBundleID).tests",
      "SDKROOT": sdkroot,
      "TARGETED_DEVICE_FAMILY": deviceFamily,
      "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/\(appProductName).app/\(appProductName)",
    ]

    let debugConfig = XCBuildConfiguration(name: "Debug", buildSettings: testBuildSettings)
    pbxproj.add(object: debugConfig)

    let releaseConfig = XCBuildConfiguration(name: "Release", buildSettings: testBuildSettings)
    pbxproj.add(object: releaseConfig)

    let configList = XCConfigurationList(
      buildConfigurations: [debugConfig, releaseConfig],
      defaultConfigurationName: "Debug"
    )
    pbxproj.add(object: configList)

    // Create product reference for the .xctest bundle
    let productRef = PBXFileReference(
      sourceTree: .buildProductsDir,
      explicitFileType: "wrapper.cfbundle",
      path: "\(name).xctest",
      includeInIndex: false
    )
    pbxproj.add(object: productRef)

    // Add to Products group if it exists
    if let productsGroup = pbxproj.groups.first(where: { $0.name == "Products" }) {
      productsGroup.children.append(productRef)
    }

    // Create the test target
    let testTarget = PBXNativeTarget(
      name: name,
      buildConfigurationList: configList,
      buildPhases: [sourcesBuildPhase, frameworksBuildPhase],
      product: productRef,
      productType: .unitTestBundle
    )
    pbxproj.add(object: testTarget)

    // Add dependency on the app target
    let targetProxy = PBXContainerItemProxy(
      containerPortal: .project(pbxproj.rootObject!),
      remoteGlobalID: .object(appTarget),
      proxyType: .nativeTarget,
      remoteInfo: appName
    )
    pbxproj.add(object: targetProxy)

    let dependency = PBXTargetDependency(target: appTarget, targetProxy: targetProxy)
    pbxproj.add(object: dependency)
    testTarget.dependencies.append(dependency)

    // Add test target to the project
    pbxproj.rootObject?.targets.append(testTarget)

    // Add test target to the scheme's test action
    // (handled by xcodebuild automatically when -only-testing is used)

    return testTarget
  }
}
