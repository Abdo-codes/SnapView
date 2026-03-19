import Foundation

struct ProjectHealth {
  let project: ProjectInfo
  let scheme: String
  let previewCount: Int
  let outputWritable: Bool
  let findings: [HealthFinding]

  var errors: [HealthFinding] {
    findings.filter { $0.severity == .error }
  }

  var warnings: [HealthFinding] {
    findings.filter { $0.severity == .warning }
  }

  var isHealthy: Bool {
    errors.isEmpty
  }
}

struct HealthFinding: Codable, Equatable {

  enum Severity: String, Codable {
    case error
    case warning
    case info
  }

  enum Code: String, Codable {
    case missingTestTarget
    case missingTestTargetInfoPlist
    case missingPreviews
    case stalePreparationState
    case staleHostState
    case outputDirectoryNotWritable
  }

  let severity: Severity
  let code: Code
  let message: String
  let fix: String?
}
