# Firebase Notification System — AI Implementation Specification

**Project:** Survey Desk / Appointment Booking App  
**Stack:** Flutter + Riverpod + Firebase Auth + Firestore + Storage + Cloud Functions + Firebase Cloud Messaging  
**Purpose:** Production-ready implementation specification for the Firebase notification system.

---

## 1. Implementation Goal

Implement a complete Firebase Cloud Messaging (FCM) notification system for the appointment booking application.

The implementation MUST:

- Follow the existing MVVM + feature-first + SOLID architecture.
- Keep Firebase SDK access out of Flutter ViewModels.
- Use a dedicated notification service abstraction.
- Let Cloud Functions determine notification recipients.
- Store FCM registration tokens against authenticated users.
- Handle foreground, background, and terminated notification states.
- Support notification tap navigation through `go_router`.
- Support the Applicant, Admin, and Committee roles.
- Integrate notifications with the existing appointment workflow.
- Avoid sensitive personal information in FCM payloads.
- Support testing with only one physical Android device.
- Work with the existing Firebase Emulator Suite for backend testing.
- Not break an appointment workflow when FCM delivery fails.

Do not redesign the existing appointment workflow or state machine while implementing notifications.

---

# 2. Existing Project Architecture

The project uses:

- Flutter
- Riverpod `Notifier` / `AsyncNotifier`
- MVVM
- Feature-first modularity
- SOLID
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Cloud Functions
- Firebase Cloud Messaging
- `go_router`

The architecture requires:

```text
View
  ↓
ViewModel
  ↓
Repository / Service Interface
  ↓
Concrete Firebase Service
  ↓
Firebase
```

Views render UI and forward actions.

ViewModels orchestrate state and business flow but MUST NOT directly call:

```dart
FirebaseFirestore.instance
FirebaseStorage.instance
FirebaseMessaging.instance
FirebaseAuth.instance
```

Firebase access belongs in repositories/services.

The existing architecture specifically defines Firebase-backed concrete services behind abstract interfaces.

---

# 3. Notification Architecture

Use the following architecture:

```text
                         Flutter App
                             │
                    NotificationService
                             │
                     FCM registration
                         token
                             │
                             ▼
                    users/{uid}
                    fcmTokens: [...]
                             │
                             │
                             ▼
                     Cloud Functions
                             │
                    Recipient Resolver
                             │
                    Notification Service
                             │
                             ▼
                    Firebase Cloud Messaging
                             │
                             ▼
                       Android Device
                             │
                ┌────────────┼────────────┐
                ▼            ▼            ▼
            Foreground   Background   Terminated
```

## Critical architectural rule

Cloud Functions decide:

- who should receive a notification
- which notification type is sent
- which appointment the notification refers to

Flutter decides:

- how to register the device
- how to receive the notification
- how to display it
- where to navigate when it is tapped

Do not move recipient-selection business logic into Flutter.

---

# 4. Notification Responsibilities

## Flutter

Flutter is responsible for:

- FCM initialization
- Android notification permission
- FCM token registration
- FCM token refresh
- foreground message handling
- background message handling
- terminated-state handling
- notification parsing
- notification tap handling
- navigation

## Firestore

Firestore stores the FCM tokens associated with users.

For MVP:

```text
users/{uid}
    fcmTokens: array<string>
```

## Cloud Functions

Cloud Functions are responsible for:

- determining recipients
- generating notification payloads
- sending FCM messages
- handling invalid/stale tokens
- integrating notifications with appointment workflow functions

## Firestore appointment state

The appointment document remains the authoritative source of workflow state.

FCM is a secondary communication mechanism and MUST NOT become the source of truth.

---

# 5. Files to Create

Create the following Flutter files:

```text
lib/
├── core/
│   ├── models/
│   │   └── notification_message.dart
│   │
│   ├── repositories/
│   │   └── notification_repository.dart
│   │
│   ├── services/
│   │   ├── notification_service.dart
│   │   └── firebase_notification_service.dart
│   │
│   └── routing/
│       └── notification_navigation.dart
│
└── features/
    └── notifications/
        ├── view/
        │   └── notification_overlay.dart
        │
        └── viewmodel/
            └── notification_viewmodel.dart
```

