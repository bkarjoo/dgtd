# SQLite Schema Review Requirements

## Objective
Conduct a comprehensive review of the DirectGTD SQLite database schema to identify potential issues, improvements, and best practices.

## Schema Location
- Primary: `DirectGTD/database/schema.sql`
- Secondary: `database/schema.sql`

## Review Focus Areas

### 1. Schema Design & Normalization
- Verify proper normalization (is the schema at appropriate normal form?)
- Check for data redundancy
- Assess table relationships and foreign key constraints
- Evaluate the hierarchical structure (parent_id self-references)

### 2. Data Types & Constraints
- Validate choice of data types (TEXT for IDs, INTEGER for timestamps, etc.)
- Check for missing NOT NULL constraints where appropriate
- Review default values
- Verify UNIQUE constraints are properly placed

### 3. Foreign Key Relationships
- Review ON DELETE CASCADE vs ON DELETE SET NULL choices
- Verify all foreign keys have proper constraints
- Check for potential orphaned record issues

### 4. Indexing Strategy
- Evaluate current indexes for query performance
- Identify missing indexes for common queries
- Check for over-indexing (unnecessary indexes)
- Consider composite indexes where appropriate

### 5. GTD-Specific Concerns
- Assess the status field enum values (next_action, waiting, someday, completed)
- Review the folder-based organization structure
- Evaluate the parent-child hierarchy for items (is_project flag + parent_id)
- Check the tagging system (many-to-many relationship)

### 6. Potential Issues to Check
- **Circular references**: Can folders or items create circular parent relationships?
- **Missing constraints**: Are there any fields that should have CHECK constraints?
- **Timestamp consistency**: INTEGER timestamps are used - verify this is Unix epoch
- **Status validation**: Should status have a CHECK constraint for valid values?
- **Context validation**: Should context values be normalized into a separate table?
- **Energy level validation**: Should energy_level have a CHECK constraint?

### 7. Schema Evolution & Migration
- Assess schema's ability to evolve (missing version tracking?)
- Consider adding a schema_version table
- Evaluate backward compatibility considerations

### 8. Performance Considerations
- Query patterns for GTD workflows (by status, by folder, by context)
- Sorting performance (sort_order fields)
- Full-text search needs (should content be indexed?)

## Expected Deliverables

1. **Issues Found**: List any bugs, errors, or critical problems
2. **Design Concerns**: Architectural or normalization issues
3. **Performance Recommendations**: Index suggestions, query optimization
4. **Data Integrity Suggestions**: Additional constraints, validations
5. **Best Practice Improvements**: SQLite-specific optimizations
6. **Priority Rating**: HIGH/MEDIUM/LOW for each finding

## Success Criteria
- All potential data integrity issues identified
- Performance bottlenecks highlighted
- Clear, actionable recommendations provided
- Priority-ordered list of improvements
