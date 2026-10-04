import Foundation

public enum RadioBrowserError: LocalizedError {
    case transport(URLError)
    case http(status: Int, body: String?)
    case decoding(Error)
    case serverUnavailable

    public var errorDescription: String? {
        switch self {
        case .transport(let error): return "Network error: \(error.localizedDescription)"
        case .http(let status, _): return "HTTP status \(status)"
        case .decoding(let error): return "Response decoding failed: \(error.localizedDescription)"
        case .serverUnavailable: return "All mirrors unreachable"
        }
    }
}
