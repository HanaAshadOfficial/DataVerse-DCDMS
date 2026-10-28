
<?php
session_start();

if (
    empty($_SESSION['user_id']) ||
    empty($_SESSION['user_role'])
) {
    header("Location: login.php");
    exit;
}

require_once __DIR__ . "/config.php";

function h($value) {
    return htmlspecialchars(
        (string)($value ?? ""),
        ENT_QUOTES | ENT_SUBSTITUTE,
        "UTF-8"
    );
}

function safeColor($color) {
    return preg_match(
        '/^#[0-9A-Fa-f]{6}$/',
        (string)$color
    ) ? $color : '#64748b';
}

function plannedMonths($value) {
    $value = trim((string)$value);

    if ($value === '') {
        return [];
    }

    /*
     * ScheduledMonths is the official planning
     * source, not the completed meeting records.
     *
     * Supports values such as:
     * 1,2,3,5,6
     * Jan,Feb,Mar
     * January February March
     */

    $names = [
        'jan' => 1, 'feb' => 2, 'mar' => 3,
        'apr' => 4, 'may' => 5, 'jun' => 6,
        'jul' => 7, 'aug' => 8, 'sep' => 9,
        'oct' => 10, 'nov' => 11, 'dec' => 12
    ];

    $months = [];

    preg_match_all(
        '/\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\b/i',
        $value,
        $matches
    );

    foreach ($matches[0] as $name) {
        $number = $names[
            substr(strtolower($name), 0, 3)
        ] ?? null;

        if ($number) {
            $months[$number] = true;
        }
    }

    if (!$months) {
        preg_match_all(
            '/(?<!\d)(?:1[0-2]|[1-9])(?!\d)/',
            $value,
            $matches
        );

        foreach ($matches[0] as $number) {
            $months[(int)$number] = true;
        }
    }

    return array_keys($months);
}

$role = (string)$_SESSION['user_role'];
$userName = (string)($_SESSION['user_name'] ?? 'Team Member');

$allowedRoles = [
    'HOD',
    'Clerk',
    'AcademicStaff'
];

if (!in_array($role, $allowedRoles, true)) {
    http_response_code(403);
    exit("You do not have permission to access Annual Planning.");
}

$isHOD = $role === 'HOD';

$roleNames = [
    'HOD' => 'Head of Department',
    'Clerk' => 'Clerk / Convener',
    'AcademicStaff' => 'Academic Staff'
];

$initials = strtoupper(
    substr(
        preg_replace('/[^a-z]/i', '', $userName),
        0,
        2
    )
);

$year = filter_input(
    INPUT_GET,
    'year',
    FILTER_VALIDATE_INT
);

if (!$year || $year < 2000 || $year > 2100) {
    $year = (int)date('Y');
}

$success = '';
$error = '';

/*
|--------------------------------------------------------------------------
| HOD: UPLOAD ANNUAL PLAN
|--------------------------------------------------------------------------
*/

