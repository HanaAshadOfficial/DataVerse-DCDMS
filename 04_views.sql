-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Script       : 04_views.sql
-- Purpose      : Role-Based Access Control (RBAC) views, derived Quorum view,
--                DataVerse Web GUI Calendar & Dashboard Analytics views,
--                Decision Search Archive, Action-Item Tracker, and Regularity
--                Analytics views.
-- Target DBMS  : MySQL Server 8.0 / 8.4 (Zero-Warning MySQL Workbench Ready)
-- ============================================================================

USE dcdms_db;

SET SESSION sql_notes = 0;
DROP VIEW IF EXISTS vw_planned_vs_actual_meetings;
DROP VIEW IF EXISTS vw_staff_attendance_regularity;
DROP VIEW IF EXISTS vw_gui_action_items_tracker;
DROP VIEW IF EXISTS vw_searchable_decisions_archive;
DROP VIEW IF EXISTS vw_user_assigned_schedule;
DROP VIEW IF EXISTS vw_student_coordinator_meetings;
DROP VIEW IF EXISTS vw_support_staff_meetings;
DROP VIEW IF EXISTS vw_clerk_schedulable_meetings;
DROP VIEW IF EXISTS vw_clerk_meetings;
DROP VIEW IF EXISTS vw_academic_staff_meetings;
DROP VIEW IF EXISTS vw_hod_all_meetings;
DROP VIEW IF EXISTS vw_meeting_quorum_status;
DROP VIEW IF EXISTS vw_gui_calendar_events;
DROP VIEW IF EXISTS vw_gui_meeting_category_chart;
DROP VIEW IF EXISTS vw_gui_dashboard_kpis;
DROP VIEW IF EXISTS vw_user_directory;
SET SESSION sql_notes = 1;

-- ============================================================================
-- 1. UNIFIED USER DIRECTORY VIEW (Exposes safe profile & role; hides Password)
-- ============================================================================
CREATE VIEW vw_user_directory AS
SELECT
    u.UserID,
    u.Name,
    u.Email,
    u.RoleType AS UserRole
FROM `User` u;

-- ============================================================================
-- 2. GUI POST-LOGIN DASHBOARD KPI CARDS VIEW
-- ============================================================================
CREATE VIEW vw_gui_dashboard_kpis AS
SELECT
    (SELECT COUNT(*) FROM `User`)                                                                 AS TotalUsers,
    (SELECT COUNT(*) FROM MeetingType)                                                            AS TotalMeetingTypes,
    (SELECT COUNT(*) FROM Meeting WHERE Meeting_Status IN ('Planned', 'Scheduled'))               AS UpcomingMeetingsCount,
    (SELECT COUNT(*) FROM Meeting WHERE Meeting_Status = 'Completed')                             AS CompletedMeetingsCount,
    (SELECT COUNT(*) FROM Meeting WHERE Meeting_Status IN ('Cancelled', 'Postponed'))             AS CancelledOrPostponedCount,
    (SELECT COUNT(*) FROM MediaRecord WHERE TaskStatus IN ('Pending', 'In Progress'))             AS OpenActionItemsCount,
    (SELECT COUNT(*) FROM Meeting
      WHERE Meeting_Status IN ('Planned', 'Scheduled')
        AND Agenda_id IS NULL
        AND PlannedDate BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 14 DAY))               AS MissingAgendaUpcomingCount;

-- ============================================================================
-- 3. GUI DASHBOARD CATEGORY DISTRIBUTION CHART VIEW
--    Powers Pie/Donut/Bar charts across Academic, Administrative,
--    External/Industry, and Student-Centric meeting categories.
-- ============================================================================
CREATE VIEW vw_gui_meeting_category_chart AS
SELECT
    mt.CategoryGroup,
    COUNT(DISTINCT mt.TypeID)                                                       AS MeetingTypesInCategory,
    COUNT(m.MeetingId)                                                              AS TotalMeetingsLogged,
    SUM(CASE WHEN m.Meeting_Status = 'Completed' THEN 1 ELSE 0 END)                 AS CompletedCount,
    SUM(CASE WHEN m.Meeting_Status IN ('Planned', 'Scheduled') THEN 1 ELSE 0 END)   AS UpcomingCount,
    SUM(CASE WHEN m.Meeting_Status IN ('Cancelled', 'Postponed') THEN 1 ELSE 0 END) AS DisruptedCount
