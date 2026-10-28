
<?php
session_start();

if (
    empty($_SESSION['user_id']) ||
    empty($_SESSION['user_role'])
) {
    header('Location: login.php');
    exit;
}

/*
|--------------------------------------------------------------------------
| HOD-ONLY ACCESS
|--------------------------------------------------------------------------
*/

if ($_SESSION['user_role'] !== 'HOD') {
    http_response_code(403);
    exit('Access denied. Only the Head of Department can manage users.');
}

require_once __DIR__ . '/config.php';

function h($value) {
    return htmlspecialchars(
        (string)($value ?? ''),
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );
}

function dbStmt($conn, $sql, $types = '', $params = []) {
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new RuntimeException($conn->error);
    }

    if ($types !== '') {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        $error = $stmt->error;
        $stmt->close();
        throw new RuntimeException($error);
    }

    return $stmt;
}

$roles = [
    'HOD' => 'Head of Department',
    'AcademicStaff' => 'Academic Staff',
    'Clerk' => 'Clerk / Convener',
    'SupportStaff' => 'Support Staff',
    'StudentCoordinator' => 'Student Coordinator'
];

$roleTables = [
    'HOD' => 'HOD',
    'AcademicStaff' => 'AcademicStaff',
    'Clerk' => 'Clerk',
    'SupportStaff' => 'SupportStaff',
    'StudentCoordinator' => 'StudentCoordinator'
];

$userId = (string)$_SESSION['user_id'];
$userName = (string)($_SESSION['user_name'] ?? 'HOD');

$error = '';
$success = '';

if (empty($_SESSION['users_csrf'])) {
    $_SESSION['users_csrf'] = bin2hex(random_bytes(32));
}

$csrf = $_SESSION['users_csrf'];

