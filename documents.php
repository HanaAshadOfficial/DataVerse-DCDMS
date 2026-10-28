
<?php
session_start();

if (empty($_SESSION['user_id']) || empty($_SESSION['user_role'])) {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config.php';

function h($value) {
    return htmlspecialchars(
        (string)($value ?? ''),
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );
}

function queryDB($conn, $sql, $types = '', $values = []) {
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new RuntimeException($conn->error);
    }

    if ($types !== '') {
        $stmt->bind_param($types, ...$values);
    }

    if (!$stmt->execute()) {
        $message = $stmt->error;
        $stmt->close();
        throw new RuntimeException($message);
    }

    return $stmt;
}

function newId($prefix, $length = 8) {
    return $prefix . strtoupper(
        substr(bin2hex(random_bytes(6)), 0, $length)
    );
}

function validLink($url) {
    if (strlen($url) > 500) {
        return false;
    }

    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        return false;
    }

    $scheme = strtolower(
        (string)parse_url($url, PHP_URL_SCHEME)
    );

    return in_array($scheme, ['https', 'http'], true);
}

function dateLabel($date) {
    return $date
        ? date('d M Y', strtotime($date))
        : 'Not set';
}

function meetingAllowed($meeting, $role, $assigned) {
    $type = $meeting['ShortName'];
    $private = $meeting['IsPrivate'] === 'Yes';

    if ($role === 'HOD') {
        return true;
    }

    if ($role === 'Clerk') {
        return !$private;
    }

    if ($role === 'AcademicStaff') {
        return $assigned;
    }

    if ($role === 'SupportStaff') {
        return !$private
            && $assigned
            && in_array($type, ['DM', 'SW'], true);
    }

    if ($role === 'StudentCoordinator') {
        return !$private
            && (
                $type === 'DM'
                || (
                    $assigned
                    && in_array($type, ['SC', 'CP'], true)
                )
            );
    }

    return false;
}

function mayUpload($meeting, $role) {
    if ($role === 'HOD') {
        return true;
    }

    if ($role === 'Clerk') {
        return $meeting['IsPrivate'] === 'No';
    }

    return false;
}

$userId = (string)$_SESSION['user_id'];
$userName = (string)($_SESSION['user_name'] ?? 'User');
$role = (string)$_SESSION['user_role'];

$roleNames = [
    'HOD' => 'Head of Department',
    'AcademicStaff' => 'Academic Staff',
    'Clerk' => 'Clerk / Convener',
    'SupportStaff' => 'Support Staff',
    'StudentCoordinator' => 'Student Coordinator'
];

if (!isset($roleNames[$role])) {
    http_response_code(403);
    exit('Access denied.');
}

if (empty($_SESSION['documents_csrf'])) {
    $_SESSION['documents_csrf'] = bin2hex(random_bytes(32));
}

$csrf = $_SESSION['documents_csrf'];
$selectedId = trim((string)($_GET['meeting_id'] ?? ''));

$error = '';
$success = '';

/*
|--------------------------------------------------------------------------
| LOAD ONE MEETING AND CHECK ACCESS
|--------------------------------------------------------------------------
*/

function getAuthorizedMeeting($conn, $meetingId, $userId, $role) {

    $stmt = queryDB(
        $conn,
        "SELECT
            m.MeetingId,
            m.PlannedDate,
            m.StartTime,
            m.EndTime,
            m.Venue,
            m.Meeting_Status,
            m.Agenda_id,
            mt.Name AS MeetingName,
            mt.ShortName,
            mt.IsPrivate,
            a.UserID AS AssignedUser
         FROM Meeting m
         JOIN MeetingType mt
           ON mt.TypeID = m.TypeID
         LEFT JOIN Attends a
           ON a.MeetingId = m.MeetingId
          AND a.UserID = ?
         WHERE m.MeetingId = ?",
        'ss',
        [$userId, $meetingId]
    );

    $meeting = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$meeting) {
        throw new RuntimeException('Meeting not found.');
    }

    $assigned = $meeting['AssignedUser'] !== null;

    if (!meetingAllowed($meeting, $role, $assigned)) {
        throw new RuntimeException(
            'You are not authorized to access this meeting.'
        );
    }

    return $meeting;
}