FROM MeetingType mt
LEFT JOIN Meeting m ON mt.TypeID = m.TypeID
GROUP BY mt.CategoryGroup;

-- ============================================================================
-- 4. DERIVED QUORUM & RSVP ANALYTICS VIEW (Exact 2/3 = 66.67% Quorum Logic)
-- ============================================================================
CREATE VIEW vw_meeting_quorum_status AS
SELECT
    m.MeetingId,
    mt.ShortName,
    mt.Name                                                            AS MeetingTypeName,
    mt.CategoryGroup,
    mt.CalendarColorHex,
    mt.IsPrivate,
    m.IsFixed,
    m.PlannedDate,
    m.ActualDate,
    m.StartTime,
    m.EndTime,
    m.Venue,
    m.Meeting_Status,
    m.RescheduleReason,
    COUNT(a.UserID)                                                    AS TotalParticipants,
    SUM(CASE WHEN a.Att_Status = 'Present' THEN 1 ELSE 0 END)          AS PresentCount,
    SUM(CASE WHEN a.Att_Status = 'Absent'  THEN 1 ELSE 0 END)          AS AbsentCount,
    SUM(CASE WHEN a.Att_Status = 'Excused' THEN 1 ELSE 0 END)          AS ExcusedCount,
    SUM(CASE WHEN a.Att_Status = 'Invited' THEN 1 ELSE 0 END)          AS PendingCheckInCount,
    COALESCE(
        ROUND(
            (SUM(CASE WHEN a.Att_Status = 'Present' THEN 1 ELSE 0 END) * 100.0)
            / NULLIF(COUNT(a.UserID), 0),
            2
        ),
        0.00
    )                                                                  AS PresentPercentage,
    CASE
        WHEN COUNT(a.UserID) > 0
             AND (SUM(CASE WHEN a.Att_Status = 'Present' THEN 1 ELSE 0 END) * 3) >= (COUNT(a.UserID) * 2)
        THEN 'Yes'
        ELSE 'No'
    END                                                                AS QuorumReached,
    (SELECT COUNT(*) FROM MeetingConfirmation mc
      WHERE mc.MeetingId = m.MeetingId AND mc.Confirmation_Status = 'Confirmed') AS ConfirmedRsvpCount,
    CASE
        WHEN m.Meeting_Status = 'Cancelled' THEN 'Cancelled & Logged'
        WHEN m.Meeting_Status = 'Postponed' THEN 'Postponed - Pending New Date'
        WHEN COUNT(a.UserID) = 0 THEN 'Pending Participant Roster'
        WHEN (SUM(CASE WHEN a.Att_Status = 'Present' THEN 1 ELSE 0 END) * 3) >= (COUNT(a.UserID) * 2)
            THEN 'Quorum Met (>= 66.67%) - Valid to Proceed'
        WHEN m.Meeting_Status IN ('Planned', 'Scheduled')
            THEN 'Awaiting Check-In / Pre-Meeting RSVP'
        ELSE 'ALERT: Below 2/3 Quorum - HOD Must Cancel or Reschedule'
    END                                                                AS HOD_Action_Recommendation
FROM Meeting m
INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
LEFT JOIN Attends a       ON m.MeetingId = a.MeetingId
GROUP BY
    m.MeetingId, mt.ShortName, mt.Name, mt.CategoryGroup, mt.CalendarColorHex,
    mt.IsPrivate, m.IsFixed, m.PlannedDate, m.ActualDate, m.StartTime,
    m.EndTime, m.Venue, m.Meeting_Status, m.RescheduleReason;