if (empty($_SESSION['annual_plan_csrf'])) {
    $_SESSION['annual_plan_csrf'] = bin2hex(random_bytes(32));
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    if (!$isHOD) {
        http_response_code(403);
        exit("Only the HOD can upload annual plans.");
    }

    if (!hash_equals(
        $_SESSION['annual_plan_csrf'],
        (string)($_POST['csrf'] ?? '')
    )) {
        $error = "Invalid request. Please refresh the page.";
    } else {

        $uploadYear = filter_var(
            $_POST['academic_year'] ?? null,
            FILTER_VALIDATE_INT
        );

        if (
            !$uploadYear ||
            $uploadYear < 2000 ||
            $uploadYear > 2100
        ) {
            $error = "Please select a valid academic year.";
        } elseif (
            empty($_FILES['plan_pdf']) ||
            $_FILES['plan_pdf']['error'] !== UPLOAD_ERR_OK
        ) {
            $error = "Please select a PDF document.";
        } else {

            $file = $_FILES['plan_pdf'];

            if ($file['size'] > 10 * 1024 * 1024) {
                $error = "The PDF must be smaller than 10 MB.";
            } else {

                $mime = (new finfo(FILEINFO_MIME_TYPE))
                    ->file($file['tmp_name']);

                $header = file_get_contents(
                    $file['tmp_name'],
                    false,
                    null,
                    0,
                    5
                );

                if (
                    $mime !== 'application/pdf' ||
                    $header !== '%PDF-'
                ) {
                    $error = "Only valid PDF files are allowed.";
                } else {

                    $folder = __DIR__ . '/uploads/annual_plans';

                    if (
                        !is_dir($folder) &&
                        !mkdir($folder, 0755, true)
                    ) {
                        $error = "Unable to create upload directory.";
                    } else {

                        $filename =
                            'annual_plan_' .
                            $uploadYear . '_' .
                            bin2hex(random_bytes(8)) .
                            '.pdf';

                        $path = $folder . '/' . $filename;

                        $link =
                            'uploads/annual_plans/' .
                            $filename;

                        if (!move_uploaded_file(
                            $file['tmp_name'],
                            $path
                        )) {
                            $error = "Unable to save the PDF.";
                        } else {

                            try {

                                $conn->begin_transaction();

                                $stmt = $conn->prepare(
                                    "SELECT PlanID, PlanLink
                                     FROM YearPlan
                                     WHERE AcademicYear = ?
                                     FOR UPDATE"
                                );

                                $stmt->bind_param(
                                    'i',
                                    $uploadYear
                                );

                                $stmt->execute();

                                $existing = $stmt
                                    ->get_result()
                                    ->fetch_assoc();

                                $stmt->close();

                                if ($existing) {

                                    $stmt = $conn->prepare(
                                        "UPDATE YearPlan
                                         SET PlanLink = ?
                                         WHERE AcademicYear = ?"
                                    );

                                    $stmt->bind_param(
                                        'si',
                                        $link,
                                        $uploadYear
                                    );

                                } else {

                                    /*
                                     * PlanID is VARCHAR(10).
                                     * Generate a unique identifier.
                                     */

                                    do {
                                        $planId =
                                            'YP' .
                                            strtoupper(
                                                bin2hex(
                                                    random_bytes(4)
                                                )
                                            );

                                        $check = $conn->prepare(
                                            "SELECT PlanID
                                             FROM YearPlan
                                             WHERE PlanID = ?"
                                        );

                                        $check->bind_param(
                                            's',
                                            $planId
                                        );

                                        $check->execute();

                                        $exists = $check
                                            ->get_result()
                                            ->num_rows > 0;

                                        $check->close();

                                    } while ($exists);

                                    $stmt = $conn->prepare(
                                        "INSERT INTO YearPlan
                                         (PlanID, AcademicYear, PlanLink)
                                         VALUES (?, ?, ?)"
                                    );

                                    $stmt->bind_param(
                                        'sis',
                                        $planId,
                                        $uploadYear,
                                        $link
                                    );
                                }

                                $stmt->execute();
                                $stmt->close();

                                $conn->commit();

                                $year = $uploadYear;

                                $success =
                                    "Annual plan uploaded successfully.";

                            } catch (Throwable $e) {

                                $conn->rollback();

                                @unlink($path);

                                error_log($e->getMessage());

                                $error =
                                    "Unable to save the annual plan in the database.";
                            }
                        }
                    }
                }
            }
        }
    }
}

/*
|--------------------------------------------------------------------------
| LOAD AVAILABLE YEARS
|--------------------------------------------------------------------------
*/

$years = [$year];

$result = $conn->query(
    "SELECT AcademicYear
     FROM YearPlan
     ORDER BY AcademicYear DESC"
);

if ($result) {
    while ($row = $result->fetch_assoc()) {
        $years[] = (int)$row['AcademicYear'];
    }
}

$years = array_values(array_unique($years));

rsort($years);

/*
|--------------------------------------------------------------------------
| SELECTED YEAR PLAN
|--------------------------------------------------------------------------
*/

