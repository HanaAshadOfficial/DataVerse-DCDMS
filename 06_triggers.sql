-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Script       : 06_triggers.sql
-- Purpose      : Automated triggers enforcing ISA disjointness & attribute sync,
--                3-day advance Agenda upload rule, Fixed-Date protection,
--                Venue/Time conflict prevention, Confidentiality (Scrutiny Board
--                & Student Coordinator RBAC), and 2/3 Quorum verification.
-- Target DBMS  : MySQL Server 8.0 / 8.4 (Zero-Warning MySQL Workbench Ready)
-- ============================================================================

USE dcdms_db;

SET SESSION sql_notes = 0;
DROP TRIGGER IF EXISTS trg_user_au_sync_subtypes;
DROP TRIGGER IF EXISTS trg_hod_bi_disjoint;
DROP TRIGGER IF EXISTS trg_academic_bi_disjoint;
DROP TRIGGER IF EXISTS trg_clerk_bi_disjoint;
DROP TRIGGER IF EXISTS trg_support_bi_disjoint;
DROP TRIGGER IF EXISTS trg_student_coord_bi_disjoint;
DROP TRIGGER IF EXISTS trg_meeting_bi_business_rules;
DROP TRIGGER IF EXISTS trg_meeting_bu_business_rules;
DROP TRIGGER IF EXISTS trg_agenda_bu_three_day_rule;
DROP TRIGGER IF EXISTS trg_attends_bi_privacy_guard;
DROP TRIGGER IF EXISTS trg_attends_bu_privacy_guard;
DROP TRIGGER IF EXISTS trg_confirmation_bi_privacy_guard;
DROP TRIGGER IF EXISTS trg_confirmation_bu_privacy_guard;
DROP TRIGGER IF EXISTS trg_mediarecord_bi_validate;
DROP TRIGGER IF EXISTS trg_mediarecord_bu_validate;
SET SESSION sql_notes = 1;

-- ============================================================================
-- 1. ISA HIERARCHY SYNC & DISJOINTNESS TRIGGERS
--    Keeps inherited attributes (Name, Email, Password) synchronized between
--    User and the 5 role tables in NORMALIZATION - NEW.pdf, and enforces
--    strictly disjoint role membership across all 5 subtypes.
-- ============================================================================
DELIMITER $$
CREATE TRIGGER trg_user_au_sync_subtypes
AFTER UPDATE ON `User`
FOR EACH ROW
BEGIN
    IF NEW.RoleType = 'HOD' THEN
        UPDATE HOD
        SET Name = NEW.Name, Email = NEW.Email, Password = NEW.Password
        WHERE UserID = NEW.UserID;
    ELSEIF NEW.RoleType = 'AcademicStaff' THEN
        UPDATE AcademicStaff
        SET Name = NEW.Name, Email = NEW.Email, Password = NEW.Password
        WHERE UserID = NEW.UserID;
    ELSEIF NEW.RoleType = 'Clerk' THEN
        UPDATE Clerk
        SET Name = NEW.Name, Email = NEW.Email, Password = NEW.Password
        WHERE UserID = NEW.UserID;
    ELSEIF NEW.RoleType = 'SupportStaff' THEN
        UPDATE SupportStaff
        SET Name = NEW.Name, Email = NEW.Email, Password = NEW.Password
        WHERE UserID = NEW.UserID;
    ELSEIF NEW.RoleType = 'StudentCoordinator' THEN
        UPDATE StudentCoordinator
        SET Name = NEW.Name, Email = NEW.Email, Password = NEW.Password
        WHERE UserID = NEW.UserID;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_hod_bi_disjoint
BEFORE INSERT ON HOD
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM AcademicStaff WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM Clerk WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ISA Disjoint Violation: UserID already belongs to another staff/student subtype.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_academic_bi_disjoint
BEFORE INSERT ON AcademicStaff
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM HOD WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM Clerk WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ISA Disjoint Violation: UserID already belongs to another staff/student subtype.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_clerk_bi_disjoint
BEFORE INSERT ON Clerk
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM HOD WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM AcademicStaff WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ISA Disjoint Violation: UserID already belongs to another staff/student subtype.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_support_bi_disjoint
BEFORE INSERT ON SupportStaff
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM HOD WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM AcademicStaff WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM Clerk WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ISA Disjoint Violation: UserID already belongs to another staff/student subtype.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_student_coord_bi_disjoint
BEFORE INSERT ON StudentCoordinator
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM HOD WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM AcademicStaff WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM Clerk WHERE UserID = NEW.UserID)
       OR EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = NEW.UserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ISA Disjoint Violation: UserID already belongs to another staff/student subtype.';
    END IF;