If the existing project uses a different provider folder convention, follow the existing project convention rather than creating unnecessary duplicate provider folders.

Backend:

```text
functions/
├── notifications/
│   ├── notification_types.js
│   ├── notification_recipients.js
│   ├── notification_payload.js
│   └── send_push_notification.js
│
└── ...
```

Integrate these modules into the existing Cloud Functions structure.

Do not duplicate existing Firebase initialization or service infrastructure.

---

# 6. Firestore Schema Change

The existing `users/{uid}` document should be extended with:

```text
fcmTokens: array<string>
```

Example:

```json
{
  "role": "committee",
  "fullName": "Committee Test User",
  "email": "committee@example.com",
  "fcmTokens": [
    "FCM_TOKEN_1",
    "FCM_TOKEN_2"
  ]
}
```

## Important

Do not add a separate notification collection for the MVP.

Do not introduce:

```text
notifications/{notificationId}
```

unless an explicit product requirement is added later.

The current MVP only needs push notification delivery.

---

# 7. FCM Token Design

A user can have multiple FCM tokens because the same account can eventually be logged in on multiple devices.

Therefore:

```text
fcmTokens: array<string>
```

is preferred over:

```text
fcmToken: string
```

The implementation MUST:

- add a token only once
- update tokens when FCM rotates them
- remove invalid tokens
- associate the current installation with the currently authenticated user

---

# 8. One-Device Role Switching

The project must support testing all three roles using one physical Android device.

Example:

```text
One Android Device
       │
       ├── Applicant Test Account
       ├── Admin Test Account
       └── Committee Test Account
```

When the device changes authenticated accounts, the current FCM token must be associated with the currently authenticated user.

Example:

```text
Applicant login
    ↓
Applicant → TOKEN_A

Logout
    ↓

Admin login
    ↓
Admin → TOKEN_A
Applicant → TOKEN_A removed
```

Then:

```text
Admin logout
    ↓
Committee login
    ↓
Committee → TOKEN_A
Admin → TOKEN_A removed
```

This prevents a notification intended for a previous test role from being delivered to the currently logged-in role.

---

# 9. FCM Token Lifecycle

Implement the following lifecycle.

## On authenticated startup/login

```text
Firebase Auth user resolved
        ↓
Firebase Messaging getToken()
        ↓
register token for user
```

## On token refresh

Listen to:

```dart
FirebaseMessaging.instance.onTokenRefresh
```

Then update Firestore.

## On account switch

When the authenticated user changes:

```text
remove current token from old user
add current token to new user
```

Do not allow duplicate token entries.

---

# 10. Notification Model

Create:

```dart
enum NotificationType {
  bookingCreated,
  reviewerAssigned,
  rejected,
  clarificationRequested,
  clarificationReply,
  approved,
  taskAssigned,
}
```

Create a notification model similar to:

```dart
class NotificationMessage {
  final NotificationType type;
  final String? appointmentId;
  final String? title;
  final String? body;

  const NotificationMessage({
    required this.type,
    this.appointmentId,
    this.title,
    this.body,
  });
}
```

The model should safely handle unknown notification types.

Unknown notification types MUST NOT crash the application.

---

# 11. Standard FCM Payload

Every application notification MUST use a consistent data payload.

Example:

```json
{
  "type": "reviewer_assigned",
  "appointmentId": "abc123"
}
```

Another example:

```json
{
  "type": "clarification_requested",
  "appointmentId": "abc123"
}
```

Another:

```json
{
  "type": "task_assigned",
  "appointmentId": "abc123"
}
```

## Payload requirements

The data payload should contain:

- notification type
- appointment ID when applicable

Do NOT include sensitive information such as:

- applicant phone
- applicant email
- XEN phone
- XEN email
- rejection reason
- clarification text
- document URLs
- Storage download URLs
- authentication information

When a notification is tapped:

```text
notification
    ↓
appointmentId
    ↓
Firestore
    ↓
authoritative appointment data
```

---

# 12. Notification Service Interface

Create an abstraction:

```dart
abstract interface class NotificationService {
  Future<void> initialize();

  Future<void> requestPermission();

  Future<String?> getToken();

  Future<void> registerToken();

  Future<void> unregisterToken();

  Stream<NotificationMessage> get foregroundMessages;

  Stream<NotificationMessage> get notificationOpened;
}
```

