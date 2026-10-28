-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Lecture 08: Database Security)
-- Script       : 09_security_roles_and_views.sql
-- Purpose      : Physical implementation of ICT1407 Lecture 08 security
--                controls on dcdms_db aligned with NORMALIZATION - NEW.pdf
--                and the DataVerse Web Application GUI:
--                  1. Column-filtering security view (vw_user_directory)
--                     hiding Password hashes (Lecture 08 Slide 36)
--                  2. Updatable row-filtering view WITH CHECK OPTION
--                     (vw_clerk_schedulable_meetings) preventing Clerks from
--                     inserting or updating confidential Scrutiny Board TypeID
--                     'T014' (Lecture 08 Slides 39, 41, 42)
--                  3. Role-Based Access Control (RBAC) roles & least-privilege
--                     GRANT statements for all 5 department roles + Web GUI &
--                     Read-Only Reporting accounts (Lecture 08 Slides 8-25)
-- Target DBMS  : MySQL Server 8.0 / 8.4 (run as root/DBA in MySQL Workbench)
-- ============================================================================

USE dcdms_db;

-- ============================================================================
-- 1. COLUMN-RESTRICTED SECURITY VIEW: vw_user_directory
-- ============================================================================
CREATE OR REPLACE VIEW vw_user_directory AS
SELECT
    UserID,
    Name,
    Email,
    RoleType AS UserRole
FROM `User`;

-- ============================================================================
-- 2. UPDATABLE FILTERED SECURITY VIEW WITH CHECK OPTION:
--    vw_clerk_schedulable_meetings (Blocks Clerk access to Scrutiny Board T014)
-- ============================================================================
CREATE OR REPLACE VIEW vw_clerk_schedulable_meetings AS
SELECT
    m.MeetingId,
    m.IsFixed,
    m.PlannedDate,
    m.ActualDate,
    m.StartTime,
    m.EndTime,
    m.Venue,
    m.Meeting_Status,
    m.RescheduleReason,
    m.TypeID,
    m.PlanID,
    m.UserID,
    m.Agenda_id
FROM Meeting m
WHERE m.TypeID <> 'T014'
WITH CHECK OPTION;

-- ============================================================================
-- 3. CLEANUP ANY PREVIOUS SECURITY ROLES & DEMO ACCOUNTS (Zero-Warning Idempotency)
-- ============================================================================
SET SESSION sql_notes = 0;
DROP USER IF EXISTS 'dcdms_hod_tharindu'@'localhost';
DROP USER IF EXISTS 'dcdms_lect_isuru'@'localhost';
DROP USER IF EXISTS 'dcdms_clerk_hasini'@'localhost';
DROP USER IF EXISTS 'dcdms_support_chamodi'@'localhost';
DROP USER IF EXISTS 'dcdms_stucoord_oshini'@'localhost';
DROP USER IF EXISTS 'dcdms_webapp_svc'@'localhost';
DROP USER IF EXISTS 'dcdms_report_svc'@'localhost';

DROP ROLE IF EXISTS 'role_dcdms_hod';
DROP ROLE IF EXISTS 'role_dcdms_academic';
DROP ROLE IF EXISTS 'role_dcdms_clerk';
DROP ROLE IF EXISTS 'role_dcdms_support';
DROP ROLE IF EXISTS 'role_dcdms_student_coord';
DROP ROLE IF EXISTS 'role_dcdms_webapp';
DROP ROLE IF EXISTS 'role_dcdms_report_reader';
SET SESSION sql_notes = 1;

-- ============================================================================
-- 4. CREATE RBAC ROLES (Lecture 08 Slides 22-24: Role-Based Access Control)
-- ============================================================================
CREATE ROLE
    'role_dcdms_hod',
    'role_dcdms_academic',
    'role_dcdms_clerk',
    'role_dcdms_support',
    'role_dcdms_student_coord',
    'role_dcdms_webapp',
    'role_dcdms_report_reader';

-- ============================================================================
-- 5. GRANT LEAST-PRIVILEGE PERMISSIONS TO EACH ROLE (Lecture 08 Slides 8, 25)
-- ============================================================================