END$$
DELIMITER ;

-- ============================================================================
-- 2. MEETING SCHEDULING, VENUE CONFLICT, AGENDA 3-DAY RULE & QUORUM TRIGGERS
-- ============================================================================
DELIMITER $$
CREATE TRIGGER trg_meeting_bi_business_rules
BEFORE INSERT ON Meeting
FOR EACH ROW
BEGIN
    DECLARE v_upload_date DATE;
    DECLARE v_conflict_id VARCHAR(10);

    -- Rule A: Agenda must be uploaded at least 3 days before PlannedDate
    IF NEW.Agenda_id IS NOT NULL THEN
        SELECT Upload_Date INTO v_upload_date
        FROM Agenda
        WHERE Agenda_id = NEW.Agenda_id;

        IF v_upload_date IS NOT NULL
           AND v_upload_date > DATE_SUB(NEW.PlannedDate, INTERVAL 3 DAY) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Pre-Meeting Rule Violation: Agenda must be uploaded at least 3 days before PlannedDate.';
        END IF;
    END IF;

    -- Rule B: Postponed meetings must document a RescheduleReason for the GUI log
    IF NEW.Meeting_Status = 'Postponed'
       AND (NEW.RescheduleReason IS NULL OR CHAR_LENGTH(TRIM(NEW.RescheduleReason)) = 0) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rescheduling Rule Violation: Postponed meetings require a non-empty RescheduleReason.';
    END IF;

    -- Rule C: Physical Venue & Time-Slot Conflict Prevention (Double-Booking Guard)
    --         Allows multiple meetings on the same day if in different venues or
    --         non-overlapping times; virtual Zoom/Online rooms are exempt.
    IF NEW.Meeting_Status IN ('Planned', 'Scheduled', 'Completed')
       AND NEW.Venue NOT LIKE 'Zoom%'
       AND NEW.Venue NOT LIKE 'Online%' THEN
        SELECT MeetingId INTO v_conflict_id
        FROM Meeting
        WHERE PlannedDate = NEW.PlannedDate
          AND Venue = NEW.Venue
          AND Meeting_Status IN ('Planned', 'Scheduled', 'Completed')
          AND NEW.StartTime < EndTime
          AND NEW.EndTime > StartTime
        LIMIT 1;

        IF v_conflict_id IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Venue Conflict Error: Selected physical venue is already booked during an overlapping time slot on PlannedDate.';
        END IF;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_meeting_bu_business_rules