The exact interface may be adjusted to match existing project conventions, but the implementation must preserve dependency inversion.

---

# 13. Firebase Notification Service

Create:

```text
firebase_notification_service.dart
```

This is the ONLY Flutter service that should directly interact with:

```dart
FirebaseMessaging.instance
```

It should handle:

```text
initialize()
requestPermission()
getToken()
onTokenRefresh
onMessage
onMessageOpenedApp
getInitialMessage()
```

No ViewModel should directly access Firebase Messaging.

---

# 14. Application Startup

Integrate notification initialization into the existing Firebase startup flow.

Conceptually:

```text
main()
  ↓
WidgetsFlutterBinding.ensureInitialized()
  ↓
Firebase.initializeApp()
  ↓
NotificationService.initialize()
  ↓
Crashlytics initialization
  ↓
runApp()
```

Do not duplicate Firebase initialization.

Do not put the complete notification implementation inside `main.dart`.

`main.dart` should only wire services/providers.

---

# 15. Android Notification Permission

Handle notification permission on Android versions that require runtime notification permission.

Do not make notification permission failure block authentication.

Recommended flow:

```text
Login
  ↓
Role resolved
  ↓
Notification permission request
```

If permission is denied:

- app continues working
- FCM token handling should fail gracefully
- no crash
- no infinite permission loop

---

# 16. Foreground Notifications

When the application is open:

```text
FCM
 ↓
onMessage
 ↓
NotificationViewModel
 ↓
NotificationOverlay
```

Display an in-app notification UI.

Example:

```text
┌──────────────────────────────────┐
│ 🔔 New appointment assigned      │
│                                  │
│ An appointment has been assigned │
│ to you for review.               │
│                                  │
│                    VIEW          │
└──────────────────────────────────┘
```

The UI must not contain sensitive appointment details unless those details are intentionally loaded from Firestore.

---

# 17. Background Notifications

When the app is backgrounded:

```text
FCM
 ↓
Android notification tray
 ↓
User taps
 ↓
onMessageOpenedApp
 ↓
notification navigation
```

The notification tap must result in the correct appointment screen.

---

# 18. Terminated-State Notifications

When the application is terminated:

```text
FCM
 ↓
Android notification
 ↓
User taps
 ↓
Application starts
 ↓
getInitialMessage()
 ↓
Auth initialization
 ↓
Role resolution
 ↓
Router initialization
 ↓
Process notification
 ↓
Navigate
```

Do not navigate before authentication and role resolution are complete.

If a notification arrives before the router is ready, retain the pending notification and process it after startup.

---

# 19. Notification Navigation

Create:

```text
lib/core/routing/notification_navigation.dart
```

Centralize notification-to-route mapping.

Conceptually:

```text
reviewerAssigned
    ↓
Committee Review Detail

rejected
    ↓
Applicant Appointment Detail

clarificationRequested
    ↓
Applicant Appointment Detail

clarificationReply
    ↓
Committee Review Detail

approved
    ↓
Applicant Appointment Detail

taskAssigned
    ↓
Appropriate appointment/task screen
```

Use the project's existing `go_router` configuration.

Do not directly instantiate feature widgets from the notification service.

Navigation should happen through the existing routing architecture.

---

# 20. Authorization After Notification Tap

Never assume that receiving a notification means the user is still authorized to view the appointment.

After the user taps:

```text
notification
    ↓
appointmentId
    ↓
navigate
    ↓
load appointment
    ↓
security authorization
```

If access is no longer valid:

```text
Appointment unavailable
```

Do not expose appointment data.

This is particularly important if a Committee reviewer is later replaced.

---

# 21. Notification Recipient Matrix

Implement the following notification matrix.

| Event | Recipient |
|---|---|
| Booking created | Admin |
| Reviewer assigned | Assigned Committee Member |
| Rejected | Applicant |
| Clarification requested | Applicant |
| Clarification reply | Assigned Committee Reviewer |
| Approved | Applicant |
| Fieldwork task assigned | Applicant + Assigned Committee Task Member |

Do not broadcast reviewer notifications to every Committee member.

