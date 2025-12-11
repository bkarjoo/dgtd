//
//  CKRecordConverters.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import DirectGTDCore
import Foundation
import CloudKit

/// Converts between local models and CKRecords for CloudKit sync.
enum CKRecordConverters {

    // MARK: - System Fields Helpers

    static func encodeSystemFields(_ record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    static func decodeSystemFields(_ data: Data?, manager: CloudKitManager = .shared) -> CKRecord? {
        guard let data = data else { return nil }

        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = true
            guard let record = CKRecord(coder: unarchiver) else {
                return nil
            }
            unarchiver.finishDecoding()
            return record
        } catch {
            NSLog("CKRecordConverters: Failed to decode system fields: \(error)")
            return nil
        }
    }

    // MARK: - Item

    /// Convert Item to CKRecord for push.
    static func record(from item: Item, manager: CloudKitManager = .shared) -> CKRecord {
        let record: CKRecord

        // Try to restore from system fields first (for updates)
        if let existingRecord = decodeSystemFields(item.ckSystemFields, manager: manager) {
            record = existingRecord
        } else {
            // New record - create fresh
            let recordName = item.ckRecordName ?? "Item_\(item.id)"
            record = manager.newRecord(type: CloudKitManager.RecordType.item, recordName: recordName)
        }

        // Set/update all field values
        record["localId"] = item.id as CKRecordValue
        record["title"] = item.title as CKRecordValue?
        record["itemType"] = item.itemType.rawValue as CKRecordValue
        record["notes"] = item.notes as CKRecordValue?
        record["parentId"] = item.parentId as CKRecordValue?
        record["sortOrder"] = item.sortOrder as CKRecordValue
        record["createdAt"] = item.createdAt as CKRecordValue
        record["modifiedAt"] = item.modifiedAt as CKRecordValue
        record["completedAt"] = item.completedAt as CKRecordValue?
        record["dueDate"] = item.dueDate as CKRecordValue?
        record["earliestStartTime"] = item.earliestStartTime as CKRecordValue?
        record["deletedAt"] = item.deletedAt as CKRecordValue?

        return record
    }

    static func item(from record: CKRecord) -> Item? {
        guard record.recordType == CloudKitManager.RecordType.item,
              let localId = record["localId"] as? String else {
            return nil
        }

        let itemTypeString = record["itemType"] as? String ?? "Unknown"
        let itemType = ItemType(rawValue: itemTypeString) ?? .unknown

        return Item(
            id: localId,
            title: record["title"] as? String,
            itemType: itemType,
            notes: record["notes"] as? String,
            parentId: record["parentId"] as? String,
            sortOrder: record["sortOrder"] as? Int ?? 0,
            createdAt: record["createdAt"] as? Int ?? Int(Date().timeIntervalSince1970),
            modifiedAt: record["modifiedAt"] as? Int ?? Int(Date().timeIntervalSince1970),
            completedAt: record["completedAt"] as? Int,
            dueDate: record["dueDate"] as? Int,
            earliestStartTime: record["earliestStartTime"] as? Int,
            ckRecordName: record.recordID.recordName,
            ckChangeTag: record.recordChangeTag,
            ckSystemFields: encodeSystemFields(record),
            needsPush: 0,
            deletedAt: record["deletedAt"] as? Int
        )
    }

    // MARK: - Tag

    /// Convert Tag to CKRecord for push.
    static func record(from tag: Tag, manager: CloudKitManager = .shared) -> CKRecord {
        let record: CKRecord

        if let existingRecord = decodeSystemFields(tag.ckSystemFields, manager: manager) {
            record = existingRecord
        } else {
            let recordName = tag.ckRecordName ?? "Tag_\(tag.id)"
            record = manager.newRecord(type: CloudKitManager.RecordType.tag, recordName: recordName)
        }

        record["localId"] = tag.id as CKRecordValue
        record["name"] = tag.name as CKRecordValue
        record["color"] = tag.color as CKRecordValue?
        record["createdAt"] = tag.createdAt as CKRecordValue?
        record["modifiedAt"] = tag.modifiedAt as CKRecordValue?
        record["deletedAt"] = tag.deletedAt as CKRecordValue?

        return record
    }

    static func tag(from record: CKRecord) -> Tag? {
        guard record.recordType == CloudKitManager.RecordType.tag,
              let localId = record["localId"] as? String,
              let name = record["name"] as? String else {
            return nil
        }

        return Tag(
            id: localId,
            name: name,
            color: record["color"] as? String,
            createdAt: record["createdAt"] as? Int,
            modifiedAt: record["modifiedAt"] as? Int,
            ckRecordName: record.recordID.recordName,
            ckChangeTag: record.recordChangeTag,
            ckSystemFields: encodeSystemFields(record),
            needsPush: 0,
            deletedAt: record["deletedAt"] as? Int
        )
    }

    // MARK: - ItemTag

