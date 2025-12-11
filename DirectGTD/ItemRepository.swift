import DirectGTDCore
import Foundation

// Extension to provide default Database.shared parameter for app-level convenience
extension ItemRepository {
    public convenience init() {
        self.init(database: Database.shared)
    }
}

// Re-export for backward compatibility with existing code using DatabaseError
public typealias DatabaseError = RepositoryError
