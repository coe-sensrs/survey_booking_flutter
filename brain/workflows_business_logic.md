# 🔄 Workflows, Business Logic & State Machines

**Parent Index:** [brain.md](file:///d:/flutter%20projects/survey_booking_app/brain/brain.md)

---

## 1. Appointment 6-State Lifecycle State Machine

An appointment moves through 6 strictly governed status states:

```mermaid
stateDiagram-v2
    [*] --> pending_assignment: Wizard Submission (submitAppointment)
    
    pending_assignment --> under_review: Admin assigns reviewer (assignReviewer)
    
    under_review --> approved: Committee Approves (reviewAppointment)
    under_review --> rejected: Committee Rejects (reviewAppointment)
    under_review --> clarification_requested: Committee Requests Info (reviewAppointment)
    
    clarification_requested --> under_review: Applicant Responds (submitClarificationReply)
    
    approved --> task_assigned: Admin assigns fieldwork task (assignFieldworkTask)
    
    rejected --> [*]: Closed (Applicant must resubmit fresh booking)
    task_assigned --> [*]: Fieldwork Completed
```

### State Definitions & Permitted Operations

| State Name | Allowed Actions & Mutators | Permitted Next States |
|---|---|---|
| `pending_assignment` | Admin assigns reviewer via `assignReviewer` | `under_review` |
| `under_review` | Committee member reviews details, executes `reviewAppointment` | `approved`, `rejected`, `clarification_requested` |
| `clarification_requested` | Applicant submits single reply via `submitClarificationReply` | `under_review` |
| `approved` | Admin sets `confirmedDate` or assigns fieldwork task via `assignFieldworkTask` | `task_assigned` |
| `rejected` | Terminal state. Contains mandatory `rejectionReason` (max 500 chars) | None |
| `task_assigned` | Active fieldwork assigned to committee member (`assignedTaskMemberId`) | Terminal |

---

## 2. Core Business Workflows

### A. Clarification Roundtrip Workflow (Single-Reply Limit)

```mermaid
sequenceDiagram
    autonumber
    actor Comm as Committee Reviewer
    actor App as Applicant
    participant CF as Cloud Functions
    participant FS as Firestore Document

    Comm->>CF: reviewAppointment(action: "clarify", note: "Need clearance PDF")
    CF->>FS: Update status = "clarification_requested", clarificationNote = note
    CF-->>App: Push notification & email sent
    
    Note over App,FS: Applicant Reply Phase (Exactly 1 Reply Allowed)
    App->>CF: submitClarificationReply(replyText: "Uploaded updated PDF")
    CF->>FS: Check: clarificationReply == null?
    FS-->>CF: Yes (First reply)
    CF->>FS: Update status = "under_review", clarificationReply = text
    CF-->>Comm: Notify committee member to re-review
    
    Note over Comm,CF: Second Clarification Blocked
    Comm->>CF: reviewAppointment(action: "clarify", note: "Still invalid")
    CF-->>Comm: ERROR: Clarification already requested once. Must Approve or Reject.
```

---

### B. Home Screen Recent Activity Feed Aggregation

The applicant Home screen displays a unified feed of status transitions across all their appointments:

```mermaid
graph TD
    UI["Applicant Home UI"] --> CG["collectionGroup('auditLog') Query"]
    CG --> Filter["WHERE applicantId == currentUid ORDER BY timestamp DESC"]
    Filter --> Map["Map AuditLogEntry to Activity Cards"]
    Map --> Render["Render Approval / Rejection / Clarification feed items"]
```

> **Performance Strategy:** By denormalizing `applicantId` onto every `auditLog` subcollection document, the client runs a single indexed `collectionGroup` query rather than querying every individual appointment document's history separately.

---

### C. Admin Confirmed Date Management

Admins can set or modify the `confirmedDate` independently of the applicant's original `preferredDate`.
- `preferredDate`: Set during wizard Step 5 (applicant request).
- `confirmedDate`: Set post-approval via `setConfirmedDate` Cloud Function. Displayed prominently in the Applicant's "Upcoming Scheduled Surveys" list.