-- ============================================================================
-- 5. GUI COLOR-CODED ANNUAL & MONTHLY CALENDAR EVENTS VIEW
--    Includes 3-Day Agenda Upload Window Status for the Pre-Meeting Workflow.
-- ============================================================================
CREATE VIEW vw_gui_calendar_events AS
SELECT
    m.MeetingId,
    mt.TypeID,
    mt.ShortName,
    mt.Name                                               AS MeetingTypeName,
    mt.CategoryGroup,
    mt.CalendarColorHex,
    mt.Semester01,
    mt.Semester02,
    mt.ScheduledMonths,
    mt.IsPrivate,
    m.IsFixed,
    yp.PlanID,
    yp.AcademicYear,
    yp.PlanLink,
    m.PlannedDate,
    MONTHNAME(m.PlannedDate)                              AS PlannedMonthName,
    MONTH(m.PlannedDate)                                  AS PlannedMonthNumber,
    m.ActualDate,
    m.StartTime,
    m.EndTime,
    m.Venue,
    m.Meeting_Status,
    m.RescheduleReason,
    u.Name                                                AS ScheduledByHOD,
    ag.Agenda_id,
    ag.Name                                               AS AgendaTitle,
    ag.Upload_Date                                        AS AgendaUploadDate,
    ag.AgendaFileLink,
    DATE_SUB(m.PlannedDate, INTERVAL 3 DAY)               AS AgendaDeadlineDate,
    CASE
        WHEN ag.Agenda_id IS NOT NULL THEN 'Agenda Uploaded'
        WHEN m.Meeting_Status IN ('Cancelled', 'Completed') THEN 'Closed'
        WHEN CURDATE() > DATE_SUB(m.PlannedDate, INTERVAL 3 DAY) THEN 'LOCKED (< 3 Days to Meeting)'
        ELSE 'Open for Agenda Upload'
    END                                                   AS AgendaUploadStatus,
    q.TotalParticipants,
    q.PresentCount,
    q.PresentPercentage,
    q.QuorumReached
FROM Meeting m
INNER JOIN MeetingType mt             ON m.TypeID = mt.TypeID
LEFT JOIN YearPlan yp                 ON m.PlanID = yp.PlanID
INNER JOIN `User` u                   ON m.UserID = u.UserID
LEFT JOIN Agenda ag                   ON m.Agenda_id = ag.Agenda_id
INNER JOIN vw_meeting_quorum_status q ON m.MeetingId = q.MeetingId;

-- ============================================================================
-- 6. ROLE-BASED ACCESS CONTROL (RBAC) VIEWS FOR ALL 5 DEPARTMENT ROLES
-- ============================================================================

-- 6A. HOD View: Full administrative & confidential visibility
CREATE VIEW vw_hod_all_meetings AS
SELECT * FROM vw_gui_calendar_events;

-- 6B. AcademicStaff View: Full academic & Scrutiny Board visibility
CREATE VIEW vw_academic_staff_meetings AS
SELECT * FROM vw_gui_calendar_events;

-- 6C. Clerk (System Convener) View: Strictly excludes private Scrutiny Board ('SB')
CREATE VIEW vw_clerk_meetings AS
SELECT
    MeetingId, TypeID, ShortName, MeetingTypeName, CategoryGroup, CalendarColorHex,
    AcademicYear, IsFixed, PlannedDate, ActualDate, StartTime, EndTime, Venue,
    Meeting_Status, RescheduleReason, Agenda_id, AgendaTitle, AgendaUploadDate,
    AgendaFileLink, AgendaDeadlineDate, AgendaUploadStatus,
    TotalParticipants, PresentCount, PresentPercentage, QuorumReached
FROM vw_gui_calendar_events
WHERE IsPrivate = 'No';

-- 6D. Clerk Updatable View (WITH CHECK OPTION prevents touching private Scrutiny Board 'T014')
CREATE VIEW vw_clerk_schedulable_meetings AS
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

-- 6E. SupportStaff View: Limited strictly to Department Meetings ('DM') & Staff Workshops ('SW')
CREATE VIEW vw_support_staff_meetings AS
SELECT
    MeetingId, ShortName, MeetingTypeName, CategoryGroup, CalendarColorHex,
    AcademicYear, PlannedDate, ActualDate, StartTime, EndTime, Venue,
    Meeting_Status, AgendaTitle, AgendaFileLink
FROM vw_gui_calendar_events
WHERE IsPrivate = 'No'
  AND ShortName IN ('DM', 'SW');