Do not broadcast applicant notifications to every applicant.

---

# 22. `submitAppointment`

Existing function:

```text
submitAppointment
```

must continue to perform the appointment creation workflow.

After successful appointment creation:

```text
submitAppointment
    ↓
validate
    ↓
rate-limit transaction
    ↓
create appointment
    ↓
audit log
    ↓
notify Admin
```

Do not send the notification before the appointment exists successfully.

The appointment creation transaction remains authoritative.

---

# 23. `assignReviewer`

Existing function:

```text
assignReviewer
```

should:

```text
assignReviewer
    ↓
authorize Admin
    ↓
validate appointment state
    ↓
validate Committee member
    ↓
update appointment
    ↓
write audit log
    ↓
send notification to assignedReviewerId
```

Notification:

```json
{
  "type": "reviewer_assigned",
  "appointmentId": "abc123"
}
```

Only the assigned Committee member receives this notification.

---

# 24. `reviewAppointment`

Existing function supports:

```text
approve
reject
request clarification
```

Integrate notifications as follows.

### Approve

```text
reviewAppointment(approve)
    ↓
status = approved
    ↓
audit log
    ↓
notify Applicant
```

### Reject

```text
reviewAppointment(reject)
    ↓
status = rejected
    ↓
rejectionReason saved
    ↓
audit log
    ↓
notify Applicant
```

### Clarification

```text
reviewAppointment(clarify)
    ↓
status = clarification_requested
    ↓
clarificationNote saved
    ↓
audit log
    ↓
notify Applicant
```

---

# 25. `submitClarificationReply`

Existing function:

```text
submitClarificationReply
```

should:

```text
Applicant
    ↓
submit reply
    ↓
status = under_review
    ↓
audit log
    ↓
notify assignedReviewerId
```

Notification:

```json
{
  "type": "clarification_reply",
  "appointmentId": "abc123"
}
```

---

# 26. `assignFieldworkTask`

Existing function:

```text
assignFieldworkTask
```

should:

```text
Admin
    ↓
assign task member
    ↓
status = task_assigned
    ↓
audit log
    ├───────────────┐
    ▼               ▼
Applicant       Task Member
```

Send:

- Applicant notification
- Assigned Committee task-member notification

Do not assume the task member is the same as the review member.

The backend schema explicitly allows them to be different.

---

# 27. Centralized Cloud Functions Notification Modules

Create:

```text
functions/notifications/notification_types.js
functions/notifications/notification_recipients.js
functions/notifications/notification_payload.js
functions/notifications/send_push_notification.js
```

## `notification_types.js`

Centralize notification identifiers.

Example:

```javascript
const NotificationType = Object.freeze({
  BOOKING_CREATED: 'booking_created',
  REVIEWER_ASSIGNED: 'reviewer_assigned',
  REJECTED: 'rejected',
  CLARIFICATION_REQUESTED: 'clarification_requested',
  CLARIFICATION_REPLY: 'clarification_reply',
  APPROVED: 'approved',
  TASK_ASSIGNED: 'task_assigned',
});
```

Use the same values consistently between backend and Flutter.

---

# 28. Recipient Resolver

Create a single recipient resolver.

Conceptually:

```javascript
function getNotificationRecipients(type, appointment) {
  switch (type) {
    case 'booking_created':
      return [/* Admin user IDs */];

    case 'reviewer_assigned':
      return [appointment.assignedReviewerId];

    case 'rejected':
      return [appointment.applicantId];

    case 'clarification_requested':
      return [appointment.applicantId];

    case 'clarification_reply':
      return [appointment.assignedReviewerId];

    case 'approved':
      return [appointment.applicantId];

    case 'task_assigned':
      return [
        appointment.applicantId,
        appointment.assignedTaskMemberId,
      ];

    default:
      return [];
  }
}
```

Do not duplicate this logic inside individual appointment functions.

---

# 29. Centralized FCM Sender

Create:

```text
send_push_notification.js
```

with a helper similar to:

```javascript
async function sendPushNotification({
  userId,
  type,
  appointmentId,
  title,
  body,
}) {
  // Load FCM tokens
  // Build FCM message
  // Send message
  // Remove invalid tokens
}
```

