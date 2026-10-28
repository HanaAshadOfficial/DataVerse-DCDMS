-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Script       : 05_procedures_and_functions.sql
-- Purpose      : Stored Functions and Stored Procedures powering DataVerse GUI
--                Authentication, User Registration, Monthly Scheduling,
--                Auto-Participant Assignment, 3-Day Agenda Upload & Reminders,
--                2/3 Quorum Verification, HOD Rescheduling, Decision/Action-Item
--                Archiving, and Role-Safe Multi-Year Keyword Search.
-- Target DBMS  : MySQL Server 8.0 / 8.4 (Zero-Warning MySQL Workbench Ready)
-- ============================================================================

USE dcdms_db;

SET SESSION sql_notes = 0;
DROP FUNCTION IF EXISTS fn_attendance_percentage;
DROP FUNCTION IF EXISTS fn_is_quorum_reached;
DROP PROCEDURE IF EXISTS sp_gui_authenticate_user;
DROP PROCEDURE IF EXISTS sp_register_department_user;
DROP PROCEDURE IF EXISTS sp_schedule_monthly_meeting;
DROP PROCEDURE IF EXISTS sp_auto_assign_meeting_participants;
DROP PROCEDURE IF EXISTS sp_upload_agenda_for_meeting;
DROP PROCEDURE IF EXISTS sp_generate_three_day_alerts;
DROP PROCEDURE IF EXISTS sp_cancel_and_reschedule_no_quorum;
DROP PROCEDURE IF EXISTS sp_record_decision_with_media;
DROP PROCEDURE IF EXISTS sp_search_decisions;
SET SESSION sql_notes = 1;

-- ============================================================================
-- 1. STORED FUNCTION: fn_attendance_percentage
-- ============================================================================
DELIMITER $$
CREATE FUNCTION fn_attendance_percentage(p_meeting_id VARCHAR(10))
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total   INT DEFAULT 0;
    DECLARE v_present INT DEFAULT 0;

    SELECT COUNT(*),
           COALESCE(SUM(CASE WHEN Att_Status = 'Present' THEN 1 ELSE 0 END), 0)
    INTO v_total, v_present
    FROM Attends
    WHERE MeetingId = p_meeting_id;

    IF v_total = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND((v_present * 100.0) / v_total, 2);
END$$
DELIMITER ;

-- ============================================================================
-- 2. STORED FUNCTION: fn_is_quorum_reached
--    Exact Two-Thirds (2/3 = 66.67%) Quorum Check: (Present * 3) >= (Total * 2)
-- ============================================================================
DELIMITER $$
CREATE FUNCTION fn_is_quorum_reached(p_meeting_id VARCHAR(10))
RETURNS VARCHAR(3)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total   INT DEFAULT 0;
    DECLARE v_present INT DEFAULT 0;

    SELECT COUNT(*),
           COALESCE(SUM(CASE WHEN Att_Status = 'Present' THEN 1 ELSE 0 END), 0)
    INTO v_total, v_present
    FROM Attends
    WHERE MeetingId = p_meeting_id;

    IF v_total > 0 AND (v_present * 3) >= (v_total * 2) THEN
        RETURN 'Yes';
    END IF;

    RETURN 'No';
END$$
DELIMITER ;

-- ============================================================================
-- 3. STORED PROCEDURE: sp_gui_authenticate_user
--    Powers Slide 2 (DataVerse Login Screen): accepts UserID or Email +
--    plaintext password, hashes via SHA-256, and returns role routing data.
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_gui_authenticate_user(
    IN p_login_identifier VARCHAR(150),
    IN p_plain_password   VARCHAR(255)
)
BEGIN
    SELECT
        CASE WHEN COUNT(*) = 1 THEN 'AUTHENTICATED' ELSE 'INVALID_CREDENTIALS' END AS AuthStatus,
        MAX(UserID)   AS UserID,
        MAX(Name)     AS FullName,
        MAX(Email)    AS Email,
        MAX(RoleType) AS RoleType
    FROM `User`
    WHERE (UserID = p_login_identifier OR Email = p_login_identifier)
      AND Password = SHA2(p_plain_password, 256);
