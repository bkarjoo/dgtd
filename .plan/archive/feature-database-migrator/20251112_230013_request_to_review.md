**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** feature-database-migrator

**Requirements:** See `.lifecycle/feature-database-migrator/requirements.md` for detailed specifications

## Assignment: Review Requirements - GRDB DatabaseMigrator Implementation

### Context

Following the completion of the database schema migration issue, the review team identified a critical limitation in the current implementation:

**Current Approach:** Drop all tables and recreate from schema.sql when any table is missing
**Problem:** Complete data loss on every schema change
**Impact:** Acceptable for development, UNACCEPTABLE for production use

This feature implements GRDB's DatabaseMigrator to enable versioned, incremental migrations that preserve user data during schema evolution.

### Your Review Tasks

#### 1. Requirements Validation

Review `.lifecycle/feature-database-migrator/requirements.md` and verify:

**Completeness:**
- Are all critical scenarios addressed? (fresh install, existing database, future migrations)
- Are success criteria clearly defined and measurable?
- Are edge cases comprehensively identified?

**Clarity:**
- Are technical specifications clear enough for implementation?
- Is the scope well-defined (what's included vs. excluded)?
- Are the references to current code and GRDB documentation sufficient?

**Feasibility:**
- Is the estimated complexity (MEDIUM) accurate?
- Are there any technical blockers or risks not mentioned?
- Does GRDB's DatabaseMigrator actually support the requirements as specified?

#### 2. State Machine Analysis (MANDATORY per Baton System README)

This feature involves database state transitions. Verify the requirements address:

**State Variables:**
- Database states: empty, has-current-schema, has-old-schema, migration-metadata-exists
- Migration states: not-started, in-progress, completed, failed

**State Transition Table:**
- Fresh install → Apply all migrations from v1
- Existing current schema → Mark v1 as applied, ready for future migrations
- Empty database → Apply all migrations
- Failed migration → Error state (how to recover?)

**Edge Case Behavior:**
- What happens if migration v1 is partially applied?
- What happens if migration metadata is corrupted?
- How do we detect "existing database has current schema"?

**Missing Specifications:**
If state transitions are not fully specified, flag as incomplete. The requirements MUST define edge case behavior before development begins.

#### 3. Backward Compatibility Analysis

Critically evaluate the backward compatibility strategy:

**Risk Assessment:**
- Current users have databases with no migration metadata - how do we detect this?
- How do we differentiate "fresh install" from "existing database with current schema"?
- Is the plan to mark v1 as applied for existing databases safe?

**Migration Path Verification:**
- Can we reliably detect all 5 tables exist with correct schema?
- What if a user has a partially broken database from previous drop/recreate logic?

#### 4. Testing Strategy Review

Evaluate whether the testing requirements are sufficient:

**Automated Test Coverage:**
- Can we write automated tests for all scenarios?
- Are there scenarios requiring manual testing?
- How do we test "existing database" scenarios in automated tests?

**Edge Case Testing:**
- Are all identified edge cases testable?
- Are there additional edge cases that should be tested?

### Critical Questions to Answer

1. **State Detection:** How do we reliably detect whether a database has the current schema vs. is empty vs. is from an old version?

2. **Migration Metadata:** Where does GRDB store migration metadata? Can we inspect it to verify which migrations have been applied?

3. **Failure Recovery:** If a migration fails halfway through, what state is the database in? How does the user recover?

4. **Testing Fresh vs. Existing:** How do we test the "existing database" path in automated tests without manually creating old database files?

5. **One-time Transition:** The requirements say "one final data loss" is acceptable to transition to the new system. Should we document this for users, or handle it silently?

### Expected Deliverables

**Status:** APPROVED / REQUIRES CHANGES / BLOCKED

**Requirements Assessment:**
[Are requirements complete, clear, and feasible?]

**State Machine Analysis:**
[Are state transitions fully specified? What's missing?]

**Recommended Changes:**
[List any additions, clarifications, or modifications needed]

**Blockers/Questions:**
[Any unresolved issues that need clarification before development]

**Next Steps:**
[If APPROVED: Send to dev. If REQUIRES CHANGES: List what needs updated. If BLOCKED: Explain blocker]

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