/*
|--------------------------------------------------------------------------
| HANDLE FORM SUBMISSIONS
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    $selectedId = trim(
        (string)($_POST['meeting_id'] ?? '')
    );

    try {

        if (!hash_equals(
            $csrf,
            (string)($_POST['csrf'] ?? '')
        )) {
            throw new RuntimeException(
                'Invalid request. Refresh the page and try again.'
            );
        }

        $meeting = getAuthorizedMeeting(
            $conn,
            $selectedId,
            $userId,
            $role
        );

        if (!mayUpload($meeting, $role)) {
            throw new RuntimeException(
                'Only authorized HOD or Clerk accounts can upload documents.'
            );
        }

        $action = (string)($_POST['action'] ?? '');

        /*
        |--------------------------------------------------------------------------
        | SAVE AGENDA
        |--------------------------------------------------------------------------
        */

        if ($action === 'save_agenda') {

            $agendaName = trim(
                (string)($_POST['agenda_name'] ?? '')
            );

            $agendaLink = trim(
                (string)($_POST['agenda_link'] ?? '')
            );

            if ($agendaName === '' || strlen($agendaName) > 200) {
                throw new RuntimeException(
                    'Enter an agenda title of 1 to 200 characters.'
                );
            }

            if (!validLink($agendaLink)) {
                throw new RuntimeException(
                    'Enter a valid HTTP or HTTPS agenda document link.'
                );
            }

            if (in_array(
                $meeting['Meeting_Status'],
                ['Completed', 'Cancelled'],
                true
            )) {
                throw new RuntimeException(
                    'Agenda uploads are closed for completed or cancelled meetings.'
                );
            }

            /*
             * Physical design:
             * Agenda must be submitted at least 3 days
             * before the planned meeting date.
             */

            $today = new DateTimeImmutable('today');

            $deadline = (
                new DateTimeImmutable($meeting['PlannedDate'])
            )->modify('-3 days');

            if ($today > $deadline) {
                throw new RuntimeException(
                    'Agenda deadline has passed. The agenda must be uploaded at least 3 days before the meeting.'
                );
            }

            /*
             * Existing agendas are updated.
             * New agendas are inserted and linked
             * to the Meeting table.
             */

            $conn->begin_transaction();

            try {

                if (!empty($meeting['Agenda_id'])) {

                    $stmt = queryDB(
                        $conn,
                        "UPDATE Agenda
                         SET Name = ?,
                             AgendaFileLink = ?,
                             Upload_Date = CURDATE()
                         WHERE Agenda_id = ?",
                        'sss',
                        [
                            $agendaName,
                            $agendaLink,
                            $meeting['Agenda_id']
                        ]
                    );

                    $stmt->close();

                } else {

                    $agendaId = newId('A');

                    $stmt = queryDB(
                        $conn,
                        "INSERT INTO Agenda
                            (
                                Agenda_id,
                                Name,
                                Upload_Date,
                                AgendaFileLink
                            )
                         VALUES (?, ?, CURDATE(), ?)",
                        'sss',
                        [
                            $agendaId,
                            $agendaName,
                            $agendaLink
                        ]
                    );

                    $stmt->close();

                    $stmt = queryDB(
                        $conn,
                        "UPDATE Meeting
                         SET Agenda_id = ?,
                             Meeting_Status =
                                CASE
                                    WHEN Meeting_Status = 'Planned'
                                    THEN 'Scheduled'
                                    ELSE Meeting_Status
                                END
                         WHERE MeetingId = ?",
                        'ss',
                        [$agendaId, $selectedId]
                    );

                    $stmt->close();
                }

                $notificationId = newId('N');

                $stmt = queryDB(
                    $conn,
                    "INSERT INTO Notification
                        (
                            NotificationID,
                            Type,
                            Sent_Date,
                            MeetingId
                        )
                     VALUES (
                        ?,
                        'Agenda Uploaded Alert',
                        CURDATE(),
                        ?
                     )",
                    'ss',
                    [$notificationId, $selectedId]
                );

                $stmt->close();

                $conn->commit();

            } catch (Throwable $e) {
                $conn->rollback();
                throw $e;
            }

            header(
                'Location: documents.php?meeting_id=' .
                urlencode($selectedId) .
                '&saved=agenda'
            );
            exit;
        }

        /*
        |--------------------------------------------------------------------------
        | SAVE MEDIA RECORD AND LINKS
        |--------------------------------------------------------------------------
        */

        if ($action === 'save_media') {

            $description = trim(
                (string)($_POST['description'] ?? '')
            );

            $recordType = trim(
                (string)($_POST['record_type'] ?? '')
            );

            $linksText = trim(
                (string)($_POST['media_links'] ?? '')
            );

            /*
             * RecordType values match the CHECK
             * constraint in the physical SQL design.
             */

            $allowedTypes = [
                '.pdf',
                '.mp3',
                '.mp4',
                '.docx',
                'Decision',
                'Minutes',
                'Audio',
                'Video',
                'Minutes & Audio',
                'Minutes & Video'
            ];

            if (!in_array($recordType, $allowedTypes, true)) {
                throw new RuntimeException(
                    'Select a valid media record type.'
                );
            }

            if ($description === '') {
                throw new RuntimeException(
                    'Enter a description for this media record.'
                );
            }

            if ($linksText === '') {
                throw new RuntimeException(
                    'Provide at least one media link.'
                );
            }

            if ($meeting['Meeting_Status'] === 'Cancelled') {
                throw new RuntimeException(
                    'Media records cannot be added to cancelled meetings.'
                );
            }

            /*
             * Each line becomes one Media_Links row.
             */

            $links = preg_split(
                '/\r\n|\r|\n/',
                $linksText
            );

            $links = array_values(
                array_unique(
                    array_filter(
                        array_map('trim', $links),
                        'strlen'
                    )
                )
            );

            if (count($links) < 1 || count($links) > 10) {
                throw new RuntimeException(
                    'Provide between 1 and 10 media links.'
                );
            }

            foreach ($links as $link) {
                if (!validLink($link)) {
                    throw new RuntimeException(
                        'All media links must be valid HTTP or HTTPS URLs, up to 500 characters each.'
                    );
                }
            }

            $recordId = newId('MR');

            $conn->begin_transaction();

            try {

                $stmt = queryDB(
                    $conn,
                    "INSERT INTO MediaRecord
                        (
                            MeetingRecID,
                            DecisionText,
                            RecordType,
                            UploadDate,
                            MeetingId,
                            ResponsibleUserID,
                            TaskDeadline,
                            TaskStatus
                        )
                     VALUES (
                        ?, ?, ?, CURDATE(), ?,
                        NULL, NULL, 'Not Applicable'
                     )",
                    'ssss',
                    [
                        $recordId,
                        $description,
                        $recordType,
                        $selectedId
                    ]
                );

                $stmt->close();

                foreach ($links as $link) {

                    $stmt = queryDB(
                        $conn,
                        "INSERT INTO Media_Links
                            (MeetingRecID, MediaLinks)
                         VALUES (?, ?)",
                        'ss',
                        [$recordId, $link]
                    );

                    $stmt->close();
                }

                $conn->commit();

            } catch (Throwable $e) {
                $conn->rollback();
                throw $e;
            }

            header(
                'Location: documents.php?meeting_id=' .
                urlencode($selectedId) .
                '&saved=media'
            );
            exit;
        }

        throw new RuntimeException('Unknown form action.');

    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