$yearPlan = null;

$stmt = $conn->prepare(
    "SELECT PlanID, AcademicYear, PlanLink
     FROM YearPlan
     WHERE AcademicYear = ?
     LIMIT 1"
);

$stmt->bind_param('i', $year);
$stmt->execute();

$yearPlan = $stmt->get_result()->fetch_assoc();

$stmt->close();

/*
|--------------------------------------------------------------------------
| LOAD OFFICIAL MEETING TYPES
|--------------------------------------------------------------------------
*/

$meetingTypes = [];

$result = $conn->query(
    "SELECT
        TypeID,
        Name,
        ShortName,
        IsPrivate,
        TargetFrequency,
        CategoryGroup,
        FrequencyLabel,
        ScheduledMonths,
        CalendarColorHex
     FROM MeetingType
     ORDER BY TypeID"
);

if ($result) {
    while ($row = $result->fetch_assoc()) {
        $meetingTypes[] = $row;
    }
}

/*
|--------------------------------------------------------------------------
| LOAD RECORDED MEETINGS FOR SELECTED YEAR
|--------------------------------------------------------------------------
*/

$recorded = [];

if ($yearPlan) {

    $stmt = $conn->prepare(
        "SELECT
            TypeID,
            MONTH(PlannedDate) AS MeetingMonth,
            COUNT(*) AS Total
         FROM Meeting
         WHERE PlanID = ?
           AND Meeting_Status <> 'Cancelled'
         GROUP BY TypeID, MONTH(PlannedDate)"
    );

    $stmt->bind_param(
        's',
        $yearPlan['PlanID']
    );

    $stmt->execute();

    $result = $stmt->get_result();

    while ($row = $result->fetch_assoc()) {
        $recorded[$row['TypeID']][
            (int)$row['MeetingMonth']
        ] = (int)$row['Total'];
    }

    $stmt->close();
}

/*
|--------------------------------------------------------------------------
| CSV EXPORT
|--------------------------------------------------------------------------
*/

if (isset($_GET['export']) && $_GET['export'] === 'csv') {

    header('Content-Type: text/csv; charset=utf-8');

    header(
        'Content-Disposition: attachment; filename="annual_plan_' .
        $year .
        '.csv"'
    );

    $out = fopen('php://output', 'w');

    fputcsv($out, [
        'Meeting Type',
        'Jan', 'Feb', 'Mar', 'Apr',
        'May', 'Jun', 'Jul', 'Aug',
        'Sep', 'Oct', 'Nov', 'Dec',
        'Annual Target'
    ]);

    foreach ($meetingTypes as $type) {

        $months = plannedMonths(
            $type['ScheduledMonths']
        );

        $line = [
            $type['ShortName'] . ' - ' . $type['Name']
        ];

        for ($m = 1; $m <= 12; $m++) {
            $line[] = in_array($m, $months, true)
                ? 'Planned'
                : '';
        }

        $line[] = $type['TargetFrequency'];

        fputcsv($out, $line);
    }

    fclose($out);
    exit;
}

$monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr',
    'May', 'Jun', 'Jul', 'Aug',
    'Sep', 'Oct', 'Nov', 'Dec'
];

?>
<!DOCTYPE html>
<html lang="en">
<head>

<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">

<title>DataVerse | Annual Planning</title>

<style>

:root {
    --navy: #102f3e;
    --navy-light: #204f5e;
    --gold: #f4c45c;
    --bg: #f2f6f7;
    --text: #183642;
    --muted: #728793;
    --border: #dce6ea;
}

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    background: var(--bg);
    font-family: "Segoe UI", Arial, sans-serif;
    color: var(--text);
}

.sidebar {
    width: 258px;
    position: fixed;
    top: 0;
    bottom: 0;
    left: 0;
    background: var(--navy);
    color: white;
    padding: 28px 18px;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
}

.logo {
    font-size: 29px;
    font-weight: 800;
    padding: 14px;
}

.logo span {
    color: var(--gold);
}

