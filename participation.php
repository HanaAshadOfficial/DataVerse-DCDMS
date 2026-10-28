
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

function formatDate($value) {
    return $value ? date('d M Y', strtotime($value)) : 'Not set';
}

function formatTime($value) {
    return $value ? date('g:i A', strtotime($value)) : 'TBA';
}

function runQuery($conn, $sql, $types = '', $params = []) {
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new RuntimeException($conn->error);
    }

    if ($types !== '') {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        throw new RuntimeException($stmt->error);
    }

    return $stmt;
}

function canAccessMeeting($meeting, $role, $assigned) {
    $private = $meeting['IsPrivate'] === 'Yes';
    $type = $meeting['ShortName'];

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

$userId = (string)$_SESSION['user_id'];
$userName = (string)($_SESSION['user_name'] ?? 'Team member');
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
    exit('Unauthorized role.');
}

$canManage = in_array($role, ['HOD', 'Clerk'], true);

if (empty($_SESSION['participation_csrf'])) {
    $_SESSION['participation_csrf'] = bin2hex(random_bytes(32));
}

$csrf = $_SESSION['participation_csrf'];

$selectedId = trim((string)($_GET['meeting_id'] ?? ''));

$error = '';
$success = '';

/*
|--------------------------------------------------------------------------
| PROCESS CONFIRMATION AND ATTENDANCE
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    $meetingId = trim((string)($_POST['meeting_id'] ?? ''));
    $selectedId = $meetingId;

    try {

        if (!hash_equals(
            $csrf,
            (string)($_POST['csrf'] ?? '')
        )) {
            throw new RuntimeException(
                'Invalid request. Please refresh the page.'
            );
        }

        $stmt = runQuery(
            $conn,
            "SELECT
                m.MeetingId,
                m.Meeting_Status,
                mt.ShortName,
                mt.IsPrivate
             FROM Meeting m
             JOIN MeetingType mt ON mt.TypeID = m.TypeID
             WHERE m.MeetingId = ?",
            's',
            [$meetingId]
        );

        $meeting = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$meeting) {
            throw new RuntimeException('Meeting not found.');
        }

        $stmt = runQuery(
            $conn,
            "SELECT 1
             FROM Attends
             WHERE UserID = ?
               AND MeetingId = ?",
            'ss',
            [$userId, $meetingId]
        );

        $assigned = $stmt->get_result()->num_rows > 0;
        $stmt->close();

        if (!canAccessMeeting($meeting, $role, $assigned)) {
            throw new RuntimeException(
                'You are not authorized for this meeting.'
            );
        }

        $action = (string)($_POST['action'] ?? '');

        /*
        |--------------------------------------------------------------------------
        | CONFIRM OR DECLINE PARTICIPATION
        |--------------------------------------------------------------------------
        */

        if ($action === 'confirm') {

            if (in_array(
                $meeting['Meeting_Status'],
                ['Completed', 'Cancelled'],
                true
            )) {
                throw new RuntimeException(
                    'Confirmation is closed for this meeting.'
                );
            }

            $response = (string)($_POST['response'] ?? '');

            if (!in_array(
                $response,
                ['Confirmed', 'Declined'],
                true
            )) {
                throw new RuntimeException('Invalid response.');
            }

            /*
             * Student Coordinators participate in Department Meetings.
             * For an older DM record without their assignment,
             * create the missing invitation.
             */

            if (
                !$assigned
                && $role === 'StudentCoordinator'
                && $meeting['ShortName'] === 'DM'
            ) {

                $stmt = runQuery(
                    $conn,
                    "INSERT INTO Attends
                        (UserID, MeetingId, Att_Status)
                     VALUES (?, ?, 'Invited')",
                    'ss',
                    [$userId, $meetingId]
                );

                $stmt->close();
                $assigned = true;
            }

            if (!$assigned) {
                throw new RuntimeException(
                    'You must be assigned before confirming.'
                );
            }

            /*
             * Check whether the participant already has
             * a confirmation record.
             */

            $stmt = runQuery(
                $conn,
                "SELECT ConfirmationID
                 FROM MeetingConfirmation
                 WHERE UserID = ?
                   AND MeetingId = ?",
                'ss',
                [$userId, $meetingId]
            );

            $existing = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if ($existing) {

                $stmt = runQuery(
                    $conn,
                    "UPDATE MeetingConfirmation
                     SET Confirmation_Status = ?,
                         ResponseDate = CURDATE()
                     WHERE UserID = ?
                       AND MeetingId = ?",
                    'sss',
                    [$response, $userId, $meetingId]
                );

            } else {

                $confirmationId = 'C' .
                    strtoupper(bin2hex(random_bytes(4)));

                $stmt = runQuery(
                    $conn,
                    "INSERT INTO MeetingConfirmation
                        (
                            ConfirmationID,
                            Confirmation_Status,
                            ResponseDate,
                            UserID,
                            MeetingId
                        )
                     VALUES (?, ?, CURDATE(), ?, ?)",
                    'ssss',
                    [
                        $confirmationId,
                        $response,
                        $userId,
                        $meetingId
                    ]
                );
            }

            $stmt->close();

            header(
                'Location: participation.php?meeting_id=' .
                urlencode($meetingId) .
                '&saved=confirmation'
            );
            exit;
        }

        /*
        |--------------------------------------------------------------------------
        | RECORD ACTUAL ATTENDANCE
        |--------------------------------------------------------------------------
        */

        if ($action === 'attendance') {

            if (
                !$canManage
                || (
                    $role === 'Clerk'
                    && $meeting['IsPrivate'] === 'Yes'
                )
            ) {
                throw new RuntimeException(
                    'You cannot manage attendance for this meeting.'
                );
            }

            if ($meeting['Meeting_Status'] === 'Cancelled') {
                throw new RuntimeException(
                    'Attendance is closed for cancelled meetings.'
                );
            }

            $participantId = trim(
                (string)($_POST['participant_id'] ?? '')
            );

            $status = (string)(
                $_POST['attendance_status'] ?? ''
            );

            if (!in_array(
                $status,
                ['Invited', 'Present', 'Absent', 'Excused'],
                true
            )) {
                throw new RuntimeException(
                    'Invalid attendance status.'
                );
            }

            $stmt = runQuery(
                $conn,
                "UPDATE Attends
                 SET Att_Status = ?
                 WHERE UserID = ?
                   AND MeetingId = ?",
                'sss',
                [$status, $participantId, $meetingId]
            );

            $stmt->close();

            header(
                'Location: participation.php?meeting_id=' .
                urlencode($meetingId) .
                '&saved=attendance'
            );
            exit;
        }

        throw new RuntimeException('Unknown action.');

    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

