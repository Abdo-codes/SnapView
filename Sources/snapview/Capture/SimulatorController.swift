import Foundation

struct SimulatorController {
  typealias Runner = (_ arguments: [String], _ environment: [String: String]) throws -> Void

  private let run: Runner

  init(run: @escaping Runner) {
    self.run = run
  }

  func openURL(_ url: String, device: String) throws {
    try run(["simctl", "openurl", device, url], [:])
  }

  func launch(
    appId: String,
    device: String,
    arguments: [String],
    environment: [String: String]
  ) throws {
    var command = ["simctl", "launch"]

    for key in environment.keys.sorted() {
      if let value = environment[key] {
        command.append(contentsOf: ["--env", "\(key)=\(value)"])
      }
    }

    command.append(contentsOf: [device, appId])
    command.append(contentsOf: arguments)

    try run(command, [:])
  }
}