Business functions should call this helper rather than directly implementing FCM logic.

---

# 30. Notification Delivery Must Not Break Workflow

This is a critical requirement.

Suppose:

```text
assignReviewer
```

successfully updates Firestore but FCM fails.

The appointment must remain:

```text
under_review
```

Do NOT roll back the workflow because FCM delivery failed.

The priority is:

```text
1. Authoritative Firestore state
2. Audit log
3. Notification delivery
```

Notification failure should be logged and handled separately.

---

# 31. Invalid FCM Token Cleanup

When FCM reports a token as invalid/unregistered:

```text
FCM send
    ↓
invalid token
    ↓
remove token from users/{uid}.fcmTokens
```

This prevents dead tokens accumulating indefinitely.

---

# 32. Notification Failure Logging

Log only technical information necessary for debugging:

```text
notificationType
recipientUid
appointmentId
FCM result/error category
```

Do NOT log:

```text
Applicant email
Applicant phone
XEN email
XEN phone
rejectionReason
clarificationNote
document content
download URLs
```

Do not place PII in Crashlytics breadcrumbs or custom keys.

---

# 33. Email vs Push

Do not merge email and FCM into one mechanism.

The project has separate requirements:

```text
Email:
SendGrid / Trigger Email

Push:
Firebase Cloud Messaging
```

The notification system should only own FCM.

Existing email workflows should remain unchanged.

---

# 34. Testing Architecture

Use three testing layers.

## Layer 1 — Unit tests

Test:

```text
NotificationType
NotificationMessage
payload parsing
notification routing
notification navigation
recipient resolution
```

## Layer 2 — Cloud Function tests

Test:

```text
submitAppointment
assignReviewer
reviewAppointment
submitClarificationReply
assignFieldworkTask
```

Verify:

- state transition
- recipient
- notification type
- appointment ID
- failure handling

## Layer 3 — Real-device FCM tests

Test:

- foreground
- background
- terminated
- notification tap
- token refresh
- permission denied
- account switching

---

# 35. One-Device Testing Strategy

Create these Firebase test accounts:

```text
Applicant Test
Admin Test
Committee Test A
Committee Test B
```

Use one physical Android device.

The device can switch accounts.

However, for actual push delivery testing, keep the intended recipient logged in and trigger the sender's workflow from:

- Firebase Emulator tooling
- development backend tooling
- test scripts
- appropriate Admin/test function tooling

Example:

```text
Phone:
Committee Test A

PC:
Admin test action
       ↓
assignReviewer()
       ↓
FCM
       ↓
Phone
       ↓
Committee notification
```

Do not require three physical phones.

---

# 36. Firebase Emulator Suite

Use the Firebase Emulator Suite for:

```text
Auth
Firestore
Functions
Storage
```

Use real Firebase Cloud Messaging for actual push-delivery tests.

Separate:

```text
Backend notification logic
```

from:

```text
Real FCM delivery
```

The Emulator Suite should verify:

- recipient resolution
- appointment state changes
- notification function invocation
- payload generation

Real Android + FCM should verify:

- actual push delivery
- Android notification UI
- foreground behavior
- background behavior
- terminated behavior
- tap handling

---

# 37. Test Matrix

Create and execute the following matrix.

| # | Action | Sender | Recipient | Expected |
|---|---|---|---|---|
| 1 | Booking created | Applicant | Admin | New appointment |
| 2 | Reviewer assigned | Admin | Committee | Review assignment |
| 3 | Reject | Committee | Applicant | Rejection |
| 4 | Request clarification | Committee | Applicant | Clarification |
| 5 | Clarification reply | Applicant | Committee | Reply |
| 6 | Approve | Committee | Applicant | Approval |
| 7 | Assign fieldwork | Admin | Committee | Task assignment |
| 8 | Assign fieldwork | Admin | Applicant | Task assignment/approval |

For every notification, test:

```text
Foreground
Background
Terminated
Tap navigation
Correct appointment
Correct authorization
```

---

# 38. Unit Test Checklist

Create tests covering:

```text
[ ] NotificationType parsing
[ ] Unknown notification type handling
[ ] Notification payload parsing
[ ] Missing appointmentId handling
[ ] Token registration
[ ] Duplicate token prevention
[ ] Token refresh
[ ] Token removal
[ ] Foreground message parsing
[ ] Background message parsing
[ ] Terminated message parsing
[ ] Notification navigation mapping
[ ] Unknown notification fallback
```