END$$
DELIMITER ;

-- ============================================================================
-- 4. STORED PROCEDURE: sp_register_department_user
--    Atomically inserts into User and the matching ISA subtype relation
--    (HOD, AcademicStaff, Clerk, SupportStaff, or StudentCoordinator).
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_register_department_user(
    IN p_user_id        VARCHAR(10),
    IN p_name           VARCHAR(100),
    IN p_email          VARCHAR(150),
    IN p_plain_password VARCHAR(255),
    IN p_role_type      VARCHAR(30)
)
BEGIN
    DECLARE v_hash VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_hash = SHA2(p_plain_password, 256);

    START TRANSACTION;

    INSERT INTO `User` (UserID, Name, Email, Password, RoleType)
    VALUES (p_user_id, p_name, p_email, v_hash, p_role_type);

    IF p_role_type = 'HOD' THEN
        INSERT INTO HOD (UserID, Name, Email, Password)
        VALUES (p_user_id, p_name, p_email, v_hash);
    ELSEIF p_role_type = 'AcademicStaff' THEN
        INSERT INTO AcademicStaff (UserID, Name, Email, Password)
        VALUES (p_user_id, p_name, p_email, v_hash);
    ELSEIF p_role_type = 'Clerk' THEN
        INSERT INTO Clerk (UserID, Name, Email, Password)
        VALUES (p_user_id, p_name, p_email, v_hash);
    ELSEIF p_role_type = 'SupportStaff' THEN
        INSERT INTO SupportStaff (UserID, Name, Email, Password)
        VALUES (p_user_id, p_name, p_email, v_hash);
    ELSEIF p_role_type = 'StudentCoordinator' THEN
        INSERT INTO StudentCoordinator (UserID, Name, Email, Password)
        VALUES (p_user_id, p_name, p_email, v_hash);
    END IF;

    COMMIT;
END$$
DELIMITER ;

-- ============================================================================
-- 5. STORED PROCEDURE: sp_schedule_monthly_meeting
--    Powers the GUI Monthly Scheduling Window (1st week of each month),
--    relying on trg_meeting_bi_business_rules for Venue Conflict checks.
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_schedule_monthly_meeting(
    IN p_meeting_id   VARCHAR(10),
    IN p_type_id      VARCHAR(10),
    IN p_plan_id      VARCHAR(10),
    IN p_hod_user_id  VARCHAR(10),
    IN p_planned_date DATE,
    IN p_start_time   TIME,
    IN p_end_time     TIME,
    IN p_venue        VARCHAR(100),
    IN p_is_fixed     VARCHAR(5)
)
BEGIN
    INSERT INTO Meeting (
        MeetingId, IsFixed, PlannedDate, ActualDate, StartTime, EndTime,
        Venue, Meeting_Status, RescheduleReason, TypeID, PlanID, UserID, Agenda_id
    ) VALUES (
        p_meeting_id, p_is_fixed, p_planned_date, NULL, p_start_time, p_end_time,
        p_venue, 'Scheduled', NULL, p_type_id, p_plan_id, p_hod_user_id, NULL
    );
END$$
DELIMITER ;