/*
|--------------------------------------------------------------------------
| SUCCESS MESSAGES
|--------------------------------------------------------------------------
*/

if (($_GET['saved'] ?? '') === 'agenda') {
    $success = 'Meeting agenda saved successfully.';
}

if (($_GET['saved'] ?? '') === 'media') {
    $success = 'Media record and links saved successfully.';
}

/*
|--------------------------------------------------------------------------
| LOAD AVAILABLE MEETINGS
|--------------------------------------------------------------------------
*/

$meetings = [];
$selected = null;
$agenda = null;
$mediaRecords = [];

try {

    $stmt = queryDB(
        $conn,
        "SELECT
            m.MeetingId,
            m.PlannedDate,
            m.StartTime,
            m.EndTime,
            m.Venue,
            m.Meeting_Status,
            m.Agenda_id,
            mt.Name AS MeetingName,
            mt.ShortName,
            mt.IsPrivate,
            a.UserID AS AssignedUser
         FROM Meeting m
         JOIN MeetingType mt
           ON mt.TypeID = m.TypeID
         LEFT JOIN Attends a
           ON a.MeetingId = m.MeetingId
          AND a.UserID = ?
         ORDER BY m.PlannedDate DESC,
                  m.StartTime DESC",
        's',
        [$userId]
    );

    $result = $stmt->get_result();

    while ($row = $result->fetch_assoc()) {

        $assigned = $row['AssignedUser'] !== null;

        if (meetingAllowed($row, $role, $assigned)) {
            $meetings[] = $row;
        }
    }

    $stmt->close();

    if ($selectedId !== '') {

        foreach ($meetings as $meeting) {

            if ($meeting['MeetingId'] === $selectedId) {
                $selected = $meeting;
                break;
            }
        }

        if (!$selected && $error === '') {
            $error = 'This meeting is not available to your role.';
        }

    } elseif (!empty($meetings)) {

        $selected = $meetings[0];
        $selectedId = $selected['MeetingId'];
    }

    /*
    |--------------------------------------------------------------------------
    | LOAD SELECTED MEETING DOCUMENTS
    |--------------------------------------------------------------------------
    */

    if ($selected) {

        if (!empty($selected['Agenda_id'])) {

            $stmt = queryDB(
                $conn,
                "SELECT
                    Agenda_id,
                    Name,
                    Upload_Date,
                    AgendaFileLink
                 FROM Agenda
                 WHERE Agenda_id = ?",
                's',
                [$selected['Agenda_id']]
            );

            $agenda = $stmt->get_result()->fetch_assoc();
            $stmt->close();
        }

        $stmt = queryDB(
            $conn,
            "SELECT
                mr.MeetingRecID,
                mr.DecisionText,
                mr.RecordType,
                mr.UploadDate,
                ml.MediaLinks
             FROM MediaRecord mr
             LEFT JOIN Media_Links ml
               ON ml.MeetingRecID = mr.MeetingRecID
             WHERE mr.MeetingId = ?
             ORDER BY
                mr.UploadDate DESC,
                mr.MeetingRecID DESC,
                ml.MediaLinks",
            's',
            [$selectedId]
        );

        $result = $stmt->get_result();

        while ($row = $result->fetch_assoc()) {

            $recordId = $row['MeetingRecID'];

            if (!isset($mediaRecords[$recordId])) {

                $mediaRecords[$recordId] = [
                    'id' => $recordId,
                    'description' => $row['DecisionText'],
                    'type' => $row['RecordType'],
                    'date' => $row['UploadDate'],
                    'links' => []
                ];
            }

            if ($row['MediaLinks'] !== null) {
                $mediaRecords[$recordId]['links'][] =
                    $row['MediaLinks'];
            }
        }

        $stmt->close();
    }

} catch (Throwable $e) {

    $error = 'Unable to load documents: ' .
        $e->getMessage();
}