---

# 39. Cloud Function Test Checklist

```text
[ ] submitAppointment notifies Admin
[ ] assignReviewer notifies assigned Committee member
[ ] reject notifies Applicant
[ ] clarification request notifies Applicant
[ ] clarification reply notifies assigned reviewer
[ ] approval notifies Applicant
[ ] task assignment notifies Applicant
[ ] task assignment notifies assigned task member
[ ] wrong role cannot trigger protected workflow
[ ] FCM failure does not roll back workflow
[ ] invalid token is removed
```

---

# 40. Real Android Test Checklist

```text
[ ] Notification permission granted
[ ] Notification permission denied
[ ] FCM token generated
[ ] FCM token stored
[ ] Token refresh handled
[ ] Foreground notification received
[ ] Background notification received
[ ] Terminated notification received
[ ] Notification tap works
[ ] Correct appointment opens
[ ] Correct role screen opens
[ ] Unauthorized appointment access is blocked
[ ] Account switching updates token ownership
```

---

# 41. Full End-to-End Test

The complete test should eventually work like this:

```text
Applicant
   │
   │ submitAppointment()
   ▼
Firestore
   │
   ├── appointment created
   ├── auditLog created
   │
   ▼
FCM → Admin
   │
   ▼
Admin
   │
   │ assignReviewer()
   ▼
Firestore
   │
   ▼
FCM → Committee
   │
   ▼
Committee
   │
   │ approve/reject/clarify
   ▼
Firestore
   │
   ├── auditLog
   │
   ▼
FCM → Applicant / Reviewer
   │
   ▼
Admin
   │
   │ assignFieldworkTask()
   ▼
Firestore
   │
   ├── Applicant notification
   └── Committee notification
```

Verify Firestore state after every transition.

---

# 42. Security Requirements

The implementation MUST NOT:

- trust a client-supplied recipient UID
- allow users to send arbitrary notifications
- allow Applicants to notify arbitrary Committee members
- expose FCM tokens to other users
- expose sensitive appointment data in notification payloads
- use FCM as an authorization mechanism
- bypass Firestore/Storage security rules because a notification contains an appointment ID

The server determines the recipient.

---

# 43. Notification Tap Security

When a notification is tapped:

```text
appointmentId
```

is only a navigation hint.

The application must still load the appointment through the normal authorized repository.

Never assume notification payloads are trusted.

---

# 44. Performance Requirements

Notification handling should not block application startup unnecessarily.

Avoid:

```text
Splash
 ↓
wait indefinitely for FCM
 ↓
app opens
```

FCM initialization failures should be non-fatal.

The application must remain usable if:

- notification permission is denied
- FCM token retrieval fails
- FCM token registration fails
- notification delivery fails
- a notification has an unknown type

---

# 45. Observability

Integrate notification errors with the project's existing Crashlytics strategy.

Useful non-PII information:

```text
notification_type
current_role
app_state
```

Do not record:

```text
email
phone
XEN contact information
free-text rejection reason
clarification text
document names if they contain sensitive information
```

Use Crashlytics for failures, not as a notification database.

---

# 46. Analytics

Do not automatically add new analytics events unless required.

The existing analytics scope already includes:

```text
sign_up
login
booking_wizard_started
booking_submitted
review_action_taken
```

If notification analytics are added later, define them explicitly.

Potential future events:

```text
notification_received
notification_opened
```

But these should not be required for the initial notification implementation unless the existing analytics scope is intentionally expanded.

---

# 47. Existing Architecture Boundaries

Follow these rules:

1. `features/` may import `core/`.
2. `features/` must not directly import another feature's ViewModel.
3. Notification service belongs in `core/services`.
4. Notification model belongs in `core/models`.
5. Notification navigation belongs in `core/routing`.
6. Notification UI belongs in the notifications feature.
7. Firebase Messaging SDK calls belong only in the concrete Firebase notification service.
8. Cloud Functions own recipient selection.
9. Appointment workflow remains authoritative in Firestore.
10. Notification delivery is secondary to successful workflow state changes.

