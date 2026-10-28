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
