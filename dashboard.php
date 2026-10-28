
<?php
session_start();

if (empty($_SESSION['user_id']) || empty($_SESSION['user_role'])) {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config.php';

function h($value) {
    return htmlspecialchars((string)($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function displayDate($date) {
    return $date ? date('d M Y', strtotime($date)) : 'Not set';
}

function displayTime($time) {
    return $time ? date('g:i A', strtotime($time)) : 'TBA';
}

function meetingAccessible($meeting, $role) {
    $type = (string)$meeting['ShortName'];
    $private = $meeting['IsPrivate'] === 'Yes';
    $assigned = $meeting['AssignedUser'] !== null;

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
        return !$private && $assigned && in_array($type, ['DM', 'SW'], true);
    }

    if ($role === 'StudentCoordinator') {
        return !$private && (
            $type === 'DM' ||
            ($assigned && in_array($type, ['SC', 'CP'], true))
        );
    }

    return false;
}

function canConfirmMeeting($meeting, $role) {
    if (!in_array($meeting['Meeting_Status'], ['Planned', 'Scheduled', 'Postponed'], true)) {
        return false;
    }

    if ($meeting['PlannedDate'] < date('Y-m-d')) {
        return false;
    }

    return $meeting['AssignedUser'] !== null ||
        ($role === 'StudentCoordinator' && $meeting['ShortName'] === 'DM');
}

function isPendingConfirmation($meeting, $role) {
    return canConfirmMeeting($meeting, $role) &&
        !in_array($meeting['MyConfirmation'], ['Confirmed', 'Declined'], true);
}

$userId = (string)$_SESSION['user_id'];
$userName = (string)($_SESSION['user_name'] ?? 'Team Member');
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

$isHOD = $role === 'HOD';
$isClerk = $role === 'Clerk';
$isManager = $isHOD || $isClerk;

$initials = strtoupper(substr(preg_replace('/[^a-z]/i', '', $userName), 0, 2));

$today = date('Y-m-d');
$meetings = [];
$upcoming = [];
$pendingMeetings = [];
$completed = 0;
$missingAgendas = 0;
$totalVisible = 0;
$totalUsers = 0;
$totalMeetingTypes = 0;
$openActionItems = 0;
$error = '';

try {
    $sql = "
        SELECT
            m.MeetingId,
            m.PlannedDate,
            m.ActualDate,
            m.StartTime,
            m.EndTime,
            m.Venue,
            m.Meeting_Status,
            m.Agenda_id,
            mt.Name AS MeetingName,
            mt.ShortName,
            mt.IsPrivate,
            a.UserID AS AssignedUser,
            a.Att_Status AS MyAttendance,
            COALESCE(mc.Confirmation_Status, 'Pending') AS MyConfirmation,
            ag.Name AS AgendaName
        FROM Meeting m
        JOIN MeetingType mt ON mt.TypeID = m.TypeID
        LEFT JOIN Attends a
            ON a.MeetingId = m.MeetingId AND a.UserID = ?
        LEFT JOIN MeetingConfirmation mc
            ON mc.MeetingId = m.MeetingId AND mc.UserID = ?
        LEFT JOIN Agenda ag ON ag.Agenda_id = m.Agenda_id
        ORDER BY m.PlannedDate ASC, m.StartTime ASC
    ";

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new RuntimeException($conn->error);
    }

    $stmt->bind_param('ss', $userId, $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    while ($meeting = $result->fetch_assoc()) {
        if (!meetingAccessible($meeting, $role)) {
            continue;
        }

        $meetings[] = $meeting;
        $totalVisible++;

        if ($meeting['Meeting_Status'] === 'Completed') {
            $completed++;
        }

        if (
            $meeting['PlannedDate'] >= $today &&
            !in_array($meeting['Meeting_Status'], ['Completed', 'Cancelled'], true)
        ) {
            $upcoming[] = $meeting;

            if (isPendingConfirmation($meeting, $role)) {
                $pendingMeetings[] = $meeting;
            }

            if ($isManager && empty($meeting['Agenda_id'])) {
                $missingAgendas++;
            }
        }
    }

    $stmt->close();

} catch (Throwable $e) {
    error_log('Dashboard meeting error: ' . $e->getMessage());
    $error = 'Unable to load some dashboard information.';
}

if ($isHOD) {
    try {
        $result = $conn->query("SELECT COUNT(*) AS total FROM `User`");
        if ($result) {
            $totalUsers = (int)$result->fetch_assoc()['total'];
        }

        $result = $conn->query("SELECT COUNT(*) AS total FROM MeetingType");
        if ($result) {
            $totalMeetingTypes = (int)$result->fetch_assoc()['total'];
        }

        $result = $conn->query("
            SELECT COUNT(*) AS total
            FROM MediaRecord
            WHERE TaskStatus IN ('Pending', 'In Progress')
        ");
        if ($result) {
            $openActionItems = (int)$result->fetch_assoc()['total'];
        }
    } catch (Throwable $e) {
        error_log('Dashboard KPI error: ' . $e->getMessage());
    }
}

$nextMeetings = array_slice($upcoming, 0, 6);
$nextPending = $pendingMeetings[0] ?? null;
$pendingCount = count($pendingMeetings);

if ($isHOD) {
    $stats = [
        ['Total Users', $totalUsers, 'Registered users'],
        ['Meeting Categories', $totalMeetingTypes, 'Department meeting types'],
        ['Upcoming Meetings', count($upcoming), 'Scheduled or planned'],
        ['Completed Meetings', $completed, 'Recorded meetings'],
        ['Open Action Items', $openActionItems, 'Pending or in progress'],
        ['Awaiting Your Confirmation', $pendingCount, 'Your meeting invitations']
    ];
} else {
    $stats = [
        ['Available Meetings', $totalVisible, 'Visible to your role'],
        ['Upcoming Meetings', count($upcoming), 'Future meetings'],
        ['Awaiting Confirmation', $pendingCount, 'Your pending responses'],
        ['Completed Meetings', $completed, 'Visible meeting records']
    ];
}

$nav = [
    ['Dashboard', 'dashboard.php', '◫'],
    ['Annual Planning', 'annual_plan.php', '▦'],
    ['Meetings & Scheduling', 'meetings.php', '▣'],
    ['Attendance & Quorum', 'participation.php', '♧'],
    ['Meeting Records & Decisions', 'documents.php', '▤']
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DataVerse | Dashboard</title>

<style>
:root {
    --navy: #102f3e;
    --navy-light: #194b5c;
    --gold: #f4c45c;
    --background: #edf3f5;
    --text: #173447;
    --muted: #718899;
    --border: #e1e9ee;
    --green: #188456;
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

button {
    font: inherit;
}

.sidebar {
    width: 258px;
    background: var(--navy);
    color: white;
    position: fixed;
    top: 0;
    bottom: 0;
    left: 0;
    padding: 28px 18px;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
    z-index: 20;
}

.brand {
    padding: 12px 14px 26px;
    border-bottom: 1px solid #ffffff20;
    margin-bottom: 25px;
}

.brand-name {
    font-size: 30px;
    font-weight: 800;
    letter-spacing: -1px;
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
    padding: 15px;
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
    width: 42px;
    height: 42px;
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
    min-width: 0;
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
    font-size: 31px;
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
    white-space: nowrap;
}

.hero {
    background: linear-gradient(115deg, var(--navy), var(--navy-light));
    color: white;
    border-radius: 20px;
    padding: 32px 35px;
    margin-bottom: 25px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
}

.hero h2 {
    font-size: 27px;
    margin: 10px 0;
}

.hero p {
    color: #d4e3e9;
    font-size: 13px;
    line-height: 1.8;
}

.hero-date {
    background: #ffffff18;
    border: 1px solid #ffffff25;
    padding: 13px 17px;
    border-radius: 11px;
    font-size: 12px;
    font-weight: 700;
    white-space: nowrap;
}

.stats {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 17px;
    margin-bottom: 25px;
}

.stat {
    background: white;
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 23px;
    min-width: 0;
}

.stat-label {
    color: var(--muted);
    font-size: 12px;
}

.stat-value {
    font-size: 34px;
    font-weight: 800;
    margin: 15px 0 6px;
    color: var(--navy);
}

.stat-note {
    color: #92a4af;
    font-size: 11px;
}

.content-grid {
    display: grid;
    grid-template-columns: minmax(0, 1.65fr) minmax(280px, 1fr);
    gap: 22px;
    align-items: start;
}

.content-column {
    min-width: 0;
}

.card {
    background: white;
    border: 1px solid var(--border);
    border-radius: 17px;
    padding: 24px;
    margin-bottom: 22px;
    min-width: 0;
}

.card h2 {
    font-size: 19px;
    margin: 0 0 8px;
}

.card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 15px;
    margin-bottom: 18px;
}

.meeting-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 15px;
    padding: 18px 0;
    border-bottom: 1px solid #edf1f3;
}

.meeting-item:last-child {
    border-bottom: none;
}

.meeting-item > div:first-child {
    min-width: 0;
}

.meeting-name {
    font-size: 13px;
    font-weight: 800;
    line-height: 1.5;
}

.meeting-meta {
    color: var(--muted);
    font-size: 11px;
    line-height: 1.8;
    margin-top: 5px;
}

.meeting-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 7px;
    justify-content: flex-end;
}

.button {
    display: inline-block;
    padding: 11px 15px;
    border: 0;
    border-radius: 9px;
    background: var(--navy);
    color: white;
    font-size: 12px;
    font-weight: 800;
    text-decoration: none;
    cursor: pointer;
    text-align: center;
}

.button:hover {
    background: var(--navy-light);
}

.button.gold {
    background: var(--gold);
    color: var(--navy);
}

.button.outline {
    background: #eef3f6;
    color: var(--navy);
}

.button.small {
    padding: 9px 11px;
    font-size: 11px;
}

.badge {
    display: inline-block;
    padding: 7px 10px;
    border-radius: 20px;
    background: #edf1f4;
    color: #607582;
    font-size: 10px;
    font-weight: 800;
}

.badge.green {
    background: #e5f7ed;
    color: #188456;
}

.badge.gold {
    background: #fff3d7;
    color: #a77512;
}

.badge.blue {
    background: #e9f1fb;
    color: #376a9c;
}

.alert-item {
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 15px;
    margin-top: 12px;
}

.alert-item.warning {
    background: #fff9ed;
    border-color: #f2e4be;
}

.alert-item.success {
    background: #eff9f3;
    border-color: #ccebd8;
}

.alert-title {
    font-size: 13px;
    font-weight: 800;
}

.alert-text {
    color: #718899;
    font-size: 12px;
    line-height: 1.7;
    margin: 7px 0 12px;
}

.quick-links {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
    margin-top: 20px;
}

.quick-link {
    background: #f7fafb;
    border: 1px solid var(--border);
    padding: 17px;
    border-radius: 12px;
    color: var(--navy);
    text-decoration: none;
    font-size: 12px;
    font-weight: 800;
    line-height: 1.6;
}

.quick-link:hover {
    border-color: var(--gold);
    background: #fffaf0;
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

/* Confirmation reminder modal */

.modal-overlay,
.dv-live-overlay {
    position: fixed;
    inset: 0;
    background: rgba(7, 27, 39, .70);
    display: none;
    justify-content: center;
    align-items: center;
    padding: 20px;
    z-index: 1000;
}

.modal-overlay.show,
.dv-live-overlay.show {
    display: flex;
}

.modal,
.dv-live-modal {
    background: white;
    width: 100%;
    max-width: 480px;
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 25px 70px #00000035;
}

.modal-top,
.dv-live-top {
    background: linear-gradient(115deg, var(--navy), var(--navy-light));
    padding: 27px 30px;
    color: white;
}

.modal-top h2,
.dv-live-top h2 {
    font-size: 23px;
    margin: 9px 0;
}

.modal-top p {
    font-size: 12px;
    line-height: 1.7;
    color: #d4e3e9;
}

.modal-body,
.dv-live-body {
    padding: 27px 30px;
}

.modal-detail {
    background: #f7fafb;
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 18px;
}

.modal-detail strong {
    display: block;
    font-size: 15px;
    line-height: 1.5;
}

.modal-detail span {
    display: block;
    color: var(--muted);
    font-size: 12px;
    margin-top: 7px;
    line-height: 1.6;
}

.modal-actions,
.dv-live-actions {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-top: 20px;
}

.modal-actions .button,
.dv-live-actions .button {
    flex: 1;
}

.modal-note {
    color: var(--muted);
    font-size: 11px;
    line-height: 1.6;
    margin-top: 15px;
}

/* Live notification bell */

.dv-notify-wrap {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    margin-bottom: 14px;
}

.dv-bell {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    border: 1px solid #d9e5eb;
    border-radius: 11px;
    padding: 10px 13px;
    background: white;
    color: var(--navy);
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
}

.dv-bell:hover {
    background: #fff8e8;
    border-color: var(--gold);
}

.dv-count {
    display: none;
    min-width: 20px;
    height: 20px;
    border-radius: 12px;
    background: #b84949;
    color: white;
    align-items: center;
    justify-content: center;
    font-size: 11px;
    padding: 0 5px;
}

.dv-count.visible {
    display: inline-flex;
}

.dv-notify-panel {
    display: none;
    position: absolute;
    right: 0;
    top: calc(100% + 9px);
    width: min(370px, calc(100vw - 35px));
    max-height: 440px;
    overflow: auto;
    background: white;
    border: 1px solid #dce6eb;
    border-radius: 14px;
    box-shadow: 0 15px 40px #112f3e25;
    z-index: 70;
    padding: 13px;
}

.dv-notify-panel.open {
    display: block;
}

.dv-notify-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 10px;
    padding: 4px 4px 12px;
    border-bottom: 1px solid #edf1f3;
}

.dv-notify-head strong {
    font-size: 14px;
}

.dv-notify-clear {
    border: 0;
    background: none;
    color: #1c566b;
    font-size: 11px;
    font-weight: 700;
    cursor: pointer;
}

.dv-notify-item {
    display: block;
    text-decoration: none;
    color: var(--text);
    padding: 13px 7px;
    border-bottom: 1px solid #edf1f3;
    border-radius: 6px;
}

.dv-notify-item:hover {
    background: #f5f9fa;
}

.dv-notify-item strong {
    display: block;
    font-size: 12px;
    line-height: 1.5;
}

.dv-notify-item span {
    display: block;
    font-size: 11px;
    color: var(--muted);
    margin-top: 5px;
    line-height: 1.5;
}

.dv-notify-empty {
    padding: 24px 8px;
    text-align: center;
    color: var(--muted);
    font-size: 12px;
}

.dv-live-top small {
    color: var(--gold);
    font-weight: 800;
    letter-spacing: 1.5px;
}

.dv-live-body p {
    font-size: 14px;
    line-height: 1.7;
}

.dv-live-date {
    font-size: 12px;
    color: var(--muted);
}

@media (max-width: 1200px) {
    .content-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 950px) {
    .stats {
        grid-template-columns: repeat(2, minmax(0, 1fr));
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
    .topbar,
    .hero,
    .meeting-item {
        flex-direction: column;
        align-items: stretch;
    }

    .stats,
    .quick-links {
        grid-template-columns: 1fr;
    }

    .meeting-actions {
        justify-content: flex-start;
    }

    .dv-notify-wrap {
        justify-content: flex-start;
    }

    .dv-notify-panel {
        right: auto;
        left: 0;
    }
}
</style>
</head>

<body>

<!-- SIDEBAR -->
<aside class="sidebar">
    <div class="brand">
        <div class="brand-name">Data<span>Verse</span></div>
        <div class="brand-desc">
            DEPARTMENT COMMUNICATION<br>
            MANAGEMENT SYSTEM
        </div>
    </div>

    <div class="nav-title">MAIN NAVIGATION</div>

    <nav>
        <?php foreach ($nav as $item): ?>
            <?php
            if (
                $item[1] === 'annual_plan.php' &&
                !in_array($role, ['HOD', 'Clerk', 'AcademicStaff'], true)
            ) {
                continue;
            }
            ?>
            <a href="<?= h($item[1]) ?>"
               class="nav-link <?= $item[1] === 'dashboard.php' ? 'active' : '' ?>">
                <span class="nav-icon"><?= h($item[2]) ?></span>
                <?= h($item[0]) ?>
            </a>
        <?php endforeach; ?>

        <?php if ($isHOD): ?>
            <a href="users.php" class="nav-link">
                <span class="nav-icon">♙</span>
                Users & Access
            </a>
        <?php endif; ?>
    </nav>

    <div class="sidebar-bottom">
        <div class="profile">
            <div class="avatar"><?= h($initials) ?></div>
            <div>
                <div class="profile-name"><?= h($userName) ?></div>
                <div class="profile-role"><?= h($roleNames[$role]) ?></div>
            </div>
        </div>

        <a href="logout.php" class="signout">↪ Sign Out</a>
    </div>
</aside>

<!-- MAIN DASHBOARD -->
<main class="main">

    <!-- NOTIFICATION CENTER -->
    <div class="dv-notify-wrap" id="dvNotificationCenter">
        <button type="button"
                class="dv-bell"
                id="dvBell"
                aria-expanded="false">
            🔔 Notifications
            <span class="dv-count" id="dvNotifyCount">0</span>
        </button>

        <div class="dv-notify-panel" id="dvNotifyPanel">
            <div class="dv-notify-head">
                <strong>Recent Notifications</strong>
                <button type="button"
                        class="dv-notify-clear"
                        id="dvMarkSeen">
                    Mark all seen
                </button>
            </div>
            <div id="dvNotifyList">
                <div class="dv-notify-empty">
                    Checking notifications...
                </div>
            </div>
        </div>
    </div>

    <!-- PAGE HEADER -->
    <header class="topbar">
        <div>
            <div class="eyebrow">DEPARTMENT OF COMPUTING</div>
            <h1>Dashboard</h1>
            <p class="subtitle">
                Monitor department meetings, confirmations,
                schedules, and upcoming activities.
            </p>
        </div>

        <div class="role-chip"><?= h($roleNames[$role]) ?></div>
    </header>

    <?php if ($error): ?>
        <div class="alert-item warning"><?= h($error) ?></div>
    <?php endif; ?>

    <!-- WELCOME -->
    <section class="hero">
        <div>
            <div class="eyebrow" style="color:var(--gold)">
                DATAVERSE WORKSPACE
            </div>

            <h2>Welcome back, <?= h($userName) ?></h2>

            <p>
                Stay informed about upcoming meetings,
                participation confirmations, and department activities.
            </p>
        </div>

        <div class="hero-date"><?= date('d F Y') ?></div>
    </section>

    <!-- STATISTICS -->
    <section class="stats">
        <?php foreach ($stats as $stat): ?>
            <div class="stat">
                <div class="stat-label"><?= h($stat[0]) ?></div>
                <div class="stat-value"><?= (int)$stat[1] ?></div>
                <div class="stat-note"><?= h($stat[2]) ?></div>
            </div>
        <?php endforeach; ?>
    </section>

    <!-- TWO-COLUMN DASHBOARD LAYOUT -->
    <div class="content-grid">

        <!-- LEFT COLUMN -->
        <div class="content-column">

            <!-- UPCOMING MEETINGS -->
            <section class="card">
                <div class="card-header">
                    <div>
                        <h2>Upcoming Meetings</h2>
                        <p class="subtitle">
                            Your next department activities and meeting schedules.
                        </p>
                    </div>

                    <a href="meetings.php" class="button outline small">
                        View All
                    </a>
                </div>

                <?php if (!$nextMeetings): ?>
                    <div class="empty">No upcoming meetings available.</div>
                <?php endif; ?>

                <?php foreach ($nextMeetings as $meeting): ?>
                    <?php $needsResponse = isPendingConfirmation($meeting, $role); ?>

                    <div class="meeting-item">
                        <div>
                            <div class="meeting-name">
                                <?= h($meeting['MeetingName']) ?>
                            </div>

                            <div class="meeting-meta">
                                <?= h(displayDate($meeting['PlannedDate'])) ?>
                                ·
                                <?= h(displayTime($meeting['StartTime'])) ?>
                                –
                                <?= h(displayTime($meeting['EndTime'])) ?>
                                <br>
                                <?= h($meeting['Venue']) ?>
                            </div>

                            <div style="margin-top:8px">
                                <span class="badge blue">
                                    <?= h($meeting['Meeting_Status']) ?>
                                </span>

                                <?php if ($needsResponse): ?>
                                    <span class="badge gold">
                                        Confirmation Pending
                                    </span>
                                <?php elseif ($meeting['MyConfirmation'] === 'Confirmed'): ?>
                                    <span class="badge green">
                                        Confirmed
                                    </span>
                                <?php endif; ?>
                            </div>
                        </div>

                        <div class="meeting-actions">
                            <a href="participation.php?meeting_id=<?= urlencode($meeting['MeetingId']) ?>"
                               class="button <?= $needsResponse ? 'gold' : 'outline' ?> small">
                                <?= $needsResponse ? 'Confirm Now' : 'Participation' ?>
                            </a>

                            <a href="documents.php?meeting_id=<?= urlencode($meeting['MeetingId']) ?>"
                               class="button outline small">
                                Records
                            </a>
                        </div>
                    </div>
                <?php endforeach; ?>
            </section>

            <!-- QUICK ACCESS -->
            <section class="card">
                <h2>Quick Access</h2>
                <p class="subtitle">
                    Open the most frequently used DataVerse modules.
                </p>

                <div class="quick-links">
                    <a href="meetings.php" class="quick-link">
                        ▣ Meetings & Scheduling
                    </a>

                    <a href="participation.php" class="quick-link">
                        ♧ Attendance & Quorum
                    </a>

                    <a href="documents.php" class="quick-link">
                        ▤ Meeting Records & Decisions
                    </a>

                    <?php if (in_array($role, ['HOD', 'Clerk', 'AcademicStaff'], true)): ?>
                        <a href="annual_plan.php" class="quick-link">
                            ▦ Annual Planning
                        </a>
                    <?php endif; ?>
                </div>
            </section>

        </div>
        <!-- END LEFT COLUMN -->

        <!-- RIGHT COLUMN -->
        <div class="content-column">

            <!-- CONFIRMATION REMINDERS -->
            <section class="card">
                <h2>Meeting Confirmations</h2>
                <p class="subtitle">
                    Invitations that need your response.
                </p>

                <?php if ($pendingCount > 0): ?>
                    <div class="alert-item warning">
                        <div class="alert-title">
                            You have <?= $pendingCount ?>
                            pending confirmation<?= $pendingCount === 1 ? '' : 's' ?>.
                        </div>

                        <div class="alert-text">
                            Please confirm whether you will attend your upcoming meetings.
                        </div>

                        <a href="participation.php?meeting_id=<?= urlencode($nextPending['MeetingId']) ?>"
                           class="button gold small">
                            Confirm Upcoming Meeting
                        </a>
                    </div>

                    <?php foreach (array_slice($pendingMeetings, 0, 4) as $meeting): ?>
                        <div class="alert-item">
                            <div class="alert-title">
                                <?= h($meeting['MeetingName']) ?>
                            </div>

                            <div class="alert-text">
                                <?= h(displayDate($meeting['PlannedDate'])) ?>
                                ·
                                <?= h(displayTime($meeting['StartTime'])) ?>
                            </div>

                            <a href="participation.php?meeting_id=<?= urlencode($meeting['MeetingId']) ?>"
                               class="button outline small">
                                Respond
                            </a>
                        </div>
                    <?php endforeach; ?>

                <?php else: ?>
                    <div class="alert-item success">
                        <div class="alert-title">
                            ✓ No Pending Confirmations
                        </div>

                        <div class="alert-text">
                            You have no upcoming meeting invitations requiring a response.
                        </div>
                    </div>
                <?php endif; ?>
            </section>

            <!-- ADMINISTRATIVE ALERTS -->
            <?php if ($isManager): ?>
                <section class="card">
                    <h2>Administrative Alerts</h2>
                    <p class="subtitle">
                        Items requiring administrative attention.
                    </p>

                    <div class="alert-item warning">
                        <div class="alert-title">
                            <?= $missingAgendas ?>
                            Upcoming Meeting<?= $missingAgendas === 1 ? '' : 's' ?>
                            Without Agendas
                        </div>

                        <div class="alert-text">
                            Review agenda availability and the three-day upload deadline.
                        </div>

                        <a href="documents.php" class="button outline small">
                            Open Meeting Records
                        </a>
                    </div>

                    <?php if ($isHOD): ?>
                        <div class="alert-item">
                            <div class="alert-title">
                                <?= $openActionItems ?> Open Action Items
                            </div>

                            <div class="alert-text">
                                Decisions and tasks awaiting progress updates or completion.
                            </div>

                            <a href="documents.php" class="button outline small">
                                View Decisions
                            </a>
                        </div>
                    <?php endif; ?>
                </section>
            <?php endif; ?>

            <!-- SYSTEM INFORMATION -->
            <section class="card">
                <h2>System Information</h2>

                <div class="alert-item">
                    <div class="alert-title">
                        Department Communication System
                    </div>

                    <div class="alert-text">
                        Rajarata University of Sri Lanka<br>
                        Department of Computing<br>
                        DataVerse
                    </div>
                </div>
            </section>

        </div>
        <!-- END RIGHT COLUMN -->

    </div>
    <!-- END CONTENT GRID -->

    <footer class="footer">
        DataVerse © <?= date('Y') ?>
        · Department of Computing
        · Rajarata University of Sri Lanka
    </footer>

</main>

<!-- EXISTING MEETING CONFIRMATION POPUP -->
<?php if ($nextPending): ?>
<div class="modal-overlay"
     id="confirmationModal"
     role="dialog"
     aria-modal="true"
     aria-labelledby="reminderTitle">

    <div class="modal">
        <div class="modal-top">
            <div class="eyebrow" style="color:var(--gold)">
                UPCOMING MEETING REMINDER
            </div>

            <h2 id="reminderTitle">Meeting Confirmation Required</h2>

            <p>
                You have an upcoming meeting that requires your participation response.
            </p>
        </div>

        <div class="modal-body">
            <div class="modal-detail">
                <strong><?= h($nextPending['MeetingName']) ?></strong>

                <span>
                    Date: <?= h(displayDate($nextPending['PlannedDate'])) ?>
                </span>

                <span>
                    Time:
                    <?= h(displayTime($nextPending['StartTime'])) ?>
                    –
                    <?= h(displayTime($nextPending['EndTime'])) ?>
                </span>

                <span>
                    Venue: <?= h($nextPending['Venue']) ?>
                </span>
            </div>

            <p class="subtitle">
                Please confirm whether you will attend this meeting.
                Your response contributes to the confirmation-based quorum calculation.
            </p>

            <div class="modal-actions">
                <a href="participation.php?meeting_id=<?= urlencode($nextPending['MeetingId']) ?>"
                   class="button gold">
                    Go to Confirmation
                </a>

                <button type="button"
                        class="button outline"
                        onclick="closeConfirmationModal()">
                    Remind Me Later
                </button>
            </div>

            <div class="modal-note">
                You can also confirm from the Attendance & Quorum page.
                Closing this reminder does not confirm your participation.
            </div>
        </div>
    </div>
</div>
<?php endif; ?>

<!-- LIVE NOTIFICATION POPUP -->
<div class="dv-live-overlay"
     id="dvLiveOverlay"
     role="dialog"
     aria-modal="true"
     aria-labelledby="dvLiveTitle">

    <div class="dv-live-modal">
        <div class="dv-live-top">
            <small>DATAVERSE · NEW ALERT</small>
            <h2 id="dvLiveTitle">New Notification</h2>
        </div>

        <div class="dv-live-body">
            <p id="dvLiveMessage"></p>
            <div class="dv-live-date" id="dvLiveDate"></div>

            <div class="dv-live-actions">
                <a href="meetings.php"
                   class="button gold"
                   id="dvLiveOpen">
                    View Meeting
                </a>

                <button type="button"
                        class="button outline"
                        id="dvLiveDismiss">
                    Dismiss
                </button>
            </div>
        </div>
    </div>
</div>

<script>
function closeConfirmationModal() {
    const modal = document.getElementById('confirmationModal');
    if (modal) {
        modal.classList.remove('show');
    }
}

document.addEventListener('DOMContentLoaded', function () {
    const modal = document.getElementById('confirmationModal');

    if (!modal) return;

    const meetingKey = <?= json_encode(
        $nextPending
            ? 'dataverse_reminder_' . $userId . '_' . $nextPending['MeetingId']
            : ''
    ) ?>;

    let alreadyShown = false;

    try {
        alreadyShown = sessionStorage.getItem(meetingKey) === 'shown';
    } catch (e) {}

    if (!alreadyShown) {
        modal.classList.add('show');

        try {
            sessionStorage.setItem(meetingKey, 'shown');
        } catch (e) {}
    }

    modal.addEventListener('click', function (event) {
        if (event.target === modal) {
            closeConfirmationModal();
        }
    });
});

/* LIVE NOTIFICATIONS - CHECK EVERY 30 SECONDS */

(function () {
    const userKey = <?= json_encode($userId) ?>;
    const storageKey = 'dataverse_seen_notifications_' + userKey;

    const bell = document.getElementById('dvBell');
    const panel = document.getElementById('dvNotifyPanel');
    const count = document.getElementById('dvNotifyCount');
    const list = document.getElementById('dvNotifyList');
    const markSeen = document.getElementById('dvMarkSeen');

    const overlay = document.getElementById('dvLiveOverlay');
    const liveTitle = document.getElementById('dvLiveTitle');
    const liveMessage = document.getElementById('dvLiveMessage');
    const liveDate = document.getElementById('dvLiveDate');
    const liveOpen = document.getElementById('dvLiveOpen');
    const liveDismiss = document.getElementById('dvLiveDismiss');

    let notifications = [];
    let seenIds = [];
    let initialized = false;
    let popupQueue = [];
    let popupActive = false;
    let checking = false;

    try {
        const stored = JSON.parse(localStorage.getItem(storageKey) || '[]');
        seenIds = Array.isArray(stored) ? stored.map(String) : [];
    } catch (e) {
        seenIds = [];
    }

    function saveSeen() {
        try {
            localStorage.setItem(storageKey, JSON.stringify(seenIds.slice(-500)));
        } catch (e) {}
    }

    function markNotificationSeen(id) {
        id = String(id);

        if (!seenIds.includes(id)) {
            seenIds.push(id);
            saveSeen();
        }

        renderNotifications();
    }

    function markAllSeen() {
        notifications.forEach(function (item) {
            const id = String(item.id);

            if (!seenIds.includes(id)) {
                seenIds.push(id);
            }
        });

        saveSeen();
        renderNotifications();
    }

    function renderNotifications() {
        const unread = notifications.filter(function (item) {
            return !seenIds.includes(String(item.id));
        });

        count.textContent = unread.length > 99 ? '99+' : String(unread.length);
        count.classList.toggle('visible', unread.length > 0);

        list.replaceChildren();

        if (notifications.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'dv-notify-empty';
            empty.textContent = 'No notifications available.';
            list.appendChild(empty);
            return;
        }

        notifications.forEach(function (item) {
            const link = document.createElement('a');
            link.className = 'dv-notify-item';
            link.href = item.url || 'meetings.php';

            const title = document.createElement('strong');
            title.textContent = item.message || item.type || 'Meeting notification';

            const details = document.createElement('span');
            details.textContent =
                (item.meeting_name || '') +
                (item.sent_date ? ' · ' + item.sent_date : '');

            if (!seenIds.includes(String(item.id))) {
                title.style.color = '#b78113';
            }

            link.appendChild(title);
            link.appendChild(details);

            link.addEventListener('click', function () {
                markNotificationSeen(item.id);
            });

            list.appendChild(link);
        });
    }

    function showNextPopup() {
        if (popupActive || popupQueue.length === 0) return;

        const confirmationModal = document.getElementById('confirmationModal');

        if (confirmationModal && confirmationModal.classList.contains('show')) {
            return;
        }

        const item = popupQueue.shift();

        popupActive = true;
        liveTitle.textContent = item.type || 'New Notification';
        liveMessage.textContent = item.message || 'You have a new meeting update.';
        liveDate.textContent =
            (item.meeting_name || '') +
            (item.sent_date ? ' · ' + item.sent_date : '');

        liveOpen.href = item.url || 'meetings.php';

        liveOpen.onclick = function () {
            markNotificationSeen(item.id);
        };

        liveDismiss.onclick = function () {
            markNotificationSeen(item.id);
            overlay.classList.remove('show');
            popupActive = false;
            showNextPopup();
        };

        overlay.classList.add('show');
    }

    async function checkNotifications() {
        if (checking) return;
        checking = true;

        try {
            const response = await fetch(
                'check_notifications.php',
                {
                    method: 'GET',
                    credentials: 'same-origin',
                    cache: 'no-store',
                    headers: {
                        'Accept': 'application/json'
                    }
                }
            );

            if (!response.ok) {
                throw new Error('Notification request failed');
            }

            const data = await response.json();

            if (!data.success || !Array.isArray(data.notifications)) {
                throw new Error('Invalid notification response');
            }

            const previousIds = new Set(
                notifications.map(function (item) {
                    return String(item.id);
                })
            );

            notifications = data.notifications;
            renderNotifications();

            if (!initialized) {
                initialized = true;
                return;
            }

            const newItems = notifications.filter(function (item) {
                return !previousIds.has(String(item.id)) &&
                    !seenIds.includes(String(item.id));
            });

            newItems.reverse().forEach(function (item) {
                popupQueue.push(item);
            });

            showNextPopup();

        } catch (error) {
            if (!initialized) {
                list.replaceChildren();

                const message = document.createElement('div');
                message.className = 'dv-notify-empty';
                message.textContent = 'Unable to load notifications.';
                list.appendChild(message);
            }

            console.error('DataVerse notification error:', error);
        } finally {
            checking = false;
        }
    }

    bell.addEventListener('click', function () {
        const open = panel.classList.toggle('open');
        bell.setAttribute('aria-expanded', open ? 'true' : 'false');
    });

    markSeen.addEventListener('click', markAllSeen);

    document.addEventListener('click', function (event) {
        if (!document.getElementById('dvNotificationCenter').contains(event.target)) {
            panel.classList.remove('open');
            bell.setAttribute('aria-expanded', 'false');
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
            panel.classList.remove('open');
            bell.setAttribute('aria-expanded', 'false');

            if (popupActive) {
                liveDismiss.click();
            } else {
                closeConfirmationModal();
            }
        }
    });

    const originalClose = window.closeConfirmationModal;

    window.closeConfirmationModal = function () {
        originalClose();
        showNextPopup();
    };

    checkNotifications();
    setInterval(checkNotifications, 30000);

    document.addEventListener('visibilitychange', function () {
        if (!document.hidden) {
            checkNotifications();
            showNextPopup();
        }
    });
})();
</script>

</body>
</html>