-- ============================================================================
-- 6. STORED PROCEDURE: sp_auto_assign_meeting_participants
--    Populates Attends with the default participant roster for a MeetingType
--    matching DEPARTMENT_MEETING_CALENDAR.XLSX & RBAC confidentiality rules.
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_auto_assign_meeting_participants(
    IN p_meeting_id VARCHAR(10)
)
BEGIN
    DECLARE v_is_private  VARCHAR(5);
    DECLARE v_short_name  VARCHAR(15);
    DECLARE v_hod_user_id VARCHAR(10);

    SELECT mt.IsPrivate, mt.ShortName, m.UserID
    INTO v_is_private, v_short_name, v_hod_user_id
    FROM Meeting m
    INNER JOIN MeetingType mt ON m.TypeID = mt.TypeID
    WHERE m.MeetingId = p_meeting_id;

    -- Always invite the presiding HOD + active AcademicStaff
    INSERT IGNORE INTO Attends (UserID, MeetingId, Att_Status)
    VALUES (v_hod_user_id, p_meeting_id, 'Invited');

    INSERT IGNORE INTO Attends (UserID, MeetingId, Att_Status)
    SELECT UserID, p_meeting_id, 'Invited'
    FROM AcademicStaff;

    -- Non-private meetings include primary Clerk (System Convener 'U029')
    IF v_is_private = 'No' THEN
        INSERT IGNORE INTO Attends (UserID, MeetingId, Att_Status)
        VALUES ('U029', p_meeting_id, 'Invited');

        -- Department Meetings & Staff Workshops also include SupportStaff
        IF v_short_name IN ('DM', 'SW') THEN
            INSERT IGNORE INTO Attends (UserID, MeetingId, Att_Status)
            SELECT UserID, p_meeting_id, 'Invited'
            FROM SupportStaff;
        END IF;

        -- Student Coordinator & Project Carnival include StudentCoordinators
        IF v_short_name IN ('SC', 'CP') THEN
            INSERT IGNORE INTO Attends (UserID, MeetingId, Att_Status)
            SELECT UserID, p_meeting_id, 'Invited'
            FROM StudentCoordinator;
        END IF;
    END IF;
END$$
DELIMITER ;

-- ============================================================================
-- 7. STORED PROCEDURE: sp_upload_agenda_for_meeting
--    Validates >= 3-day pre-meeting deadline, saves Google Drive cloud link,
--    attaches Agenda to Meeting, and emits an Agenda Uploaded Alert.
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_upload_agenda_for_meeting(
    IN p_agenda_id       VARCHAR(10),
    IN p_meeting_id      VARCHAR(10),
    IN p_agenda_name     VARCHAR(200),
    IN p_upload_date     DATE,
    IN p_file_link       VARCHAR(500),
    IN p_notification_id VARCHAR(10)
)
BEGIN
    DECLARE v_planned_date DATE;
    DECLARE v_status       VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT PlannedDate, Meeting_Status
    INTO v_planned_date, v_status
    FROM Meeting
    WHERE MeetingId = p_meeting_id;

    IF v_planned_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Target MeetingId does not exist.';
    END IF;

    IF v_status IN ('Cancelled', 'Completed') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot upload a pre-meeting agenda for a Completed or Cancelled meeting.';
    END IF;

    IF p_upload_date > DATE_SUB(v_planned_date, INTERVAL 3 DAY) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Agenda Upload Rejected: Agenda must be uploaded at least 3 days before PlannedDate.';
    END IF;

    START TRANSACTION;

    INSERT INTO Agenda (Agenda_id, Name, Upload_Date, AgendaFileLink)
    VALUES (p_agenda_id, p_agenda_name, p_upload_date, p_file_link);

    UPDATE Meeting
    SET Agenda_id      = p_agenda_id,
        Meeting_Status = CASE WHEN Meeting_Status = 'Planned' THEN 'Scheduled' ELSE Meeting_Status END
    WHERE MeetingId = p_meeting_id;

    IF p_notification_id IS NOT NULL THEN
        INSERT INTO Notification (NotificationID, Type, Sent_Date, MeetingId)
        VALUES (p_notification_id, 'Agenda Uploaded Alert', p_upload_date, p_meeting_id);
    END IF;

    COMMIT;
END$$
DELIMITER ;

