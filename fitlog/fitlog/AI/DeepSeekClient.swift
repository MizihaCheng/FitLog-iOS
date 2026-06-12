import Foundation

/// DeepSeek API 客户端（OpenAI 兼容，App 内直连）。
/// base：https://api.deepseek.com ，端点 /chat/completions ，Bearer 认证。
/// 默认模型 deepseek-v4-flash（快/省，非思考模式，足够写短报告）。
struct DeepSeekClient {
    var apiKey: String
    var model: String = "deepseek-v4-flash"
    var endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    enum DeepSeekError: LocalizedError {
        case missingKey
        case http(Int, String)
        case empty

        var errorDescription: String? {
            switch self {
            case .missingKey: return "还没填 DeepSeek API Key（去「我的」页设置）"
            case .http(let code, let msg):
                let trimmed = msg.count > 200 ? String(msg.prefix(200)) + "…" : msg
                return "请求失败（HTTP \(code)）：\(trimmed)"
            case .empty: return "没收到有效回复"
            }
        }
    }

    private struct Message: Codable { let role: String; let content: String }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let stream: Bool
        let temperature: Double
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable { let message: Message }
        let choices: [Choice]
    }

    /// 一次普通对话补全，返回助手回复文本。
    func chat(system: String, user: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw DeepSeekError.missingKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: model,
            messages: [
                Message(role: "system", content: system),
                Message(role: "user", content: user)
            ],
            stream: false,
            temperature: 0.7
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DeepSeekError.empty }
        guard (200..<300).contains(http.statusCode) else {
            throw DeepSeekError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekError.empty
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