/*
|--------------------------------------------------------------------------
| SUCCESS MESSAGES
|--------------------------------------------------------------------------
*/

if (($_GET['saved'] ?? '') === 'confirmation') {
    $success = 'Your participation response was saved.';
}

if (($_GET['saved'] ?? '') === 'attendance') {
    $success = 'Attendance was updated successfully.';
}

/*
|--------------------------------------------------------------------------
| LOAD AVAILABLE MEETINGS
|--------------------------------------------------------------------------
*/

$meetings = [];
$selected = null;
$participants = [];

try {

    $stmt = runQuery(
        $conn,
        "SELECT
            m.MeetingId,
            m.PlannedDate,
            m.ActualDate,
            m.StartTime,
            m.EndTime,
            m.Venue,
            m.Meeting_Status,
            mt.Name AS MeetingName,
            mt.ShortName,
            mt.IsPrivate,
            mt.CalendarColorHex,
            a.Att_Status AS MyAttendance,
            COALESCE(
                mc.Confirmation_Status,
                'Pending'
            ) AS MyConfirmation
         FROM Meeting m
         JOIN MeetingType mt
            ON mt.TypeID = m.TypeID
         LEFT JOIN Attends a
            ON a.MeetingId = m.MeetingId
            AND a.UserID = ?
         LEFT JOIN MeetingConfirmation mc
            ON mc.MeetingId = m.MeetingId
            AND mc.UserID = ?
         ORDER BY
            CASE
                WHEN m.PlannedDate >= CURDATE()
                THEN 0 ELSE 1
            END,
            CASE
                WHEN m.PlannedDate >= CURDATE()
                THEN m.PlannedDate
            END ASC,
            m.PlannedDate DESC",
        'ss',
        [$userId, $userId]
    );

    $result = $stmt->get_result();

    while ($meeting = $result->fetch_assoc()) {

        $assigned = $meeting['MyAttendance'] !== null;

        if (canAccessMeeting($meeting, $role, $assigned)) {
            $meetings[] = $meeting;
        }
    }

    $stmt->close();

    /*
     * Select meeting from dashboard link,
     * or select the first available meeting.
     */

    if ($selectedId !== '') {

        foreach ($meetings as $meeting) {

            if ($meeting['MeetingId'] === $selectedId) {
                $selected = $meeting;
                break;
            }
        }

        if (!$selected) {
            $error = 'This meeting is not available to your role.';
        }

    } elseif (!empty($meetings)) {

        $selected = $meetings[0];
        $selectedId = $selected['MeetingId'];
    }

    /*
    |--------------------------------------------------------------------------
    | LOAD PARTICIPANTS FOR SELECTED MEETING
    |--------------------------------------------------------------------------
    */

    if ($selected) {

        $stmt = runQuery(
            $conn,
            "SELECT
                u.UserID,
                u.Name,
                u.RoleType,
                a.Att_Status,
                COALESCE(
                    mc.Confirmation_Status,
                    'Pending'
                ) AS Confirmation_Status
             FROM Attends a
             JOIN `User` u
                ON u.UserID = a.UserID
             LEFT JOIN MeetingConfirmation mc
                ON mc.UserID = a.UserID
                AND mc.MeetingId = a.MeetingId
             WHERE a.MeetingId = ?
             ORDER BY
                FIELD(
                    u.RoleType,
                    'HOD',
                    'AcademicStaff',
                    'Clerk',
                    'SupportStaff',
                    'StudentCoordinator'
                ),
                u.Name",
            's',
            [$selectedId]
        );

        $result = $stmt->get_result();

        while ($participant = $result->fetch_assoc()) {
            $participants[] = $participant;
        }

        $stmt->close();
    }

} catch (Throwable $e) {

    $error = 'Unable to load participation records: ' .
        $e->getMessage();
}