/*
|--------------------------------------------------------------------------
| PAGE STATE
|--------------------------------------------------------------------------
*/

$canUpload = $selected
    ? mayUpload($selected, $role)
    : false;

$deadline = null;
$agendaOpen = false;

if ($selected) {

    $deadline = (
        new DateTimeImmutable($selected['PlannedDate'])
    )->modify('-3 days');

    $agendaOpen = $canUpload
        && new DateTimeImmutable('today') <= $deadline
        && !in_array(
            $selected['Meeting_Status'],
            ['Completed', 'Cancelled'],
            true
        );
}

$initials = strtoupper(
    substr(
        preg_replace('/[^a-z]/i', '', $userName),
        0,
        2
    )
);

$nav = [
    ['Dashboard', 'dashboard.php', '◫'],
    ['Annual Planning', 'annual_plan.php', '▦'],
    ['Meetings & Scheduling', 'meetings.php', '▣'],
    ['Attendance & Quorum', 'participation.php', '♧'],
    ['Agendas & Documents', 'documents.php', '▤'],
    ['Decisions & Reports', 'decisions.php', '☷']
];

?>
<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">

<title>DataVerse | Agendas & Documents</title>

<style>

:root {
    --navy: #102f3e;
    --navy2: #194b5c;
    --gold: #f4c45c;
    --background: #edf3f5;
    --text: #173447;
    --muted: #718899;
    --border: #e1e9ee;
    --green: #188456;
    --red: #b84949;
}

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: "Segoe UI", Arial, sans-serif;
    background: var(--background);
    color: var(--text);
}

.sidebar {
    width: 258px;
    background: var(--navy);
    color: white;
    position: fixed;
    inset: 0 auto 0 0;
    padding: 28px 18px;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
}

.brand {
    padding: 12px 14px 26px;
    border-bottom: 1px solid #ffffff20;
    margin-bottom: 25px;
}

.brand-name {
    font-size: 30px;
    font-weight: 800;
}

.brand-name span {
    color: var(--gold);
}

.brand-desc {
    color: #c3d4db;
    font-size: 11px;
    line-height: 1.7;
    letter-spacing: 1px;
    margin-top: 10px;
}

.nav-title {
    padding: 10px 15px;
    color: #8ba8b7;
    font-size: 10px;
    font-weight: 800;
    letter-spacing: 2px;
}

.nav-link {
    display: flex;
    align-items: center;
    gap: 13px;
    padding: 14px 15px;
    margin: 3px 0;
    color: #d1e0e8;
    text-decoration: none;
    border-radius: 10px;
    font-size: 13px;
}

.nav-link:hover {
    background: #ffffff13;
}

.nav-link.active {
    background: var(--gold);
    color: var(--navy);
    font-weight: 800;
}

.nav-icon {
    width: 24px;
    text-align: center;
    font-size: 19px;
}

.sidebar-bottom {
    margin-top: auto;
    border-top: 1px solid #ffffff20;
    padding-top: 20px;
}

.profile {
    display: flex;
    align-items: center;
    gap: 11px;
    margin-bottom: 20px;
}

.avatar {
    width: 40px;
    height: 40px;
    background: var(--gold);
    border-radius: 12px;
    color: var(--navy);
    display: grid;
    place-items: center;
    font-weight: 800;
}

.profile-name {
    font-size: 12px;
    font-weight: 800;
}

.profile-role {
    font-size: 11px;
    color: #adc5d0;
    margin-top: 5px;
}

.signout {
    display: block;
    text-align: center;
    color: white;
    text-decoration: none;
    background: #ffffff15;
    border: 1px solid #ffffff30;
    padding: 13px;
    border-radius: 9px;
    font-size: 13px;
    font-weight: 700;
}

.main {
    margin-left: 258px;
    padding: 34px 40px 55px;
}

.topbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    margin-bottom: 26px;
}

.eyebrow {
    color: #b78113;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 2px;
}

h1 {
    color: var(--navy);
    font-size: 30px;
    margin: 9px 0;
}

.subtitle {
    color: var(--muted);
    font-size: 13px;
    line-height: 1.7;
}

