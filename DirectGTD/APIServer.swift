//
//  APIServer.swift
//  DirectGTD
//
//  Local HTTP API server that exposes ItemStore methods.
//  All writes go through the same code path as the UI.
//

import Foundation
import DirectGTDCore
import Network

/// Local HTTP API server for MCP and external tool integration
class APIServer {
    private var listener: NWListener?
    private weak var itemStore: ItemStore?
    private let port: UInt16
    private let queue = DispatchQueue(label: "com.directgtd.apiserver", qos: .userInitiated)

    init(itemStore: ItemStore, port: UInt16 = 9876) {
        self.itemStore = itemStore
        self.port = port
    }

    // MARK: - Server Lifecycle

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                NSLog("APIServer: Listening on port \(self?.port ?? 0)")
            case .failed(let error):
                NSLog("APIServer: Failed to start - \(error)")
            case .cancelled:
                NSLog("APIServer: Stopped")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        NSLog("APIServer: Shutting down")
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleRequest(data: data, connection: connection)
            }

            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }

    private func handleRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid request encoding"])
            return
        }

        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, status: 400, body: ["error": "Empty request"])
            return
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid request line"])
            return
        }

        let method = parts[0]
        let path = parts[1]

        // Extract body (after empty line)
        var body: Data?
        if let emptyLineIndex = lines.firstIndex(of: "") {
            let bodyString = lines[(emptyLineIndex + 1)...].joined(separator: "\r\n")
            body = bodyString.data(using: .utf8)
        }

        // Route request
        routeRequest(method: method, path: path, body: body, connection: connection)
    }

    // MARK: - Routing

    private func routeRequest(method: String, path: String, body: Data?, connection: NWConnection) {
        // Parse path and query parameters
        let components = path.components(separatedBy: "?")
        let basePath = components[0]
        let queryString = components.count > 1 ? components[1] : nil
        let queryParams = parseQueryString(queryString)

        // Parse path segments
        let segments = basePath.split(separator: "/").map(String.init)

        // Route to handlers
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let store = self.itemStore else {
                self?.sendResponse(connection: connection, status: 500, body: ["error": "Server not ready"])
                return
            }

            do {
                let response = try self.handleRoute(
                    method: method,
                    segments: segments,
                    queryParams: queryParams,
                    body: body,
                    store: store
                )
                self.sendResponse(connection: connection, status: 200, body: response)
            } catch let error as APIError {
                self.sendResponse(connection: connection, status: error.statusCode, body: ["error": error.message])
            } catch {
                self.sendResponse(connection: connection, status: 500, body: ["error": error.localizedDescription])
            }
        }
    }

    private func handleRoute(
        method: String,
        segments: [String],
        queryParams: [String: String],
        body: Data?,
        store: ItemStore
    ) throws -> [String: Any] {

        // GET /health - Health check
        if method == "GET" && segments == ["health"] {
            return ["status": "ok", "itemCount": store.items.count]
        }

        // GET /items - List all items
        if method == "GET" && segments == ["items"] {
            return ["items": store.items.map { itemToDict($0) }]
        }

        // GET /items/:id - Get single item
        if method == "GET" && segments.count == 2 && segments[0] == "items" {
            let itemId = segments[1]
            guard let item = store.items.first(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }
            return ["item": itemToDict(item)]
        }

        // POST /items - Create item
        if method == "POST" && segments == ["items"] {
            let params = try parseBody(body)
            guard let title = params["title"] as? String else {
                throw APIError(statusCode: 400, message: "Missing required field: title")
            }

            let parentId = params["parentId"] as? String
            let itemTypeStr = params["itemType"] as? String ?? "task"
            let itemType = ItemType(rawValue: itemTypeStr) ?? .task
            let notes = params["notes"] as? String

            guard let item = store.createItemWithDetails(
                title: title,
                parentId: parentId,
                itemType: itemType,
                notes: notes
            ) else {
                throw APIError(statusCode: 500, message: "Failed to create item")
            }
            return ["item": itemToDict(item)]
        }

        // PUT /items/:id - Update item
        if method == "PUT" && segments.count == 2 && segments[0] == "items" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            let params = try parseBody(body)
            let updatedItem = try updateItem(store: store, itemId: itemId, params: params)
            return ["item": itemToDict(updatedItem)]
        }

        // DELETE /items/:id - Delete item
        if method == "DELETE" && segments.count == 2 && segments[0] == "items" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            store.selectedItemId = itemId
            store.deleteSelectedItem()
            return ["deleted": true, "id": itemId]
        }

        // POST /items/:id/complete - Toggle completion
        if method == "POST" && segments.count == 3 && segments[0] == "items" && segments[2] == "complete" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            store.toggleTaskCompletion(id: itemId)
            store.loadItems()

            guard let item = store.items.first(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 500, message: "Item disappeared after toggle")
            }
            return ["item": itemToDict(item)]
        }

        // POST /items/:id/move - Move item
        if method == "POST" && segments.count == 3 && segments[0] == "items" && segments[2] == "move" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            let params = try parseBody(body)
            guard let targetId = params["targetId"] as? String else {
                throw APIError(statusCode: 400, message: "Missing required field: targetId")
            }

            let positionStr = params["position"] as? String ?? "into"
            let position: DropPosition
            switch positionStr {
            case "above": position = .above
            case "below": position = .below
            default: position = .into
            }

            guard store.canDropItem(draggedItemId: itemId, onto: targetId, position: position) else {
                throw APIError(statusCode: 400, message: "Invalid move operation")
            }

            store.moveItem(draggedItemId: itemId, targetItemId: targetId, position: position)

            guard let item = store.items.first(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 500, message: "Item disappeared after move")
            }
            return ["item": itemToDict(item)]
        }

        // GET /tags - List all tags
        if method == "GET" && segments == ["tags"] {
            return ["tags": store.tags.map { tagToDict($0) }]
        }

        // POST /tags - Create tag
        if method == "POST" && segments == ["tags"] {
            let params = try parseBody(body)
            guard let name = params["name"] as? String else {
                throw APIError(statusCode: 400, message: "Missing required field: name")
            }

            let color = params["color"] as? String ?? "#808080"

            guard let tag = store.createTag(name: name, color: color) else {
                throw APIError(statusCode: 500, message: "Failed to create tag")
            }
            return ["tag": tagToDict(tag)]
        }

        // PUT /tags/:id - Update tag
        if method == "PUT" && segments.count == 2 && segments[0] == "tags" {
            let tagId = segments[1]
            guard var tag = store.tags.first(where: { $0.id == tagId }) else {
                throw APIError(statusCode: 404, message: "Tag not found")
            }

            let params = try parseBody(body)
            if let name = params["name"] as? String {
                tag.name = name
            }
            if let color = params["color"] as? String {
                tag.color = color
            }

            store.updateTag(tag: tag)

            guard let updatedTag = store.tags.first(where: { $0.id == tagId }) else {
                throw APIError(statusCode: 500, message: "Tag disappeared after update")
            }
            return ["tag": tagToDict(updatedTag)]
        }

        // DELETE /tags/:id - Delete tag
        if method == "DELETE" && segments.count == 2 && segments[0] == "tags" {
            let tagId = segments[1]
            guard store.tags.contains(where: { $0.id == tagId }) else {
                throw APIError(statusCode: 404, message: "Tag not found")
            }

            store.deleteTag(tagId: tagId)
            return ["deleted": true, "id": tagId]
        }

        // GET /items/:id/tags - Get tags for item
        if method == "GET" && segments.count == 3 && segments[0] == "items" && segments[2] == "tags" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            let tags = store.getTagsForItem(itemId: itemId)
            return ["tags": tags.map { tagToDict($0) }]
        }

        // POST /items/:id/tags - Add tag to item
        if method == "POST" && segments.count == 3 && segments[0] == "items" && segments[2] == "tags" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            let params = try parseBody(body)
            guard let tagId = params["tagId"] as? String else {
                throw APIError(statusCode: 400, message: "Missing required field: tagId")
            }

            guard let tag = store.tags.first(where: { $0.id == tagId }) else {
                throw APIError(statusCode: 404, message: "Tag not found")
            }

            store.addTagToItem(itemId: itemId, tag: tag)

            let tags = store.getTagsForItem(itemId: itemId)
            return ["tags": tags.map { tagToDict($0) }]
        }

        // DELETE /items/:id/tags/:tagId - Remove tag from item
        if method == "DELETE" && segments.count == 4 && segments[0] == "items" && segments[2] == "tags" {
            let itemId = segments[1]
            let tagId = segments[3]

            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            store.removeTagFromItem(itemId: itemId, tagId: tagId)

            let tags = store.getTagsForItem(itemId: itemId)
            return ["tags": tags.map { tagToDict($0) }]
        }

        // GET /items/:id/children - Get children of item
        if method == "GET" && segments.count == 3 && segments[0] == "items" && segments[2] == "children" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            let children = store.items
                .filter { $0.parentId == itemId }
                .sorted { $0.sortOrder < $1.sortOrder }
            return ["items": children.map { itemToDict($0) }]
        }

        // GET /root-items - Get root items (no parent)
        if method == "GET" && segments == ["root-items"] {
            let rootItems = store.items
                .filter { $0.parentId == nil }
                .sorted { $0.sortOrder < $1.sortOrder }
            return ["items": rootItems.map { itemToDict($0) }]
        }

        // GET /search?q=query - Search items
        if method == "GET" && segments == ["search"] {
            guard let query = queryParams["q"], !query.isEmpty else {
                throw APIError(statusCode: 400, message: "Missing required query parameter: q")
            }

            let results = store.items.filter { item in
                (item.title?.localizedCaseInsensitiveContains(query) ?? false) ||
                (item.notes?.localizedCaseInsensitiveContains(query) ?? false)
            }
            return ["items": results.map { itemToDict($0) }]
        }

        // POST /sql-search - Execute SQL search
        if method == "POST" && segments == ["sql-search"] {
            let params = try parseBody(body)
            guard let sql = params["sql"] as? String else {
                throw APIError(statusCode: 400, message: "Missing required field: sql")
            }

            // Execute synchronously using semaphore (we're already on main thread)
            var resultIds: [String] = []
            var sqlError: Error?

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    try await store.executeSQLSearch(query: sql)
                    resultIds = store.sqlSearchResults
                } catch {
                    sqlError = error
                }
                semaphore.signal()
            }
            semaphore.wait()

            if let error = sqlError {
                throw APIError(statusCode: 400, message: "SQL error: \(error.localizedDescription)")
            }

            let items = store.items.filter { resultIds.contains($0.id) }
            return ["items": items.map { itemToDict($0) }, "ids": resultIds]
        }

        // GET /saved-searches - List saved searches
        if method == "GET" && segments == ["saved-searches"] {
            store.loadSavedSearches()
            return ["searches": store.savedSearches.map { savedSearchToDict($0) }]
        }

        // POST /saved-searches - Create saved search
        if method == "POST" && segments == ["saved-searches"] {
            let params = try parseBody(body)
            guard let name = params["name"] as? String else {
                throw APIError(statusCode: 400, message: "Missing required field: name")
            }
            guard let sql = params["sql"] as? String else {
                throw APIError(statusCode: 400, message: "Missing required field: sql")
            }

            try store.saveSQLSearch(name: name, sql: sql)
            store.loadSavedSearches()

            guard let search = store.savedSearches.first(where: { $0.name == name }) else {
                throw APIError(statusCode: 500, message: "Failed to create saved search")
            }
            return ["search": savedSearchToDict(search)]
        }

        // GET /items/:id/time-entries - Get time entries for item
        if method == "GET" && segments.count == 3 && segments[0] == "items" && segments[2] == "time-entries" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            let entries = store.getTimeEntries(for: itemId)
            return [
                "entries": entries.map { timeEntryToDict($0) },
                "totalSeconds": store.totalTime(for: itemId),
                "hasActiveTimer": store.hasActiveTimer(for: itemId)
            ]
        }

        // POST /items/:id/timer/start - Start timer for item
        if method == "POST" && segments.count == 4 && segments[0] == "items" && segments[2] == "timer" && segments[3] == "start" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            guard let entry = store.startTimer(for: itemId) else {
                throw APIError(statusCode: 500, message: "Failed to start timer")
            }
            return ["entry": timeEntryToDict(entry)]
        }

        // POST /items/:id/timer/stop - Stop timer for item
        if method == "POST" && segments.count == 4 && segments[0] == "items" && segments[2] == "timer" && segments[3] == "stop" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            guard let activeEntry = store.activeTimeEntry(for: itemId) else {
                throw APIError(statusCode: 400, message: "No active timer for this item")
            }

            guard let stoppedEntry = store.stopTimer(entryId: activeEntry.id) else {
                throw APIError(statusCode: 500, message: "Failed to stop timer")
            }
            return ["entry": timeEntryToDict(stoppedEntry)]
        }

        // POST /items/:id/timer/toggle - Toggle timer for item
        if method == "POST" && segments.count == 4 && segments[0] == "items" && segments[2] == "timer" && segments[3] == "toggle" {
            let itemId = segments[1]
            guard store.items.contains(where: { $0.id == itemId }) else {
                throw APIError(statusCode: 404, message: "Item not found")
            }

            guard let entry = store.toggleTimer(for: itemId) else {
                throw APIError(statusCode: 500, message: "Failed to toggle timer")
            }
            return ["entry": timeEntryToDict(entry), "isRunning": entry.endedAt == nil]
        }

        // DELETE /time-entries/:id - Delete time entry
        if method == "DELETE" && segments.count == 2 && segments[0] == "time-entries" {
            let entryId = segments[1]
            store.deleteTimeEntry(id: entryId)
            return ["deleted": true, "id": entryId]
        }

        // POST /sync - Trigger sync
        if method == "POST" && segments == ["sync"] {
            NotificationCenter.default.post(name: NSNotification.Name("RequestSync"), object: nil)
            return ["requested": true]
        }

        // POST /reload - Reload items from database
        if method == "POST" && segments == ["reload"] {
            store.loadItems()
            return ["reloaded": true, "itemCount": store.items.count]
        }

        throw APIError(statusCode: 404, message: "Not found: \(method) /\(segments.joined(separator: "/"))")
    }

    // MARK: - Item Operations

    private func updateItem(store: ItemStore, itemId: String, params: [String: Any]) throws -> Item {
        guard var item = store.items.first(where: { $0.id == itemId }) else {
            throw APIError(statusCode: 404, message: "Item not found")
        }

        // Update fields if provided
        if let title = params["title"] as? String {
            store.updateItemTitle(id: itemId, title: title)
        }

        if let notes = params["notes"] as? String {
            store.updateNotes(id: itemId, notes: notes)
        }

        if let itemTypeStr = params["itemType"] as? String, let itemType = ItemType(rawValue: itemTypeStr) {
            store.updateItemType(id: itemId, itemType: itemType)
        }

        if params.keys.contains("dueDate") {
            let dueDate = params["dueDate"] as? Int
            store.updateDueDate(id: itemId, dueDate: dueDate)
        }

        if params.keys.contains("earliestStartTime") {
            let earliestStartTime = params["earliestStartTime"] as? Int
            store.updateEarliestStartTime(id: itemId, earliestStartTime: earliestStartTime)
        }

        // Reload and return updated item
        store.loadItems()
        guard let updatedItem = store.items.first(where: { $0.id == itemId }) else {
            throw APIError(statusCode: 500, message: "Item disappeared after update")
        }

        return updatedItem
    }

    // MARK: - Serialization

    private func itemToDict(_ item: Item) -> [String: Any] {
        var dict: [String: Any] = [
            "id": item.id,
            "itemType": item.itemType.rawValue,
            "sortOrder": item.sortOrder,
            "createdAt": item.createdAt,
            "modifiedAt": item.modifiedAt
        ]

        if let title = item.title { dict["title"] = title }
        if let notes = item.notes { dict["notes"] = notes }
        if let parentId = item.parentId { dict["parentId"] = parentId }
        if let completedAt = item.completedAt { dict["completedAt"] = completedAt }
        if let dueDate = item.dueDate { dict["dueDate"] = dueDate }
        if let earliestStartTime = item.earliestStartTime { dict["earliestStartTime"] = earliestStartTime }

        return dict
    }

    private func tagToDict(_ tag: Tag) -> [String: Any] {
        var dict: [String: Any] = [
            "id": tag.id,
            "name": tag.name
        ]

        if let color = tag.color { dict["color"] = color }
        if let createdAt = tag.createdAt { dict["createdAt"] = createdAt }
        if let modifiedAt = tag.modifiedAt { dict["modifiedAt"] = modifiedAt }

        return dict
    }

    private func savedSearchToDict(_ search: SavedSearch) -> [String: Any] {
        return [
            "id": search.id,
            "name": search.name,
            "sql": search.sql,
            "sortOrder": search.sortOrder,
            "createdAt": search.createdAt,
            "modifiedAt": search.modifiedAt
        ]
    }

    private func timeEntryToDict(_ entry: TimeEntry) -> [String: Any] {
        var dict: [String: Any] = [
            "id": entry.id,
            "itemId": entry.itemId,
            "startedAt": entry.startedAt
        ]

        if let endedAt = entry.endedAt { dict["endedAt"] = endedAt }
        if let duration = entry.duration { dict["duration"] = duration }
        if let modifiedAt = entry.modifiedAt { dict["modifiedAt"] = modifiedAt }

        return dict
    }

    // MARK: - Helpers

    private func parseQueryString(_ queryString: String?) -> [String: String] {
        guard let queryString = queryString else { return [:] }

        var params: [String: String] = [:]
        for pair in queryString.components(separatedBy: "&") {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].removingPercentEncoding ?? parts[0]
                let value = parts[1].removingPercentEncoding ?? parts[1]
                params[key] = value
            }
        }
        return params
    }

    private func parseBody(_ body: Data?) throws -> [String: Any] {
        guard let body = body, !body.isEmpty else {
            return [:]
        }

        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw APIError(statusCode: 400, message: "Invalid JSON body")
        }

        return json
    }

    private func sendResponse(connection: NWConnection, status: Int, body: [String: Any]) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let jsonData = (try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(jsonData.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(jsonString)
        """

        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

// MARK: - API Error

struct APIError: Error {
    let statusCode: Int
    let message: String
}