-- ============================================================================
-- 8. STORED PROCEDURE: sp_generate_three_day_alerts
--    Automated 3-5 day pre-meeting Dashboard & Gmail reminder generator.
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_generate_three_day_alerts(IN p_reference_date DATE)
BEGIN
    DECLARE v_done       INT DEFAULT 0;
    DECLARE v_meeting_id VARCHAR(10);
    DECLARE v_next_num   INT DEFAULT 1;
    DECLARE v_notif_id   VARCHAR(10);

    DECLARE cur_upcoming CURSOR FOR
        SELECT m.MeetingId
        FROM Meeting m
        WHERE m.Meeting_Status IN ('Planned', 'Scheduled')
          AND DATEDIFF(m.PlannedDate, p_reference_date) BETWEEN 3 AND 5
          AND NOT EXISTS (
              SELECT 1
              FROM Notification n
              WHERE n.MeetingId = m.MeetingId
                AND n.Type IN ('Dashboard & Gmail Alert', 'Gmail Alert', 'Dashboard Alert', 'Meeting Reminder')
          )
        ORDER BY m.PlannedDate ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SELECT COALESCE(MAX(CAST(SUBSTRING(NotificationID, 2) AS UNSIGNED)), 0) + 1
    INTO v_next_num
    FROM Notification
    WHERE NotificationID REGEXP '^N[0-9]+$';

    OPEN cur_upcoming;

    read_loop: LOOP
        FETCH cur_upcoming INTO v_meeting_id;
        IF v_done = 1 THEN
            LEAVE read_loop;
        END IF;

        SET v_notif_id = CONCAT('N', LPAD(v_next_num, 3, '0'));

        INSERT INTO Notification (NotificationID, Type, Sent_Date, MeetingId)
        VALUES (v_notif_id, 'Dashboard & Gmail Alert', p_reference_date, v_meeting_id);

        SET v_next_num = v_next_num + 1;
    END LOOP;

    CLOSE cur_upcoming;
END$$
DELIMITER ;

-- ============================================================================
-- 9. STORED PROCEDURE: sp_cancel_and_reschedule_no_quorum
--    HOD Conditional Cancellation & Rescheduling Workflow when Present < 2/3.
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_cancel_and_reschedule_no_quorum(
    IN p_meeting_id          VARCHAR(10),
    IN p_hod_user_id         VARCHAR(10),
    IN p_new_meeting_id      VARCHAR(10),
    IN p_new_planned_date    DATE,
    IN p_new_start_time      TIME,
    IN p_new_end_time        TIME,
    IN p_new_venue           VARCHAR(100),
    IN p_reschedule_reason   VARCHAR(255),
    IN p_cancel_notif_id     VARCHAR(10),
    IN p_reschedule_notif_id VARCHAR(10)
)
BEGIN
    DECLARE v_type_id VARCHAR(10);
    DECLARE v_plan_id VARCHAR(10);
    DECLARE v_quorum  VARCHAR(3);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM HOD WHERE UserID = p_hod_user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Authorization Error: Only an HOD can cancel and reschedule a meeting for lack of quorum.';
    END IF;

    SET v_quorum = fn_is_quorum_reached(p_meeting_id);
    IF v_quorum = 'Yes' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Action Blocked: Meeting already satisfies >= 2/3 (66.67%) quorum and does not require no-quorum cancellation.';
    END IF;

    SELECT TypeID, PlanID
    INTO v_type_id, v_plan_id
    FROM Meeting
    WHERE MeetingId = p_meeting_id;

    START TRANSACTION;

    UPDATE Meeting
    SET Meeting_Status   = 'Cancelled',
        ActualDate       = NULL,
        RescheduleReason = p_reschedule_reason
    WHERE MeetingId = p_meeting_id;

    INSERT INTO Notification (NotificationID, Type, Sent_Date, MeetingId)
    VALUES (p_cancel_notif_id, 'Meeting Cancellation', CURDATE(), p_meeting_id);

    INSERT INTO Meeting (
        MeetingId, IsFixed, PlannedDate, ActualDate, StartTime, EndTime,
        Venue, Meeting_Status, RescheduleReason, TypeID, PlanID, UserID, Agenda_id
    ) VALUES (
        p_new_meeting_id, 'No', p_new_planned_date, NULL, p_new_start_time, p_new_end_time,
        p_new_venue, 'Scheduled', CONCAT('Rescheduled from ', p_meeting_id, ': ', p_reschedule_reason),
        v_type_id, v_plan_id, p_hod_user_id, NULL
    );

    INSERT INTO Attends (UserID, MeetingId, Att_Status)
    SELECT UserID, p_new_meeting_id, 'Invited'
    FROM Attends
    WHERE MeetingId = p_meeting_id;

    INSERT INTO Notification (NotificationID, Type, Sent_Date, MeetingId)
    VALUES (p_reschedule_notif_id, 'Reschedule Alert', CURDATE(), p_new_meeting_id);

    COMMIT;
END$$
DELIMITER ;

