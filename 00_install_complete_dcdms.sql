-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Script       : 00_install_complete_dcdms.sql
-- Purpose      : Master all-in-one installer (Database + 15 Normalized 3NF
--                Tables + 14 Triggers + >10 Rows per Table Sample Dataset +
--                16 RBAC/GUI Views + 11 Functions/Procedures + Verification
--                Test Suite).
-- Target DBMS  : MySQL Server 8.0 / 8.4 (Zero-Warning MySQL Workbench Ready)
-- ============================================================================



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- BEGIN MODULE: 01_create_database.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Project      : Department Communication Database Management System (DCDMS)
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Team         : DataVerse
-- Script       : 01_create_database.sql
-- Purpose      : Create and select the DCDMS MySQL database with UTF-8 Unicode
--                encoding suitable for MySQL Server 8.0 / 8.4 & MySQL Workbench.
-- ============================================================================

SET SESSION sql_notes = 0;
DROP DATABASE IF EXISTS dcdms_db;
SET SESSION sql_notes = 1;

CREATE DATABASE dcdms_db
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE dcdms_db;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- BEGIN MODULE: 02_create_tables.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Script       : 02_create_tables.sql
-- Purpose      : Physical implementation of all normalized (3NF) relations
--                aligned with NORMALIZATION - NEW.pdf, DEPARTMENT_MEETING_CALENDAR,
--                the updated EER Diagram, and DataVerse Web GUI requirements.
-- Target DBMS  : MySQL Server 8.0 / 8.4 (Zero-Warning MySQL Workbench Ready)
-- ============================================================================

USE dcdms_db;

-- Clean drop in reverse dependency order when re-running modularly
SET SESSION sql_notes = 0;
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Attends;
DROP TABLE IF EXISTS Notification;
DROP TABLE IF EXISTS Media_Links;
DROP TABLE IF EXISTS MediaRecord;
DROP TABLE IF EXISTS MeetingConfirmation;
DROP TABLE IF EXISTS Meeting;
DROP TABLE IF EXISTS Agenda;
DROP TABLE IF EXISTS YearPlan;
DROP TABLE IF EXISTS MeetingType;
DROP TABLE IF EXISTS StudentCoordinator;
DROP TABLE IF EXISTS SupportStaff;
DROP TABLE IF EXISTS Clerk;
DROP TABLE IF EXISTS AcademicStaff;
DROP TABLE IF EXISTS HOD;
DROP TABLE IF EXISTS `User`;
SET FOREIGN_KEY_CHECKS = 1;
SET SESSION sql_notes = 1;