/*
|--------------------------------------------------------------------------
| CALCULATE QUORUM
|--------------------------------------------------------------------------
*/

$total = count($participants);

$confirmed = 0;
$declined = 0;

$present = 0;
$absent = 0;
$excused = 0;

foreach ($participants as $participant) {

    if ($participant['Confirmation_Status'] === 'Confirmed') {
        $confirmed++;
    }

    if ($participant['Confirmation_Status'] === 'Declined') {
        $declined++;
    }

    if ($participant['Att_Status'] === 'Present') {
        $present++;
    }

    if ($participant['Att_Status'] === 'Absent') {
        $absent++;
    }

    if ($participant['Att_Status'] === 'Excused') {
        $excused++;
    }
}

$pending = $total - $confirmed - $declined;

$required = (int)ceil($total * 2 / 3);

$confirmationQuorum = (
    $total > 0
    && $confirmed >= $required
);

$attendanceQuorum = (
    $total > 0
    && $present >= $required
);

$confirmationPercent = $total > 0
    ? round(($confirmed / $total) * 100)
    : 0;

$attendancePercent = $total > 0
    ? round(($present / $total) * 100)
    : 0;

/*
|--------------------------------------------------------------------------
| CURRENT USER PERMISSIONS
|--------------------------------------------------------------------------
*/

$myAssigned = (
    $selected
    && $selected['MyAttendance'] !== null
);

$myResponse = $selected['MyConfirmation'] ?? 'Pending';

