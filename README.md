# DataVerse — Department Communication Database Management System (`dcdms_db`)

**Institution:** Department of Computing, Rajarata University of Sri Lanka  
**Course:** ICT1407 — Database Systems (Final Semester Project)  
**Target DBMS:** MySQL Server 8.0 / 8.4 (Zero-Warning MySQL Workbench Ready)

---

## What Was Updated in This Release (`NORMALIZATION - NEW.pdf` + DataVerse GUI Support)

1. **100% Alignment with `NORMALIZATION - NEW.pdf` & `DEPARTMENT_MEETING_CALENDAR.XLSX`:**
   - All **5 ISA Role Relations** (`HOD`, `AcademicStaff`, `Clerk`, `SupportStaff`, `StudentCoordinator`) inherit `(UserID, Name, Email, Password)` while syncing cleanly with the master `User` identity registry so `Attends(UserID)` and `MeetingConfirmation(UserID)` maintain genuine physical `InnoDB` `FOREIGN KEY` constraints.
   - `YearPlan` updated to `(PlanID, AcademicYear, PlanLink)` (`P001`–`P012`, years `2016`–`2027`).
   - `Media_Links` updated with composite primary key `(MeetingRecID, MediaLinks)` supporting `.pdf`, `.docx`, `.mp3`, `.mp4`, and Google Drive cloud links.
   - All **14 official Rajarata Dept. of Computing meeting types (`T001`–`T014`)** configured with exact short codes (`DM, CD, IT, AP, GB, MM, IV, SW, CG, PE23, PE22, SC, CP, SB`), `Semester01`/`Semester02` flags, `ScheduledMonths`, `CategoryGroup`, and `CalendarColorHex` badge colors.
2. **Strictly `> 10` Records in Every Single Table:**
   - Every one of the **15 tables** contains between **12 and 159 records** (`HOD`: 12, `AcademicStaff`: 16, `Clerk`: 12, `SupportStaff`: 12, `StudentCoordinator`: 12, `User`: 64, `MeetingType`: 14, `YearPlan`: 12, `Agenda`: 18, `Meeting`: 24, `MeetingConfirmation`: 24, `MediaRecord`: 18, `Media_Links`: 24, `Notification`: 20, `Attends`: 159).
3. **Full DataVerse Web GUI Database Support (3NF Preserved):**
   - **Login Authentication:** `sp_gui_authenticate_user` verifies `UserID` or `Email` + password hash and returns `RoleType` for Function Box Dashboard routing.
   - **Monthly Scheduler & Venue Conflict Trigger:** `StartTime`, `EndTime`, `Venue`, `Meeting_Status`, and `RescheduleReason` on `Meeting` + automatic trigger preventing physical room double-booking while permitting non-conflicting same-day meetings.
   - **Pre-Meeting 3-Day Agenda Lock & Cloud Links:** `Agenda.AgendaFileLink` + `AgendaUploadStatus` indicator + `sp_generate_three_day_alerts`.
   - **Exact 2/3 (`66.67%`) Quorum & HOD Intervention:** `fn_is_quorum_reached`, `vw_meeting_quorum_status`, and `sp_cancel_and_reschedule_no_quorum`.
   - **Action-Item & Task Deadline Tracker:** `ResponsibleUserID`, `TaskDeadline`, and `TaskStatus` on atomized `MediaRecord` decisions + `vw_gui_action_items_tracker` & `sp_search_decisions`.

---

## Package File Structure (18 Files)

```text
DCDMS_MySQL_Final_Project/
├── README.md
├── 00_install_complete_dcdms.sql       # One-click installer + 9-test verification suite
├── 01_create_database.sql              # Database creation (utf8mb4_unicode_ci)
├── 02_create_tables.sql                # All 15 normalized (3NF) tables, PK/FK/CHECK/Indexes
├── 03_insert_sample_data.sql           # > 10 records in EVERY table (12 to 159 rows/table)
├── 04_views.sql                        # 16 GUI, Calendar, KPI, Quorum & RBAC views
├── 05_procedures_and_functions.sql     # 2 Functions + 9 GUI/Workflow Stored Procedures
├── 06_triggers.sql                     # 14 Triggers (ISA, 3-day Agenda, Venue Conflict, Quorum, RBAC)
├── 07_reports_and_queries.sql          # 10 Analytical & GUI demonstration queries
├── 08_verification_tests.sql           # Automated 9-case positive/negative test suite
├── 09_security_roles_and_views.sql     # Lecture 08 RBAC roles, WITH CHECK OPTION & accounts
└── documentation/
    ├── schema_dictionary.md            # Complete 15-table column & row-count dictionary
    ├── relationships_and_keys.md       # FK matrix + NORMALIZATION - NEW.pdf discrepancy notes
    ├── constraints_and_business_rules.md # Declarative CHECKs & procedural trigger catalog
    ├── gui_database_integration_guide.md # Screen-by-screen DataVerse Web GUI -> DB mapping
    ├── security_management_report.md   # Concise report section on Database Security & Conclusion
    └── execution_guide.md              # Step-by-step MySQL Workbench & Reverse Engineer guide
```