BEFORE UPDATE ON Meeting
FOR EACH ROW
BEGIN
    DECLARE v_upload_date   DATE;
    DECLARE v_conflict_id   VARCHAR(10);
    DECLARE v_total_invited INT DEFAULT 0;
    DECLARE v_present_count INT DEFAULT 0;

    -- Rule A: Fixed calendar dates cannot be shifted unless unlocked by HOD (IsFixed = 'No')
    IF OLD.IsFixed = 'Yes' AND NEW.IsFixed = 'Yes' AND NEW.PlannedDate <> OLD.PlannedDate THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Fixed-Date Protection: PlannedDate of a fixed calendar meeting cannot be changed unless unlocked by HOD (set IsFixed = No).';
    END IF;

    -- Rule B: Agenda must be uploaded at least 3 days before PlannedDate
    IF NEW.Agenda_id IS NOT NULL THEN
        SELECT Upload_Date INTO v_upload_date
        FROM Agenda
        WHERE Agenda_id = NEW.Agenda_id;

        IF v_upload_date IS NOT NULL
           AND v_upload_date > DATE_SUB(NEW.PlannedDate, INTERVAL 3 DAY) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Pre-Meeting Rule Violation: Agenda must be uploaded at least 3 days before PlannedDate.';
        END IF;
    END IF;

    -- Rule C: Postponed meetings require a RescheduleReason
    IF NEW.Meeting_Status = 'Postponed'
       AND (NEW.RescheduleReason IS NULL OR CHAR_LENGTH(TRIM(NEW.RescheduleReason)) = 0) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rescheduling Rule Violation: Postponed meetings require a non-empty RescheduleReason.';
    END IF;

    -- Rule D: Physical Venue & Time-Slot Conflict Prevention
    IF NEW.Meeting_Status IN ('Planned', 'Scheduled', 'Completed')
       AND NEW.Venue NOT LIKE 'Zoom%'
       AND NEW.Venue NOT LIKE 'Online%' THEN
        SELECT MeetingId INTO v_conflict_id
        FROM Meeting
        WHERE MeetingId <> NEW.MeetingId
          AND PlannedDate = NEW.PlannedDate
          AND Venue = NEW.Venue
          AND Meeting_Status IN ('Planned', 'Scheduled', 'Completed')
          AND NEW.StartTime < EndTime
          AND NEW.EndTime > StartTime
        LIMIT 1;

        IF v_conflict_id IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Venue Conflict Error: Selected physical venue is already booked during an overlapping time slot on PlannedDate.';
        END IF;
    END IF;

    -- Rule E: Minimum Two-Thirds (2/3 = 66.67%) Quorum Check on Completion
    IF OLD.Meeting_Status <> 'Completed' AND NEW.Meeting_Status = 'Completed' THEN
        SELECT COUNT(*),
               COALESCE(SUM(CASE WHEN Att_Status = 'Present' THEN 1 ELSE 0 END), 0)
        INTO v_total_invited, v_present_count
        FROM Attends
        WHERE MeetingId = NEW.MeetingId;

        IF v_total_invited = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Quorum Violation: Cannot complete a meeting with zero registered participants in Attends.';
        END IF;

        IF (v_present_count * 3) < (v_total_invited * 2) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Quorum Violation: Minimum 2/3 (66.67%) Present attendance not reached. HOD must postpone or cancel and reschedule.';
        END IF;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_agenda_bu_three_day_rule
BEFORE UPDATE ON Agenda
FOR EACH ROW
BEGIN
    DECLARE v_planned_date DATE;

    SELECT PlannedDate INTO v_planned_date
    FROM Meeting
    WHERE Agenda_id = NEW.Agenda_id
    LIMIT 1;

    IF v_planned_date IS NOT NULL
       AND NEW.Upload_Date > DATE_SUB(v_planned_date, INTERVAL 3 DAY) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pre-Meeting Rule Violation: Updated Agenda Upload_Date violates the 3-day advance requirement for its linked Meeting.';
    END IF;
END$$
DELIMITER ;

-- ============================================================================
-- 3. CONFIDENTIALITY & RBAC TRIGGERS ON ATTENDS AND MEETINGCONFIRMATION
--    * Clerk, SupportStaff, and StudentCoordinator are strictly blocked from
--      confidential IsPrivate = 'Yes' meetings (Scrutiny Board 'SB').
--    * StudentCoordinator is restricted strictly to 'SC' and 'CP' meetings.
-- ============================================================================
DELIMITER $$
CREATE TRIGGER trg_attends_bi_privacy_guard
BEFORE INSERT ON Attends
FOR EACH ROW
BEGIN
    DECLARE v_is_private VARCHAR(5);
    DECLARE v_short_name VARCHAR(15);

    SELECT mt.IsPrivate, mt.ShortName
    INTO v_is_private, v_short_name
    FROM Meeting m
    INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
    WHERE m.MeetingId = NEW.MeetingId;

    IF v_is_private = 'Yes' AND (
        EXISTS (SELECT 1 FROM Clerk WHERE UserID = NEW.UserID)
        OR EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = NEW.UserID)
        OR EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID)
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Confidentiality Violation: Clerk, SupportStaff, and StudentCoordinator are strictly excluded from private Scrutiny Board meetings.';
    END IF;

    IF EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID)
       AND v_short_name NOT IN ('SC', 'CP') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RBAC Violation: Student Coordinators may only attend Student Coordinator (SC) and Conference & Project Carnival (CP) meetings.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_attends_bu_privacy_guard