    /// Convert ItemTag to CKRecord for push.
    static func record(from itemTag: ItemTag, manager: CloudKitManager = .shared) -> CKRecord {
        let record: CKRecord

        if let existingRecord = decodeSystemFields(itemTag.ckSystemFields, manager: manager) {
            record = existingRecord
        } else {
            let recordName = itemTag.ckRecordName ?? "ItemTag_\(itemTag.itemId)_\(itemTag.tagId)"
            record = manager.newRecord(type: CloudKitManager.RecordType.itemTag, recordName: recordName)
        }

        record["itemId"] = itemTag.itemId as CKRecordValue
        record["tagId"] = itemTag.tagId as CKRecordValue
        record["createdAt"] = itemTag.createdAt as CKRecordValue?
        record["modifiedAt"] = itemTag.modifiedAt as CKRecordValue?
        record["deletedAt"] = itemTag.deletedAt as CKRecordValue?

        return record
    }

    static func itemTag(from record: CKRecord) -> ItemTag? {
        guard record.recordType == CloudKitManager.RecordType.itemTag,
              let itemId = record["itemId"] as? String,
              let tagId = record["tagId"] as? String else {
            return nil
        }

        return ItemTag(
            itemId: itemId,
            tagId: tagId,
            createdAt: record["createdAt"] as? Int,
            modifiedAt: record["modifiedAt"] as? Int,
            ckRecordName: record.recordID.recordName,
            ckChangeTag: record.recordChangeTag,
            ckSystemFields: encodeSystemFields(record),
            needsPush: 0,
            deletedAt: record["deletedAt"] as? Int
        )
    }

    // MARK: - TimeEntry

    /// Convert TimeEntry to CKRecord for push.
    static func record(from timeEntry: TimeEntry, manager: CloudKitManager = .shared) -> CKRecord {
        let record: CKRecord

        if let existingRecord = decodeSystemFields(timeEntry.ckSystemFields, manager: manager) {
            record = existingRecord
        } else {
            let recordName = timeEntry.ckRecordName ?? "TimeEntry_\(timeEntry.id)"
            record = manager.newRecord(type: CloudKitManager.RecordType.timeEntry, recordName: recordName)
        }

        record["localId"] = timeEntry.id as CKRecordValue
        record["itemId"] = timeEntry.itemId as CKRecordValue
        record["startedAt"] = timeEntry.startedAt as CKRecordValue
        record["endedAt"] = timeEntry.endedAt as CKRecordValue?
        record["duration"] = timeEntry.duration as CKRecordValue?
        record["modifiedAt"] = timeEntry.modifiedAt as CKRecordValue?
        record["deletedAt"] = timeEntry.deletedAt as CKRecordValue?

        return record
    }

    static func timeEntry(from record: CKRecord) -> TimeEntry? {
        guard record.recordType == CloudKitManager.RecordType.timeEntry,
              let localId = record["localId"] as? String,
              let itemId = record["itemId"] as? String,
              let startedAt = record["startedAt"] as? Int else {
            return nil
        }

        return TimeEntry(
            id: localId,
            itemId: itemId,
            startedAt: startedAt,
            endedAt: record["endedAt"] as? Int,
            duration: record["duration"] as? Int,
            modifiedAt: record["modifiedAt"] as? Int,
            ckRecordName: record.recordID.recordName,
            ckChangeTag: record.recordChangeTag,
            ckSystemFields: encodeSystemFields(record),
            needsPush: 0,
            deletedAt: record["deletedAt"] as? Int
        )
    }

    // MARK: - SavedSearch

    /// Convert SavedSearch to CKRecord for push.
    static func record(from savedSearch: SavedSearch, manager: CloudKitManager = .shared) -> CKRecord {
        let record: CKRecord

        if let existingRecord = decodeSystemFields(savedSearch.ckSystemFields, manager: manager) {
            record = existingRecord
        } else {
            let recordName = savedSearch.ckRecordName ?? "SavedSearch_\(savedSearch.id)"
            record = manager.newRecord(type: CloudKitManager.RecordType.savedSearch, recordName: recordName)
        }

        record["localId"] = savedSearch.id as CKRecordValue
        record["name"] = savedSearch.name as CKRecordValue
        record["sql"] = savedSearch.sql as CKRecordValue
        record["sortOrder"] = savedSearch.sortOrder as CKRecordValue
        record["createdAt"] = savedSearch.createdAt as CKRecordValue
        record["modifiedAt"] = savedSearch.modifiedAt as CKRecordValue
        record["deletedAt"] = savedSearch.deletedAt as CKRecordValue?

        return record
    }

    static func savedSearch(from record: CKRecord) -> SavedSearch? {
        guard record.recordType == CloudKitManager.RecordType.savedSearch,
              let localId = record["localId"] as? String,
              let name = record["name"] as? String,
              let sql = record["sql"] as? String else {
            return nil
        }

        return SavedSearch(
            id: localId,
            name: name,
            sql: sql,
            sortOrder: record["sortOrder"] as? Int ?? 0,
            createdAt: record["createdAt"] as? Int ?? Int(Date().timeIntervalSince1970),
            modifiedAt: record["modifiedAt"] as? Int ?? Int(Date().timeIntervalSince1970),
            ckRecordName: record.recordID.recordName,
            ckChangeTag: record.recordChangeTag,
            ckSystemFields: encodeSystemFields(record),
            needsPush: 0,
            deletedAt: record["deletedAt"] as? Int
        )
    }
}