-- 5A. HOD Role: Full operational access across all 14 meeting types, decisions,
--     quorum management, GUI analytics views, and stored procedures (no DDL/DROP).
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.Meeting             TO 'role_dcdms_hod';
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.MeetingType         TO 'role_dcdms_hod';
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.YearPlan            TO 'role_dcdms_hod';
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.Agenda              TO 'role_dcdms_hod';
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.Attends             TO 'role_dcdms_hod';
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.MeetingConfirmation TO 'role_dcdms_hod';
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.MediaRecord         TO 'role_dcdms_hod';
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.Media_Links         TO 'role_dcdms_hod';
GRANT SELECT, INSERT, UPDATE, DELETE ON dcdms_db.Notification        TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_user_directory                           TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_gui_dashboard_kpis                       TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_gui_meeting_category_chart               TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_gui_calendar_events                      TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_hod_all_meetings                         TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_meeting_quorum_status                    TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_searchable_decisions_archive             TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_gui_action_items_tracker                 TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_staff_attendance_regularity              TO 'role_dcdms_hod';
GRANT SELECT ON dcdms_db.vw_planned_vs_actual_meetings               TO 'role_dcdms_hod';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_register_department_user       TO 'role_dcdms_hod';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_schedule_monthly_meeting       TO 'role_dcdms_hod';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_auto_assign_meeting_participants TO 'role_dcdms_hod';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_upload_agenda_for_meeting      TO 'role_dcdms_hod';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_generate_three_day_alerts      TO 'role_dcdms_hod';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_cancel_and_reschedule_no_quorum TO 'role_dcdms_hod';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_record_decision_with_media     TO 'role_dcdms_hod';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_search_decisions               TO 'role_dcdms_hod';
GRANT EXECUTE ON FUNCTION  dcdms_db.fn_attendance_percentage          TO 'role_dcdms_hod';
GRANT EXECUTE ON FUNCTION  dcdms_db.fn_is_quorum_reached              TO 'role_dcdms_hod';

-- 5B. Academic Staff Role: Read academic & confidential Scrutiny Board schedules
--     and decisions; update RSVP confirmations; upload agendas.
GRANT SELECT ON dcdms_db.vw_user_directory                 TO 'role_dcdms_academic';
GRANT SELECT ON dcdms_db.vw_academic_staff_meetings        TO 'role_dcdms_academic';
GRANT SELECT ON dcdms_db.vw_user_assigned_schedule         TO 'role_dcdms_academic';
GRANT SELECT ON dcdms_db.vw_meeting_quorum_status          TO 'role_dcdms_academic';
GRANT SELECT ON dcdms_db.vw_searchable_decisions_archive   TO 'role_dcdms_academic';
GRANT SELECT ON dcdms_db.vw_gui_action_items_tracker       TO 'role_dcdms_academic';
GRANT SELECT, INSERT, UPDATE ON dcdms_db.MeetingConfirmation TO 'role_dcdms_academic';
GRANT SELECT, INSERT ON dcdms_db.Agenda                    TO 'role_dcdms_academic';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_search_decisions    TO 'role_dcdms_academic';

-- 5C. Clerk (System Convener) Role: Enters schedules, agendas, attendance, and
--     notifications ONLY through non-private views/tables; NO direct SELECT on
--     Meeting or MediaRecord so Scrutiny Board ('T014') stays completely hidden!
GRANT SELECT ON dcdms_db.vw_user_directory                              TO 'role_dcdms_clerk';
GRANT SELECT ON dcdms_db.vw_clerk_meetings                              TO 'role_dcdms_clerk';
GRANT SELECT, INSERT, UPDATE ON dcdms_db.vw_clerk_schedulable_meetings  TO 'role_dcdms_clerk';
GRANT SELECT ON dcdms_db.YearPlan                                       TO 'role_dcdms_clerk';
GRANT SELECT ON dcdms_db.MeetingType                                    TO 'role_dcdms_clerk';
GRANT SELECT, INSERT, UPDATE ON dcdms_db.Agenda                         TO 'role_dcdms_clerk';
GRANT SELECT, INSERT, UPDATE ON dcdms_db.Attends                        TO 'role_dcdms_clerk';
GRANT SELECT, INSERT ON dcdms_db.Notification                           TO 'role_dcdms_clerk';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_upload_agenda_for_meeting        TO 'role_dcdms_clerk';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_generate_three_day_alerts        TO 'role_dcdms_clerk';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_search_decisions                 TO 'role_dcdms_clerk';