-- ============================================================================
-- 10. STORED PROCEDURE: sp_record_decision_with_media
--     Logs an atomized post-meeting decision with Responsible Officer,
--     TaskDeadline, TaskStatus, and primary Media_Links entry.
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_record_decision_with_media(
    IN p_meeting_rec_id      VARCHAR(10),
    IN p_meeting_id          VARCHAR(10),
    IN p_decision_text       TEXT,
    IN p_record_type         VARCHAR(30),
    IN p_upload_date         DATE,
    IN p_responsible_user_id VARCHAR(10),
    IN p_task_deadline       DATE,
    IN p_task_status         VARCHAR(20),
    IN p_primary_media_link  VARCHAR(500)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO MediaRecord (
        MeetingRecID, DecisionText, RecordType, UploadDate,
        MeetingId, ResponsibleUserID, TaskDeadline, TaskStatus
    ) VALUES (
        p_meeting_rec_id, p_decision_text, p_record_type, p_upload_date,
        p_meeting_id, p_responsible_user_id, p_task_deadline, p_task_status
    );

    IF p_primary_media_link IS NOT NULL AND CHAR_LENGTH(TRIM(p_primary_media_link)) > 0 THEN
        INSERT INTO Media_Links (MeetingRecID, MediaLinks)
        VALUES (p_meeting_rec_id, p_primary_media_link);
    END IF;

    COMMIT;
END$$
DELIMITER ;

-- ============================================================================
-- 11. STORED PROCEDURE: sp_search_decisions
--     Role-Safe Global Decision Search for the DataVerse GUI Search Bar.
-- ============================================================================
DELIMITER $$
CREATE PROCEDURE sp_search_decisions(
    IN p_requester_user_id VARCHAR(10),
    IN p_keyword           VARCHAR(100),
    IN p_short_name        VARCHAR(15),
    IN p_from_date         DATE,
    IN p_to_date           DATE
)
BEGIN
    DECLARE v_can_view_private INT DEFAULT 0;
    DECLARE v_is_student_coord INT DEFAULT 0;
    DECLARE v_is_support_staff INT DEFAULT 0;
    DECLARE v_pattern          VARCHAR(120) DEFAULT '%';

    IF p_keyword IS NOT NULL AND CHAR_LENGTH(TRIM(p_keyword)) > 0 THEN
        SET v_pattern = CONCAT('%', TRIM(p_keyword), '%');
    END IF;

    IF EXISTS (SELECT 1 FROM HOD WHERE UserID = p_requester_user_id)
       OR EXISTS (SELECT 1 FROM AcademicStaff WHERE UserID = p_requester_user_id) THEN
        SET v_can_view_private = 1;
    END IF;

    IF EXISTS (SELECT 1 FROM StudentCoordinator WHERE UserID = p_requester_user_id) THEN
        SET v_is_student_coord = 1;
    END IF;

    IF EXISTS (SELECT 1 FROM SupportStaff WHERE UserID = p_requester_user_id) THEN
        SET v_is_support_staff = 1;
    END IF;

    SELECT
        d.MeetingRecID,
        d.MeetingId,
        d.AcademicYear,
        d.ShortName,
        d.MeetingTypeName,
        d.CategoryGroup,
        d.CalendarColorHex,
        d.MeetingDate,
        d.RecordType,
        d.DecisionText,
        d.ResponsibleOfficerName,
        d.TaskDeadline,
        d.TaskStatus,
        d.AttachedMediaLinks
    FROM vw_searchable_decisions_archive d
    WHERE (v_can_view_private = 1 OR d.IsPrivate = 'No')
      AND (v_is_student_coord = 0 OR d.ShortName IN ('SC', 'CP'))
      AND (v_is_support_staff = 0 OR d.ShortName IN ('DM', 'SW'))
      AND d.DecisionText LIKE v_pattern
      AND (p_short_name IS NULL OR p_short_name = '' OR d.ShortName = p_short_name)
      AND (p_from_date IS NULL OR d.MeetingDate >= p_from_date)
      AND (p_to_date IS NULL OR d.MeetingDate <= p_to_date)
    ORDER BY d.MeetingDate DESC, d.MeetingRecID ASC;
END$$
DELIMITER ;