BEFORE UPDATE ON Attends
FOR EACH ROW
BEGIN
    DECLARE v_is_private VARCHAR(5);
    DECLARE v_short_name VARCHAR(15);

    SELECT mt.IsPrivate, mt.ShortName
    INTO v_is_private, v_short_name
    FROM Meeting m
    INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
    WHERE m.MeetingId = NEW.MeetingId;

    IF v_is_private = 'Yes' AND (
        EXISTS (SELECT 1 FROM Clerk WHERE UserID = NEW.UserID)
        OR EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = NEW.UserID)
        OR EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID)
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Confidentiality Violation: Clerk, SupportStaff, and StudentCoordinator are strictly excluded from private Scrutiny Board meetings.';
    END IF;

    IF EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID)
       AND v_short_name NOT IN ('SC', 'CP') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RBAC Violation: Student Coordinators may only attend Student Coordinator (SC) and Conference & Project Carnival (CP) meetings.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_confirmation_bi_privacy_guard
BEFORE INSERT ON MeetingConfirmation
FOR EACH ROW
BEGIN
    DECLARE v_is_private VARCHAR(5);
    DECLARE v_short_name VARCHAR(15);

    SELECT mt.IsPrivate, mt.ShortName
    INTO v_is_private, v_short_name
    FROM Meeting m
    INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
    WHERE m.MeetingId = NEW.MeetingId;

    IF v_is_private = 'Yes' AND (
        EXISTS (SELECT 1 FROM Clerk WHERE UserID = NEW.UserID)
        OR EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = NEW.UserID)
        OR EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID)
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Confidentiality Violation: Unauthorized role cannot confirm attendance for a private Scrutiny Board meeting.';
    END IF;

    IF EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID)
       AND v_short_name NOT IN ('SC', 'CP') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RBAC Violation: Student Coordinators may only confirm Student Coordinator (SC) and Project Carnival (CP) meetings.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_confirmation_bu_privacy_guard
BEFORE UPDATE ON MeetingConfirmation
FOR EACH ROW
BEGIN
    DECLARE v_is_private VARCHAR(5);
    DECLARE v_short_name VARCHAR(15);

    SELECT mt.IsPrivate, mt.ShortName
    INTO v_is_private, v_short_name
    FROM Meeting m
    INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
    WHERE m.MeetingId = NEW.MeetingId;

    IF v_is_private = 'Yes' AND (
        EXISTS (SELECT 1 FROM Clerk WHERE UserID = NEW.UserID)
        OR EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = NEW.UserID)
        OR EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID)
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Confidentiality Violation: Unauthorized role cannot confirm attendance for a private Scrutiny Board meeting.';
    END IF;

    IF EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = NEW.UserID)
       AND v_short_name NOT IN ('SC', 'CP') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RBAC Violation: Student Coordinators may only confirm Student Coordinator (SC) and Project Carnival (CP) meetings.';
    END IF;
END$$
DELIMITER ;

-- ============================================================================
-- 4. POST-MEETING MEDIARECORD CHRONOLOGY & STATUS VALIDATION TRIGGERS
-- ============================================================================
DELIMITER $$
CREATE TRIGGER trg_mediarecord_bi_validate
BEFORE INSERT ON MediaRecord
FOR EACH ROW
BEGIN
    DECLARE v_planned_date DATE;
    DECLARE v_actual_date  DATE;
    DECLARE v_status       VARCHAR(20);

    SELECT PlannedDate, ActualDate, Meeting_Status
    INTO v_planned_date, v_actual_date, v_status
    FROM Meeting
    WHERE MeetingId = NEW.MeetingId;

    IF v_status = 'Cancelled' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Post-Meeting Rule Violation: Cannot attach decisions or media records to a Cancelled meeting.';
    END IF;

    IF NEW.UploadDate < COALESCE(v_actual_date, v_planned_date) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chronology Violation: MediaRecord UploadDate cannot precede the meeting date.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_mediarecord_bu_validate
BEFORE UPDATE ON MediaRecord
FOR EACH ROW
BEGIN
    DECLARE v_planned_date DATE;
    DECLARE v_actual_date  DATE;
    DECLARE v_status       VARCHAR(20);

    SELECT PlannedDate, ActualDate, Meeting_Status
    INTO v_planned_date, v_actual_date, v_status
    FROM Meeting
    WHERE MeetingId = NEW.MeetingId;

    IF v_status = 'Cancelled' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Post-Meeting Rule Violation: Cannot attach decisions or media records to a Cancelled meeting.';
    END IF;

    IF NEW.UploadDate < COALESCE(v_actual_date, v_planned_date) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chronology Violation: MediaRecord UploadDate cannot precede the meeting date.';
    END IF;
END$$
DELIMITER ;
