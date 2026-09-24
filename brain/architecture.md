# 🏗️ System Architecture, Design Patterns & Core Principles

**Parent Index:** [brain.md](file:///d:/flutter%20projects/survey_booking_app/brain/brain.md)

---

## 1. 3-Layer MVVM Architectural Pattern

The application enforces a **3-Layer MVVM (Model-View-ViewModel)** architecture:

```mermaid
graph LR
    subgraph View ["View Layer (UI)"]
        Widget["ConsumerWidget / ConsumerStatefulWidget"]
        Shells["ApplicantShellScreen / AdminShellScreen / CommitteeShellScreen"]
        Widgets["AppButton / AppTextField / SafeProfileAvatar / SurveyDocumentTiles / PdfViewerScreen"]
    end

    subgraph ViewModel ["ViewModel Layer (State)"]
        Riverpod["Riverpod Notifier / AsyncNotifier / StreamProvider"]
        ThemeVM["themeProvider (ThemeNotifier + Hive)"]
        WizardVM["BookingWizardViewModel (Step 1-9 Accumulator)"]
        AdminVM["AdminDashboardViewModel / AdminAppointmentDetailController"]
        CommVM["committeeDashboardStreamProvider / CommitteeReviewDetailController"]
        TaskVM["assignedTasksStreamProvider"]
    end

    subgraph Model ["Model Layer (Data & Domain)"]
        DataModels["AppUser / Appointment / XenDetails / Logistics / AuditLog"]
        RepoInterfaces["AppointmentReader / AppointmentWriter / UserRepository"]
        ConcreteServices["FirebaseAppointmentRepository / StorageUploadService / DocumentActionService / HiveStorageService"]
    end

    Widget -->|Watch State & Triggers| Riverpod
    Riverpod -->|Calls Abstract Methods| RepoInterfaces
    RepoInterfaces ..->|Implemented By| ConcreteServices
    ConcreteServices -->|Serialization| DataModels
```

### Layer Responsibilities:
1. **View (UI Layer):** `ConsumerWidget` / `ConsumerStatefulWidget`. Renders widgets, handles layout via `flutter_screenutil_plus` & `AppBreakpoints`, listens to Riverpod state. Zero direct Firebase SDK calls. Sub-widgets are split into focused `StatelessWidget` subclasses to minimize unnecessary widget rebuild scopes.
2. **ViewModel (State Layer):** Riverpod `Notifier`, `AsyncNotifier`, `StreamProvider.autoDispose`, and imperative Controllers. Holds local and async feature state, orchestrates repository invocations, applies business validation rules, and checks RBAC rights.
3. **Model (Data Layer):** Plain Dart data classes (`AppUser`, `Appointment`, etc.) + Abstract Repositories (`core/repositories/`) + Concrete Firebase implementations (`core/services/`).
   - **Dual Serialization Architectural Pattern (`toMap` vs `toJson`):**
     - `.toMap()`: Serializes models for direct Cloud Firestore writes via the Firestore SDK, emitting native `cloud_firestore.Timestamp` instances for date fields.
     - `.toJson()`: Serializes models for Cloud Functions / HTTP transport, emitting ISO-8601 strings for dates. This strictly complies with Flutter `cloud_functions` parameter constraints (`_debugIsValidParameterType`) which reject native Firestore `Timestamp` objects.
     - **Defensive Deserialization (`fromMap`):** Deserializers defensively handle both `Timestamp` and `String` date representations (e.g. `uploadedAt: map['uploadedAt'] is Timestamp ? ... : (map['uploadedAt'] is String ? DateTime.tryParse(...) : ...)`), immunizing the app against runtime type cast errors if documents are saved with string dates.
   - **Pre-Generated Appointment ID & Storage Path Synchronization Pattern:**
     - The client generates the real Firestore document ID (`appointmentRepo.newAppointmentId()` $\rightarrow$ `_firestore.collection('appointments').doc().id`) *before* uploading KML and permission files.
     - Files are uploaded to `appointments/<appointmentId>/kml/...` and `appointments/<appointmentId>/permissionDocuments/...`, ensuring Cloud Storage directory paths match the Firestore document ID from inception.
     - The pre-generated `appointmentId` is passed in the `submitAppointment` HTTPS Callable payload, ensuring the atomic server transaction commits to that exact document reference. This eliminates orphaned storage paths and allows Storage security rules to cross-reference the Firestore document without failure.

---

## 2. SOLID Principles Applied

- **Single Responsibility Principle (SRP):** Views render UI only. ViewModels manage state only. Repositories handle data persistence only.
- **Open/Closed Principle (OCP):** Config-driven survey types (`SurveyType` enum), status badges (`AppointmentStatus`), and wizard steps (`List<WizardStepConfig>`).
- **Liskov Substitution Principle (LSP):** Abstract repository interfaces (`AppointmentRepository`, `UserRepository`, `AuditLogRepository`) allow fully mockable repository implementations for unit testing without touching Firebase.
- **Interface Segregation Principle (ISP):** `AppointmentRepository` is split into `AppointmentReader` (read-only queries for dashboards & queues) and `AppointmentWriter` (mutations). Features depend only on the interface they consume.
- **Dependency Inversion Principle (DIP):** Feature ViewModels depend exclusively on abstract repository interfaces declared in `core/repositories/`, injected via Riverpod providers (`appointmentRepositoryProvider`, `userRepositoryProvider`).

---

## 3. Feature-First Modularity Rules

1. **Self-Contained Modules:** Code inside `lib/features/<feature>/` contains its own `view/` and `viewmodel/` directories.
2. **Strict Import Rule:** A feature may freely import from `lib/core/`. A feature may **NEVER** import from another feature's `view/` or `viewmodel/` directory.
3. **Cross-Feature Communication:** Handled solely via shared `core/` state (e.g., auth state, repository providers) or `GoRouter` navigation.
4. **Deletability Rule:** Deleting any single feature directory in `lib/features/` should cause zero compilation errors outside that directory (excluding route registration).

---

## 4. Multi-Role Shell Architecture

The app provides three independent, persistent bottom navigation shells matching user personas:

```mermaid
graph TD
    AppRouter["GoRouter (refreshListenable: AsyncAuthNotifier)"]
    
    AppRouter -->|role == 'applicant'| AppShell["ApplicantShellScreen (4 Branches)"]
    AppRouter -->|role == 'admin'| AdminShell["AdminShellScreen (4 Branches)"]
    AppRouter -->|role == 'committee'| CommShell["CommitteeShellScreen (3 Branches)"]

    AppShell --> App1["Branch 0: /home"]
    AppShell --> App2["Branch 1: /my-bookings"]
    AppShell --> App3["Branch 2: /appointment-detail"]
    AppShell --> App4["Branch 3: /profile"]

    AdminShell --> Adm1["Branch 0: /admin-dashboard"]
    AdminShell --> Adm2["Branch 1: /admin-committees"]
    AdminShell --> Adm3["Branch 2: /admin-add-member"]
    AdminShell --> Adm4["Branch 3: /admin-settings"]

    CommShell --> Com1["Branch 0: /committee-dashboard (Reviews)"]
    CommShell --> Com2["Branch 1: /committee-tasks (Fieldwork Tasks)"]
    CommShell --> Com3["Branch 2: /committee-profile (Profile & Logout)"]
```

---

## 5. Reactive Streaming & Stream Provider Auto-Dispose Pattern

To eliminate memory leaks, prevent stale background Firestore listeners, and ensure instant UI updates:
- **`committeeDashboardStreamProvider` (`StreamProvider.autoDispose`)**: Subscribes to `watchCommitteeReviewAppointments(uid)`. Automatically terminates the stream listener when the user navigates away or logs out.
- **`assignedTasksStreamProvider` (`StreamProvider.autoDispose`)**: Subscribes to `watchCommitteeAssignedTasks(uid)` for real-time task queue updates.
- **`committeeReviewDetailStreamProvider` (`StreamProvider.autoDispose.family`)**: Subscribes to `watchAppointmentById(id)` on the review detail screen.
- **`adminAppointmentDetailStreamProvider` (`StreamProvider.family`)**: Streams real-time appointment document updates to the Admin inspector.
- **`applicantAppointmentDetailStreamProvider` (`StreamProvider.autoDispose.family`)**: Streams live appointment updates to the applicant detail screen. Includes defensive empty ID guard (`if (id.isEmpty) return Stream.value(null);`) to prevent Firestore document path assertion exceptions when route parameters are uninitialized.

### 5.1 Riverpod Pull-to-Refresh & Non-Collapsing State Lifecycle Pattern
When building pull-to-refresh flows with Riverpod's `AsyncNotifier` and Flutter's `RefreshIndicator`:
1. **Never Call `state = const AsyncLoading()` in `refresh()`**: Forcing `AsyncLoading` strips existing data from `state`, which drops the view into a loading skeleton/spinner. This creates an uncoordinated "dual spinner" effect (`RefreshIndicator` top circle + centered `CircularProgressIndicator`) and collapses the scroll view height, resetting user scroll position.
2. **Never Call `build()` Directly**: In Riverpod, `build()` registers dependencies via `ref.watch()`. Calling `build()` from an asynchronous helper method invokes `ref.watch` outside Riverpod's synchronous build lifecycle. Instead, extract independent data fetch functions (`_fetchData(...)`) and assign `state = await AsyncValue.guard(() => _fetchData(...))`.
3. **Startup Auth Synchronization**: In notifiers that depend on authentication, always await the auth future (`await ref.watch(authViewModelProvider.future)`) in `build()` rather than reading `.value`. Reading `.value` synchronously returns `null` while auth initializes, causing a flash of empty UI followed by an immediate second rebuild when auth resolves.
4. **Model Value Equality (`AppUser`)**: State classes emitted by auth or repositories must implement `operator ==` and `hashCode`. Without value equality, Riverpod assumes every re-emitted instance is a state mutation, triggering spurious rebuild cascades across all watching screens.

### 5.2 Guaranteed Scrollable Child Architecture for `RefreshIndicator`
Flutter's `RefreshIndicator` requires an active scrollable child that dispatches `ScrollNotification` events. If the child is a non-scrollable widget (such as `Center(child: CircularProgressIndicator())` or an unconstrained `EmptyStateWidget`), scroll metrics are lost, overscroll detection breaks, and the refresh spinner gets trapped in an infinite loop.
- **Data State**: Use `ListView.separated(physics: const AlwaysScrollableScrollPhysics(), ...)`.
- **Empty & Error States**: Wrap in `LayoutBuilder` + `SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: ConstrainedBox(minHeight: constraints.maxHeight, child: EmptyStateWidget(...)))`. This ensures pull-to-refresh works even when lists are completely empty or in an error state.
- **Tab Screen State Retention**: Top-level tab screens (e.g. `AppointmentDetailTabScreen`) must check `state.hasValue` rather than `state.when(loading: ...)`. This preserves the active detail screen when background lists refresh, avoiding destructive unmounts.

---

## 6. Theme & Responsiveness Architecture

- **Theme Engine:** Light and Dark themes defined in `lib/core/theme/app_theme.dart` using `AppColors` and `FlexColorScheme` (v8.4.0, Green M3). `ResponsiveTheme.fromTheme(...)` ensures text styles scale fluidly.
- **Theme Persistence:** `themeProvider` (`ThemeNotifier` using Riverpod) manages `ThemeMode.light`, `ThemeMode.dark`, and `ThemeMode.system` backed by `HiveStorageService` (`settingsBox`).
- **Screen Scaling:** `ScreenUtilPlusInit` initialized in `main.dart` with `designSize: Size(375, 812)`, `minTextAdapt: true`, `splitScreenMode: true`, and `autoRebuild: false` for high-performance targeted scope rebuilds.
- **Graceful Error Handling:** Domain failure hierarchy (`failures.dart`) translates network, auth, and server exceptions into human-readable alerts displayed via `AppSnackbar`. Isolated error and retry views prevent network hiccups from breaking unaffected screen sections.

---

## 7. Cloud Functions Service Gateways Architecture

The application defines two specialized service gateways for invoking Firebase Cloud Functions:
1. **`AdminFunctionsService` (`lib/core/services/admin_functions_service.dart`)**:
   - Used for authenticated administrative operations (e.g. `createCommitteeAccount`).
   - Performs client-side pre-flight admin claim validation (`authState.value?.isAdmin == true`).
   - Forces session token refreshes (`user.getIdToken(true)`) to avoid stale unauthenticated errors.
   - Translates `FirebaseFunctionsException` into `ValidationFailure`, `AuthFailure`, or `ServerFailure`.
2. **`AuthFunctionsService` (`lib/core/services/auth_functions_service.dart`)**:
   - Used for unauthenticated auth operations (`authenticateUser`, `registerApplicant`, `requestPasswordReset`).
   - Requires zero pre-flight auth checks (the caller is unauthenticated by definition).
   - Serves as the client bridge for server-mediated rate limiting.
   - Extracts server-provided `secondsRemaining` from `FirebaseFunctionsException` (`code: 'resource-exhausted'`) and maps to `AuthRateLimitFailure(message, secondsRemaining)`.

---

## 8. Push Notification System & In-App Banners Architecture

The application implements an end-to-end Firebase Cloud Messaging (FCM) push notification system with in-app banner overlays, deep linking, and server-side recipient resolution:

```mermaid
graph TD
    subgraph Backend ["Cloud Functions (Node.js 20 2nd Gen)"]
        Mutations["Appointment Mutations (submit, review, assign, reply)"]
        Notifier["sendAppointmentNotification (send_push_notification.ts)"]
        Resolver["getRecipientUids (notification_recipients.ts)"]
        Payload["buildNotificationPayload (notification_payload.ts)"]
        FCM_Admin["admin.messaging().sendEachForMulticast()"]
        Prune["pruneInvalidToken()"]
    end

    subgraph FCM ["Firebase Cloud Messaging Gateway"]
        FCM_GW["FCM HTTP v1 Protocol"]
    end

    subgraph Client ["Flutter Mobile Client"]
        Init["FirebaseNotificationService (initialize & token registration)"]
        Handler["NotificationHandler (Terminated & Background tap listener)"]
        Overlay["NotificationOverlayWrapper + NotificationOverlay (Foreground banner)"]
        Nav["NotificationNavigation (Role-aware deep linker)"]
        AuthGate["Auth & Role Resolution Guard (authViewModelProvider)"]
    end

    Mutations --> Notifier
    Notifier --> Resolver
    Notifier --> Payload
    Notifier --> FCM_Admin
    FCM_Admin -->|Invalid Token Code| Prune
    FCM_Admin --> FCM_GW
    FCM_GW -->|Push Delivered| Client
    Client --> Overlay
    Client --> Handler
    Handler --> AuthGate
    Overlay -->|User Tap| AuthGate
    AuthGate --> Nav
```

### Architectural Rules & Separation of Concerns:
1. **Direct SDK Isolation:** `FirebaseNotificationService` (`lib/core/services/firebase_notification_service.dart`) is the **ONLY** class in the Flutter client permitted to call `FirebaseMessaging.instance`. ViewModels, handlers, and routers consume the abstract `NotificationService` interface.
2. **Top-Level Background Handler:** `_firebaseMessagingBackgroundHandler` is a top-level `@pragma('vm:entry-point')` function executing in a background isolate for pure data payloads.
3. **Tri-State Lifecycle Support:**
   - **Foreground:** `FirebaseMessaging.onMessage` emits to `foregroundMessages`. `NotificationOverlayWrapper` sits above shell navigation and presents an animated top banner with green accent, type-specific icons, auto-dismiss (4s timer), swipe-to-dismiss, and tap-to-navigate.
   - **Background:** `FirebaseMessaging.onMessageOpenedApp` emits to `notificationOpened`, processed by `NotificationHandler`.
   - **Terminated:** `getInitialNotification()` retrieves the launch message in `NotificationHandler.initState()`.
4. **Auth-Gate Deep Linking:** In `NotificationNavigation.navigate(context, ref, message)` and `NotificationHandler`, navigation never triggers before authentication and role resolution are complete. If auth is pending, navigation is safely deferred until `authViewModelProvider.value` resolves. Routes map strictly by role:
   - `booking_created` $\rightarrow$ `/admin-dashboard`
   - `reviewer_assigned`, `clarification_requested`, `booking_approved`, `booking_rejected` $\rightarrow$ `/appointment-detail/:id` (Applicant)
   - `clarification_replied` $\rightarrow$ `/committee-review/:id` (Reviewer)
   - `task_assigned` $\rightarrow$ `/committee-task/:id` (Fieldwork Member)
5. **Token Lifecycle & Security:**
   - Tokens registered upon login via `FieldValue.arrayUnion([token])` in `users/{uid}.fcmTokens` and removed on logout / account switch via `FieldValue.arrayRemove([token])`.
   - Token rotation handled via `FirebaseMessaging.instance.onTokenRefresh`.
   - `firestore.rules` enforces type and size limits: `request.resource.data.fcmTokens is list && request.resource.data.fcmTokens.size() <= 10` to eliminate DoS / resource exhaustion vectors.