$studentDepartmentMeeting = (
    $selected
    && $role === 'StudentCoordinator'
    && $selected['ShortName'] === 'DM'
);

$canRespond = (
    $selected
    && ($myAssigned || $studentDepartmentMeeting)
    && !in_array(
        $selected['Meeting_Status'],
        ['Completed', 'Cancelled'],
        true
    )
);

$showDetails = (
    $selected
    && (
        $role === 'HOD'
        || (
            $role === 'Clerk'
            && $selected['IsPrivate'] === 'No'
        )
    )
);

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

<title>DataVerse | Attendance & Quorum</title>

<style>

:root {
    --navy: #102f3e;
    --navy2: #194b5c;
    --gold: #f4c45c;
    --bg: #edf3f5;
    --text: #173447;
    --muted: #708797;
    --border: #e3ebef;
    --green: #168455;
    --red: #ba4444;
}

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: "Segoe UI", Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
}

button,
input,
select {
    font: inherit;
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
    align-items: center;
    justify-content: space-between;
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
    grid-template-columns: 310px minmax(0, 1fr);
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

.badge.red {
    background: #fff0f0;
    color: var(--red);
}

.badge.gold {
    background: #fff3d7;
    color: #a77512;
}

.badge.blue {
    background: #e9f1fb;
    color: #376a9c;
}

.stats {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 14px;
    margin: 22px 0;
}

.stat {
    background: #f8fafb;
    border: 1px solid var(--border);
    border-radius: 13px;
    padding: 17px;
}

.stat-label {
    color: var(--muted);
    font-size: 11px;
}

.stat-number {
    font-size: 27px;
    font-weight: 800;
    margin-top: 9px;
}

.progress {
    height: 13px;
    border-radius: 20px;
    overflow: hidden;
    background: #e8eef1;
    margin: 13px 0;
}

.progress-fill {
    height: 100%;
    background: var(--gold);
    border-radius: 20px;
}

.progress-fill.green {
    background: #2dbb80;
}

.quorum-box {
    border-radius: 13px;
    padding: 18px;
    margin-top: 18px;
    background: #f8fafb;
    border: 1px solid var(--border);
}

.quorum-box.reached {
    background: #eaf8f0;
    border-color: #bfe7d0;
}

.quorum-box.pending {
    background: #fff9ed;
    border-color: #f4e5c0;
}

.quorum-title {
    font-weight: 800;
    margin-bottom: 7px;
}

.button {
    border: 0;
    padding: 11px 16px;
    border-radius: 9px;
    cursor: pointer;
    font-size: 12px;
    font-weight: 800;
    color: white;
    background: var(--navy);
}

.button.green {
    background: var(--green);
}

.button.red {
    background: #fff0f0;
    color: var(--red);
}

.button.small {
    padding: 8px 11px;
    font-size: 11px;
}

.button-row {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-top: 15px;
}

.detail-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin: 20px 0;
}

.detail {
    background: #f8fafb;
    padding: 15px;
    border-radius: 11px;
}

.detail-label {
    color: var(--muted);
    font-size: 11px;
    margin-bottom: 7px;
}

.detail-value {
    font-size: 13px;
    font-weight: 700;
}

.section-heading {
    font-size: 17px;
    font-weight: 800;
    margin: 24px 0 10px;
}

.table-wrap {
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
    text-align: left;
}

th {
    background: #f7fafb;
    color: #8195a1;
    padding: 13px 11px;
    font-size: 11px;
}

td {
    padding: 13px 11px;
    border-bottom: 1px solid #edf1f3;
    font-size: 12px;
}

select {
    width: 100%;
    padding: 9px;
    border: 1px solid #d9e4e9;
    border-radius: 8px;
    background: white;
}

.inline-form {
    display: flex;
    gap: 8px;
    align-items: center;
}

.notice {
    border-radius: 11px;
    padding: 15px;
    font-size: 13px;
    margin-bottom: 18px;
}

.notice.success {
    background: #e5f7ed;
    color: #218455;
}