.logo-caption {
    padding: 0 14px 25px;
    font-size: 11px;
    letter-spacing: 1px;
    line-height: 1.7;
    color: #b6d0da;
    border-bottom: 1px solid #ffffff20;
}

.nav-heading {
    font-size: 11px;
    letter-spacing: 2px;
    color: #8ba8b7;
    font-weight: 800;
    margin: 30px 14px 18px;
}

.nav-link {
    display: block;
    padding: 17px;
    border-radius: 10px;
    margin-bottom: 6px;
    color: #d5e2e8;
    text-decoration: none;
    font-size: 13px;
}

.nav-link:hover {
    background: #ffffff12;
}

.nav-link.active {
    background: var(--gold);
    color: var(--navy);
    font-weight: 800;
}

.profile-area {
    margin-top: auto;
    padding-top: 20px;
    border-top: 1px solid #ffffff20;
}

.profile-name {
    font-weight: 800;
    font-size: 12px;
}

.profile-role {
    font-size: 11px;
    color: #b6d0da;
    margin-top: 6px;
}

.signout {
    display: block;
    margin-top: 18px;
    background: #ffffff15;
    border: 1px solid #ffffff30;
    border-radius: 9px;
    padding: 13px;
    text-align: center;
    color: white;
    text-decoration: none;
    font-size: 12px;
    font-weight: 700;
}

.main {
    margin-left: 258px;
    padding: 35px;
}

.top {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
    gap: 20px;
}

.eyebrow {
    color: #b68116;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1.5px;
}

h1 {
    font-size: 29px;
    margin: 10px 0 8px;
}

.subtitle {
    font-size: 13px;
    color: var(--muted);
}

.role-badge {
    padding: 12px 16px;
    background: #fff5dc;
    border-radius: 11px;
    font-size: 12px;
    font-weight: 800;
    color: #956600;
}

.panel {
    background: white;
    border: 1px solid var(--border);
    border-radius: 15px;
    padding: 26px;
    margin-bottom: 22px;
}

.panel-title {
    font-size: 20px;
    font-weight: 800;
    margin: 0 0 8px;
}

.panel-top {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 15px;
    margin-bottom: 24px;
}

.button {
    border: 0;
    background: #087f7b;
    color: white;
    border-radius: 8px;
    padding: 12px 17px;
    font-weight: 700;
    font-size: 12px;
    text-decoration: none;
    cursor: pointer;
    display: inline-block;
}

.button:hover {
    background: #066b67;
}

.button.secondary {
    background: #edf2f4;
    color: var(--navy);
}

.button.gold {
    background: var(--gold);
    color: var(--navy);
}

.filters {
    display: grid;
    grid-template-columns: 150px 150px 1fr;
    gap: 12px;
    margin-bottom: 20px;
}

select,
input[type="search"],
input[type="file"] {
    width: 100%;
    padding: 13px;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: white;
    font: inherit;
    font-size: 13px;
}

.notice {
    background: #fff4dc;
    border-left: 3px solid #d5a329;
    padding: 15px 18px;
    border-radius: 5px;
    font-size: 12px;
    margin-bottom: 22px;
    line-height: 1.7;
}

.success {
    background: #e9f8ef;
    color: #166b43;
    padding: 14px;
    border-radius: 9px;
    margin-bottom: 18px;
    font-size: 13px;
}

.error {
    background: #fff0f0;
    color: #ae3636;
    padding: 14px;
    border-radius: 9px;
    margin-bottom: 18px;
    font-size: 13px;
}

.matrix-container {
    overflow-x: auto;
}

.matrix {
    width: 100%;
    border-collapse: collapse;
    min-width: 950px;
}

.matrix th {
    text-align: center;
    background: #f3f6f7;
    color: #687f8b;
    font-size: 10px;
    padding: 13px 7px;
    white-space: nowrap;
}

.matrix th:first-child {
    text-align: left;
    width: 33%;
}

.matrix td {
    border-bottom: 1px solid #e9eff1;
    padding: 12px 7px;
    font-size: 11px;
    text-align: center;
}

