import UIKit

enum NetworkError: Error {
    case badUrl
    case decodingError
    case invalidId
}

struct CreditScore: Decodable {
    let score: Int
}

struct Constant {
    struct URLs {
        static func equifax(userId: Int) -> URL? {
            return URL(string: "https://ember-sparkly-rule.glitch.me/equifax/credit-score/\(userId)")
        }
        
        static func experian(userId: Int) -> URL? {
            return URL(string: "https://ember-sparkly-rule.glitch.me/experian/credit-score/\(userId)")
        }
    }
}

func calculateAPR(creditScores: [CreditScore]) -> Double {
    let sum = creditScores.reduce(0) { $0 + $1.score }
    return Double(sum / creditScores.count) / 100
}

func getAPR(userId: Int) async throws -> Double {
    
    guard let equifaxUrl = Constant.URLs.equifax(userId: userId),
          let experianUrl = Constant.URLs.experian(userId: userId) else {
              throw NetworkError.badUrl
          }
    
    async let (equifaxdata, _) = URLSession.shared.data(from: equifaxUrl)
    async let (experianData, _) = URLSession.shared.data(from: experianUrl)
    
    guard let equifaxCreditScore = try? JSONDecoder().decode(CreditScore.self, from: try await equifaxdata),
          let experianCreditScore = try? JSONDecoder().decode(CreditScore.self, from: try await experianData) else {
              throw NetworkError.decodingError
          }
    
    return calculateAPR(creditScores: [equifaxCreditScore, experianCreditScore])
}

Task(priority: .medium) {
    let apr = try await getAPR(userId: 1)
    print(apr)
}

let numbers = [1, 2, 3, 4, 5]
var invalidIds: [Int] = []

numbers.forEach { number in
    Task(priority: .medium) {
        do {
            try Task.checkCancellation()
            let apr = try await getAPR(userId: number)
            print(apr)
        } catch {
            print(error)
            invalidIds.append(number)
        }
    }
}

print(invalidIds)


func getAPRForAllUsers(ids: [Int]) async throws -> [Int: Double] {
    
    var userAPR: [Int: Double] = [:]
    
    try await withThrowingTaskGroup(of: (Int, Double).self, body: { group in
        for id in ids {
            group.addTask(priority: .high) {
                return (id, try await getAPR(userId: id))
            }
        }
        
        for try await (id, apr) in group {
            userAPR[id] = apr
        }
    })
    
    return userAPR
}

Task(priority: .high) {
    let aprForAllUsers = try await getAPRForAllUsers(ids: numbers)
    print(aprForAllUsers)
}