---

# 48. Do Not Introduce These Changes

While implementing this feature, do NOT:

- rewrite the existing appointment architecture
- replace Riverpod
- replace `go_router`
- introduce a new state-management package
- create a separate notification Firestore collection
- move appointment business logic into Flutter notification code
- put Firebase Messaging calls in ViewModels
- put notification recipient logic in Flutter
- change appointment status values
- change existing appointment schemas except the required `fcmTokens`
- add persisted wizard drafts
- add chat functionality
- add SMS notifications

Keep the implementation focused on FCM.

---

# 49. Suggested Implementation Order

Implement in exactly this order.

## Phase 1 — Flutter infrastructure

1. Add `firebase_messaging`.
2. Create `NotificationMessage`.
3. Create `NotificationType`.
4. Create `NotificationService`.
5. Create `FirebaseNotificationService`.
6. Initialize FCM.
7. Request notification permission.
8. Retrieve token.
9. Register token.
10. Handle token refresh.
11. Handle account switching.
12. Implement foreground handling.
13. Implement background handling.
14. Implement terminated-state handling.

## Phase 2 — Notification navigation

15. Create notification navigation mapper.
16. Integrate with `go_router`.
17. Add pending-notification handling during startup.
18. Add authorization check after notification navigation.

## Phase 3 — Backend

19. Add `fcmTokens` to user schema.
20. Create notification types.
21. Create recipient resolver.
22. Create payload builder.
23. Create FCM sender.
24. Add invalid-token cleanup.

## Phase 4 — Workflow integration

25. Integrate `submitAppointment`.
26. Integrate `assignReviewer`.
27. Integrate `reviewAppointment`.
28. Integrate `submitClarificationReply`.
29. Integrate `assignFieldworkTask`.

## Phase 5 — Testing

30. Unit tests.
31. Emulator Function tests.
32. Real FCM direct test.
33. Foreground test.
34. Background test.
35. Terminated test.
36. Tap-navigation test.
37. One-device role-switch test.
38. Complete end-to-end workflow test.

---

# 50. Definition of Done

The implementation is complete only when all of the following are true:

```text
[ ] firebase_messaging configured
[ ] NotificationService interface created
[ ] FirebaseNotificationService implemented
[ ] Android notification permission handled
[ ] FCM token registered after authentication
[ ] Token refresh handled
[ ] Duplicate tokens prevented
[ ] Account switching updates token ownership
[ ] Foreground messages handled
[ ] Background messages handled
[ ] Terminated messages handled
[ ] Notification payload standardized
[ ] Notification tap navigation implemented
[ ] Auth/role initialization is respected before navigation
[ ] Appointment authorization checked after navigation
[ ] Cloud Function notification helper implemented
[ ] Recipient resolver implemented
[ ] Invalid FCM tokens removed
[ ] Booking-created notification tested
[ ] Reviewer-assigned notification tested
[ ] Rejection notification tested
[ ] Clarification notification tested
[ ] Clarification-reply notification tested
[ ] Approval notification tested
[ ] Fieldwork assignment notification tested
[ ] Applicant receives appropriate task/approval notification
[ ] Committee task member receives task notification
[ ] FCM failure does not break appointment workflow
[ ] No PII is included in FCM data payload
[ ] No PII is included in notification debugging logs
[ ] Emulator backend tests pass
[ ] Real-device FCM tests pass
[ ] Foreground tested
[ ] Background tested
[ ] Terminated tested
[ ] One-device role switching tested
[ ] Notification tap tested
[ ] Security/authorization verified
```

---

# 51. Final Implementation Principle

The notification system must follow this rule:

```text
              APPOINTMENT STATE
                     │
                     │ authoritative
                     ▼
                Firestore
                     │
                     │ event/action
                     ▼
              Cloud Function
                     │
              recipient resolver
                     │
                     ▼
                   FCM
                     │
                     ▼
              Flutter Device
                     │
             notification tap
                     │
                     ▼
              go_router
                     │
                     ▼
         Authorized appointment data
```

**Firestore determines what happened.  
Cloud Functions determine who should know.  
FCM delivers the notification.  
Flutter displays it and navigates.**

Do not invert these responsibilities.