.matrix td:first-child {
    text-align: left;
}

.type-name {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
    line-height: 1.5;
}

.color-square {
    display: inline-block;
    width: 12px;
    height: 12px;
    min-width: 12px;
    border-radius: 3px;
}

.month-dot {
    color: #8597a0;
}

.month-square {
    width: 13px;
    height: 13px;
    border-radius: 3px;
    display: inline-block;
}

.target {
    font-weight: 700;
}

.legend {
    font-size: 11px;
    color: var(--muted);
    margin-top: 18px;
    line-height: 1.7;
}

.document-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 15px;
}

.upload-box {
    background: #f8fafb;
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 22px;
    margin-top: 20px;
}

.upload-box label {
    display: block;
    font-size: 12px;
    font-weight: 800;
    margin-bottom: 10px;
}

.upload-actions {
    display: flex;
    align-items: center;
    gap: 15px;
    margin-top: 14px;
}

.small-text {
    font-size: 11px;
    color: var(--muted);
    line-height: 1.7;
}

.footer {
    text-align: center;
    font-size: 11px;
    color: #91a3ae;
    padding: 20px;
}

@media (max-width: 850px) {
    .sidebar {
        position: relative;
        width: 100%;
    }

    .main {
        margin-left: 0;
        padding: 20px;
    }

    .top,
    .panel-top,
    .document-row {
        flex-direction: column;
        align-items: flex-start;
    }

    .filters {
        grid-template-columns: 1fr;
    }
}

</style>

</head>

<body>

<aside class="sidebar">

    <div class="logo">
        Data<span>Verse</span>
    </div>

    <div class="logo-caption">
        DEPARTMENT COMMUNICATION<br>
        MANAGEMENT SYSTEM
    </div>

    <div class="nav-heading">
        MAIN NAVIGATION
    </div>

    <nav>

        <a href="dashboard.php" class="nav-link">
            Dashboard
        </a>

        <a href="annual_plan.php" class="nav-link active">
            Annual Planning
        </a>

        <a href="meetings.php" class="nav-link">
            Meetings & Scheduling
        </a>

        <a href="participation.php" class="nav-link">
            Attendance & Quorum
        </a>

        <a href="documents.php" class="nav-link">
            Meeting Records & Decisions
        </a>

        <?php if ($isHOD): ?>
            <a href="users.php" class="nav-link">
                Users & Access
            </a>
        <?php endif; ?>

    </nav>

    <div class="profile-area">

        <div class="profile-name">
            <?= h($userName) ?>
        </div>

        <div class="profile-role">
            <?= h($roleNames[$role]) ?>
        </div>

        <a href="logout.php" class="signout">
            ↪ Sign Out
        </a>

    </div>

</aside>