-- 6F. StudentCoordinator View: Restricted strictly to 'SC' & 'CP' meetings
CREATE VIEW vw_student_coordinator_meetings AS
SELECT
    MeetingId, ShortName, MeetingTypeName, CategoryGroup, CalendarColorHex,
    AcademicYear, PlannedDate, ActualDate, StartTime, EndTime, Venue,
    Meeting_Status, AgendaTitle, AgendaFileLink
FROM vw_gui_calendar_events
WHERE IsPrivate = 'No'
  AND ShortName IN ('SC', 'CP');

-- 6G. Strict Personal Calendar Isolation View: Only meetings assigned to UserID
CREATE VIEW vw_user_assigned_schedule AS
SELECT
    a.UserID,
    u.Name                                  AS ParticipantName,
    u.RoleType                              AS UserRole,
    m.MeetingId,
    mt.ShortName,
    mt.Name                                 AS MeetingTypeName,
    mt.CategoryGroup,
    mt.CalendarColorHex,
    mt.IsPrivate,
    m.PlannedDate,
    m.ActualDate,
    m.StartTime,
    m.EndTime,
    m.Venue,
    m.Meeting_Status,
    ag.Name                                 AS AgendaTitle,
    ag.AgendaFileLink,
    COALESCE(mc.Confirmation_Status, 'Not Responded') AS RSVP_Status,
    mc.ResponseDate,
    a.Att_Status                            AS AttendanceStatus
FROM Attends a
INNER JOIN `User` u               ON a.UserID = u.UserID
INNER JOIN Meeting m              ON a.MeetingId = m.MeetingId
INNER JOIN MeetingType mt         ON m.TypeID = mt.TypeID
LEFT JOIN Agenda ag               ON m.Agenda_id = ag.Agenda_id
LEFT JOIN MeetingConfirmation mc  ON mc.UserID = a.UserID AND mc.MeetingId = a.MeetingId;

-- ============================================================================
-- 7. POST-MEETING DECISION ARCHIVE & ACTION-ITEM TRACKER VIEWS
-- ============================================================================
CREATE VIEW vw_searchable_decisions_archive AS
SELECT
    mr.MeetingRecID,
    m.MeetingId,
    yp.AcademicYear,
    mt.ShortName,
    mt.Name                                                        AS MeetingTypeName,
    mt.CategoryGroup,
    mt.CalendarColorHex,
    mt.IsPrivate,
    COALESCE(m.ActualDate, m.PlannedDate)                          AS MeetingDate,
    m.Venue,
    mr.RecordType,
    mr.DecisionText,
    mr.UploadDate,
    mr.ResponsibleUserID,
    ru.Name                                                        AS ResponsibleOfficerName,
    mr.TaskDeadline,
    mr.TaskStatus,
    GROUP_CONCAT(ml.MediaLinks ORDER BY ml.MediaLinks SEPARATOR ' | ') AS AttachedMediaLinks
FROM MediaRecord mr
INNER JOIN Meeting m      ON mr.MeetingId = m.MeetingId
INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
LEFT JOIN YearPlan yp     ON m.PlanID = yp.PlanID
LEFT JOIN `User` ru       ON mr.ResponsibleUserID = ru.UserID
LEFT JOIN Media_Links ml  ON mr.MeetingRecID = ml.MeetingRecID
GROUP BY
    mr.MeetingRecID, m.MeetingId, yp.AcademicYear, mt.ShortName, mt.Name,
    mt.CategoryGroup, mt.CalendarColorHex, mt.IsPrivate, m.ActualDate,
    m.PlannedDate, m.Venue, mr.RecordType, mr.DecisionText, mr.UploadDate,
    mr.ResponsibleUserID, ru.Name, mr.TaskDeadline, mr.TaskStatus;