/*
|--------------------------------------------------------------------------
| HANDLE ADD / EDIT USER
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    try {

        if (!hash_equals(
            $csrf,
            (string)($_POST['csrf'] ?? '')
        )) {
            throw new RuntimeException(
                'Invalid request. Refresh the page and try again.'
            );
        }

        $action = (string)($_POST['action'] ?? '');

        if (!in_array($action, ['add', 'edit'], true)) {
            throw new RuntimeException('Invalid operation.');
        }

        $targetId = trim((string)($_POST['user_id'] ?? ''));
        $name = trim((string)($_POST['name'] ?? ''));
        $email = trim((string)($_POST['email'] ?? ''));
        $newRole = trim((string)($_POST['role'] ?? ''));
        $password = (string)($_POST['password'] ?? '');

        if (
            $targetId === '' ||
            strlen($targetId) > 10 ||
            !preg_match('/^[A-Za-z0-9_-]+$/', $targetId)
        ) {
            throw new RuntimeException(
                'User ID must contain 1–10 letters, numbers, underscores or hyphens.'
            );
        }

        if ($name === '' || strlen($name) > 100) {
            throw new RuntimeException(
                'Enter a valid name of up to 100 characters.'
            );
        }

        if (
            !filter_var($email, FILTER_VALIDATE_EMAIL) ||
            strlen($email) > 150
        ) {
            throw new RuntimeException('Enter a valid email address.');
        }

        if (!isset($roles[$newRole])) {
            throw new RuntimeException('Select a valid user role.');
        }

        if ($action === 'add' && strlen($password) < 8) {
            throw new RuntimeException(
                'A new user password must contain at least 8 characters.'
            );
        }

        if (
            $action === 'edit' &&
            $password !== '' &&
            strlen($password) < 8
        ) {
            throw new RuntimeException(
                'A replacement password must contain at least 8 characters.'
            );
        }

        if (strlen($password) > 255) {
            throw new RuntimeException('Password is too long.');
        }

        /*
         * Protect the currently logged-in HOD from
         * accidentally removing their own HOD role.
         */

        if (
            $action === 'edit' &&
            $targetId === $userId &&
            $newRole !== 'HOD'
        ) {
            throw new RuntimeException(
                'You cannot change your own HOD role.'
            );
        }

        $conn->begin_transaction();

        try {

            if ($action === 'add') {

                /*
                 * Existing physical SQL procedure:
                 * sp_register_department_user
                 *
                 * It creates the User record and the
                 * matching subtype record together.
                 */

                $stmt = dbStmt(
                    $conn,
                    "SELECT UserID
                     FROM `User`
                     WHERE UserID = ? OR Email = ?
                     LIMIT 1",
                    'ss',
                    [$targetId, $email]
                );

                $existing = $stmt->get_result()->fetch_assoc();
                $stmt->close();

                if ($existing) {
                    throw new RuntimeException(
                        'This User ID or email address is already registered.'
                    );
                }

                /*
                 * Insert into the master registry.
                 * Password storage matches the supplied
                 * physical database's SHA-256 convention.
                 */

                $hash = hash('sha256', $password);

                $stmt = dbStmt(
                    $conn,
                    "INSERT INTO `User`
                        (UserID, Name, Email, Password, RoleType)
                     VALUES (?, ?, ?, ?, ?)",
                    'sssss',
                    [
                        $targetId,
                        $name,
                        $email,
                        $hash,
                        $newRole
                    ]
                );

                $stmt->close();

                $table = $roleTables[$newRole];

                $stmt = dbStmt(
                    $conn,
                    "INSERT INTO `$table`
                        (UserID, Name, Email, Password)
                     VALUES (?, ?, ?, ?)",
                    'ssss',
                    [
                        $targetId,
                        $name,
                        $email,
                        $hash
                    ]
                );

                $stmt->close();

                $message = 'New user added successfully.';

            } else {

                /*
                 * Lock the selected user while editing.
                 */

                $stmt = dbStmt(
                    $conn,
                    "SELECT
                        UserID,
                        Name,
                        Email,
                        Password,
                        RoleType
                     FROM `User`
                     WHERE UserID = ?
                     FOR UPDATE",
                    's',
                    [$targetId]
                );

                $existing = $stmt->get_result()->fetch_assoc();
                $stmt->close();

                if (!$existing) {
                    throw new RuntimeException('User not found.');
                }

                $oldRole = $existing['RoleType'];

                /*
                 * Prevent removing the last HOD account.
                 */

                if (
                    $oldRole === 'HOD' &&
                    $newRole !== 'HOD'
                ) {

                    $stmt = dbStmt(
                        $conn,
                        "SELECT COUNT(*) AS total
                         FROM `User`
                         WHERE RoleType = 'HOD'"
                    );

                    $hodCount = (int)$stmt
                        ->get_result()
                        ->fetch_assoc()['total'];

                    $stmt->close();

                    if ($hodCount <= 1) {
                        throw new RuntimeException(
                            'The last HOD account cannot be reassigned.'
                        );
                    }
                }

                $hash = $password !== ''
                    ? hash('sha256', $password)
                    : $existing['Password'];

                if ($oldRole !== $newRole) {

                    /*
                     * Remove the old subtype membership,
                     * then create the new one.
                     *
                     * The User row remains unchanged
                     * until its role is updated below.
                     */

                    $oldTable = $roleTables[$oldRole];
                    $newTable = $roleTables[$newRole];

                    $stmt = dbStmt(
                        $conn,
                        "DELETE FROM `$oldTable`
                         WHERE UserID = ?",
                        's',
                        [$targetId]
                    );

                    $stmt->close();

                    $stmt = dbStmt(
                        $conn,
                        "UPDATE `User`
                         SET Name = ?,
                             Email = ?,
                             Password = ?,
                             RoleType = ?
                         WHERE UserID = ?",
                        'sssss',
                        [
                            $name,
                            $email,
                            $hash,
                            $newRole,
                            $targetId
                        ]
                    );

                    $stmt->close();

                    $stmt = dbStmt(
                        $conn,
                        "INSERT INTO `$newTable`
                            (UserID, Name, Email, Password)
                         VALUES (?, ?, ?, ?)",
                        'ssss',
                        [
                            $targetId,
                            $name,
                            $email,
                            $hash
                        ]
                    );

                    $stmt->close();

                } else {

                    /*
                     * Existing synchronization trigger
                     * updates inherited subtype fields.
                     */

                    $stmt = dbStmt(
                        $conn,
                        "UPDATE `User`
                         SET Name = ?,
                             Email = ?,
                             Password = ?
                         WHERE UserID = ?",
                        'ssss',
                        [
                            $name,
                            $email,
                            $hash,
                            $targetId
                        ]
                    );

                    $stmt->close();
                }

                if ($targetId === $userId) {
                    $_SESSION['user_name'] = $name;
                    $_SESSION['user_email'] = $email;
                    $userName = $name;
                }

                $message = 'User details updated successfully.';
            }

            $conn->commit();

            $_SESSION['users_flash'] = $message;

            header('Location: users.php');
            exit;

        } catch (Throwable $e) {

            $conn->rollback();
            throw $e;
        }

    } catch (Throwable $e) {

        $error = $e->getMessage();
    }
}