<main class="main">

    <header class="top">

        <div>

            <div class="eyebrow">
                DEPARTMENT OF COMPUTING
            </div>

            <h1>Annual Organization Plan</h1>

            <p class="subtitle">
                Academic Year <?= $year ?>
                · Department Meeting Distribution
            </p>

        </div>

        <div class="role-badge">
            <?= h($roleNames[$role]) ?>
        </div>

    </header>

    <?php if ($success): ?>
        <div class="success">
            <?= h($success) ?>
        </div>
    <?php endif; ?>

    <?php if ($error): ?>
        <div class="error">
            <?= h($error) ?>
        </div>
    <?php endif; ?>

    <section class="panel">

        <div class="panel-top">

            <div>

                <h2 class="panel-title">
                    Annual Meeting Planner
                </h2>

                <div class="subtitle">
                    Plan ID:
                    <?= h($yearPlan['PlanID'] ?? 'Not created') ?>
                    · January–December <?= $year ?>
                </div>

            </div>

            <div style="display:flex;gap:10px;flex-wrap:wrap">

                <?php if ($isHOD): ?>

                    <button
                        class="button secondary"
                        type="button"
                        onclick="showUpload()"
                    >
                        Upload / Update Plan
                    </button>

                <?php endif; ?>

                <a
                    href="annual_plan.php?year=<?= $year ?>&export=csv"
                    class="button"
                >
                    Export Planner
                </a>

            </div>

        </div>

        <div class="filters">

            <select id="yearSelect" onchange="changeYear()">

                <?php foreach ($years as $optionYear): ?>

                    <option
                        value="<?= $optionYear ?>"
                        <?= $optionYear === $year ? 'selected' : '' ?>
                    >
                        <?= $optionYear ?>
                    </option>

                <?php endforeach; ?>

            </select>

            <select id="periodFilter" onchange="filterMatrix()">

                <option value="all">
                    Full Year
                </option>

                <option value="first">
                    January – June
                </option>

                <option value="second">
                    July – December
                </option>

            </select>

            <input
                type="search"
                id="searchMeeting"
                placeholder="Search meeting type..."
                oninput="filterMatrix()"
            >

        </div>

        <div class="notice">
            Month placements are taken from the official
            <strong>MeetingType.ScheduledMonths</strong>
            values. Each meeting category has its own
            colour. Annual targets come from
            <strong>MeetingType.TargetFrequency</strong>.
        </div>

        <h3 style="font-size:15px;margin-bottom:18px">
            Planned Meeting Distribution
        </h3>

        <div class="matrix-container">

            <table class="matrix" id="planningMatrix">

                <thead>

                    <tr>

                        <th>MEETING TYPE</th>

                        <?php foreach ($monthNames as $index => $month): ?>

                            <th
                                class="month-column"
                                data-month="<?= $index + 1 ?>"
                            >
                                <?= h(strtoupper($month)) ?>
                            </th>

                        <?php endforeach; ?>

                        <th>TARGET</th>

                    </tr>

                </thead>

                <tbody>

                    <?php foreach ($meetingTypes as $type): ?>

                        <?php

                        $months = plannedMonths(
                            $type['ScheduledMonths']
                        );

                        $color = safeColor(
                            $type['CalendarColorHex']
                        );

                        ?>

                        <tr class="meeting-row">

                            <td>

                                <div class="type-name">

                                    <span
                                        class="color-square"
                                        style="background:<?= h($color) ?>"
                                    ></span>

                                    <span>

                                        <?= h($type['ShortName']) ?>
                                        ·
                                        <?= h($type['Name']) ?>

                                    </span>

                                </div>

                            </td>

                            <?php for ($month = 1; $month <= 12; $month++): ?>

                                <td
                                    class="month-column"
                                    data-month="<?= $month ?>"
                                >

                                    <?php if (in_array(
                                        $month,
                                        $months,
                                        true
                                    )): ?>

                                        <span
                                            class="month-square"
                                            style="background:<?= h($color) ?>"
                                            title="Planned for <?= h($monthNames[$month - 1]) ?>"
                                        ></span>

                                    <?php else: ?>

                                        <span class="month-dot">
                                            ·
                                        </span>

                                    <?php endif; ?>

                                </td>

                            <?php endfor; ?>

                            <td class="target">
                                <?= (int)$type['TargetFrequency'] ?>
                            </td>

                        </tr>

                    <?php endforeach; ?>

                </tbody>

            </table>

        </div>

        <div class="legend">
            Coloured square = planned month.
            Dot = no planned occurrence.
            The matrix shows the official annual schedule,
            not the number of completed meetings.
        </div>

    </section>

    <!-- ANNUAL PLAN DOCUMENT -->

    <section class="panel" id="planDocument">

        <div class="document-row">

            <div>

                <h2 class="panel-title">
                    Annual Plan Document
                </h2>

                <p class="subtitle">
                    Official PDF document for Academic Year
                    <?= $year ?>.
                </p>

            </div>

            <?php if (
                $yearPlan &&
                !empty($yearPlan['PlanLink'])
            ): ?>

                <?php

                $planLink = $yearPlan['PlanLink'];

                $validLink = (
                    preg_match(
                        '#^uploads/annual_plans/[A-Za-z0-9_.-]+\.pdf$#',
                        $planLink
                    )
                    || filter_var(
                        $planLink,
                        FILTER_VALIDATE_URL
                    )
                );

                ?>

                <?php if ($validLink): ?>

                    <a
                        class="button"
                        href="<?= h($planLink) ?>"
                        target="_blank"
                        rel="noopener noreferrer"
                    >
                        Open Plan Document
                    </a>

                <?php else: ?>

                    <span class="small-text">
                        The saved document link needs verification.
                    </span>

                <?php endif; ?>

            <?php else: ?>

                <span class="small-text">
                    No annual plan document uploaded.
                </span>

            <?php endif; ?>

        </div>

        <?php if ($isHOD): ?>

            <div
                class="upload-box"
                id="uploadBox"
                style="display:none"
            >

                <form
                    method="POST"
                    enctype="multipart/form-data"
                    onsubmit="return confirmUpload()"
                >

                    <input
                        type="hidden"
                        name="csrf"
                        value="<?= h($_SESSION['annual_plan_csrf']) ?>"
                    >

                    <input
                        type="hidden"
                        name="academic_year"
                        value="<?= $year ?>"
                    >

                    <label>
                        Upload Annual Plan PDF for <?= $year ?>
                    </label>

                    <input
                        type="file"
                        id="planFile"
                        name="plan_pdf"
                        accept=".pdf,application/pdf"
                        required
                    >

                    <div class="upload-actions">

                        <button
                            type="submit"
                            class="button gold"
                        >
                            Save Annual Plan
                        </button>

                        <button
                            type="button"
                            class="button secondary"
                            onclick="hideUpload()"
                        >
                            Cancel
                        </button>

                    </div>

                    <p class="small-text">
                        PDF only. Maximum file size: 10 MB.
                        Uploading another plan for the same year
                        updates the YearPlan.PlanLink record.
                    </p>

                </form>

            </div>

        <?php endif; ?>

    </section>

    <footer class="footer">
        DataVerse © <?= date('Y') ?>
        · Department of Computing
        · Rajarata University of Sri Lanka
    </footer>

