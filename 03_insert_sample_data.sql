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