-- ============================================================================
-- 0. MASTER IDENTITY REGISTRY: User
--    Supports global UserID & Email uniqueness for the DataVerse Web GUI Login
--    screen and enables genuine InnoDB Foreign Keys from Attends(UserID) and
--    MeetingConfirmation(UserID) across all 5 ISA role relations.
-- ============================================================================
CREATE TABLE `User` (
    UserID      VARCHAR(10)  NOT NULL,
    Name        VARCHAR(100) NOT NULL,
    Email       VARCHAR(150) NOT NULL,
    Password    VARCHAR(255) NOT NULL,
    RoleType    VARCHAR(30)  NOT NULL,

    PRIMARY KEY (UserID),
    CONSTRAINT uq_user_email UNIQUE (Email),
    CONSTRAINT chk_user_name_nonempty CHECK (CHAR_LENGTH(TRIM(Name)) > 0),
    CONSTRAINT chk_user_email_format CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT chk_user_password_len CHECK (CHAR_LENGTH(Password) >= 6),
    CONSTRAINT chk_user_role_type CHECK (
        RoleType IN ('HOD', 'AcademicStaff', 'Clerk', 'SupportStaff', 'StudentCoordinator')
    ),
    INDEX idx_user_role (RoleType)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 1. HOD Relation (NORMALIZATION - NEW.pdf Relation 1)
--    HOD (UserID, Name, Email, Password) - Full administrative & scheduling rights.
-- ============================================================================
CREATE TABLE HOD (
    UserID      VARCHAR(10)  NOT NULL,
    Name        VARCHAR(100) NOT NULL,
    Email       VARCHAR(150) NOT NULL,
    Password    VARCHAR(255) NOT NULL,

    PRIMARY KEY (UserID),
    CONSTRAINT uq_hod_email UNIQUE (Email),
    CONSTRAINT fk_hod_user FOREIGN KEY (UserID)
        REFERENCES `User` (UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_hod_email_format CHECK (Email LIKE '%_@_%._%')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 2. AcademicStaff Relation (NORMALIZATION - NEW.pdf Relation 2)
--    AcademicStaff (UserID, Name, Email, Password) - Permanent lecturers with
--    access to academic meetings and confidential Scrutiny Board records.
-- ============================================================================
CREATE TABLE AcademicStaff (
    UserID      VARCHAR(10)  NOT NULL,
    Name        VARCHAR(100) NOT NULL,
    Email       VARCHAR(150) NOT NULL,
    Password    VARCHAR(255) NOT NULL,

    PRIMARY KEY (UserID),
    CONSTRAINT uq_academic_email UNIQUE (Email),
    CONSTRAINT fk_academic_staff_user FOREIGN KEY (UserID)
        REFERENCES `User` (UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_academic_email_format CHECK (Email LIKE '%_@_%._%')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 3. Clerk Relation (NORMALIZATION - NEW.pdf Relation 3)
--    Clerk (UserID, Name, Email, Password) - System convener responsible for
--    data entry and uploads, strictly excluded from Scrutiny Board meetings.
-- ============================================================================
CREATE TABLE Clerk (
    UserID      VARCHAR(10)  NOT NULL,
    Name        VARCHAR(100) NOT NULL,
    Email       VARCHAR(150) NOT NULL,
    Password    VARCHAR(255) NOT NULL,

    PRIMARY KEY (UserID),
    CONSTRAINT uq_clerk_email UNIQUE (Email),
    CONSTRAINT fk_clerk_user FOREIGN KEY (UserID)
        REFERENCES `User` (UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_clerk_email_format CHECK (Email LIKE '%_@_%._%')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 4. SupportStaff Relation (NORMALIZATION - NEW.pdf Relation 4)
--    SupportStaff (UserID, Name, Email, Password) - Technical, lab & support
--    staff with access to general meetings and staff/technical workshops.
-- ============================================================================
CREATE TABLE SupportStaff (
    UserID      VARCHAR(10)  NOT NULL,
    Name        VARCHAR(100) NOT NULL,
    Email       VARCHAR(150) NOT NULL,
    Password    VARCHAR(255) NOT NULL,

    PRIMARY KEY (UserID),
    CONSTRAINT uq_support_email UNIQUE (Email),
    CONSTRAINT fk_support_staff_user FOREIGN KEY (UserID)
        REFERENCES `User` (UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_support_email_format CHECK (Email LIKE '%_@_%._%')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 5. StudentCoordinator Relation (NORMALIZATION - NEW.pdf Relation 5)
--    StudentCoordinator (UserID, Name, Email, Password) - Restricted to Student
--    Coordinator ('SC') and Conference/Project Carnival ('CP') sessions.
-- ============================================================================
CREATE TABLE StudentCoordinator (
    UserID      VARCHAR(10)  NOT NULL,
    Name        VARCHAR(100) NOT NULL,
    Email       VARCHAR(150) NOT NULL,
    Password    VARCHAR(255) NOT NULL,

    PRIMARY KEY (UserID),
    CONSTRAINT uq_student_coord_email UNIQUE (Email),
    CONSTRAINT fk_student_coordinator_user FOREIGN KEY (UserID)
        REFERENCES `User` (UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_student_coord_email_format CHECK (Email LIKE '%_@_%._%')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 6. MeetingType Relation (NORMALIZATION - NEW.pdf Relation 8)
--    Core 3NF attributes: (TypeID, Name, ShortName, IsPrivate, TargetFrequency)
--    GUI Calendar & Classification attributes (dependent solely on TypeID):
--    (CategoryGroup, FrequencyLabel, Semester01, Semester02, ScheduledMonths,
--     CalendarColorHex) matching DEPARTMENT_MEETING_CALENDAR.XLSX.
-- ============================================================================
CREATE TABLE MeetingType (
    TypeID           VARCHAR(10)  NOT NULL,
    Name             VARCHAR(120) NOT NULL,
    ShortName        VARCHAR(15)  NOT NULL,
    IsPrivate        VARCHAR(5)   NOT NULL DEFAULT 'No',
    TargetFrequency  INT          NOT NULL,
    CategoryGroup    VARCHAR(30)  NOT NULL DEFAULT 'Academic',
    FrequencyLabel   VARCHAR(80)  NOT NULL,
    Semester01       CHAR(1)      NOT NULL DEFAULT 'Y',
    Semester02       CHAR(1)      NOT NULL DEFAULT 'Y',
    ScheduledMonths  VARCHAR(60)  NOT NULL,
    CalendarColorHex CHAR(7)      NOT NULL DEFAULT '#3B82F6',

    PRIMARY KEY (TypeID),
    CONSTRAINT uq_meeting_type_name UNIQUE (Name),
    CONSTRAINT chk_meeting_type_isprivate CHECK (IsPrivate IN ('Yes', 'No')),
    CONSTRAINT chk_meeting_type_freq CHECK (TargetFrequency > 0),
    CONSTRAINT chk_meeting_type_category CHECK (
        CategoryGroup IN ('Academic', 'Administrative', 'External/Industry', 'Student-Centric')
    ),
    CONSTRAINT chk_meeting_type_sem1 CHECK (Semester01 IN ('Y', 'N')),
    CONSTRAINT chk_meeting_type_sem2 CHECK (Semester02 IN ('Y', 'N')),
    CONSTRAINT chk_meeting_type_color CHECK (CalendarColorHex LIKE '#______'),
    INDEX idx_meeting_type_category (CategoryGroup),
    INDEX idx_meeting_type_shortname (ShortName)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 7. YearPlan Relation (NORMALIZATION - NEW.pdf Relation 15)
--    YearPlan (PlanID, AcademicYear, PlanLink) - Annual high-level planner
--    storing the academic year and exported/uploaded PDF plan document link.
-- ============================================================================
CREATE TABLE YearPlan (
    PlanID       VARCHAR(10)  NOT NULL,
    AcademicYear INT          NOT NULL,
    PlanLink     VARCHAR(500) NOT NULL,

    PRIMARY KEY (PlanID),
    CONSTRAINT uq_year_plan_year UNIQUE (AcademicYear),
    CONSTRAINT chk_year_plan_range CHECK (AcademicYear BETWEEN 2000 AND 2100),
    CONSTRAINT chk_year_plan_link CHECK (CHAR_LENGTH(TRIM(PlanLink)) >= 5)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 8. Agenda Relation (NORMALIZATION - NEW.pdf Relation 12)
--    Agenda (Agenda_id, Name, Upload_Date, AgendaFileLink) - Enforces >= 3-day
--    pre-meeting upload rule and supports Google Drive cloud document links.
-- ============================================================================
CREATE TABLE Agenda (
    Agenda_id      VARCHAR(10)  NOT NULL,
    Name           VARCHAR(200) NOT NULL,
    Upload_Date    DATE         NOT NULL,
    AgendaFileLink VARCHAR(500) NULL DEFAULT NULL,

    PRIMARY KEY (Agenda_id),
    CONSTRAINT chk_agenda_name_nonempty CHECK (CHAR_LENGTH(TRIM(Name)) > 0),
    INDEX idx_agenda_upload_date (Upload_Date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 9. Meeting Relation (NORMALIZATION - NEW.pdf Relation 7)
--    Core 3NF attributes: (MeetingId, IsFixed, PlannedDate, ActualDate, TypeID,
--    PlanID, UserID, Agenda_id)
--    GUI Monthly Scheduler & Rescheduling attributes (dependent on MeetingId):
--    (StartTime, EndTime, Venue, Meeting_Status, RescheduleReason)
-- ============================================================================
CREATE TABLE Meeting (
    MeetingId        VARCHAR(10)  NOT NULL,
    IsFixed          VARCHAR(5)   NOT NULL DEFAULT 'No',
    PlannedDate      DATE         NOT NULL,
    ActualDate       DATE         NULL DEFAULT NULL,
    StartTime        TIME         NOT NULL DEFAULT '09:00:00',
    EndTime          TIME         NOT NULL DEFAULT '10:30:00',
    Venue            VARCHAR(100) NOT NULL DEFAULT 'Department Boardroom',
    Meeting_Status   VARCHAR(20)  NOT NULL DEFAULT 'Scheduled',
    RescheduleReason VARCHAR(255) NULL DEFAULT NULL,
    TypeID           VARCHAR(10)  NOT NULL,
    PlanID           VARCHAR(10)  NULL DEFAULT NULL,
    UserID           VARCHAR(10)  NOT NULL,
    Agenda_id        VARCHAR(10)  NULL DEFAULT NULL,

    PRIMARY KEY (MeetingId),
    CONSTRAINT uq_meeting_agenda UNIQUE (Agenda_id),

    CONSTRAINT fk_meeting_type FOREIGN KEY (TypeID)
        REFERENCES MeetingType (TypeID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_meeting_yearplan FOREIGN KEY (PlanID)
        REFERENCES YearPlan (PlanID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    CONSTRAINT fk_meeting_hod FOREIGN KEY (UserID)
        REFERENCES HOD (UserID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_meeting_agenda FOREIGN KEY (Agenda_id)
        REFERENCES Agenda (Agenda_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT chk_meeting_isfixed CHECK (IsFixed IN ('Yes', 'No')),
    CONSTRAINT chk_meeting_time_order CHECK (EndTime > StartTime),
    CONSTRAINT chk_meeting_venue_nonempty CHECK (CHAR_LENGTH(TRIM(Venue)) > 0),
    CONSTRAINT chk_meeting_status CHECK (
        Meeting_Status IN ('Planned', 'Scheduled', 'Completed', 'Postponed', 'Cancelled')
    ),
    CONSTRAINT chk_meeting_status_actualdate CHECK (
        (Meeting_Status = 'Completed' AND ActualDate IS NOT NULL)
        OR (Meeting_Status IN ('Planned', 'Scheduled', 'Postponed', 'Cancelled') AND ActualDate IS NULL)
    ),

    INDEX idx_meeting_planned_date (PlannedDate),
    INDEX idx_meeting_venue_slot (PlannedDate, Venue, StartTime, EndTime),
    INDEX idx_meeting_type_status_date (TypeID, Meeting_Status, PlannedDate),
    INDEX idx_meeting_plan_status (PlanID, Meeting_Status),
    INDEX idx_meeting_hod (UserID)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 10. MeetingConfirmation Relation (NORMALIZATION - NEW.pdf Relation 9)
--     MeetingConfirmation (ConfirmationID, Confirmation_Status, ResponseDate,
--     UserID, MeetingId) with Composite UNIQUE (UserID, MeetingId).
-- ============================================================================
CREATE TABLE MeetingConfirmation (
    ConfirmationID      VARCHAR(10) NOT NULL,
    Confirmation_Status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    ResponseDate        DATE        NULL DEFAULT NULL,
    UserID              VARCHAR(10) NOT NULL,
    MeetingId           VARCHAR(10) NOT NULL,

    PRIMARY KEY (ConfirmationID),
    CONSTRAINT uq_confirmation_user_meeting UNIQUE (UserID, MeetingId),

    CONSTRAINT fk_confirmation_user FOREIGN KEY (UserID)
        REFERENCES `User` (UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_confirmation_meeting FOREIGN KEY (MeetingId)
        REFERENCES Meeting (MeetingId)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT chk_confirmation_status CHECK (
        Confirmation_Status IN ('Pending', 'Confirmed', 'Declined', 'Acknowledged')
    ),
    CONSTRAINT chk_confirmation_response_date CHECK (
        (Confirmation_Status = 'Pending' AND ResponseDate IS NULL)
        OR (Confirmation_Status IN ('Confirmed', 'Declined', 'Acknowledged') AND ResponseDate IS NOT NULL)
    ),

    INDEX idx_confirmation_meeting_status (MeetingId, Confirmation_Status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 11. MediaRecord Relation (NORMALIZATION - NEW.pdf Relation 10)
--     Core 3NF attributes: (MeetingRecID, DecisionText, RecordType, UploadDate,
--     MeetingId) + GUI Action-Item Tracking attributes: (ResponsibleUserID,
--     TaskDeadline, TaskStatus) so atomized decisions link to action owners.
-- ============================================================================
CREATE TABLE MediaRecord (
    MeetingRecID      VARCHAR(10) NOT NULL,
    DecisionText      TEXT        NOT NULL,
    RecordType        VARCHAR(30) NOT NULL,
    UploadDate        DATE        NOT NULL,
    MeetingId         VARCHAR(10) NOT NULL,
    ResponsibleUserID VARCHAR(10) NULL DEFAULT NULL,
    TaskDeadline      DATE        NULL DEFAULT NULL,
    TaskStatus        VARCHAR(20) NOT NULL DEFAULT 'Completed',

    PRIMARY KEY (MeetingRecID),

    CONSTRAINT fk_media_record_meeting FOREIGN KEY (MeetingId)
        REFERENCES Meeting (MeetingId)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_media_record_responsible_user FOREIGN KEY (ResponsibleUserID)
        REFERENCES `User` (UserID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT chk_media_record_type CHECK (
        RecordType IN (
            '.pdf', '.mp3', '.mp4', '.docx',
            'Decision', 'Minutes', 'Audio', 'Video', 'Minutes & Audio', 'Minutes & Video'
        )
    ),
    CONSTRAINT chk_media_decision_nonempty CHECK (CHAR_LENGTH(TRIM(DecisionText)) > 0),
    CONSTRAINT chk_media_task_status CHECK (
        TaskStatus IN ('Pending', 'In Progress', 'Completed', 'Not Applicable')
    ),

    INDEX idx_mediarecord_meeting_date (MeetingId, UploadDate),
    INDEX idx_mediarecord_task_status (TaskStatus, TaskDeadline),
    INDEX idx_mediarecord_responsible (ResponsibleUserID),
    FULLTEXT INDEX ft_mediarecord_decision (DecisionText)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 12. Media_Links Relation (NORMALIZATION - NEW.pdf Relation 11)
--     Media_Links (MeetingRecID, MediaLinks) - Composite PK resolving the
--     multivalued {Media_Links} attribute into 1NF, 2NF, and 3NF.
-- ============================================================================
CREATE TABLE Media_Links (
    MeetingRecID VARCHAR(10)  NOT NULL,
    MediaLinks   VARCHAR(500) NOT NULL,

    PRIMARY KEY (MeetingRecID, MediaLinks),

    CONSTRAINT fk_media_links_record FOREIGN KEY (MeetingRecID)
        REFERENCES MediaRecord (MeetingRecID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT chk_media_links_nonempty CHECK (CHAR_LENGTH(TRIM(MediaLinks)) >= 5)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 13. Notification Relation (NORMALIZATION - NEW.pdf Relation 13)
--     Notification (NotificationID, Type, Sent_Date, MeetingId) - Automated
--     3-day Dashboard & Gmail alerts, invitations, reminders, and cancellations.
-- ============================================================================
CREATE TABLE Notification (
    NotificationID VARCHAR(10) NOT NULL,
    Type           VARCHAR(40) NOT NULL,
    Sent_Date      DATE        NOT NULL,
    MeetingId      VARCHAR(10) NOT NULL,

    PRIMARY KEY (NotificationID),

    CONSTRAINT fk_notification_meeting FOREIGN KEY (MeetingId)
        REFERENCES Meeting (MeetingId)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT chk_notification_type CHECK (
        Type IN (
            'Meeting Invitation',
            'Meeting Reminder',
            'Meeting Cancellation',
            'Dashboard Alert',
            'Gmail Alert',
            'Dashboard & Gmail Alert',
            'Agenda Uploaded Alert',
            'Reschedule Alert'
        )
    ),

    INDEX idx_notification_meeting_sent (MeetingId, Sent_Date),
    INDEX idx_notification_type_sent (Type, Sent_Date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 14. Attends Relation (NORMALIZATION - NEW.pdf Relation 14)
--     Attends (UserID, MeetingId, Att_Status) - Composite PK resolving M:N
--     Attendance relationship; drives digital check-in & 2/3 quorum check.
-- ============================================================================
CREATE TABLE Attends (
    UserID      VARCHAR(10) NOT NULL,
    MeetingId   VARCHAR(10) NOT NULL,
    Att_Status  VARCHAR(20) NOT NULL DEFAULT 'Invited',

    PRIMARY KEY (UserID, MeetingId),

    CONSTRAINT fk_attends_user FOREIGN KEY (UserID)
        REFERENCES `User` (UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_attends_meeting FOREIGN KEY (MeetingId)
        REFERENCES Meeting (MeetingId)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT chk_attends_status CHECK (
        Att_Status IN ('Invited', 'Present', 'Absent', 'Excused')
    ),

    INDEX idx_attends_meeting_status (MeetingId, Att_Status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- BEGIN MODULE: 06_triggers.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- BEGIN MODULE: 03_insert_sample_data.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Script       : 03_insert_sample_data.sql
-- Purpose      : Populates EVERY SINGLE TABLE (all 15 relations) with > 10
--                realistic synthetic departmental records aligned with
--                NORMALIZATION - NEW.pdf, DEPARTMENT_MEETING_CALENDAR.XLSX,
--                and DataVerse Web GUI workflows.
-- Privacy Note : All names, emails, SHA-256 password hashes, and cloud URLs
--                are 100% synthetic academic test data.
-- ============================================================================

USE dcdms_db;

-- ============================================================================
-- 1. MASTER USER REGISTRY (64 Synthetic Department Users across 5 ISA Roles)
--    * U001 - U012 : HOD (12 records - current & historical/acting heads)
--    * U013 - U028 : AcademicStaff (16 records - permanent lecturers)
--    * U029 - U040 : Clerk (12 records - system conveners / office staff)
--    * U041 - U052 : SupportStaff (12 records - technical & lab officers)
--    * U053 - U064 : StudentCoordinator (12 records - batch representatives)
-- ============================================================================
INSERT INTO `User` (UserID, Name, Email, Password, RoleType) VALUES
-- HODs (12)
('U001', 'Dr. Tharindu Wijekoon',       'tharindu@computing.rjt.ac.lk',      SHA2('Hod@Rjt2026#01', 256), 'HOD'),
('U002', 'Prof. Sanjeewa Kulathilake',  'sanjeewa.k@computing.rjt.ac.lk',    SHA2('Hod@Rjt2025#02', 256), 'HOD'),
('U003', 'Dr. Nalin Samaraweera',       'nalin.s@computing.rjt.ac.lk',       SHA2('Hod@Rjt2024#03', 256), 'HOD'),
('U004', 'Dr. Priyantha Senanayake',    'priyantha.s@computing.rjt.ac.lk',   SHA2('Hod@Rjt2023#04', 256), 'HOD'),
('U005', 'Prof. Anoja Herath',          'anoja.h@computing.rjt.ac.lk',       SHA2('Hod@Rjt2022#05', 256), 'HOD'),
('U006', 'Dr. Nishantha Liyanage',      'nishantha.l@computing.rjt.ac.lk',   SHA2('Hod@Rjt2021#06', 256), 'HOD'),
('U007', 'Dr. Sujeewa Rathnayake',      'sujeewa.r@computing.rjt.ac.lk',     SHA2('Hod@Rjt2020#07', 256), 'HOD'),
('U008', 'Dr. Chaminda Subasinghe',     'chaminda.s@computing.rjt.ac.lk',    SHA2('Hod@Rjt2019#08', 256), 'HOD'),
('U009', 'Dr. Saman Bandara',           'saman.b@computing.rjt.ac.lk',       SHA2('Hod@Rjt2018#09', 256), 'HOD'),
('U010', 'Dr. Chathura De Silva',       'chathura.ds@computing.rjt.ac.lk',   SHA2('Hod@Rjt2017#10', 256), 'HOD'),
('U011', 'Dr. Damith Dissanayake',      'damith.d@computing.rjt.ac.lk',      SHA2('Hod@Rjt2016#11', 256), 'HOD'),
('U012', 'Dr. Gayan Hettiarachchi',     'gayan.h@computing.rjt.ac.lk',       SHA2('Hod@Rjt2015#12', 256), 'HOD'),

-- AcademicStaff (16)
('U013', 'Mr. Isuru Madushanka',        'isuru@computing.rjt.ac.lk',         SHA2('Acad@Rjt2026#13', 256), 'AcademicStaff'),
('U014', 'Ms. Sachini Dilhara',         'sachini@computing.rjt.ac.lk',       SHA2('Acad@Rjt2026#14', 256), 'AcademicStaff'),
('U015', 'Dr. Nethmi Jayawardena',      'nethmi@computing.rjt.ac.lk',        SHA2('Acad@Rjt2026#15', 256), 'AcademicStaff'),
('U016', 'Dr. Harsha Fernando',         'harsha.f@computing.rjt.ac.lk',      SHA2('Acad@Rjt2026#16', 256), 'AcademicStaff'),
('U017', 'Dr. Nadeeshapathirana Perera','nadeesha.p@computing.rjt.ac.lk',    SHA2('Acad@Rjt2026#17', 256), 'AcademicStaff'),
('U018', 'Mr. Prabath Pathirana',       'prabath.p@computing.rjt.ac.lk',     SHA2('Acad@Rjt2026#18', 256), 'AcademicStaff'),
('U019', 'Dr. Amali Karunarathna',      'amali.k@computing.rjt.ac.lk',       SHA2('Acad@Rjt2026#19', 256), 'AcademicStaff'),
('U020', 'Mr. Nuwan Wanniarachchi',     'nuwan.w@computing.rjt.ac.lk',       SHA2('Acad@Rjt2026#20', 256), 'AcademicStaff'),
('U021', 'Dr. Sanduni Samarasinghe',    'sanduni.s@computing.rjt.ac.lk',     SHA2('Acad@Rjt2026#21', 256), 'AcademicStaff'),
('U022', 'Mr. Chinthaka Somarathna',    'chinthaka.s@computing.rjt.ac.lk',   SHA2('Acad@Rjt2026#22', 256), 'AcademicStaff'),
('U023', 'Dr. Shyamali Balasooriya',    'shyamali.b@computing.rjt.ac.lk',    SHA2('Acad@Rjt2026#23', 256), 'AcademicStaff'),
('U024', 'Mr. Charith Dharmasena',      'charith.d@computing.rjt.ac.lk',     SHA2('Acad@Rjt2026#24', 256), 'AcademicStaff'),
('U025', 'Ms. Dulani Dayananda',        'dulani.d@computing.rjt.ac.lk',      SHA2('Acad@Rjt2026#25', 256), 'AcademicStaff'),
('U026', 'Mr. Geethanjana Herath',      'geeth.h@computing.rjt.ac.lk',       SHA2('Acad@Rjt2026#26', 256), 'AcademicStaff'),
('U027', 'Dr. Hiruni Fonseka',          'hiruni.f@computing.rjt.ac.lk',      SHA2('Acad@Rjt2026#27', 256), 'AcademicStaff'),
('U028', 'Mr. Kasun Rajapaksha',        'kasun.r@computing.rjt.ac.lk',       SHA2('Acad@Rjt2026#28', 256), 'AcademicStaff'),

-- Clerk (12)
('U029', 'Ms. Hasini Weerasinghe',      'hasini@computing.rjt.ac.lk',        SHA2('Clerk@Rjt2026#29', 256), 'Clerk'),
('U030', 'Ms. Duleeka Senavirathna',    'duleeka@computing.rjt.ac.lk',       SHA2('Clerk@Rjt2026#30', 256), 'Clerk'),
('U031', 'Mr. Pasindu Liyanage',        'pasindu@computing.rjt.ac.lk',       SHA2('Clerk@Rjt2026#31', 256), 'Clerk'),
('U032', 'Ms. Apsara Gunasekara',       'apsara.g@computing.rjt.ac.lk',      SHA2('Clerk@Rjt2026#32', 256), 'Clerk'),
('U033', 'Mr. Ruwan Jayasooriya',       'ruwan.j@computing.rjt.ac.lk',       SHA2('Clerk@Rjt2026#33', 256), 'Clerk'),
('U034', 'Ms. Madhavi Ekanayake',       'madhavi.e@computing.rjt.ac.lk',     SHA2('Clerk@Rjt2026#34', 256), 'Clerk'),
('U035', 'Mr. Janaka Alwis',            'janaka.a@computing.rjt.ac.lk',      SHA2('Clerk@Rjt2026#35', 256), 'Clerk'),
('U036', 'Ms. Nayomi Munasinghe',       'nayomi.m@computing.rjt.ac.lk',      SHA2('Clerk@Rjt2026#36', 256), 'Clerk'),
('U037', 'Mr. Suranga Peiris',          'suranga.p@computing.rjt.ac.lk',     SHA2('Clerk@Rjt2026#37', 256), 'Clerk'),
('U038', 'Ms. Gayani Kodithuwakku',     'gayani.k@computing.rjt.ac.lk',      SHA2('Clerk@Rjt2026#38', 256), 'Clerk'),
('U039', 'Mr. Lahiru Nanayakkara',      'lahiru.n@computing.rjt.ac.lk',      SHA2('Clerk@Rjt2026#39', 256), 'Clerk'),
('U040', 'Ms. Chathurika Gamage',       'chathurika.g@computing.rjt.ac.lk',  SHA2('Clerk@Rjt2026#40', 256), 'Clerk'),

-- SupportStaff (12)
('U041', 'Ms. Chamodi Wickramasinghe',  'chamodi@computing.rjt.ac.lk',       SHA2('Supp@Rjt2026#41', 256), 'SupportStaff'),
('U042', 'Mr. Kavindu Dissanayake',     'kavindu@computing.rjt.ac.lk',       SHA2('Supp@Rjt2026#42', 256), 'SupportStaff'),
('U043', 'Ms. Thilini Abeyrathna',      'thilini@computing.rjt.ac.lk',       SHA2('Supp@Rjt2026#43', 256), 'SupportStaff'),
('U044', 'Mr. Hemantha Kumara',         'hemantha.k@computing.rjt.ac.lk',    SHA2('Supp@Rjt2026#44', 256), 'SupportStaff'),
('U045', 'Mr. Chaminda Pushpakumara',   'chaminda.p@computing.rjt.ac.lk',    SHA2('Supp@Rjt2026#45', 256), 'SupportStaff'),
('U046', 'Ms. Dilrukshi Premarathna',   'dilrukshi.p@computing.rjt.ac.lk',   SHA2('Supp@Rjt2026#46', 256), 'SupportStaff'),
('U047', 'Mr. Asanka Tennakoon',        'asanka.t@computing.rjt.ac.lk',      SHA2('Supp@Rjt2026#47', 256), 'SupportStaff'),
('U048', 'Mr. Roshan Illangakoon',      'roshan.i@computing.rjt.ac.lk',      SHA2('Supp@Rjt2026#48', 256), 'SupportStaff'),
('U049', 'Ms. Menaka Amarasinghe',      'menaka.a@computing.rjt.ac.lk',      SHA2('Supp@Rjt2026#49', 256), 'SupportStaff'),
('U050', 'Mr. Dinesh Kularathna',       'dinesh.k@computing.rjt.ac.lk',      SHA2('Supp@Rjt2026#50', 256), 'SupportStaff'),
('U051', 'Ms. Shanika Rajakaruna',      'shanika.r@computing.rjt.ac.lk',     SHA2('Supp@Rjt2026#51', 256), 'SupportStaff'),
('U052', 'Mr. Buddhika Siriwardena',    'buddhika.s@computing.rjt.ac.lk',    SHA2('Supp@Rjt2026#52', 256), 'SupportStaff'),

-- StudentCoordinator (12)
('U053', 'Ms. Oshini Ranathunga',       'oshini@computing.rjt.ac.lk',        SHA2('Stud@Rjt2026#53', 256), 'StudentCoordinator'),
('U054', 'Mr. Thisal Bandaranayake',    'thisal@computing.rjt.ac.lk',        SHA2('Stud@Rjt2026#54', 256), 'StudentCoordinator'),
('U055', 'Ms. Senuri Wijesundara',      'senuri@computing.rjt.ac.lk',        SHA2('Stud@Rjt2026#55', 256), 'StudentCoordinator'),
('U056', 'Mr. Ravindu Jayalath',        'ravindu.j@computing.rjt.ac.lk',     SHA2('Stud@Rjt2026#56', 256), 'StudentCoordinator'),
('U057', 'Ms. Dinithi Gunawardena',     'dinithi.g@computing.rjt.ac.lk',     SHA2('Stud@Rjt2026#57', 256), 'StudentCoordinator'),
('U058', 'Mr. Nipun Seneviratne',       'nipun.s@computing.rjt.ac.lk',       SHA2('Stud@Rjt2026#58', 256), 'StudentCoordinator'),
('U059', 'Ms. Piumi Rathnayake',        'piumi.r@computing.rjt.ac.lk',       SHA2('Stud@Rjt2026#59', 256), 'StudentCoordinator'),
('U060', 'Mr. Akila Weerakoon',         'akila.w@computing.rjt.ac.lk',       SHA2('Stud@Rjt2026#60', 256), 'StudentCoordinator'),
('U061', 'Ms. Tharushi Wickrama',       'tharushi.w@computing.rjt.ac.lk',    SHA2('Stud@Rjt2026#61', 256), 'StudentCoordinator'),
('U062', 'Mr. Sahan Adikari',           'sahan.a@computing.rjt.ac.lk',       SHA2('Stud@Rjt2026#62', 256), 'StudentCoordinator'),
('U063', 'Ms. Ishara Madubhashini',     'ishara.m@computing.rjt.ac.lk',      SHA2('Stud@Rjt2026#63', 256), 'StudentCoordinator'),
('U064', 'Mr. Kalana Dharmarathna',     'kalana.d@computing.rjt.ac.lk',      SHA2('Stud@Rjt2026#64', 256), 'StudentCoordinator');

-- ============================================================================
-- 2. ISA SUBTYPE TABLES (NORMALIZATION - NEW.pdf Relations 1 to 5)
--    Each subtype table has > 10 records (12 to 16 rows) and inherits
--    (UserID, Name, Email, Password) directly from User.
-- ============================================================================
INSERT INTO HOD (UserID, Name, Email, Password)
SELECT UserID, Name, Email, Password FROM `User` WHERE RoleType = 'HOD';

INSERT INTO AcademicStaff (UserID, Name, Email, Password)
SELECT UserID, Name, Email, Password FROM `User` WHERE RoleType = 'AcademicStaff';

INSERT INTO Clerk (UserID, Name, Email, Password)
SELECT UserID, Name, Email, Password FROM `User` WHERE RoleType = 'Clerk';

INSERT INTO SupportStaff (UserID, Name, Email, Password)
SELECT UserID, Name, Email, Password FROM `User` WHERE RoleType = 'SupportStaff';

INSERT INTO StudentCoordinator (UserID, Name, Email, Password)
SELECT UserID, Name, Email, Password FROM `User` WHERE RoleType = 'StudentCoordinator';

-- ============================================================================
-- 3. MEETINGTYPE (14 Official Categories from DEPARTMENT_MEETING_CALENDAR.XLSX)
-- ============================================================================
INSERT INTO MeetingType (
    TypeID, Name, ShortName, IsPrivate, TargetFrequency,
    CategoryGroup, FrequencyLabel, Semester01, Semester02, ScheduledMonths, CalendarColorHex
) VALUES
('T001', 'Department Meeting',                                                 'DM',   'No',  10, 'Administrative',    'Monthly (Excl. Apr & Dec)',               'Y', 'Y', 'JAN,FEB,MAR,MAY,JUN,JUL,AUG,SEP,OCT,NOV',     '#EF4444'),
('T002', 'Curriculum Development Committee Meeting',                           'CD',   'No',  11, 'Academic',          'Monthly (Excl. Dec)',                     'Y', 'N', 'JAN,FEB,MAR,APR,MAY,JUN,JUL,AUG,SEP,OCT,NOV', '#FCA5A5'),
('T003', 'Industry Training and External Affairs',                             'IT',   'No',  10, 'External/Industry', 'Once in Two Months / Active Placement',   'Y', 'Y', 'JAN,FEB,MAR,MAY,JUN,JUL,AUG,SEP,OCT,NOV',     '#FACC15'),
('T004', 'Action Plan Meeting',                                                'AP',   'No',   6, 'Administrative',    'Once in Two Months',                      'Y', 'Y', 'FEB,APR,JUN,AUG,OCT,DEC',                     '#84CC16'),
('T005', 'Participation in Industry-Academic Gap Breaking Workshop - 1st Year','GB',   'No',   2, 'External/Industry', 'Biannual (Feb & Aug)',                    'Y', 'Y', 'FEB,AUG',                                     '#93C5FD'),
('T006', 'Mentor Meeting - 1st Year',                                          'MM',   'No',   3, 'Student-Centric',   'Semester 01 Monthly Induction (Jan-Mar)', 'Y', 'N', 'JAN,FEB,MAR',                                 '#818CF8'),
('T007', 'Industry Visits',                                                    'IV',   'No',   1, 'External/Industry', 'Annual Semester 02 Field Visit (Aug)',    'N', 'Y', 'AUG',                                         '#CA8A04'),
('T008', 'Staff Workshops',                                                    'SW',   'No',   4, 'Administrative',    'Biannual Intensive Blocks (Feb-Mar,Aug-Sep)', 'Y', 'Y', 'FEB,MAR,AUG,SEP',                         '#6B7280'),
('T009', 'Career Guidance Workshops',                                          'CG',   'No',   3, 'Student-Centric',   'Thrice Yearly (Mar, Jul, Aug)',           'Y', 'Y', 'MAR,JUL,AUG',                                 '#94A3B8'),
('T010', '2023 Project Evaluations',                                           'PE23', 'No',  10, 'Academic',          'Monthly Milestone Reviews (2023 Cohort)', 'Y', 'N', 'JAN,FEB,MAR,JUN,JUL,AUG,SEP,OCT,NOV,DEC',     '#FDE68A'),
('T011', '2022 Project Evaluations',                                           'PE22', 'No',  10, 'Academic',          'Monthly Milestone Reviews (2022 Cohort)', 'Y', 'Y', 'JAN,FEB,MAR,JUN,JUL,AUG,SEP,OCT,NOV,DEC',     '#F59E0B'),
('T012', 'Student Coordinator Meeting',                                        'SC',   'No',   4, 'Student-Centric',   'Quarterly (Mar, Jun, Sep, Dec)',          'Y', 'Y', 'MAR,JUN,SEP,DEC',                             '#C2410C'),
('T013', 'Conference and Project Carnival Meeting',                            'CP',   'No',   7, 'External/Industry', 'Carnival Planning Milestones (Annual)',   'Y', 'Y', 'JAN,APR,MAY,AUG,SEP,NOV,DEC',                 '#FB923C'),
('T014', 'Scrutiny Board Meeting',                                             'SB',   'Yes',  4, 'Academic',          'Pre-Semester Exam Moderation (Confidential)', 'Y', 'Y', 'MAR,APR,OCT,NOV',                         '#D946EF');

-- ============================================================================
-- 4. YEARPLAN (12 Annual Plans: P001 - P012 covering 2016 to 2027)
--    Matches NORMALIZATION - NEW.pdf Relation 15: (PlanID, AcademicYear, PlanLink)
-- ============================================================================
INSERT INTO YearPlan (PlanID, AcademicYear, PlanLink) VALUES
('P001', 2016, 'plan_2016.pdf'),
('P002', 2017, 'plan_2017.pdf'),
('P003', 2018, 'plan_2018.pdf'),
('P004', 2019, 'plan_2019.pdf'),
('P005', 2020, 'plan_2020.pdf'),
('P006', 2021, 'plan_2021.pdf'),
('P007', 2022, 'plan_2022.pdf'),
('P008', 2023, 'plan_2023.pdf'),
('P009', 2024, 'plan_2024.pdf'),
('P010', 2025, 'plan_2025.pdf'),
('P011', 2026, 'https://drive.google.com/file/d/1RJT_DoC_2026_AnnualPlan/view?usp=sharing'),
('P012', 2027, 'https://drive.google.com/file/d/1RJT_DoC_2027_DraftPlan/view?usp=sharing');

-- ============================================================================
-- 5. AGENDA (18 Pre-Meeting Agendas: A001 - A018, all uploaded >= 3 days prior)
-- ============================================================================
INSERT INTO Agenda (Agenda_id, Name, Upload_Date, AgendaFileLink) VALUES
('A001', '2024 Mid-Year Department Meeting Agenda',                       '2024-06-08', 'https://drive.google.com/file/d/1DoC_A001_DM_2024/view'),
('A002', '2025 Semester 01 Curriculum Revision Committee Agenda',         '2025-03-12', 'https://drive.google.com/file/d/1DoC_A002_CD_2025/view'),
('A003', '2025 Semester 02 Scrutiny Board Paper Moderation Agenda',       '2025-10-16', 'https://drive.google.com/file/d/1DoC_A003_SB_2025/view'),
('A004', 'January 2026 Opening Department Meeting Agenda',                '2026-01-10', 'https://drive.google.com/file/d/1DoC_A004_DM_Jan26/view'),
('A005', 'February 2026 Action Plan & KPI Review Agenda',                 '2026-02-06', 'https://drive.google.com/file/d/1DoC_A005_AP_Feb26/view'),
('A006', '2026 Industry-Academic Gap Breaking Workshop Agenda (1st Yr)',  '2026-02-18', 'https://drive.google.com/file/d/1DoC_A006_GB_Feb26/view'),
('A007', 'March 2026 1st-Year Student Mentor Review Agenda',              '2026-03-05', 'https://drive.google.com/file/d/1DoC_A007_MM_Mar26/view'),
('A008', 'March 2026 Career Guidance & CV Clinic Planning Agenda',        '2026-03-19', 'https://drive.google.com/file/d/1DoC_A008_CG_Mar26/view'),
('A009', 'April 2026 Semester 01 Scrutiny Board Moderation Agenda',       '2026-04-02', 'https://drive.google.com/file/d/1DoC_A009_SB_Apr26/view'),
('A010', 'May 2026 Industry Training & Internship Placement Agenda',      '2026-05-08', 'https://drive.google.com/file/d/1DoC_A010_IT_May26/view'),
('A011', 'June 2026 2023-Cohort Undergraduate Project Evaluation Agenda', '2026-06-12', 'https://drive.google.com/file/d/1DoC_A011_PE23_Jun26/view'),
('A012', 'August 2026 Colombo Tech Park Industry Visit Briefing Agenda',  '2026-08-14', 'https://drive.google.com/file/d/1DoC_A012_IV_Aug26/view'),
('A013', 'September 2026 Q3 Student Coordinator Feedback Agenda',         '2026-09-10', 'https://drive.google.com/file/d/1DoC_A013_SC_Sep26/view'),
('A014', 'September 2026 OBE Assessment Rubric Staff Workshop Agenda',    '2026-09-18', 'https://drive.google.com/file/d/1DoC_A014_SW_Sep26/view'),
('A015', 'October 2026 Rescheduled OBE Staff Workshop Agenda',            '2026-10-09', 'https://drive.google.com/file/d/1DoC_A015_SW_Oct26/view'),
('A016', 'October 2026 Computing Research Conference & Carnival Agenda',  '2026-10-16', 'https://drive.google.com/file/d/1DoC_A016_CP_Oct26/view'),
('A017', 'October 2026 Monthly Department Progress & Budget Agenda',      '2026-10-25', 'https://drive.google.com/file/d/1DoC_A017_DM_Oct26/view'),
('A018', 'November 2026 AI & Cloud Track Curriculum Revision Agenda',     '2026-10-27', 'https://drive.google.com/file/d/1DoC_A018_CD_Nov26/view');

-- ============================================================================
-- 6. MEETING (24 Meetings: M001 - M024 across 2024, 2025, and all 14 2026 Types)
--    Note: Completed meetings are inserted as 'Scheduled' first, then transitioned
--    to 'Completed' AFTER Attends rows are loaded so trg_meeting_bu_business_rules
--    actively validates >= 2/3 (66.67%) Quorum on every single completed meeting!
--    Notice M018 (09:00-10:30 Boardroom) and M019 (13:30-15:30 Main Computing Lab)
--    run on the SAME date (2026-11-05) without venue conflict (GUI multi-meeting).
-- ============================================================================
INSERT INTO Meeting (
    MeetingId, IsFixed, PlannedDate, ActualDate, StartTime, EndTime,
    Venue, Meeting_Status, RescheduleReason, TypeID, PlanID, UserID, Agenda_id
) VALUES
-- Historical 2024 & 2025 archive meetings (for multi-year Decision Search)
('M001', 'Yes', '2024-06-14', NULL, '09:00:00', '11:00:00', 'Department Boardroom',    'Scheduled', NULL,                                                              'T001', 'P009', 'U003', 'A001'),
('M002', 'No',  '2025-03-18', NULL, '10:00:00', '12:00:00', 'Department Boardroom',    'Scheduled', NULL,                                                              'T002', 'P010', 'U002', 'A002'),
('M003', 'Yes', '2025-10-22', NULL, '09:00:00', '11:30:00', 'HOD Confidential Room',   'Scheduled', NULL,                                                              'T014', 'P010', 'U002', 'A003'),

-- 2026 Completed Departmental Meetings (M004 - M013, plus M015 & M016)
('M004', 'Yes', '2026-01-15', NULL, '09:00:00', '11:00:00', 'Department Boardroom',    'Scheduled', NULL,                                                              'T001', 'P011', 'U001', 'A004'),
('M005', 'No',  '2026-02-12', NULL, '09:30:00', '11:30:00', 'Department Boardroom',    'Scheduled', NULL,                                                              'T004', 'P011', 'U001', 'A005'),
('M006', 'Yes', '2026-02-24', NULL, '13:30:00', '16:00:00', 'Smart Lecture Hall 01',   'Scheduled', NULL,                                                              'T005', 'P011', 'U001', 'A006'),
('M007', 'No',  '2026-03-11', NULL, '10:00:00', '11:30:00', 'Smart Lecture Hall 02',   'Scheduled', NULL,                                                              'T006', 'P011', 'U001', 'A007'),
('M008', 'No',  '2026-03-25', NULL, '13:30:00', '15:30:00', 'Main Computing Lab',      'Scheduled', NULL,                                                              'T009', 'P011', 'U001', 'A008'),
('M009', 'Yes', '2026-04-08', NULL, '09:00:00', '11:30:00', 'HOD Confidential Room',   'Scheduled', NULL,                                                              'T014', 'P011', 'U001', 'A009'),
('M010', 'No',  '2026-05-14', NULL, '10:00:00', '12:00:00', 'Department Boardroom',    'Scheduled', NULL,                                                              'T003', 'P011', 'U001', 'A010'),
('M011', 'Yes', '2026-06-18', NULL, '09:00:00', '12:30:00', 'Main Computing Lab',      'Scheduled', NULL,                                                              'T010', 'P011', 'U001', 'A011'),
('M012', 'Yes', '2026-08-19', NULL, '08:00:00', '16:30:00', 'Colombo Tech Park Site',  'Scheduled', NULL,                                                              'T007', 'P011', 'U001', 'A012'),
('M013', 'Yes', '2026-09-16', NULL, '14:00:00', '15:30:00', 'Smart Lecture Hall 01',   'Scheduled', NULL,                                                              'T012', 'P011', 'U001', 'A013'),

-- M014 Cancelled due to Lack of 2/3 Quorum, followed by Rescheduled M015
('M014', 'No',  '2026-09-24', NULL, '13:30:00', '15:30:00', 'Main Computing Lab',      'Cancelled', 'Cancelled by HOD: Present attendance (37.5%) fell below 2/3 quorum.', 'T008', 'P011', 'U001', 'A014'),
('M015', 'No',  '2026-10-15', NULL, '13:30:00', '15:30:00', 'Main Computing Lab',      'Scheduled', 'Rescheduled session replacing M014 after quorum shortfall.',       'T008', 'P011', 'U001', 'A015'),
('M016', 'Yes', '2026-10-22', NULL, '14:00:00', '16:00:00', 'Smart Lecture Hall 01',   'Scheduled', NULL,                                                              'T013', 'P011', 'U001', 'A016'),

-- Upcoming Late-Oct, Nov & Dec 2026 Meetings (relative to 2026-10-28)
('M017', 'Yes', '2026-10-31', NULL, '09:00:00', '11:00:00', 'Department Boardroom',    'Scheduled', NULL,                                                              'T001', 'P011', 'U001', 'A017'),
('M018', 'No',  '2026-11-05', NULL, '09:00:00', '10:30:00', 'Department Boardroom',    'Scheduled', NULL,                                                              'T002', 'P011', 'U001', 'A018'),
('M019', 'Yes', '2026-11-05', NULL, '13:30:00', '16:00:00', 'Main Computing Lab',      'Scheduled', NULL,                                                              'T011', 'P011', 'U001', NULL),
('M020', 'Yes', '2026-11-12', NULL, '09:00:00', '11:30:00', 'HOD Confidential Room',   'Scheduled', NULL,                                                              'T014', 'P011', 'U001', NULL),
('M021', 'Yes', '2026-11-18', NULL, '09:00:00', '12:30:00', 'Main Computing Lab',      'Planned',   NULL,                                                              'T010', 'P011', 'U001', NULL),
('M022', 'No',  '2026-11-25', NULL, '10:00:00', '12:00:00', 'Department Boardroom',    'Postponed', 'Postponed due to Faculty Board overlap; awaiting new Nov/Dec slot.', 'T011', 'P011', 'U001', NULL),
('M023', 'Yes', '2026-12-09', NULL, '14:00:00', '15:30:00', 'Smart Lecture Hall 01',   'Planned',   NULL,                                                              'T012', 'P011', 'U001', NULL),
('M024', 'No',  '2026-12-16', NULL, '09:30:00', '11:30:00', 'Department Boardroom',    'Planned',   NULL,                                                              'T004', 'P011', 'U001', NULL);

-- ============================================================================
-- 7. ATTENDS (154 Participant Attendance Rows across M001 - M020)
--    * Every Completed meeting meets >= 2/3 (66.67%) Present quorum.
--    * M014 has only 3/8 (37.50%) Present -> Cancelled by HOD.
--    * Confidential Scrutiny Board meetings (M003, M009, M020) strictly contain
--      ONLY HOD + AcademicStaff (zero Clerk, SupportStaff, StudentCoordinator).
--    * StudentCoordinators (U053-U058) strictly attend 'SC' (M013) & 'CP' (M016).
-- ============================================================================
INSERT INTO Attends (UserID, MeetingId, Att_Status) VALUES
-- M001 (DM 2024: 8/9 = 88.89% Present)
('U003', 'M001', 'Present'), ('U013', 'M001', 'Present'), ('U014', 'M001', 'Present'),
('U015', 'M001', 'Present'), ('U016', 'M001', 'Present'), ('U017', 'M001', 'Absent'),
('U029', 'M001', 'Present'), ('U041', 'M001', 'Present'), ('U042', 'M001', 'Present'),

-- M002 (CD 2025: 7/8 = 87.50% Present)
('U002', 'M002', 'Present'), ('U013', 'M002', 'Present'), ('U014', 'M002', 'Present'),
('U015', 'M002', 'Present'), ('U016', 'M002', 'Excused'), ('U018', 'M002', 'Present'),
('U019', 'M002', 'Present'), ('U029', 'M002', 'Present'),

-- M003 (Confidential SB 2025: 7/8 = 87.50% Present - ONLY HOD + AcademicStaff)
('U002', 'M003', 'Present'), ('U013', 'M003', 'Present'), ('U014', 'M003', 'Present'),
('U015', 'M003', 'Present'), ('U016', 'M003', 'Present'), ('U017', 'M003', 'Present'),
('U018', 'M003', 'Present'), ('U019', 'M003', 'Excused'),

-- M004 (DM Jan 2026: 9/10 = 90.00% Present)
('U001', 'M004', 'Present'), ('U013', 'M004', 'Present'), ('U014', 'M004', 'Present'),
('U015', 'M004', 'Present'), ('U016', 'M004', 'Present'), ('U017', 'M004', 'Present'),
('U018', 'M004', 'Absent'),  ('U029', 'M004', 'Present'), ('U041', 'M004', 'Present'),
('U044', 'M004', 'Present'),

-- M005 (AP Feb 2026: 7/9 = 77.78% Present)
('U001', 'M005', 'Present'), ('U013', 'M005', 'Present'), ('U014', 'M005', 'Present'),
('U015', 'M005', 'Excused'), ('U019', 'M005', 'Present'), ('U020', 'M005', 'Present'),
('U029', 'M005', 'Present'), ('U032', 'M005', 'Present'), ('U044', 'M005', 'Absent'),

-- M006 (GB Feb 2026: 7/8 = 87.50% Present)
('U001', 'M006', 'Present'), ('U013', 'M006', 'Present'), ('U014', 'M006', 'Present'),
('U021', 'M006', 'Present'), ('U022', 'M006', 'Present'), ('U029', 'M006', 'Present'),
('U041', 'M006', 'Present'), ('U045', 'M006', 'Excused'),

-- M007 (MM Mar 2026: 6/8 = 75.00% Present)
('U001', 'M007', 'Present'), ('U013', 'M007', 'Present'), ('U014', 'M007', 'Present'),
('U015', 'M007', 'Present'), ('U023', 'M007', 'Present'), ('U024', 'M007', 'Absent'),
('U025', 'M007', 'Excused'), ('U029', 'M007', 'Present'),

-- M008 (CG Mar 2026: 7/8 = 87.50% Present)
('U001', 'M008', 'Present'), ('U016', 'M008', 'Present'), ('U017', 'M008', 'Present'),
('U026', 'M008', 'Present'), ('U027', 'M008', 'Absent'),  ('U029', 'M008', 'Present'),
('U044', 'M008', 'Present'), ('U045', 'M008', 'Present'),

-- M009 (Confidential SB Apr 2026: 8/9 = 88.89% Present - ONLY HOD + AcademicStaff)
('U001', 'M009', 'Present'), ('U013', 'M009', 'Present'), ('U014', 'M009', 'Present'),
('U015', 'M009', 'Present'), ('U016', 'M009', 'Present'), ('U017', 'M009', 'Present'),
('U018', 'M009', 'Present'), ('U019', 'M009', 'Present'), ('U020', 'M009', 'Excused'),

-- M010 (IT May 2026: 6/8 = 75.00% Present)
('U001', 'M010', 'Present'), ('U013', 'M010', 'Present'), ('U018', 'M010', 'Present'),
('U021', 'M010', 'Present'), ('U022', 'M010', 'Absent'),  ('U028', 'M010', 'Present'),
('U029', 'M010', 'Present'), ('U032', 'M010', 'Excused'),

-- M011 (PE23 Jun 2026: 7/9 = 77.78% Present)
('U001', 'M011', 'Present'), ('U013', 'M011', 'Present'), ('U014', 'M011', 'Present'),
('U015', 'M011', 'Present'), ('U016', 'M011', 'Present'), ('U017', 'M011', 'Excused'),
('U018', 'M011', 'Present'), ('U019', 'M011', 'Absent'),  ('U029', 'M011', 'Present'),

-- M012 (IV Aug 2026: 6/8 = 75.00% Present)
('U001', 'M012', 'Present'), ('U013', 'M012', 'Present'), ('U018', 'M012', 'Present'),
('U020', 'M012', 'Present'), ('U029', 'M012', 'Present'), ('U044', 'M012', 'Present'),
('U045', 'M012', 'Absent'),  ('U046', 'M012', 'Excused'),

-- M013 (SC Sep 2026: 9/10 = 90.00% Present - includes StudentCoordinators!)
('U001', 'M013', 'Present'), ('U013', 'M013', 'Present'), ('U014', 'M013', 'Present'),
('U029', 'M013', 'Present'), ('U053', 'M013', 'Present'), ('U054', 'M013', 'Present'),
('U055', 'M013', 'Present'), ('U056', 'M013', 'Present'), ('U057', 'M013', 'Present'),
('U058', 'M013', 'Absent'),

-- M014 (SW Sep 2026 - FAILED QUORUM: only 3/8 = 37.50% Present -> Cancelled)
('U001', 'M014', 'Present'), ('U013', 'M014', 'Absent'),  ('U014', 'M014', 'Excused'),
('U015', 'M014', 'Absent'),  ('U029', 'M014', 'Present'), ('U041', 'M014', 'Present'),
('U042', 'M014', 'Absent'),  ('U043', 'M014', 'Excused'),

-- M015 (Rescheduled SW Oct 2026: 7/8 = 87.50% Present)
('U001', 'M015', 'Present'), ('U013', 'M015', 'Present'), ('U014', 'M015', 'Present'),
('U015', 'M015', 'Present'), ('U029', 'M015', 'Present'), ('U041', 'M015', 'Present'),
('U042', 'M015', 'Present'), ('U043', 'M015', 'Absent'),

-- M016 (CP Oct 2026: 9/10 = 90.00% Present - includes StudentCoordinators!)
('U001', 'M016', 'Present'), ('U013', 'M016', 'Present'), ('U015', 'M016', 'Present'),
('U029', 'M016', 'Present'), ('U053', 'M016', 'Present'), ('U054', 'M016', 'Present'),
('U055', 'M016', 'Present'), ('U059', 'M016', 'Present'), ('U060', 'M016', 'Present'),
('U061', 'M016', 'Excused'),

-- M017 (Upcoming DM 2026-10-31: Invited roster)
('U001', 'M017', 'Invited'), ('U013', 'M017', 'Invited'), ('U014', 'M017', 'Invited'),
('U015', 'M017', 'Invited'), ('U016', 'M017', 'Invited'), ('U029', 'M017', 'Invited'),
('U032', 'M017', 'Invited'), ('U041', 'M017', 'Invited'), ('U044', 'M017', 'Invited'),

-- M018 (Upcoming CD 2026-11-05 Morning: Invited roster)
('U001', 'M018', 'Invited'), ('U013', 'M018', 'Invited'), ('U014', 'M018', 'Invited'),
('U015', 'M018', 'Invited'), ('U016', 'M018', 'Invited'), ('U029', 'M018', 'Invited'),

-- M020 (Upcoming Confidential SB 2026-11-12: Invited ONLY HOD + AcademicStaff)
('U001', 'M020', 'Invited'), ('U013', 'M020', 'Invited'), ('U014', 'M020', 'Invited'),
('U015', 'M020', 'Invited'), ('U016', 'M020', 'Invited'), ('U017', 'M020', 'Invited');

-- Transition M001-M013, M015, M016 to 'Completed' (verified live by trg_meeting_bu_business_rules!)
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2024-06-14' WHERE MeetingId = 'M001';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2025-03-18' WHERE MeetingId = 'M002';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2025-10-22' WHERE MeetingId = 'M003';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-01-15' WHERE MeetingId = 'M004';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-02-12' WHERE MeetingId = 'M005';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-02-24' WHERE MeetingId = 'M006';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-03-11' WHERE MeetingId = 'M007';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-03-26' WHERE MeetingId = 'M008';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-04-08' WHERE MeetingId = 'M009';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-05-14' WHERE MeetingId = 'M010';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-06-18' WHERE MeetingId = 'M011';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-08-19' WHERE MeetingId = 'M012';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-09-16' WHERE MeetingId = 'M013';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-10-15' WHERE MeetingId = 'M015';
UPDATE Meeting SET Meeting_Status = 'Completed', ActualDate = '2026-10-22' WHERE MeetingId = 'M016';

-- ============================================================================
-- 8. MEETINGCONFIRMATION (24 RSVP & Minutes Sign-Off Records: C001 - C024)
--    Matches NORMALIZATION - NEW.pdf Relation 9: (ConfirmationID,
--    Confirmation_Status, ResponseDate, UserID, MeetingId)
-- ============================================================================
INSERT INTO MeetingConfirmation (ConfirmationID, Confirmation_Status, ResponseDate, UserID, MeetingId) VALUES
('C001', 'Acknowledged', '2026-01-16', 'U013', 'M004'),
('C002', 'Acknowledged', '2026-01-16', 'U014', 'M004'),
('C003', 'Acknowledged', '2026-04-09', 'U013', 'M009'),
('C004', 'Acknowledged', '2026-04-09', 'U015', 'M009'),
('C005', 'Acknowledged', '2026-10-16', 'U013', 'M015'),
('C006', 'Acknowledged', '2026-10-23', 'U053', 'M016'),
('C007', 'Confirmed',    '2026-10-26', 'U001', 'M017'),
('C008', 'Confirmed',    '2026-10-26', 'U013', 'M017'),
('C009', 'Confirmed',    '2026-10-26', 'U014', 'M017'),
('C010', 'Confirmed',    '2026-10-27', 'U015', 'M017'),
('C011', 'Declined',     '2026-10-27', 'U016', 'M017'),
('C012', 'Confirmed',    '2026-10-26', 'U029', 'M017'),
('C013', 'Pending',      NULL,         'U032', 'M017'),
('C014', 'Confirmed',    '2026-10-27', 'U041', 'M017'),
('C015', 'Pending',      NULL,         'U044', 'M017'),
('C016', 'Confirmed',    '2026-10-27', 'U001', 'M018'),
('C017', 'Confirmed',    '2026-10-28', 'U013', 'M018'),
('C018', 'Pending',      NULL,         'U014', 'M018'),
('C019', 'Pending',      NULL,         'U015', 'M018'),
('C020', 'Confirmed',    '2026-10-28', 'U029', 'M018'),
('C021', 'Confirmed',    '2026-10-28', 'U001', 'M020'),
('C022', 'Confirmed',    '2026-10-28', 'U013', 'M020'),
('C023', 'Pending',      NULL,         'U014', 'M020'),
('C024', 'Pending',      NULL,         'U015', 'M020');

-- ============================================================================
-- 9. MEDIARECORD (18 Atomized Decisions & Official Records: MR001 - MR018)
--    Matches NORMALIZATION - NEW.pdf Relation 10 + GUI Action-Item Tracking.
-- ============================================================================
INSERT INTO MediaRecord (
    MeetingRecID, DecisionText, RecordType, UploadDate,
    MeetingId, ResponsibleUserID, TaskDeadline, TaskStatus
) VALUES
('MR001', 'Decision 2024/DM/01: Approved modernization of Main Computing Lab workstations and UPS backup units for academic year 2024/2025.',                                       '.pdf',     '2024-06-15', 'M001', 'U044', '2024-08-30', 'Completed'),
('MR002', 'Decision 2025/CD/01: Approved revised ICT1407 Database Systems syllabus incorporating physical MySQL Workbench implementation and RBAC security.',                       '.docx',    '2025-03-19', 'M002', 'U013', '2025-05-15', 'Completed'),
('MR003', 'Decision 2025/SB/01 [CONFIDENTIAL]: Moderated and sealed Semester 02 final examination question papers for Level I to Level IV Computing modules.',                      '.pdf',     '2025-10-22', 'M003', 'U002', '2025-10-30', 'Completed'),
('MR004', 'Decision 2026/DM/01: Adopted the 2026 Department Annual Meeting Calendar across all 14 official meeting categories and assigned convener duties.',                       '.pdf',     '2026-01-16', 'M004', 'U029', '2026-01-25', 'Completed'),
('MR005', 'Decision 2026/DM/02: Mandated uploading pre-meeting agendas at least 3 days prior to PlannedDate with linked Google Drive cloud folders.',                               '.mp3',     '2026-01-16', 'M004', 'U032', '2026-02-01', 'Completed'),
('MR006', 'Decision 2026/AP/01: Established departmental research publication KPI target of 18 indexed papers for academic year 2026.',                                            '.pdf',     '2026-02-13', 'M005', 'U015', '2026-12-15', 'In Progress'),
('MR007', 'Decision 2026/GB/01: Scheduled Git, Linux, and Cloud DevOps practitioner bootcamps with industry alumni for 1st-year undergraduates.',                                   '.mp4',     '2026-02-25', 'M006', 'U018', '2026-04-10', 'Completed'),
('MR008', 'Decision 2026/MM/01: Assigned academic staff mentors to 1st-year student groups with monthly progress logs for at-risk students.',                                       '.pdf',     '2026-03-12', 'M007', 'U014', '2026-04-01', 'Completed'),
('MR009', 'Decision 2026/CG/01: Approved mock technical interview panels and CV review clinics for 3rd-year internship candidates.',                                                '.mp4',     '2026-03-27', 'M008', 'U016', '2026-05-01', 'Completed'),
('MR010', 'Decision 2026/SB/01 [CONFIDENTIAL]: Verified Semester 01 examination paper marking schemes, rubric weightings, and second-marker allocations.',                          '.pdf',     '2026-04-08', 'M009', 'U001', '2026-04-20', 'Completed'),
('MR011', 'Decision 2026/SB/02 [CONFIDENTIAL]: Approved confidential external examiner moderation feedback for Level IV Honours research dissertations.',                           '.docx',    '2026-04-09', 'M009', 'U015', '2026-04-25', 'Completed'),
('MR012', 'Decision 2026/IT/01: Ratified 6-month industrial training placements for 58 undergraduates across 19 SLASSCOM partner software companies.',                             '.pdf',     '2026-05-15', 'M010', 'U018', '2026-06-05', 'Completed'),
('MR013', 'Decision 2026/PE23/01: Approved mid-year prototype evaluation scores for 2023-cohort software engineering capstones; 3 teams flagged for Database ER revision.',         '.pdf',     '2026-06-19', 'M011', 'U013', '2026-07-15', 'Completed'),
('MR014', 'Decision 2026/IV/01: Signed MoU follow-up action plan after Colombo Tech Park visit to co-supervise 8 undergraduate AI & cybersecurity projects.',                       '.mp4',     '2026-08-21', 'M012', 'U020', '2026-11-15', 'In Progress'),
('MR015', 'Decision 2026/SC/01: Extended Main Computing Lab evening practical hours until 20:00 during project evaluation weeks following Student Coordinator request.',            '.pdf',     '2026-09-17', 'M013', 'U044', '2026-10-01', 'Completed'),
('MR016', 'Decision 2026/SW/01: Standardized Outcome-Based Education (OBE) continuous assessment rubrics across all programming and database laboratory courses.',                  '.mp3',     '2026-10-16', 'M015', 'U014', '2026-11-10', 'Pending'),
('MR017', 'Decision 2026/CP/01: Finalized exhibition booth layout, judging criteria, and IEEE student branch sponsorship tiers for the 2026 Computing Project Carnival.',          '.pdf',     '2026-10-23', 'M016', 'U053', '2026-11-20', 'In Progress'),
('MR018', 'Decision 2026/CP/02: Appointed Student Coordinator logistics team to publish digital abstract book and QR visitor registration portal before Carnival opening.',         '.docx',    '2026-10-23', 'M016', 'U054', '2026-11-25', 'Pending');

-- ============================================================================
-- 10. MEDIA_LINKS (24 Multimedia & Cloud Document Links across MR001 - MR018)
--     Matches NORMALIZATION - NEW.pdf Relation 11: Media_Links (MeetingRecID, MediaLinks)
-- ============================================================================
INSERT INTO Media_Links (MeetingRecID, MediaLinks) VALUES
('MR001', 'minutes_M001_DM_2024.pdf'),
('MR002', 'syllabus_ICT1407_revision_2025.docx'),
('MR002', 'minutes_M002_CD_2025.pdf'),
('MR003', 'confidential_SB_moderation_2025.pdf'),
('MR004', 'https://drive.google.com/file/d/1DoC_MR004_Minutes_DM_Jan26/view'),
('MR005', 'https://drive.google.com/file/d/1DoC_MR005_Audio_DM_Jan26.mp3/view'),
('MR006', 'https://drive.google.com/file/d/1DoC_MR006_ActionPlan_KPI_2026.pdf/view'),
('MR007', 'https://drive.google.com/file/d/1DoC_MR007_GapWorkshop_Video.mp4/view'),
('MR007', 'https://drive.google.com/file/d/1DoC_MR007_GapWorkshop_Minutes.pdf/view'),
('MR008', 'https://drive.google.com/file/d/1DoC_MR008_MentorAllocation_2026.pdf/view'),
('MR009', 'https://drive.google.com/file/d/1DoC_MR009_CareerClinic_Recording.mp4/view'),
('MR010', 'https://drive.google.com/file/d/1DoC_MR010_Restricted_SB_Sem1.pdf/view'),
('MR011', 'https://drive.google.com/file/d/1DoC_MR011_Restricted_Examiner_Notes.docx/view'),
('MR012', 'https://drive.google.com/file/d/1DoC_MR012_Internship_Placements_2026.pdf/view'),
('MR012', 'https://drive.google.com/file/d/1DoC_MR012_Partner_List_2026.docx/view'),
('MR013', 'https://drive.google.com/file/d/1DoC_MR013_PE23_Scoresheet.pdf/view'),
('MR014', 'https://drive.google.com/file/d/1DoC_MR014_IndustryVisit_Highlights.mp4/view'),
('MR014', 'https://drive.google.com/file/d/1DoC_MR014_MoU_Summary.pdf/view'),
('MR015', 'https://drive.google.com/file/d/1DoC_MR015_SC_Q3_Minutes.pdf/view'),
('MR016', 'https://drive.google.com/file/d/1DoC_MR016_OBE_Workshop_Minutes.pdf/view'),
('MR016', 'https://drive.google.com/file/d/1DoC_MR016_OBE_Audio_Session.mp3/view'),
('MR017', 'https://drive.google.com/file/d/1DoC_MR017_Carnival_Floorplan.pdf/view'),
('MR017', 'https://drive.google.com/file/d/1DoC_MR017_Carnival_Promo.mp4/view'),
('MR018', 'https://drive.google.com/file/d/1DoC_MR018_AbstractBook_Template.docx/view');

-- ============================================================================
-- 11. NOTIFICATION (20 Automated Alerts: N001 - N020)
--     Matches NORMALIZATION - NEW.pdf Relation 13: (NotificationID, Type, Sent_Date, MeetingId)
-- ============================================================================
INSERT INTO Notification (NotificationID, Type, Sent_Date, MeetingId) VALUES
('N001', 'Meeting Invitation',      '2024-06-10', 'M001'),
('N002', 'Meeting Reminder',        '2025-03-15', 'M002'),
('N003', 'Dashboard & Gmail Alert', '2025-10-19', 'M003'),
('N004', 'Dashboard & Gmail Alert', '2026-01-12', 'M004'),
('N005', 'Dashboard & Gmail Alert', '2026-02-09', 'M005'),
('N006', 'Meeting Invitation',      '2026-02-20', 'M006'),
('N007', 'Meeting Reminder',        '2026-03-08', 'M007'),
('N008', 'Dashboard & Gmail Alert', '2026-03-22', 'M008'),
('N009', 'Gmail Alert',             '2026-04-05', 'M009'),
('N010', 'Dashboard & Gmail Alert', '2026-05-11', 'M010'),
('N011', 'Meeting Reminder',        '2026-06-15', 'M011'),
('N012', 'Dashboard & Gmail Alert', '2026-08-16', 'M012'),
('N013', 'Dashboard & Gmail Alert', '2026-09-13', 'M013'),
('N014', 'Dashboard & Gmail Alert', '2026-09-21', 'M014'),
('N015', 'Meeting Cancellation',    '2026-09-24', 'M014'),
('N016', 'Reschedule Alert',        '2026-10-10', 'M015'),
('N017', 'Dashboard & Gmail Alert', '2026-10-19', 'M016'),
('N018', 'Agenda Uploaded Alert',   '2026-10-25', 'M017'),
('N019', 'Dashboard & Gmail Alert', '2026-10-28', 'M017'),
('N020', 'Agenda Uploaded Alert',   '2026-10-27', 'M018');


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- BEGIN MODULE: 04_views.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- BEGIN MODULE: 05_procedures_and_functions.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- BEGIN MODULE: 08_verification_tests.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Project      : DataVerse - Department Communication Database Management System
-- Institution  : Department of Computing, Rajarata University of Sri Lanka
-- Course       : ICT1407 - Database Systems (Final Semester Project)
-- Script       : 08_verification_tests.sql
-- Purpose      : Automated verification suite proving (> 10 rows per table),
--                ISA disjointness, Scrutiny Board & Student Coordinator RBAC,
--                3-day Agenda rule, Fixed-Date lock, Venue Conflict prevention,
--                2/3 Quorum enforcement, and GUI Login authentication.
-- Target DBMS  : MySQL Server 8.0 / 8.4 (Zero-Warning MySQL Workbench Ready)
-- ============================================================================

USE dcdms_db;

SET SESSION sql_notes = 0;
DROP PROCEDURE IF EXISTS sp_run_dcdms_verification_suite;
DROP TABLE IF EXISTS _verification_results;
SET SESSION sql_notes = 1;

DELIMITER $$
CREATE PROCEDURE sp_run_dcdms_verification_suite()
BEGIN
    DECLARE v_err_caught INT DEFAULT 0;
    DECLARE v_err_msg     VARCHAR(255) DEFAULT '';
    DECLARE v_min_rows   INT DEFAULT 0;
    DECLARE v_before_cnt INT DEFAULT 0;
    DECLARE v_after_cnt  INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err_msg = MESSAGE_TEXT;
        SET v_err_caught = 1;
    END;

    CREATE TEMPORARY TABLE _verification_results (
        TestNo      INT          NOT NULL,
        TestCase    VARCHAR(115) NOT NULL,
        Expected    VARCHAR(40)  NOT NULL,
        Actual      VARCHAR(40)  NOT NULL,
        Status      VARCHAR(10)  NOT NULL,
        Diagnostic  VARCHAR(255) NOT NULL,
        PRIMARY KEY (TestNo)
    );

    -- ------------------------------------------------------------------------
    -- TEST 1: Verify EVERY SINGLE TABLE (all 15 relations) has > 10 records
    -- ------------------------------------------------------------------------
    SELECT MIN(RowCount) INTO v_min_rows
    FROM (
        SELECT COUNT(*) AS RowCount FROM `User`
        UNION ALL SELECT COUNT(*) FROM HOD
        UNION ALL SELECT COUNT(*) FROM AcademicStaff
        UNION ALL SELECT COUNT(*) FROM Clerk
        UNION ALL SELECT COUNT(*) FROM SupportStaff
        UNION ALL SELECT COUNT(*) FROM StudentCoordinator
        UNION ALL SELECT COUNT(*) FROM MeetingType
        UNION ALL SELECT COUNT(*) FROM YearPlan
        UNION ALL SELECT COUNT(*) FROM Agenda
        UNION ALL SELECT COUNT(*) FROM Meeting
        UNION ALL SELECT COUNT(*) FROM MeetingConfirmation
        UNION ALL SELECT COUNT(*) FROM MediaRecord
        UNION ALL SELECT COUNT(*) FROM Media_Links
        UNION ALL SELECT COUNT(*) FROM Notification
        UNION ALL SELECT COUNT(*) FROM Attends
    ) AS counts;

    INSERT INTO _verification_results VALUES (
        1,
        'Dataset Completeness: Every single table (all 15 tables) has > 10 rows',
        'Min > 10 rows',
        CONCAT('Min = ', v_min_rows, ' rows'),
        IF(v_min_rows > 10, 'PASS', 'FAIL'),
        'All 15 normalized tables contain between 12 and 154 synthetic records.'
    );

    -- ------------------------------------------------------------------------
    -- TEST 2: ISA Disjointness (U001 is HOD -> cannot insert into Clerk)
    -- ------------------------------------------------------------------------
    SET v_err_caught = 0;
    SET v_err_msg = '';
    INSERT INTO Clerk (UserID, Name, Email, Password)
    VALUES ('U001', 'Dr. Tharindu Wijekoon', 'tharindu@computing.rjt.ac.lk', SHA2('test1234', 256));

    INSERT INTO _verification_results VALUES (
        2,
        'ISA Disjointness: Prevent HOD (U001) from also being inserted into Clerk',
        'REJECTED',
        IF(v_err_caught = 1, 'REJECTED', 'ACCEPTED'),
        IF(v_err_caught = 1, 'PASS', 'FAIL'),
        IF(v_err_caught = 1, v_err_msg, 'Unexpectedly accepted overlapping role')
    );

    -- ------------------------------------------------------------------------
    -- TEST 3: Confidentiality Guard (Clerk U029 blocked from Scrutiny Board M020)
    -- ------------------------------------------------------------------------
    SET v_err_caught = 0;
    SET v_err_msg = '';
    INSERT INTO Attends (UserID, MeetingId, Att_Status) VALUES ('U029', 'M020', 'Invited');

    INSERT INTO _verification_results VALUES (
        3,
        'Confidentiality Guard: Block Clerk (U029) from Scrutiny Board (M020)',
        'REJECTED',
        IF(v_err_caught = 1, 'REJECTED', 'ACCEPTED'),
        IF(v_err_caught = 1, 'PASS', 'FAIL'),
        IF(v_err_caught = 1, v_err_msg, 'Confidentiality check failed')
    );

    -- ------------------------------------------------------------------------
    -- TEST 4: Student Coordinator RBAC (U053 blocked from Dept Meeting M017)
    -- ------------------------------------------------------------------------
    SET v_err_caught = 0;
    SET v_err_msg = '';
    INSERT INTO Attends (UserID, MeetingId, Att_Status) VALUES ('U053', 'M017', 'Invited');

    INSERT INTO _verification_results VALUES (
        4,
        'Student Coordinator RBAC: Block U053 from non-SC/CP meeting (M017)',
        'REJECTED',
        IF(v_err_caught = 1, 'REJECTED', 'ACCEPTED'),
        IF(v_err_caught = 1, 'PASS', 'FAIL'),
        IF(v_err_caught = 1, v_err_msg, 'RBAC check failed')
    );

    -- ------------------------------------------------------------------------
    -- TEST 5: Pre-Meeting 3-Day Agenda Deadline Rule (1 day prior rejected)
    -- ------------------------------------------------------------------------
    SET v_err_caught = 0;
    SET v_err_msg = '';
    CALL sp_upload_agenda_for_meeting(
        'A999', 'M020', 'Late Scrutiny Agenda', '2026-11-11',
        'https://drive.google.com/file/d/late_test/view', 'N999'
    );

    INSERT INTO _verification_results VALUES (
        5,
        '3-Day Agenda Deadline: Reject agenda uploaded 1 day before M020 (2026-11-12)',
        'REJECTED',
        IF(v_err_caught = 1, 'REJECTED', 'ACCEPTED'),
        IF(v_err_caught = 1, 'PASS', 'FAIL'),
        IF(v_err_caught = 1, v_err_msg, 'Late agenda was unexpectedly accepted')
    );

    -- ------------------------------------------------------------------------
    -- TEST 6: Fixed Calendar Date Protection (IsFixed = 'Yes' on M017)
    -- ------------------------------------------------------------------------
    SET v_err_caught = 0;
    SET v_err_msg = '';
    UPDATE Meeting SET PlannedDate = '2026-11-02' WHERE MeetingId = 'M017';

    INSERT INTO _verification_results VALUES (
        6,
        'Fixed-Date Protection: Block altering PlannedDate on fixed meeting M017',
        'REJECTED',
        IF(v_err_caught = 1, 'REJECTED', 'ACCEPTED'),
        IF(v_err_caught = 1, 'PASS', 'FAIL'),
        IF(v_err_caught = 1, v_err_msg, 'Fixed PlannedDate was altered without unlock')
    );

    -- ------------------------------------------------------------------------
    -- TEST 7: GUI Venue & Time-Slot Conflict Trigger (Overlap with M018)
    --         M018 books 'Department Boardroom' on 2026-11-05 from 09:00-10:30
    -- ------------------------------------------------------------------------
    SET v_err_caught = 0;
    SET v_err_msg = '';
    INSERT INTO Meeting (
        MeetingId, IsFixed, PlannedDate, ActualDate, StartTime, EndTime,
        Venue, Meeting_Status, TypeID, PlanID, UserID, Agenda_id
    ) VALUES (
        'M999', 'No', '2026-11-05', NULL, '09:30:00', '11:00:00',
        'Department Boardroom', 'Scheduled', 'T004', 'P011', 'U001', NULL
    );

    INSERT INTO _verification_results VALUES (
        7,
        'GUI Venue Conflict Trigger: Block overlapping booking in Department Boardroom',
        'REJECTED',
        IF(v_err_caught = 1, 'REJECTED', 'ACCEPTED'),
        IF(v_err_caught = 1, 'PASS', 'FAIL'),
        IF(v_err_caught = 1, v_err_msg, 'Overlapping room booking was accepted')
    );

    -- ------------------------------------------------------------------------
    -- TEST 8: Minimum 2/3 (66.67%) Quorum Check on Meeting Completion
    --         M017 currently has 0 Present out of 9 Invited -> must reject!
    -- ------------------------------------------------------------------------
    SET v_err_caught = 0;
    SET v_err_msg = '';
    UPDATE Meeting
    SET Meeting_Status = 'Completed', ActualDate = '2026-10-31'
    WHERE MeetingId = 'M017';

    INSERT INTO _verification_results VALUES (
        8,
        '2/3 Quorum Guard: Block marking M017 Completed before 66.67% Present check-in',
        'REJECTED',
        IF(v_err_caught = 1, 'REJECTED', 'ACCEPTED'),
        IF(v_err_caught = 1, 'PASS', 'FAIL'),
        IF(v_err_caught = 1, v_err_msg, 'Completed meeting despite < 2/3 quorum')
    );

    -- ------------------------------------------------------------------------
    -- TEST 9: Automated 3-5 Day Pre-Meeting Alert Engine (for 2026-11-05)
    -- ------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_before_cnt FROM Notification WHERE MeetingId IN ('M018', 'M019') AND Type = 'Dashboard & Gmail Alert';
    CALL sp_generate_three_day_alerts('2026-11-01');
    SELECT COUNT(*) INTO v_after_cnt FROM Notification WHERE MeetingId IN ('M018', 'M019') AND Type = 'Dashboard & Gmail Alert';

    -- Clean up test alerts generated during suite so base state stays repeatable
    DELETE FROM Notification WHERE Sent_Date = '2026-11-01' AND MeetingId IN ('M018', 'M019');

    INSERT INTO _verification_results VALUES (
        9,
        '3-Day Reminder Engine: Auto-generate Dashboard & Gmail Alerts for Nov 05 slots',
        'Alerts Created',
        CONCAT('Created = ', (v_after_cnt - v_before_cnt)),
        IF(v_after_cnt > v_before_cnt, 'PASS', 'FAIL'),
        'sp_generate_three_day_alerts created upcoming meeting alerts cleanly.'
    );

    -- ------------------------------------------------------------------------
    -- Return Complete Verification Report & Per-Table Row Counts
    -- ------------------------------------------------------------------------
    SELECT * FROM _verification_results ORDER BY TestNo;

    SELECT TableName, RecordCount, IF(RecordCount > 10, 'YES (> 10)', 'NO') AS MeetsRowRequirement
    FROM (
        SELECT 'User'                AS TableName, COUNT(*) AS RecordCount FROM `User`
        UNION ALL SELECT 'HOD',                    COUNT(*) FROM HOD
        UNION ALL SELECT 'AcademicStaff',          COUNT(*) FROM AcademicStaff
        UNION ALL SELECT 'Clerk',                  COUNT(*) FROM Clerk
        UNION ALL SELECT 'SupportStaff',           COUNT(*) FROM SupportStaff
        UNION ALL SELECT 'StudentCoordinator',     COUNT(*) FROM StudentCoordinator
        UNION ALL SELECT 'MeetingType',            COUNT(*) FROM MeetingType
        UNION ALL SELECT 'YearPlan',               COUNT(*) FROM YearPlan
        UNION ALL SELECT 'Agenda',                 COUNT(*) FROM Agenda
        UNION ALL SELECT 'Meeting',                COUNT(*) FROM Meeting
        UNION ALL SELECT 'MeetingConfirmation',    COUNT(*) FROM MeetingConfirmation
        UNION ALL SELECT 'MediaRecord',            COUNT(*) FROM MediaRecord
        UNION ALL SELECT 'Media_Links',            COUNT(*) FROM Media_Links
        UNION ALL SELECT 'Notification',           COUNT(*) FROM Notification
        UNION ALL SELECT 'Attends',                COUNT(*) FROM Attends
    ) AS summary;

    SET SESSION sql_notes = 0;
    DROP TEMPORARY TABLE IF EXISTS _verification_results;
    SET SESSION sql_notes = 1;
END$$
DELIMITER ;

CALL sp_run_dcdms_verification_suite();

SET SESSION sql_notes = 0;
DROP PROCEDURE IF EXISTS sp_run_dcdms_verification_suite;
SET SESSION sql_notes = 1;