.notice.error {
    background: #fff0f0;
    color: #b65353;
}

.info-text {
    font-size: 12px;
    line-height: 1.8;
    color: var(--muted);
}

.empty {
    text-align: center;
    color: var(--muted);
    padding: 35px 12px;
}

.footer {
    text-align: center;
    font-size: 11px;
    color: #92a1ab;
    margin-top: 30px;
}

@media (max-width: 1150px) {
    .layout {
        grid-template-columns: 1fr;
    }

    .stats {
        grid-template-columns: repeat(2, 1fr);
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

    .stats,
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
                class="nav-link <?= $item[1] === 'participation.php' ? 'active' : '' ?>"
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

            <h1>Attendance & Quorum</h1>

            <p class="subtitle">
                Confirm participation, monitor quorum,
                and record actual meeting attendance.
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
            PARTICIPATION MANAGEMENT WORKSPACE
        </div>

        <h2>Meeting Confirmation & Quorum</h2>

        <p>
            Respond to meeting invitations.
            Quorum is calculated automatically
            from confirmed participants.
        </p>

    </section>

    <div class="layout">

        <!-- AVAILABLE MEETINGS -->

        <div>

            <section class="card">

                <h2>Available Meetings</h2>

                <p class="subtitle">
                    Select a meeting to view its confirmation
                    and quorum details.
                </p>

                <div class="meeting-list">

                    <?php if (!$meetings): ?>

                        <div class="empty">
                            No meetings are available.
                        </div>

                    <?php endif; ?>

                    <?php foreach ($meetings as $meeting): ?>

                        <a
                            href="participation.php?meeting_id=<?= urlencode($meeting['MeetingId']) ?>"
                            class="meeting-link <?= $selectedId === $meeting['MeetingId'] ? 'selected' : '' ?>"
                        >

                            <strong>
                                <?= h($meeting['MeetingName']) ?>
                            </strong>

                            <small>
                                <?= h(formatDate($meeting['PlannedDate'])) ?>
                                ·
                                <?= h(formatTime($meeting['StartTime'])) ?>
                            </small>

                            <small>

                                <?= h($meeting['Meeting_Status']) ?>

                                <?php if ($meeting['MyAttendance'] !== null): ?>

                                    · Your response:
                                    <?= h($meeting['MyConfirmation']) ?>

                                <?php elseif (
                                    $role === 'StudentCoordinator'
                                    && $meeting['ShortName'] === 'DM'
                                ): ?>

                                    · Department-wide invitation

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

                    <span class="badge blue">
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
                                Meeting Date
                            </div>

                            <div class="detail-value">
                                <?= h(formatDate($selected['PlannedDate'])) ?>
                            </div>

                        </div>

                        <div class="detail">

                            <div class="detail-label">
                                Meeting Time
                            </div>

                            <div class="detail-value">
                                <?= h(formatTime($selected['StartTime'])) ?>
                                –
                                <?= h(formatTime($selected['EndTime'])) ?>
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
                                Meeting ID
                            </div>

                            <div class="detail-value">
                                <?= h($selected['MeetingId']) ?>
                            </div>

                        </div>

                    </div>

                    <h3 class="section-heading">
                        Your Participation Confirmation
                    </h3>

                    <?php if ($myAssigned || $studentDepartmentMeeting): ?>

                        <p class="info-text">
                            Your current response:
                            <strong>
                                <?= h($myResponse) ?>
                            </strong>
                        </p>

                        <?php if ($canRespond): ?>

                            <div class="button-row">

                                <form method="post">

                                    <input
                                        type="hidden"
                                        name="csrf"
                                        value="<?= h($csrf) ?>"
                                    >

                                    <input
                                        type="hidden"
                                        name="action"
                                        value="confirm"
                                    >

                                    <input
                                        type="hidden"
                                        name="meeting_id"
                                        value="<?= h($selectedId) ?>"
                                    >

                                    <input
                                        type="hidden"
                                        name="response"
                                        value="Confirmed"
                                    >

                                    <button
                                        type="submit"
                                        class="button green"
                                        onclick="return confirm('Confirm that you will attend this meeting?')"
                                    >
                                        ✓ Confirm Participation
                                    </button>

                                </form>

                                <form method="post">

                                    <input
                                        type="hidden"
                                        name="csrf"
                                        value="<?= h($csrf) ?>"
                                    >

                                    <input
                                        type="hidden"
                                        name="action"
                                        value="confirm"
                                    >

                                    <input
                                        type="hidden"
                                        name="meeting_id"
                                        value="<?= h($selectedId) ?>"
                                    >

                                    <input
                                        type="hidden"
                                        name="response"
                                        value="Declined"
                                    >

                                    <button
                                        type="submit"
                                        class="button red"
                                        onclick="return confirm('Decline this meeting invitation?')"
                                    >
                                        Decline
                                    </button>

                                </form>

                            </div>

                        <?php else: ?>

                            <p class="info-text">
                                Confirmation is closed for this meeting.
                            </p>

                        <?php endif; ?>

                    <?php else: ?>

                        <p class="info-text">
                            You can view this meeting, but you have
                            not been assigned as a participant.
                        </p>

                    <?php endif; ?>

                </section>

                <!-- QUORUM -->

                <section class="card">

                    <h2>Confirmation-Based Quorum</h2>

                    <p class="subtitle">
                        Automatically calculated from saved
                        confirmation responses.
                    </p>

                    <div class="stats">

                        <div class="stat">

                            <div class="stat-label">
                                Invited
                            </div>

                            <div class="stat-number">
                                <?= $total ?>
                            </div>

                        </div>

                        <div class="stat">

                            <div class="stat-label">
                                Confirmed
                            </div>

                            <div class="stat-number">
                                <?= $confirmed ?>
                            </div>

                        </div>

                        <div class="stat">

                            <div class="stat-label">
                                Pending
                            </div>

                            <div class="stat-number">
                                <?= $pending ?>
                            </div>

                        </div>

                        <div class="stat">

                            <div class="stat-label">
                                Required
                            </div>

                            <div class="stat-number">
                                <?= $required ?>
                            </div>

                        </div>

                    </div>

                    <div class="progress">

                        <div
                            class="progress-fill <?= $confirmationQuorum ? 'green' : '' ?>"
                            style="width:<?= $confirmationPercent ?>%"
                        ></div>

                    </div>

                    <p class="info-text">
                        <?= $confirmed ?> of <?= $total ?>
                        invited participants confirmed
                        (<?= $confirmationPercent ?>%).
                        <?= $declined ?> declined.
                    </p>

                    <div class="quorum-box <?= $confirmationQuorum ? 'reached' : 'pending' ?>">

                        <?php if ($confirmationQuorum): ?>

                            <div class="quorum-title">
                                ✓ Confirmation Quorum Reached
                            </div>

                            <div class="info-text">
                                At least two-thirds of assigned
                                participants have confirmed.
                            </div>

                        <?php else: ?>

                            <div class="quorum-title">
                                Confirmation Quorum Pending
                            </div>

                            <div class="info-text">

                                <?php if ($total === 0): ?>

                                    No participants have been assigned yet.

                                <?php else: ?>

                                    <?= max(0, $required - $confirmed) ?>
                                    more confirmation(s) required.

                                <?php endif; ?>

                            </div>

                        <?php endif; ?>

                    </div>

                    <h3 class="section-heading">
                        Actual Attendance Quorum
                    </h3>

                    <div class="progress">

                        <div
                            class="progress-fill <?= $attendanceQuorum ? 'green' : '' ?>"
                            style="width:<?= $attendancePercent ?>%"
                        ></div>

                    </div>

                    <p class="info-text">

                        <?= $present ?> present,
                        <?= $absent ?> absent,
                        <?= $excused ?> excused.

                        Required:
                        <?= $required ?> present.

                        <strong>

                            <?= $attendanceQuorum
                                ? 'Actual quorum reached.'
                                : 'Actual quorum not yet reached.' ?>

                        </strong>

                    </p>

                    <p class="info-text">
                        Confirmation quorum and actual attendance quorum
                        are separate. Confirming does not automatically
                        mark someone as present.
                    </p>

                </section>

                <!-- PARTICIPANT MANAGEMENT -->

                <?php if ($showDetails): ?>

                    <section class="card">

                        <h2>Participant Management</h2>

                        <p class="subtitle">
                            View participant responses
                            and record actual attendance.
                        </p>

                        <div class="table-wrap">

                            <table>

                                <thead>

                                    <tr>
                                        <th>Participant</th>
                                        <th>Role</th>
                                        <th>Confirmation</th>
                                        <th>Attendance</th>
                                    </tr>

                                </thead>

                                <tbody>

                                    <?php foreach ($participants as $participant): ?>

                                        <?php

                                        $response = $participant['Confirmation_Status'];

                                        $badgeColor = $response === 'Confirmed'
                                            ? 'green'
                                            : (
                                                $response === 'Declined'
                                                ? 'red'
                                                : 'gold'
                                            );

                                        ?>

                                        <tr>

                                            <td>
                                                <strong>
                                                    <?= h($participant['Name']) ?>
                                                </strong>
                                            </td>

                                            <td>
                                                <?= h(
                                                    $roleNames[$participant['RoleType']]
                                                    ?? $participant['RoleType']
                                                ) ?>
                                            </td>

                                            <td>

                                                <span class="badge <?= $badgeColor ?>">
                                                    <?= h($response) ?>
                                                </span>

                                            </td>

                                            <td>

                                                <form
                                                    method="post"
                                                    class="inline-form"
                                                >

                                                    <input
                                                        type="hidden"
                                                        name="csrf"
                                                        value="<?= h($csrf) ?>"
                                                    >

                                                    <input
                                                        type="hidden"
                                                        name="action"
                                                        value="attendance"
                                                    >

                                                    <input
                                                        type="hidden"
                                                        name="meeting_id"
                                                        value="<?= h($selectedId) ?>"
                                                    >

                                                    <input
                                                        type="hidden"
                                                        name="participant_id"
                                                        value="<?= h($participant['UserID']) ?>"
                                                    >

                                                    <select
                                                        name="attendance_status"
                                                        aria-label="Attendance status"
                                                    >

                                                        <?php foreach (
                                                            ['Invited', 'Present', 'Absent', 'Excused']
                                                            as $status
                                                        ): ?>

                                                            <option
                                                                value="<?= h($status) ?>"
                                                                <?= $participant['Att_Status'] === $status ? 'selected' : '' ?>
                                                            >
                                                                <?= h($status) ?>
                                                            </option>

                                                        <?php endforeach; ?>

                                                    </select>

                                                    <button
                                                        type="submit"
                                                        class="button small"
                                                    >
                                                        Save
                                                    </button>

                                                </form>

                                            </td>

                                        </tr>

                                    <?php endforeach; ?>

                                </tbody>

                            </table>

                        </div>

                    </section>

                <?php else: ?>

                    <section class="card">

                        <h2>Participation Information</h2>

                        <p class="info-text">
                            Individual participant records are
                            restricted to authorized meeting administrators.

                            You can see your own response and
                            the overall quorum status.
                        </p>

                    </section>

                <?php endif; ?>

            <?php else: ?>

                <section class="card">

                    <div class="empty">
                        Select an available meeting to view
                        its confirmation and quorum information.
                    </div>

                </section>

            <?php endif; ?>

        </div>

    </div>

    <div class="footer">
        DataVerse © <?= date('Y') ?>
        · Department of Computing
        · Rajarata University of Sri Lanka
    </div>

</main>

<?php if (
    ($_GET['saved'] ?? '') === 'confirmation'
    && $confirmationQuorum
): ?>

<script>
window.addEventListener('load', function () {
    alert(
        'Confirmation quorum has been reached for this meeting!'
    );
});
</script>

<?php endif; ?>

</body>
</html>