if (!empty($_SESSION['users_flash'])) {
    $success = $_SESSION['users_flash'];
    unset($_SESSION['users_flash']);
}

/*
|--------------------------------------------------------------------------
| LOAD USER DIRECTORY
|--------------------------------------------------------------------------
*/

$users = [];
$counts = array_fill_keys(array_keys($roles), 0);

try {

    $result = $conn->query(
        "SELECT
            UserID,
            Name,
            Email,
            RoleType
         FROM `User`
         ORDER BY
            FIELD(
                RoleType,
                'HOD',
                'AcademicStaff',
                'Clerk',
                'SupportStaff',
                'StudentCoordinator'
            ),
            Name ASC"
    );

    if (!$result) {
        throw new RuntimeException($conn->error);
    }

    while ($row = $result->fetch_assoc()) {

        $users[] = $row;

        if (isset($counts[$row['RoleType']])) {
            $counts[$row['RoleType']]++;
        }
    }

} catch (Throwable $e) {

    $error = 'Unable to load users: ' . $e->getMessage();
}

$totalUsers = count($users);

$initials = strtoupper(
    substr(
        preg_replace('/[^a-z]/i', '', $userName),
        0,
        2
    )
);

/*
|--------------------------------------------------------------------------
| PERMISSION MATRIX
|--------------------------------------------------------------------------
*/

$permissions = [
    [
        'name' => 'View Dashboard',
        'HOD' => true,
        'AcademicStaff' => true,
        'Clerk' => true,
        'SupportStaff' => true,
        'StudentCoordinator' => true
    ],
    [
        'name' => 'Manage Annual Plan',
        'HOD' => true,
        'AcademicStaff' => false,
        'Clerk' => false,
        'SupportStaff' => false,
        'StudentCoordinator' => false
    ],
    [
        'name' => 'View Authorized Meetings',
        'HOD' => true,
        'AcademicStaff' => true,
        'Clerk' => true,
        'SupportStaff' => true,
        'StudentCoordinator' => true
    ],
    [
        'name' => 'Schedule / Reschedule Meetings',
        'HOD' => true,
        'AcademicStaff' => false,
        'Clerk' => true,
        'SupportStaff' => false,
        'StudentCoordinator' => false
    ],
    [
        'name' => 'Cancel Authorized Meetings',
        'HOD' => true,
        'AcademicStaff' => false,
        'Clerk' => true,
        'SupportStaff' => false,
        'StudentCoordinator' => false
    ],
    [
        'name' => 'Confirm Meeting Participation',
        'HOD' => true,
        'AcademicStaff' => true,
        'Clerk' => true,
        'SupportStaff' => true,
        'StudentCoordinator' => true
    ],
    [
        'name' => 'Upload Agendas & Media',
        'HOD' => true,
        'AcademicStaff' => false,
        'Clerk' => true,
        'SupportStaff' => false,
        'StudentCoordinator' => false
    ],
    [
        'name' => 'Manage Decision Records',
        'HOD' => true,
        'AcademicStaff' => false,
        'Clerk' => true,
        'SupportStaff' => false,
        'StudentCoordinator' => false
    ],
    [
        'name' => 'Access Scrutiny Board Records',
        'HOD' => true,
        'AcademicStaff' => true,
        'Clerk' => false,
        'SupportStaff' => false,
        'StudentCoordinator' => false
    ],
    [
        'name' => 'Manage Users & Access',
        'HOD' => true,
        'AcademicStaff' => false,
        'Clerk' => false,
        'SupportStaff' => false,
        'StudentCoordinator' => false
    ]
];