.role-chip {
    background: #fff5dd;
    color: #8c640c;
    border: 1px solid #f6e6bd;
    border-radius: 12px;
    padding: 12px 15px;
    font-size: 12px;
    font-weight: 800;
}

.hero {
    background: linear-gradient(
        115deg,
        var(--navy),
        var(--navy2)
    );
    color: white;
    border-radius: 20px;
    padding: 30px 35px;
    margin-bottom: 25px;
}

.hero h2 {
    font-size: 26px;
    margin: 9px 0;
}

.hero p {
    color: #d4e3e9;
    font-size: 13px;
}

.layout {
    display: grid;
    grid-template-columns: 300px minmax(0, 1fr);
    gap: 22px;
    align-items: start;
}

.card {
    background: white;
    border: 1px solid var(--border);
    border-radius: 17px;
    padding: 24px;
    margin-bottom: 22px;
}

.card h2 {
    margin: 0 0 8px;
    font-size: 19px;
}

.meeting-list {
    max-height: 720px;
    overflow-y: auto;
}

.meeting-link {
    display: block;
    padding: 15px;
    margin-top: 10px;
    border: 1px solid var(--border);
    border-radius: 12px;
    text-decoration: none;
    color: var(--text);
}

.meeting-link:hover {
    border-color: var(--gold);
}

.meeting-link.selected {
    background: #fff9eb;
    border-color: var(--gold);
}

.meeting-link strong {
    display: block;
    font-size: 13px;
    line-height: 1.5;
}

.meeting-link small {
    display: block;
    color: var(--muted);
    margin-top: 6px;
    line-height: 1.5;
}

.badge {
    display: inline-block;
    border-radius: 20px;
    padding: 7px 11px;
    background: #edf1f4;
    color: #5e7180;
    font-size: 11px;
    font-weight: 800;
}

.badge.green {
    background: #e5f7ed;
    color: var(--green);
}

.badge.gold {
    background: #fff3d7;
    color: #a77512;
}

.badge.red {
    background: #fff0f0;
    color: var(--red);
}

.detail-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 14px;
    margin-top: 20px;
}

.detail {
    background: #f8fafb;
    border-radius: 11px;
    padding: 15px;
}

.detail-label {
    color: var(--muted);
    font-size: 11px;
    margin-bottom: 8px;
}

.detail-value {
    font-size: 13px;
    font-weight: 700;
}

.section-title {
    font-size: 16px;
    font-weight: 800;
    margin: 24px 0 12px;
}

.form-group {
    margin: 15px 0;
}

.form-group label {
    display: block;
    font-size: 12px;
    font-weight: 700;
    margin-bottom: 8px;
}

input,
select,
textarea {
    width: 100%;
    padding: 12px;
    border: 1px solid #d9e4e9;
    border-radius: 9px;
    background: white;
    color: var(--text);
    font: inherit;
    font-size: 13px;
}

textarea {
    min-height: 105px;
    resize: vertical;
}

input:focus,
select:focus,
textarea:focus {
    outline: 2px solid #f4c45c70;
    border-color: var(--gold);
}

.button {
    display: inline-block;
    background: var(--navy);
    color: white;
    border: none;
    border-radius: 9px;
    padding: 12px 17px;
    font-size: 12px;
    font-weight: 800;
    cursor: pointer;
    text-decoration: none;
}

.button:hover {
    background: var(--navy2);
}

.button.gold {
    background: var(--gold);
    color: var(--navy);
}

.button-row {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    margin-top: 15px;
}

.notice {
    padding: 15px;
    border-radius: 11px;
    font-size: 13px;
    margin-bottom: 20px;
}

.notice.success {
    background: #e5f7ed;
    color: #17764a;
}

.notice.error {
    background: #fff0f0;
    color: #ad4141;
}

.info {
    padding: 15px;
    background: #f7fafb;
    border: 1px solid var(--border);
    border-radius: 11px;
    font-size: 12px;
    line-height: 1.8;
    color: #667e8f;
    margin: 15px 0;
}

.info.warning {
    background: #fff9ed;
    border-color: #f2e4be;
    color: #94701d;
}

.info.good {
    background: #ecf8f1;
    border-color: #c8ead7;
    color: #23794f;
}

.record {
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 17px;
    margin-top: 13px;
}

.record-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    margin-bottom: 10px;
}

.record p {
    color: #5e7483;
    font-size: 12px;
    line-height: 1.7;
    overflow-wrap: anywhere;
}

.link-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: 12px;
}

.document-link {
    display: block;
    padding: 10px 12px;
    background: #f7fafb;
    border-radius: 8px;
    color: #236d9a;
    text-decoration: none;
    font-size: 12px;
    overflow-wrap: anywhere;
}

.document-link:hover {
    text-decoration: underline;
}

.empty {
    text-align: center;
    padding: 30px 10px;
    color: var(--muted);
    font-size: 13px;
}

