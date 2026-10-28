-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Script       : 07_reports_and_queries.sql
-- Purpose      : Comprehensive analytical, GUI-ready, and operational queries
--                demonstrating all DataVerse workflows across 15 relations.
-- Target DBMS  : MySQL Server 8.0 / 8.4 (Zero-Warning MySQL Workbench Ready)
-- ============================================================================

USE dcdms_db;

-- ============================================================================
-- QUERY 1: DataVerse GUI Login Authentication Demo (Slide 2)
-- ============================================================================
CALL sp_gui_authenticate_user('tharindu@computing.rjt.ac.lk', 'Hod@Rjt2026#01');
CALL sp_gui_authenticate_user('U029', 'Clerk@Rjt2026#29');

-- ============================================================================
-- QUERY 2: GUI Executive Dashboard KPI Cards & Category Distribution Chart
-- ============================================================================
SELECT * FROM vw_gui_dashboard_kpis;
SELECT * FROM vw_gui_meeting_category_chart ORDER BY TotalMeetingsLogged DESC;

-- ============================================================================
-- QUERY 3: 2026 Color-Coded Annual Meeting Matrix (Matching Excel Summary Sheet)
-- ============================================================================
SELECT
    TypeID,
    ShortName,
    Name AS Event,
    CategoryGroup,
    FrequencyLabel AS Frequency,
    TargetFrequency,
    Semester01,
    Semester02,
    ScheduledMonths,
    CalendarColorHex,
    IsPrivate
FROM MeetingType
ORDER BY TypeID;

-- ============================================================================
-- QUERY 4: 2026 Planned vs. Actual Annual Meeting Progress (AcademicYear = 2026)
-- ============================================================================
SELECT
    ShortName,
    MeetingTypeName,
    CategoryGroup,
    CalendarColorHex,
    AnnualTargetMeetings,
    TotalLoggedInCalendar,
    CompletedMeetings,
    UpcomingMeetings,
    PostponedMeetings,
    CancelledMeetings,
    TargetCompletionRatePct
FROM vw_planned_vs_actual_meetings
WHERE AcademicYear = 2026
ORDER BY TypeID;

-- ============================================================================
-- QUERY 5: Role-Based Confidentiality Proof (HOD vs. Clerk vs. StudentCoordinator)
-- ============================================================================
SELECT
    (SELECT COUNT(*) FROM vw_hod_all_meetings)                        AS HOD_Total_Visible_Meetings,
    (SELECT COUNT(*) FROM vw_hod_all_meetings WHERE IsPrivate = 'Yes') AS HOD_ScrutinyBoard_Visible,
    (SELECT COUNT(*) FROM vw_clerk_meetings)                          AS Clerk_Total_Visible_Meetings,
    (SELECT COUNT(*) FROM vw_student_coordinator_meetings)            AS StudentCoord_Visible_Meetings;

-- ============================================================================
-- QUERY 6: Two-Thirds (2/3 = 66.67%) Quorum Audit & HOD Recommendations
-- ============================================================================
SELECT
    MeetingId,
    ShortName,
    PlannedDate,
    ActualDate,
    Venue,
    Meeting_Status,
    TotalParticipants,
    PresentCount,
    PresentPercentage,
    QuorumReached,
    HOD_Action_Recommendation
FROM vw_meeting_quorum_status
ORDER BY PlannedDate DESC;

-- ============================================================================
-- QUERY 7: Pre-Meeting 3-Day Agenda Deadline & Notification Audit Trail
-- ============================================================================
SELECT
    m.MeetingId,
    mt.ShortName,
    m.PlannedDate,
    m.StartTime,
    m.Venue,
    ag.Agenda_id,
    ag.Upload_Date,
    DATEDIFF(m.PlannedDate, ag.Upload_Date) AS DaysUploadedInAdvance,
    ag.AgendaFileLink,
    GROUP_CONCAT(CONCAT(n.NotificationID, ':', n.Type, ' (', n.Sent_Date, ')') SEPARATOR '; ') AS SentAlerts
FROM Meeting m
INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
LEFT JOIN Agenda ag       ON m.Agenda_id = ag.Agenda_id
LEFT JOIN Notification n  ON m.MeetingId = n.MeetingId
GROUP BY m.MeetingId, mt.ShortName, m.PlannedDate, m.StartTime, m.Venue,
         ag.Agenda_id, ag.Upload_Date, ag.AgendaFileLink
ORDER BY m.PlannedDate DESC;

-- ============================================================================
-- QUERY 8: Action-Item & Responsible Officer Task Deadline Tracker (GUI Level-Up)
-- ============================================================================
SELECT
    MeetingRecID,
    ShortName,
    ResponsibleOfficer,
    TaskDeadline,
    TaskStatus,
    DeadlineUrgency,
    LEFT(DecisionText, 95) AS DecisionSummary
FROM vw_gui_action_items_tracker
WHERE IsPrivate = 'No'
ORDER BY FIELD(TaskStatus, 'Pending', 'In Progress', 'Completed'), TaskDeadline ASC;

-- ============================================================================
-- QUERY 9: Role-Safe Multi-Year Decision Search (HOD vs. Clerk on 'examination')
-- ============================================================================
-- HOD ('U001') sees confidential Scrutiny Board moderation decisions:
CALL sp_search_decisions('U001', 'examination', NULL, '2024-01-01', '2026-12-31');

-- Clerk ('U029') runs the exact same search -> 0 confidential rows leaked!
CALL sp_search_decisions('U029', 'examination', NULL, '2024-01-01', '2026-12-31');

-- ============================================================================
-- QUERY 10: Staff Attendance Regularity Leaderboard (Completed Meetings)
-- ============================================================================
SELECT
    UserID,
    Name,
    UserRole,
    CompletedMeetingsInvited,
    MeetingsPresent,
    MeetingsAbsent,
    MeetingsExcused,
    RegularityPercentage
FROM vw_staff_attendance_regularity
WHERE CompletedMeetingsInvited > 0
ORDER BY RegularityPercentage DESC, MeetingsPresent DESC
LIMIT 15;