</main>

<script>

function changeYear() {

    const year = document.getElementById(
        'yearSelect'
    ).value;

    window.location.href =
        'annual_plan.php?year=' +
        encodeURIComponent(year);
}

function filterMatrix() {

    const search = document.getElementById(
        'searchMeeting'
    ).value.toLowerCase();

    const period = document.getElementById(
        'periodFilter'
    ).value;

    document.querySelectorAll(
        '.meeting-row'
    ).forEach(function(row) {

        const text = row.cells[0]
            .textContent
            .toLowerCase();

        row.style.display =
            text.includes(search) ? '' : 'none';
    });

    document.querySelectorAll(
        '.month-column'
    ).forEach(function(cell) {

        const month = parseInt(
            cell.dataset.month,
            10
        );

        let visible = true;

        if (period === 'first') {
            visible = month <= 6;
        }

        if (period === 'second') {
            visible = month >= 7;
        }

        cell.style.display =
            visible ? '' : 'none';
    });
}

function showUpload() {

    const box = document.getElementById(
        'uploadBox'
    );

    if (box) {
        box.style.display = 'block';
        box.scrollIntoView({
            behavior: 'smooth',
            block: 'center'
        });
    }
}

function hideUpload() {

    const box = document.getElementById(
        'uploadBox'
    );

    if (box) {
        box.style.display = 'none';
    }
}

function confirmUpload() {

    const input = document.getElementById(
        'planFile'
    );

    if (!input || !input.files.length) {
        alert('Please select a PDF.');
        return false;
    }

    const file = input.files[0];

    if (file.size > 10 * 1024 * 1024) {
        alert('File size must be below 10 MB.');
        return false;
    }

    if (!file.name.toLowerCase().endsWith('.pdf')) {
        alert('Only PDF documents are allowed.');
        return false;
    }

    return confirm(
        'Are you sure you want to upload this annual plan?'
    );
}

</script>

</body>
</html>