CREATE VIEW vw_gui_action_items_tracker AS
SELECT
    mr.MeetingRecID,
    m.MeetingId,
    mt.ShortName,
    mt.Name                               AS MeetingTypeName,
    mt.IsPrivate,
    mr.DecisionText,
    mr.ResponsibleUserID,
    u.Name                                AS ResponsibleOfficer,
    u.Email                               AS OfficerEmail,
    mr.TaskDeadline,
    mr.TaskStatus,
    CASE
        WHEN mr.TaskStatus = 'Completed' THEN 'Completed'
        WHEN mr.TaskStatus = 'Not Applicable' THEN 'No Action Required'
        WHEN mr.TaskDeadline < CURDATE() THEN 'OVERDUE'
        WHEN mr.TaskDeadline <= DATE_ADD(CURDATE(), INTERVAL 7 DAY) THEN 'Due Within 7 Days'
        ELSE 'On Track'
    END                                   AS DeadlineUrgency
FROM MediaRecord mr
INNER JOIN Meeting m      ON mr.MeetingId = m.MeetingId
INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
LEFT JOIN `User` u        ON mr.ResponsibleUserID = u.UserID;

-- ============================================================================
-- 8. REGULARITY & PLANNED-VS-ACTUAL ANALYTICS VIEWS
-- ============================================================================
CREATE VIEW vw_staff_attendance_regularity AS
SELECT
    u.UserID,
    u.Name,
    u.RoleType                                                         AS UserRole,
    COUNT(CASE WHEN m.Meeting_Status = 'Completed' THEN 1 END)         AS CompletedMeetingsInvited,
    SUM(CASE WHEN m.Meeting_Status = 'Completed' AND a.Att_Status = 'Present' THEN 1 ELSE 0 END) AS MeetingsPresent,
    SUM(CASE WHEN m.Meeting_Status = 'Completed' AND a.Att_Status = 'Absent'  THEN 1 ELSE 0 END) AS MeetingsAbsent,
    SUM(CASE WHEN m.Meeting_Status = 'Completed' AND a.Att_Status = 'Excused' THEN 1 ELSE 0 END) AS MeetingsExcused,
    COALESCE(
        ROUND(
            (SUM(CASE WHEN m.Meeting_Status = 'Completed' AND a.Att_Status = 'Present' THEN 1 ELSE 0 END) * 100.0)
            / NULLIF(COUNT(CASE WHEN m.Meeting_Status = 'Completed' THEN 1 END), 0),
            2
        ),
        0.00
    )                                                                  AS RegularityPercentage
FROM `User` u
LEFT JOIN Attends a ON u.UserID = a.UserID
LEFT JOIN Meeting m ON a.MeetingId = m.MeetingId
GROUP BY u.UserID, u.Name, u.RoleType;

CREATE VIEW vw_planned_vs_actual_meetings AS
SELECT
    yp.PlanID,
    yp.AcademicYear,
    yp.PlanLink,
    mt.TypeID,
    mt.ShortName,
    mt.Name                                                                         AS MeetingTypeName,
    mt.CategoryGroup,
    mt.CalendarColorHex,
    mt.TargetFrequency                                                              AS AnnualTargetMeetings,
    COUNT(m.MeetingId)                                                              AS TotalLoggedInCalendar,
    SUM(CASE WHEN m.Meeting_Status = 'Completed' THEN 1 ELSE 0 END)                 AS CompletedMeetings,
    SUM(CASE WHEN m.Meeting_Status IN ('Planned', 'Scheduled') THEN 1 ELSE 0 END)   AS UpcomingMeetings,
    SUM(CASE WHEN m.Meeting_Status = 'Postponed' THEN 1 ELSE 0 END)                 AS PostponedMeetings,
    SUM(CASE WHEN m.Meeting_Status = 'Cancelled' THEN 1 ELSE 0 END)                 AS CancelledMeetings,
    ROUND(
        (SUM(CASE WHEN m.Meeting_Status = 'Completed' THEN 1 ELSE 0 END) * 100.0)
        / mt.TargetFrequency,
        2
    )                                                                               AS TargetCompletionRatePct
FROM YearPlan yp
CROSS JOIN MeetingType mt
LEFT JOIN Meeting m
    ON m.PlanID = yp.PlanID AND m.TypeID = mt.TypeID
GROUP BY
    yp.PlanID, yp.AcademicYear, yp.PlanLink, mt.TypeID, mt.ShortName,
    mt.Name, mt.CategoryGroup, mt.CalendarColorHex, mt.TargetFrequency;