.footer {
    text-align: center;
    color: #91a2ad;
    font-size: 11px;
    margin-top: 30px;
}

@media (max-width: 1050px) {
    .layout {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 850px) {
    .sidebar {
        position: relative;
        width: 100%;
        height: auto;
    }

    .main {
        margin-left: 0;
        padding: 24px;
    }
}

@media (max-width: 600px) {
    .topbar {
        flex-direction: column;
        align-items: stretch;
    }

    .detail-grid {
        grid-template-columns: 1fr;
    }
}

</style>

</head>

<body>

<aside class="sidebar">

    <div class="brand">

        <div class="brand-name">
            Data<span>Verse</span>
        </div>

        <div class="brand-desc">
            DEPARTMENT COMMUNICATION<br>
            MANAGEMENT SYSTEM
        </div>

    </div>

    <div class="nav-title">
        MAIN NAVIGATION
    </div>

    <nav>

        <?php foreach ($nav as $item): ?>

            <?php

            if (
                $item[1] === 'annual_plan.php'
                && !in_array(
                    $role,
                    ['HOD', 'Clerk', 'AcademicStaff'],
                    true
                )
            ) {
                continue;
            }

            if (
                $item[1] === 'decisions.php'
                && !in_array(
                    $role,
                    ['HOD', 'Clerk', 'AcademicStaff'],
                    true
                )
            ) {
                continue;
            }

            ?>

            <a
                href="<?= h($item[1]) ?>"
                class="nav-link <?= $item[1] === 'documents.php' ? 'active' : '' ?>"
            >

                <span class="nav-icon">
                    <?= h($item[2]) ?>
                </span>

                <?= h($item[0]) ?>

            </a>

        <?php endforeach; ?>

        <?php if ($role === 'HOD'): ?>

            <a href="users.php" class="nav-link">
                <span class="nav-icon">♙</span>
                Users & Access
            </a>

        <?php endif; ?>

    </nav>

    <div class="sidebar-bottom">

        <div class="profile">

            <div class="avatar">
                <?= h($initials) ?>
            </div>

            <div>

                <div class="profile-name">
                    <?= h($userName) ?>
                </div>

                <div class="profile-role">
                    <?= h($roleNames[$role]) ?>
                </div>

            </div>

        </div>

        <a href="logout.php" class="signout">
            ↪ Sign Out
        </a>

    </div>

</aside>

<main class="main">

    <header class="topbar">

        <div>

            <div class="eyebrow">
                DEPARTMENT OF COMPUTING
            </div>

            <h1>Agendas & Documents</h1>

            <p class="subtitle">
                Manage meeting agendas, minutes,
                supporting documents, recordings,
                and media links.
            </p>

        </div>

        <div class="role-chip">
            <?= h($roleNames[$role]) ?>
        </div>

    </header>

    <?php if ($success): ?>

        <div class="notice success">
            ✓ <?= h($success) ?>
        </div>

    <?php endif; ?>

    <?php if ($error): ?>

        <div class="notice error">
            <?= h($error) ?>
        </div>

    <?php endif; ?>

    <section class="hero">

        <div
            class="eyebrow"
            style="color:var(--gold)"
        >
            DOCUMENT MANAGEMENT WORKSPACE
        </div>

        <h2>Meeting Agendas & Media Records</h2>

        <p>
            Prepare agendas before the deadline,
            organize supporting materials,
            and maintain meeting recordings and minutes.
        </p>

    </section>

    <div class="layout">

        <!-- MEETING LIST -->

        <div>

            <section class="card">

                <h2>Available Meetings</h2>

                <p class="subtitle">
                    Select a meeting to view
                    its agenda and documents.
                </p>

                <div class="meeting-list">

                    <?php if (!$meetings): ?>

                        <div class="empty">
                            No meetings available.
                        </div>

                    <?php endif; ?>

                    <?php foreach ($meetings as $meeting): ?>

                        <a
                            href="documents.php?meeting_id=<?= urlencode($meeting['MeetingId']) ?>"
                            class="meeting-link <?= $selectedId === $meeting['MeetingId'] ? 'selected' : '' ?>"
                        >

                            <strong>
                                <?= h($meeting['MeetingName']) ?>
                            </strong>

                            <small>
                                <?= h(dateLabel($meeting['PlannedDate'])) ?>
                                ·
                                <?= h($meeting['Meeting_Status']) ?>
                            </small>

                            <small>

                                <?php if ($meeting['Agenda_id']): ?>

                                    <span class="badge green">
                                        Agenda Available
                                    </span>

                                <?php else: ?>

                                    <span class="badge gold">
                                        No Agenda
                                    </span>

                                <?php endif; ?>

                            </small>

                        </a>

                    <?php endforeach; ?>

                </div>

            </section>

        </div>

        <!-- SELECTED MEETING -->

        <div>

            <?php if ($selected): ?>

                <section class="card">

                    <div class="eyebrow">
                        SELECTED MEETING
                    </div>

                    <h2 style="margin-top:10px">
                        <?= h($selected['MeetingName']) ?>
                    </h2>

                    <span class="badge">
                        <?= h($selected['Meeting_Status']) ?>
                    </span>

                    <?php if ($selected['IsPrivate'] === 'Yes'): ?>

                        <span class="badge gold">
                            Confidential
                        </span>

                    <?php endif; ?>

                    <div class="detail-grid">

                        <div class="detail">

                            <div class="detail-label">
                                Meeting ID
                            </div>

                            <div class="detail-value">
                                <?= h($selected['MeetingId']) ?>
                            </div>

                        </div>

                        <div class="detail">

                            <div class="detail-label">
                                Meeting Date
                            </div>

                            <div class="detail-value">
                                <?= h(dateLabel($selected['PlannedDate'])) ?>
                            </div>

                        </div>

                        <div class="detail">

                            <div class="detail-label">
                                Venue
                            </div>

                            <div class="detail-value">
                                <?= h($selected['Venue']) ?>
                            </div>

                        </div>

                        <div class="detail">

                            <div class="detail-label">
                                Agenda Deadline
                            </div>

                            <div class="detail-value">
                                <?= h($deadline->format('d M Y')) ?>
                            </div>

                        </div>

                    </div>

                </section>

                <!-- AGENDA -->

                <section class="card">

                    <h2>Meeting Agenda</h2>

                    <p class="subtitle">
                        Agenda documents must be submitted
                        at least three days before the meeting.
                    </p>

                    <?php if ($agenda): ?>

                        <div class="info good">

                            <strong>
                                ✓ Agenda Available
                            </strong>

                            <div style="margin-top:8px">
                                <?= h($agenda['Name']) ?>
                            </div>

                            <div>
                                Agenda ID:
                                <?= h($agenda['Agenda_id']) ?>
                            </div>

                            <div>
                                Uploaded:
                                <?= h(dateLabel($agenda['Upload_Date'])) ?>
                            </div>

                        </div>

                        <?php if (
                            validLink(
                                (string)($agenda['AgendaFileLink'] ?? '')
                            )
                        ): ?>

                            <div class="button-row">

                                <a
                                    href="<?= h($agenda['AgendaFileLink']) ?>"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    class="button"
                                >
                                    Open Agenda Document
                                </a>

                            </div>

                        <?php endif; ?>

                    <?php else: ?>

                        <div class="info warning">
                            No agenda has been uploaded
                            for this meeting yet.
                        </div>

                    <?php endif; ?>

                    <?php if ($canUpload): ?>

                        <h3 class="section-title">
                            <?= $agenda
                                ? 'Update Agenda'
                                : 'Upload Agenda' ?>
                        </h3>

                        <?php if ($agendaOpen): ?>

                            <form
                                method="post"
                                onsubmit="return confirm('Save this agenda document?')"
                            >

                                <input
                                    type="hidden"
                                    name="csrf"
                                    value="<?= h($csrf) ?>"
                                >

                                <input
                                    type="hidden"
                                    name="action"
                                    value="save_agenda"
                                >

                                <input
                                    type="hidden"
                                    name="meeting_id"
                                    value="<?= h($selectedId) ?>"
                                >

                                <div class="form-group">

                                    <label>
                                        Agenda Title
                                    </label>

                                    <input
                                        type="text"
                                        name="agenda_name"
                                        maxlength="200"
                                        required
                                        placeholder="e.g. November Department Meeting Agenda"
                                        value="<?= h($agenda['Name'] ?? '') ?>"
                                    >

                                </div>

                                <div class="form-group">

                                    <label>
                                        Agenda Document Link
                                    </label>

                                    <input
                                        type="url"
                                        name="agenda_link"
                                        maxlength="500"
                                        required
                                        placeholder="https://drive.google.com/..."
                                        value="<?= h($agenda['AgendaFileLink'] ?? '') ?>"
                                    >

                                </div>

                                <div class="info">
                                    Upload your PDF or Word document
                                    to authorized cloud storage first,
                                    then paste its sharing link here.

                                    The link must be accessible
                                    to the intended participants.
                                </div>

                                <button
                                    type="submit"
                                    class="button gold"
                                >
                                    Save Agenda
                                </button>

                            </form>

                        <?php else: ?>

                            <div class="info warning">

                                Agenda editing is closed.

                                The three-day deadline has passed,
                                or the meeting is completed
                                or cancelled.

                            </div>

                        <?php endif; ?>

                    <?php else: ?>

                        <div class="info">
                            You have read-only access
                            to this meeting's agenda.
                        </div>

                    <?php endif; ?>

                </section>

                <!-- MEDIA RECORDS -->

                <section class="card">

                    <h2>Meeting Media & Recordings</h2>

                    <p class="subtitle">
                        Minutes, audio recordings,
                        video recordings, and supporting
                        document links.
                    </p>

                    <?php if (!$mediaRecords): ?>

                        <div class="empty">
                            No media records are available
                            for this meeting.
                        </div>

                    <?php endif; ?>

                    <?php foreach ($mediaRecords as $record): ?>

                        <div class="record">

                            <div class="record-top">

                                <strong>
                                    <?= h($record['id']) ?>
                                </strong>

                                <span class="badge">
                                    <?= h($record['type']) ?>
                                </span>

                            </div>

                            <p>
                                <?= nl2br(h($record['description'])) ?>
                            </p>

                            <div class="subtitle">
                                Recorded:
                                <?= h(dateLabel($record['date'])) ?>
                            </div>

                            <div class="link-list">

                                <?php foreach ($record['links'] as $link): ?>

                                    <?php if (validLink($link)): ?>

                                        <a
                                            href="<?= h($link) ?>"
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            class="document-link"
                                        >
                                            ↗ Open Media / Document
                                        </a>

                                    <?php else: ?>

                                        <div class="info">
                                            Stored reference:
                                            <?= h($link) ?>
                                        </div>

                                    <?php endif; ?>

                                <?php endforeach; ?>

                            </div>

                        </div>

                    <?php endforeach; ?>

                </section>

                <!-- MEDIA UPLOAD -->

                <?php if ($canUpload): ?>

                    <section class="card">

                        <h2>Add Media Record</h2>

                        <p class="subtitle">
                            HOD and Clerk can register
                            minutes, recordings, and
                            supporting materials.
                        </p>

                        <?php if (
                            $selected['Meeting_Status'] !== 'Cancelled'
                        ): ?>

                            <form
                                method="post"
                                onsubmit="return confirm('Save this media record and its links?')"
                            >

                                <input
                                    type="hidden"
                                    name="csrf"
                                    value="<?= h($csrf) ?>"
                                >

                                <input
                                    type="hidden"
                                    name="action"
                                    value="save_media"
                                >

                                <input
                                    type="hidden"
                                    name="meeting_id"
                                    value="<?= h($selectedId) ?>"
                                >

                                <div class="form-group">

                                    <label>
                                        Record Type
                                    </label>

                                    <select
                                        name="record_type"
                                        required
                                    >

                                        <option value="">
                                            Select record type
                                        </option>

                                        <option value="Minutes">
                                            Meeting Minutes
                                        </option>

                                        <option value="Audio">
                                            Audio Recording
                                        </option>

                                        <option value="Video">
                                            Video Recording
                                        </option>

                                        <option value="Minutes & Audio">
                                            Minutes & Audio
                                        </option>

                                        <option value="Minutes & Video">
                                            Minutes & Video
                                        </option>

                                        <option value=".pdf">
                                            PDF Document
                                        </option>

                                        <option value=".docx">
                                            Word Document
                                        </option>

                                        <option value=".mp3">
                                            MP3 Audio
                                        </option>

                                        <option value=".mp4">
                                            MP4 Video
                                        </option>

                                        <option value="Decision">
                                            Decision Record
                                        </option>

                                    </select>

                                </div>

                                <div class="form-group">

                                    <label>
                                        Description / Record Details
                                    </label>

                                    <textarea
                                        name="description"
                                        required
                                        placeholder="Describe the minutes, recording, or supporting material..."
                                    ></textarea>

                                </div>

                                <div class="form-group">

                                    <label>
                                        Media / Document Links
                                    </label>

                                    <textarea
                                        name="media_links"
                                        required
                                        placeholder="https://drive.google.com/...

https://drive.google.com/..."
                                    ></textarea>

                                    <p class="subtitle">
                                        Enter one URL per line.
                                        Maximum 10 links per record.
                                    </p>

                                </div>

                                <div class="info">

                                    <strong>
                                        How to add a recording:
                                    </strong>

                                    <div style="margin-top:8px">
                                        1. Upload the MP3 or MP4
                                        to your authorized cloud storage.
                                    </div>

                                    <div>
                                        2. Copy its sharing link.
                                    </div>

                                    <div>
                                        3. Paste the link above
                                        and save the record.
                                    </div>

                                    <div style="margin-top:8px">
                                        The system stores the link
                                        in the Media_Links relation.
                                    </div>

                                </div>

                                <button
                                    type="submit"
                                    class="button gold"
                                >
                                    + Save Media Record
                                </button>

                            </form>

                        <?php else: ?>

                            <div class="info warning">
                                Media uploads are closed
                                for cancelled meetings.
                            </div>

                        <?php endif; ?>

                    </section>

                <?php endif; ?>

            <?php else: ?>

                <section class="card">

                    <div class="empty">
                        Select a meeting to view
                        its agendas and documents.
                    </div>

                </section>

            <?php endif; ?>

        </div>

    </div>

    <footer class="footer">
        DataVerse © <?= date('Y') ?>
        · Department of Computing
        · Rajarata University of Sri Lanka
    </footer>

</main>

</body>
</html>