-- 5D. Support / Technical Staff Role: Limited strictly to DM & SW views + RSVP.
GRANT SELECT ON dcdms_db.vw_user_directory                   TO 'role_dcdms_support';
GRANT SELECT ON dcdms_db.vw_support_staff_meetings           TO 'role_dcdms_support';
GRANT SELECT ON dcdms_db.vw_user_assigned_schedule           TO 'role_dcdms_support';
GRANT SELECT, INSERT, UPDATE ON dcdms_db.MeetingConfirmation TO 'role_dcdms_support';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_search_decisions      TO 'role_dcdms_support';

-- 5E. Student Coordinator Role: Strictly restricted to 'SC' & 'CP' views + RSVP.
GRANT SELECT ON dcdms_db.vw_student_coordinator_meetings     TO 'role_dcdms_student_coord';
GRANT SELECT ON dcdms_db.vw_user_assigned_schedule           TO 'role_dcdms_student_coord';
GRANT SELECT, INSERT, UPDATE ON dcdms_db.MeetingConfirmation TO 'role_dcdms_student_coord';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_search_decisions      TO 'role_dcdms_student_coord';

-- 5F. DataVerse Web Application Service Role (Least-Privilege Backend Pool):
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_gui_authenticate_user TO 'role_dcdms_webapp';
GRANT SELECT ON dcdms_db.vw_gui_dashboard_kpis               TO 'role_dcdms_webapp';
GRANT SELECT ON dcdms_db.vw_gui_meeting_category_chart       TO 'role_dcdms_webapp';
GRANT SELECT ON dcdms_db.vw_gui_calendar_events              TO 'role_dcdms_webapp';
GRANT SELECT ON dcdms_db.vw_user_assigned_schedule           TO 'role_dcdms_webapp';
GRANT EXECUTE ON PROCEDURE dcdms_db.sp_search_decisions      TO 'role_dcdms_webapp';

-- 5G. Read-Only Reporting Role (Lecture 08 Slides 8-9):
GRANT SELECT ON dcdms_db.vw_meeting_quorum_status            TO 'role_dcdms_report_reader';
GRANT SELECT ON dcdms_db.vw_staff_attendance_regularity      TO 'role_dcdms_report_reader';
GRANT SELECT ON dcdms_db.vw_planned_vs_actual_meetings       TO 'role_dcdms_report_reader';

-- ============================================================================
-- 6. CREATE INDIVIDUAL & WEB SERVICE ACCOUNTS RESTRICTED TO LOCALHOST
-- ============================================================================
CREATE USER 'dcdms_hod_tharindu'@'localhost'    IDENTIFIED BY 'Hod#Tharindu26!Sec';
CREATE USER 'dcdms_lect_isuru'@'localhost'      IDENTIFIED BY 'Lect#Isuru2026!Sec';
CREATE USER 'dcdms_clerk_hasini'@'localhost'    IDENTIFIED BY 'Clerk#Hasini26!Sec';
CREATE USER 'dcdms_support_chamodi'@'localhost' IDENTIFIED BY 'Supp#Chamodi26!Sec';
CREATE USER 'dcdms_stucoord_oshini'@'localhost' IDENTIFIED BY 'StuC#Oshini26!Sec';
CREATE USER 'dcdms_webapp_svc'@'localhost'      IDENTIFIED BY 'WebApp#DataV26!Sec';
CREATE USER 'dcdms_report_svc'@'localhost'      IDENTIFIED BY 'Rept#ReadOnly26!Sec';

GRANT 'role_dcdms_hod'           TO 'dcdms_hod_tharindu'@'localhost';
GRANT 'role_dcdms_academic'      TO 'dcdms_lect_isuru'@'localhost';
GRANT 'role_dcdms_clerk'         TO 'dcdms_clerk_hasini'@'localhost';
GRANT 'role_dcdms_support'       TO 'dcdms_support_chamodi'@'localhost';
GRANT 'role_dcdms_student_coord' TO 'dcdms_stucoord_oshini'@'localhost';
GRANT 'role_dcdms_webapp'        TO 'dcdms_webapp_svc'@'localhost';
GRANT 'role_dcdms_report_reader' TO 'dcdms_report_svc'@'localhost';

SET DEFAULT ROLE ALL TO
    'dcdms_hod_tharindu'@'localhost',
    'dcdms_lect_isuru'@'localhost',
    'dcdms_clerk_hasini'@'localhost',
    'dcdms_support_chamodi'@'localhost',
    'dcdms_stucoord_oshini'@'localhost',
    'dcdms_webapp_svc'@'localhost',
    'dcdms_report_svc'@'localhost';