?>
<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">

<title>DataVerse | Users & Access</title>

<style>

:root {
    --navy: #102f3e;
    --navy2: #194b5c;
    --gold: #f4c45c;
    --bg: #edf3f5;
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
    line-height: 1.8;
}

.stats {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 17px;
    margin-bottom: 25px;
}

.stat {
    background: white;
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 22px;
}

.stat-label {
    color: var(--muted);
    font-size: 12px;
}

.stat-value {
    font-size: 33px;
    font-weight: 800;
    margin: 12px 0 5px;
}

.stat-note {
    color: #92a4af;
    font-size: 11px;
}

.card {
    background: white;
    border: 1px solid var(--border);
    border-radius: 17px;
    padding: 24px;
    margin-bottom: 23px;
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
    margin-bottom: 20px;
}

.button {
    display: inline-block;
    padding: 12px 16px;
    border: none;
    border-radius: 9px;
    background: var(--navy);
    color: white;
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

.button.outline {
    background: #edf2f4;
    color: var(--navy);
}

.button.small {
    padding: 8px 12px;
    font-size: 11px;
}

.filters {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    margin-bottom: 18px;
}

.filters input {
    flex: 1;
    min-width: 220px;
}

input,
select {
    padding: 12px;
    border: 1px solid #d9e4e9;
    border-radius: 9px;
    background: white;
    color: var(--text);
    font-size: 13px;
}

input:focus,
select:focus {
    outline: 2px solid #f4c45c70;
    border-color: var(--gold);
}

.table-wrap {
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
}

th {
    background: #f6f9fa;
    text-align: left;
    padding: 14px;
    font-size: 11px;
    color: #718899;
    white-space: nowrap;
}

td {
    padding: 15px 14px;
    border-bottom: 1px solid #edf1f3;
    font-size: 12px;
    vertical-align: middle;
}

tr:hover td {
    background: #fbfcfd;
}

.user-name {
    font-weight: 800;
}

.user-email {
    color: var(--muted);
    margin-top: 5px;
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

.badge.gold {
    background: #fff3d7;
    color: #a77512;
}

.badge.green {
    background: #e5f7ed;
    color: var(--green);
}

.badge.blue {
    background: #e9f1fb;
    color: #376a9c;
}

.badge.purple {
    background: #f0ebfa;
    color: #7655a2;
}

.badge.gray {
    background: #edf1f4;
    color: #607582;
}

.permission-yes {
    color: var(--green);
    font-size: 17px;
    font-weight: 800;
}

.permission-no {
    color: #c5d0d5;
    font-size: 17px;
    font-weight: 800;
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
    background: #f7fafb;
    border: 1px solid var(--border);
    padding: 15px;
    border-radius: 11px;
    color: #647c8b;
    font-size: 12px;
    line-height: 1.8;
}

.empty {
    text-align: center;
    padding: 30px;
    color: var(--muted);
    font-size: 13px;
}

.modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(7, 27, 39, .72);
    display: none;
    align-items: center;
    justify-content: center;
    padding: 20px;
    z-index: 1000;
}

.modal-overlay.show {
    display: flex;
}

.modal {
    background: white;
    width: 100%;
    max-width: 550px;
    border-radius: 18px;
    overflow: hidden;
    max-height: 95vh;
    overflow-y: auto;
}

.modal-top {
    background: var(--navy);
    color: white;
    padding: 24px 28px;
}

.modal-top h2 {
    margin: 0 0 7px;
    font-size: 21px;
}

.modal-top p {
    margin: 0;
    font-size: 12px;
    color: #c7d8e0;
}

.modal-body {
    padding: 25px 28px;
}

.form-group {
    margin-bottom: 17px;
}

.form-group label {
    display: block;
    font-size: 12px;
    font-weight: 800;
    margin-bottom: 8px;
}

.form-group input,
.form-group select {
    width: 100%;
}

.modal-actions {
    display: flex;
    gap: 10px;
    margin-top: 20px;
}

.footer {
    text-align: center;
    color: #91a2ad;
    font-size: 11px;
    margin-top: 30px;
}

@media (max-width: 1100px) {
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
    .topbar,
    .card-header {
        flex-direction: column;
        align-items: flex-start;
    }

    .stats {
        grid-template-columns: 1fr;
    }
}

</style>

</head>

<body>

<!-- SIDEBAR -->

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

        <a href="dashboard.php" class="nav-link">
            <span class="nav-icon">◫</span>
            Dashboard
        </a>

        <a href="annual_plan.php" class="nav-link">
            <span class="nav-icon">▦</span>
            Annual Planning
        </a>

        <a href="meetings.php" class="nav-link">
            <span class="nav-icon">▣</span>
            Meetings & Scheduling
        </a>

        <a href="participation.php" class="nav-link">
            <span class="nav-icon">♧</span>
            Attendance & Quorum
        </a>

        <a href="documents.php" class="nav-link">
            <span class="nav-icon">▤</span>
            Meeting Records & Decisions
        </a>

        <a href="users.php" class="nav-link active">
            <span class="nav-icon">♙</span>
            Users & Access
        </a>

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
                    Head of Department
                </div>

            </div>

        </div>

        <a href="logout.php" class="signout">
            ↪ Sign Out
        </a>

    </div>

</aside>

<!-- MAIN -->

<main class="main">

    <header class="topbar">

        <div>

            <div class="eyebrow">
                DEPARTMENT OF COMPUTING
            </div>

            <h1>Users & Access</h1>

            <p class="subtitle">
                Manage department users,
                role assignments, and access permissions.
            </p>

        </div>

        <div class="role-chip">
            Head of Department
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

    <!-- HERO -->

    <section class="hero">

        <div
            class="eyebrow"
            style="color:var(--gold)"
        >
            ADMINISTRATIVE CONTROL
        </div>

        <h2>Department User Management</h2>

        <p>
            Register users, update staff details,
            assign roles, and review department
            access restrictions.
        </p>

    </section>

    <!-- STATS -->

    <section class="stats">

        <div class="stat">

            <div class="stat-label">
                Total Registered Users
            </div>

            <div class="stat-value">
                <?= $totalUsers ?>
            </div>

            <div class="stat-note">
                Across all five roles
            </div>

        </div>

        <div class="stat">

            <div class="stat-label">
                Academic Staff
            </div>

            <div class="stat-value">
                <?= $counts['AcademicStaff'] ?>
            </div>

            <div class="stat-note">
                Permanent lecturers
            </div>

        </div>

        <div class="stat">

            <div class="stat-label">
                Student Coordinators
            </div>

            <div class="stat-value">
                <?= $counts['StudentCoordinator'] ?>
            </div>

            <div class="stat-note">
                Restricted academic access
            </div>

        </div>

        <div class="stat">

            <div class="stat-label">
                Heads of Department
            </div>

            <div class="stat-value">
                <?= $counts['HOD'] ?>
            </div>

            <div class="stat-note">
                Administrative accounts
            </div>

        </div>

        <div class="stat">

            <div class="stat-label">
                Clerks
            </div>

            <div class="stat-value">
                <?= $counts['Clerk'] ?>
            </div>

            <div class="stat-note">
                Department conveners
            </div>

        </div>

        <div class="stat">

            <div class="stat-label">
                Support Staff
            </div>

            <div class="stat-value">
                <?= $counts['SupportStaff'] ?>
            </div>

            <div class="stat-note">
                Technical and support users
            </div>

        </div>

    </section>

    <!-- USER DIRECTORY -->

    <section class="card">

        <div class="card-header">

            <div>

                <h2>User Directory</h2>

                <p class="subtitle">
                    View and manage registered
                    department users.
                </p>

            </div>

            <button
                class="button gold"
                type="button"
                onclick="openAddModal()"
            >
                + Add New User
            </button>

        </div>

        <div class="filters">

            <input
                type="search"
                id="searchUsers"
                placeholder="Search by name, email or User ID..."
                oninput="filterUsers()"
            >

            <select
                id="roleFilter"
                onchange="filterUsers()"
            >

                <option value="">
                    All Roles
                </option>

                <?php foreach ($roles as $key => $label): ?>

                    <option value="<?= h($key) ?>">
                        <?= h($label) ?>
                    </option>

                <?php endforeach; ?>

            </select>

        </div>

        <div class="table-wrap">

            <table id="usersTable">

                <thead>

                    <tr>

                        <th>USER ID</th>
                        <th>USER DETAILS</th>
                        <th>ROLE</th>
                        <th>ACCESS LEVEL</th>
                        <th>ACTIONS</th>

                    </tr>

                </thead>

                <tbody>

                    <?php foreach ($users as $user): ?>

                        <?php

                        $roleType = $user['RoleType'];

                        $badgeClass = match ($roleType) {
                            'HOD' => 'gold',
                            'AcademicStaff' => 'blue',
                            'Clerk' => 'green',
                            'SupportStaff' => 'gray',
                            'StudentCoordinator' => 'purple',
                            default => 'gray'
                        };

                        $accessLabel = match ($roleType) {
                            'HOD' => 'Full Administration',
                            'AcademicStaff' => 'Academic Access',
                            'Clerk' => 'Convener Access',
                            'SupportStaff' => 'Limited Staff Access',
                            'StudentCoordinator' => 'Student Access',
                            default => 'Restricted'
                        };

                        ?>

                        <tr
                            class="user-row"
                            data-role="<?= h($roleType) ?>"
                        >

                            <td>
                                <strong>
                                    <?= h($user['UserID']) ?>
                                </strong>
                            </td>

                            <td>

                                <div class="user-name">
                                    <?= h($user['Name']) ?>
                                </div>

                                <div class="user-email">
                                    <?= h($user['Email']) ?>
                                </div>

                            </td>

                            <td>

                                <span class="badge <?= h($badgeClass) ?>">
                                    <?= h($roles[$roleType] ?? $roleType) ?>
                                </span>

                            </td>

                            <td>
                                <?= h($accessLabel) ?>
                            </td>

                            <td>

                                <button
                                    type="button"
                                    class="button outline small"
                                    onclick="editUser(this)"
                                    data-id="<?= h($user['UserID']) ?>"
                                    data-name="<?= h($user['Name']) ?>"
                                    data-email="<?= h($user['Email']) ?>"
                                    data-role="<?= h($roleType) ?>"
                                >
                                    Edit User
                                </button>

                            </td>

                        </tr>

                    <?php endforeach; ?>

                </tbody>

            </table>

            <?php if (!$users): ?>

                <div class="empty">
                    No registered users found.
                </div>

            <?php endif; ?>

        </div>

    </section>

    <!-- ROLE PERMISSION MATRIX -->

    <section class="card">

        <h2>Role-Based Access Permissions</h2>

        <p class="subtitle">
            Overview of department permissions
            defined by the DataVerse access policy.
        </p>

        <div class="table-wrap" style="margin-top:20px">

            <table>

                <thead>

                    <tr>

                        <th>PERMISSION</th>

                        <th>HOD</th>

                        <th>ACADEMIC STAFF</th>

                        <th>CLERK</th>

                        <th>SUPPORT STAFF</th>

                        <th>STUDENT COORDINATOR</th>

                    </tr>

                </thead>

                <tbody>

                    <?php foreach ($permissions as $permission): ?>

                        <tr>

                            <td>
                                <strong>
                                    <?= h($permission['name']) ?>
                                </strong>
                            </td>

                            <?php foreach ($roles as $key => $label): ?>

                                <td>

                                    <?php if ($permission[$key]): ?>

                                        <span class="permission-yes">
                                            ✓
                                        </span>

                                    <?php else: ?>

                                        <span class="permission-no">
                                            —
                                        </span>

                                    <?php endif; ?>

                                </td>

                            <?php endforeach; ?>

                        </tr>

                    <?php endforeach; ?>

                </tbody>

            </table>

        </div>

        <div class="info" style="margin-top:20px">

            <strong>Important:</strong>

            The Clerk may manage ordinary department
            meetings but cannot modify or access
            confidential Scrutiny Board records.

            Academic Staff may access Scrutiny Board
            meetings according to their meeting assignment.

            Student Coordinators may participate in
            Department Meetings and their authorized
            student-related meetings.

            This matrix describes the intended role policy.
            Each PHP module must also enforce these
            permissions on the server.

        </div>

    </section>

    <!-- USER MANAGEMENT NOTES -->

    <section class="card">

        <h2>User Account Management</h2>

        <div class="info">

            New users are registered in the
            <strong>User</strong> table and their
            matching role-specific subtype table.

            Editing a user's role updates their
            subtype membership while preserving
            their User ID and existing meeting records.

            Existing users are not deleted from
            this interface because their IDs may
            already be referenced by attendance,
            confirmation, meeting, or decision records.

        </div>

    </section>

    <footer class="footer">
        DataVerse © <?= date('Y') ?>
        · Department of Computing
        · Rajarata University of Sri Lanka
    </footer>

</main>

<!-- ADD / EDIT MODAL -->

<div
    class="modal-overlay"
    id="userModal"
    role="dialog"
    aria-modal="true"
    aria-labelledby="modalTitle"
>

    <div class="modal">

        <div class="modal-top">

            <h2 id="modalTitle">
                Add New User
            </h2>

            <p id="modalSubtitle">
                Register a department user
                and assign their access role.
            </p>

        </div>

        <div class="modal-body">

            <form
                method="POST"
                id="userForm"
                onsubmit="return confirmUserSave()"
            >

                <input
                    type="hidden"
                    name="csrf"
                    value="<?= h($csrf) ?>"
                >

                <input
                    type="hidden"
                    name="action"
                    id="formAction"
                    value="add"
                >

                <div class="form-group">

                    <label for="formUserId">
                        User ID
                    </label>

                    <input
                        type="text"
                        id="formUserId"
                        name="user_id"
                        maxlength="10"
                        pattern="[A-Za-z0-9_-]+"
                        required
                        placeholder="e.g. U065"
                    >

                </div>

                <div class="form-group">

                    <label for="formName">
                        Full Name
                    </label>

                    <input
                        type="text"
                        id="formName"
                        name="name"
                        maxlength="100"
                        required
                        placeholder="Enter full name"
                    >

                </div>

                <div class="form-group">

                    <label for="formEmail">
                        Email Address
                    </label>

                    <input
                        type="email"
                        id="formEmail"
                        name="email"
                        maxlength="150"
                        required
                        placeholder="name@computing.rjt.ac.lk"
                    >

                </div>

                <div class="form-group">

                    <label for="formRole">
                        User Role
                    </label>

                    <select
                        id="formRole"
                        name="role"
                        required
                    >

                        <option value="">
                            Select role
                        </option>

                        <?php foreach ($roles as $key => $label): ?>

                            <option value="<?= h($key) ?>">
                                <?= h($label) ?>
                            </option>

                        <?php endforeach; ?>

                    </select>

                </div>

                <div class="form-group">

                    <label for="formPassword">
                        <span id="passwordLabel">
                            Initial Password
                        </span>
                    </label>

                    <input
                        type="password"
                        id="formPassword"
                        name="password"
                        minlength="8"
                        autocomplete="new-password"
                        placeholder="Minimum 8 characters"
                    >

                    <p
                        class="subtitle"
                        id="passwordHelp"
                    >
                        Required for new accounts.
                    </p>

                </div>

                <div class="modal-actions">

                    <button
                        type="submit"
                        class="button gold"
                        id="saveButton"
                    >
                        Save User
                    </button>

                    <button
                        type="button"
                        class="button outline"
                        onclick="closeUserModal()"
                    >
                        Cancel
                    </button>

                </div>

            </form>

        </div>

    </div>

</div>

<script>

/*
|--------------------------------------------------------------------------
| USER DIRECTORY FILTER
|--------------------------------------------------------------------------
*/

function filterUsers() {

    const search = document.getElementById(
        'searchUsers'
    ).value.toLowerCase();

    const role = document.getElementById(
        'roleFilter'
    ).value;

    document.querySelectorAll(
        '.user-row'
    ).forEach(function(row) {

        const text = row.textContent.toLowerCase();

        const matchesSearch = text.includes(search);

        const matchesRole =
            role === '' ||
            row.dataset.role === role;

        row.style.display =
            matchesSearch && matchesRole
                ? ''
                : 'none';
    });
}

/*
|--------------------------------------------------------------------------
| ADD USER
|--------------------------------------------------------------------------
*/

function openAddModal() {

    document.getElementById(
        'userForm'
    ).reset();

    document.getElementById(
        'formAction'
    ).value = 'add';

    document.getElementById(
        'formUserId'
    ).readOnly = false;

    document.getElementById(
        'formPassword'
    ).required = true;

    document.getElementById(
        'modalTitle'
    ).textContent = 'Add New User';

    document.getElementById(
        'modalSubtitle'
    ).textContent =
        'Register a department user and assign their role.';

    document.getElementById(
        'passwordLabel'
    ).textContent = 'Initial Password';

    document.getElementById(
        'passwordHelp'
    ).textContent =
        'Required for new accounts. Minimum 8 characters.';

    document.getElementById(
        'saveButton'
    ).textContent = 'Save User';

    document.getElementById(
        'userModal'
    ).classList.add('show');
}

/*
|--------------------------------------------------------------------------
| EDIT USER
|--------------------------------------------------------------------------
*/

function editUser(button) {

    document.getElementById(
        'userForm'
    ).reset();

    document.getElementById(
        'formAction'
    ).value = 'edit';

    const idField = document.getElementById(
        'formUserId'
    );

    idField.value = button.dataset.id;
    idField.readOnly = true;

    document.getElementById(
        'formName'
    ).value = button.dataset.name;

    document.getElementById(
        'formEmail'
    ).value = button.dataset.email;

    document.getElementById(
        'formRole'
    ).value = button.dataset.role;

    const passwordField = document.getElementById(
        'formPassword'
    );

    passwordField.value = '';
    passwordField.required = false;

    document.getElementById(
        'modalTitle'
    ).textContent = 'Edit User';

    document.getElementById(
        'modalSubtitle'
    ).textContent =
        'Update account details and role permissions.';

    document.getElementById(
        'passwordLabel'
    ).textContent = 'New Password (Optional)';

    document.getElementById(
        'passwordHelp'
    ).textContent =
        'Leave blank to keep the current password.';

    document.getElementById(
        'saveButton'
    ).textContent = 'Update User';

    document.getElementById(
        'userModal'
    ).classList.add('show');
}

/*
|--------------------------------------------------------------------------
| CLOSE MODAL
|--------------------------------------------------------------------------
*/

function closeUserModal() {

    document.getElementById(
        'userModal'
    ).classList.remove('show');
}

document.getElementById(
    'userModal'
).addEventListener('click', function(event) {

    if (event.target === this) {
        closeUserModal();
    }
});

document.addEventListener('keydown', function(event) {

    if (event.key === 'Escape') {
        closeUserModal();
    }
});

/*
|--------------------------------------------------------------------------
| SAVE CONFIRMATION
|--------------------------------------------------------------------------
*/

function confirmUserSave() {

    const action = document.getElementById(
        'formAction'
    ).value;

    if (action === 'edit') {
        return confirm(
            'Are you sure you want to update this user account?'
        );
    }

    return confirm(
        'Are you sure you want to register this new user?'
    );
}

</script>

</body>
</html>
