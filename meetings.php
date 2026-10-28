
<?php
session_start();

if (
    empty($_SESSION["user_id"]) ||
    empty($_SESSION["user_role"])
) {
    header("Location: login.php");
    exit;
}

require_once __DIR__ . "/config.php";

header("Cache-Control: no-store, no-cache, must-revalidate");

function e($value) {
    return htmlspecialchars(
        (string)($value ?? ""),
        ENT_QUOTES | ENT_SUBSTITUTE,
        "UTF-8"
    );
}

function prettyDate($value) {
    if (!$value) return "Not set";
    $time = strtotime((string)$value);
    return $time ? date("d M Y", $time) : "Not set";
}

function prettyTime($value) {
    if (!$value) return "Not set";
    $time = strtotime((string)$value);
    return $time ? date("g:i A", $time) : "Not set";
}

function newId($prefix) {
    return $prefix . strtoupper(bin2hex(random_bytes(4)));
}

function validDateValue($date) {
    $d = DateTime::createFromFormat("!Y-m-d", (string)$date);
    return $d && $d->format("Y-m-d") === $date;
}

function validTimeValue($time) {
    return preg_match(
        '/^([01][0-9]|2[0-3]):[0-5][0-9]$/',
        (string)$time
    ) === 1;
}

function isPrivateMeeting($meeting) {
    return (string)$meeting["IsPrivate"] === "Yes";
}

$userId = (string)$_SESSION["user_id"];
$userName = (string)($_SESSION["user_name"] ?? "User");
$role = (string)$_SESSION["user_role"];

$roleNames = [
    "HOD" => "Head of Department",
    "AcademicStaff" => "Academic Staff",
    "Clerk" => "Clerk / Convener",
    "SupportStaff" => "Support Staff",
    "StudentCoordinator" => "Student Coordinator"
];

if (!isset($roleNames[$role])) {
    header("Location: logout.php");
    exit;
}

$isHod = $role === "HOD";
$isClerk = $role === "Clerk";
$canManage = $isHod || $isClerk;

if (empty($_SESSION["meetings_csrf"])) {
    $_SESSION["meetings_csrf"] = bin2hex(random_bytes(32));
}

$csrf = $_SESSION["meetings_csrf"];

$success = "";
$error = "";

if (isset($_GET["saved"])) {
    $messages = [
        "created" => "Meeting scheduled successfully.",
        "rescheduled" => "Meeting rescheduled successfully.",
        "cancelled" => "Meeting cancelled successfully."
    ];

    $success = $messages[$_GET["saved"]] ?? "";
}

/*
|--------------------------------------------------------------------------
| DATA ACCESS HELPERS
|--------------------------------------------------------------------------
*/

function getMeetingForEdit($conn, $meetingId, $role) {

    $sql = "
        SELECT
            m.MeetingId,
            m.TypeID,
            m.PlanID,
            m.PlannedDate,
            m.StartTime,
            m.EndTime,
            m.Venue,
            m.IsFixed,
            m.Meeting_Status,
            m.RescheduleReason,
            mt.Name AS MeetingTypeName,
            mt.IsPrivate
        FROM Meeting m
        INNER JOIN MeetingType mt
            ON mt.TypeID = m.TypeID
        WHERE m.MeetingId = ?
        LIMIT 1
    ";

    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception($conn->error);

    $stmt->bind_param("s", $meetingId);
    $stmt->execute();

    $meeting = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$meeting) {
        throw new Exception("Meeting not found.");
    }

    /*
     * IMPORTANT:
     * The Clerk may VIEW private Scrutiny Board
     * meetings in the schedule, but cannot modify them.
     */
    if (
        $role === "Clerk" &&
        isPrivateMeeting($meeting)
    ) {
        throw new Exception(
            "Clerk accounts have view-only access to Scrutiny Board meetings."
        );
    }

    return $meeting;
}

function checkVenueConflict(
    $conn,
    $date,
    $start,
    $end,
    $venue,
    $excludeId = ""
) {

    $sql = "
        SELECT MeetingId
        FROM Meeting
        WHERE PlannedDate = ?
          AND Venue = ?
          AND MeetingId <> ?
          AND Meeting_Status NOT IN ('Cancelled', 'Postponed')
          AND StartTime < ?
          AND EndTime > ?
        LIMIT 1
    ";

    $stmt = $conn->prepare($sql);

    if (!$stmt) throw new Exception($conn->error);

    $stmt->bind_param(
        "sssss",
        $date,
        $venue,
        $excludeId,
        $end,
        $start
    );

    $stmt->execute();

    $conflict = $stmt->get_result()->fetch_assoc();

    $stmt->close();

    if ($conflict) {
        throw new Exception(
            "Venue conflict: another meeting (" .
            $conflict["MeetingId"] .
            ") uses this venue during the selected time."
        );
    }
}

function addMeetingNotification($conn, $meetingId, $type) {

    $notificationId = newId("N");

    $stmt = $conn->prepare(
        "INSERT INTO Notification
         (NotificationID, Type, Sent_Date, MeetingId)
         VALUES (?, ?, CURDATE(), ?)"
    );

    if (!$stmt) throw new Exception($conn->error);

    $stmt->bind_param(
        "sss",
        $notificationId,
        $type,
        $meetingId
    );

    if (!$stmt->execute()) {
        throw new Exception($stmt->error);
    }

    $stmt->close();
}

function redirectAfterSave($action) {
    header(
        "Location: meetings.php?saved=" .
        urlencode($action)
    );
    exit;
}

/*
|--------------------------------------------------------------------------
| CREATE / RESCHEDULE / CANCEL
|--------------------------------------------------------------------------
| All permissions are checked on the server.
|--------------------------------------------------------------------------
*/

if ($_SERVER["REQUEST_METHOD"] === "POST") {

    try {

        if (!$canManage) {
            throw new Exception(
                "Your role does not allow meeting changes."
            );
        }

        $postedCsrf = (string)($_POST["csrf"] ?? "");

        if (!hash_equals($csrf, $postedCsrf)) {
            throw new Exception(
                "Invalid request. Refresh the page and try again."
            );
        }

        $action = (string)($_POST["action"] ?? "");

        if (!in_array(
            $action,
            ["create", "reschedule", "cancel"],
            true
        )) {
            throw new Exception("Invalid meeting action.");
        }

        /*
        |--------------------------------------------------------------
        | CREATE MEETING
        |--------------------------------------------------------------
        */
        if ($action === "create") {

            $typeId = trim((string)($_POST["type_id"] ?? ""));
            $planId = trim((string)($_POST["plan_id"] ?? ""));
            $date = trim((string)($_POST["date"] ?? ""));
            $start = trim((string)($_POST["start"] ?? ""));
            $end = trim((string)($_POST["end"] ?? ""));
            $venue = trim((string)($_POST["venue"] ?? ""));
            $fixed = isset($_POST["is_fixed"]) ? "Yes" : "No";

            if (
                !$typeId ||
                !$planId ||
                !$date ||
                !$start ||
                !$end ||
                !$venue
            ) {
                throw new Exception(
                    "Please complete every required field."
                );
            }

            if (!validDateValue($date)) {
                throw new Exception("Invalid meeting date.");
            }

            if (
                !validTimeValue($start) ||
                !validTimeValue($end) ||
                $start >= $end
            ) {
                throw new Exception(
                    "The end time must be later than the start time."
                );
            }

            if (strlen($venue) > 100) {
                throw new Exception(
                    "Venue must be 100 characters or fewer."
                );
            }

            // Confirm selected meeting type and privacy.
            $stmt = $conn->prepare(
                "SELECT TypeID, IsPrivate
                 FROM MeetingType
                 WHERE TypeID = ?
                 LIMIT 1"
            );

            if (!$stmt) {
                throw new Exception($conn->error);
            }

            $stmt->bind_param("s", $typeId);
            $stmt->execute();

            $type = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if (!$type) {
                throw new Exception("Invalid meeting type.");
            }

            /*
             * The Clerk cannot CREATE Scrutiny Board meetings.
             * Only the HOD may schedule private meetings.
             */
            if (
                $isClerk &&
                $type["IsPrivate"] === "Yes"
            ) {
                throw new Exception(
                    "Clerk accounts cannot schedule private Scrutiny Board meetings."
                );
            }

            // Confirm annual plan and its year.
            $stmt = $conn->prepare(
                "SELECT AcademicYear
                 FROM YearPlan
                 WHERE PlanID = ?
                 LIMIT 1"
            );

            if (!$stmt) {
                throw new Exception($conn->error);
            }

            $stmt->bind_param("s", $planId);
            $stmt->execute();

            $plan = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if (!$plan) {
                throw new Exception("Invalid annual plan.");
            }

            if (
                (int)substr($date, 0, 4) !==
                (int)$plan["AcademicYear"]
            ) {
                throw new Exception(
                    "The meeting date must belong to the selected annual plan year."
                );
            }

            checkVenueConflict(
                $conn,
                $date,
                $start,
                $end,
                $venue
            );

            /*
             * Meeting.UserID references the HOD.
             * A Clerk-created meeting is recorded under
             * the department HOD.
             */
            if ($isHod) {
                $hodId = $userId;
            } else {

                $result = $conn->query(
                    "SELECT UserID
                     FROM HOD
                     ORDER BY UserID
                     LIMIT 1"
                );

                if (!$result) {
                    throw new Exception($conn->error);
                }

                $hod = $result->fetch_assoc();

                if (!$hod) {
                    throw new Exception(
                        "No HOD account is available."
                    );
                }

                $hodId = $hod["UserID"];
            }

            $meetingId = newId("M");

            $conn->begin_transaction();

            try {

                $stmt = $conn->prepare(
                    "INSERT INTO Meeting
                    (
                        MeetingId,
                        IsFixed,
                        PlannedDate,
                        ActualDate,
                        StartTime,
                        EndTime,
                        Venue,
                        Meeting_Status,
                        RescheduleReason,
                        TypeID,
                        PlanID,
                        UserID,
                        Agenda_id
                    )
                    VALUES
                    (
                        ?, ?, ?, NULL, ?, ?, ?,
                        'Scheduled', NULL, ?, ?, ?, NULL
                    )"
                );

                if (!$stmt) {
                    throw new Exception($conn->error);
                }

                $stmt->bind_param(
                    "sssssssss",
                    $meetingId,
                    $fixed,
                    $date,
                    $start,
                    $end,
                    $venue,
                    $typeId,
                    $planId,
                    $hodId
                );

                if (!$stmt->execute()) {
                    throw new Exception($stmt->error);
                }

                $stmt->close();

                addMeetingNotification(
                    $conn,
                    $meetingId,
                    "Meeting Invitation"
                );

                $conn->commit();

            } catch (Throwable $ex) {
                $conn->rollback();
                throw $ex;
            }

            redirectAfterSave("created");
        }

        /*
        |--------------------------------------------------------------
        | RESCHEDULE MEETING
        |--------------------------------------------------------------
        */
        if ($action === "reschedule") {

            $meetingId = trim(
                (string)($_POST["meeting_id"] ?? "")
            );

            $meeting = getMeetingForEdit(
                $conn,
                $meetingId,
                $role
            );

            if ($meeting["IsFixed"] === "Yes") {
                throw new Exception(
                    "This meeting has a fixed academic date and cannot be rescheduled."
                );
            }

            if (in_array(
                $meeting["Meeting_Status"],
                ["Completed", "Cancelled"],
                true
            )) {
                throw new Exception(
                    "Completed or cancelled meetings cannot be rescheduled."
                );
            }

            $date = trim((string)($_POST["date"] ?? ""));
            $start = trim((string)($_POST["start"] ?? ""));
            $end = trim((string)($_POST["end"] ?? ""));
            $venue = trim((string)($_POST["venue"] ?? ""));
            $reason = trim((string)($_POST["reason"] ?? ""));

            if (
                !validDateValue($date) ||
                !validTimeValue($start) ||
                !validTimeValue($end) ||
                $start >= $end
            ) {
                throw new Exception(
                    "Please provide a valid date and time range."
                );
            }

            if (
                $venue === "" ||
                strlen($venue) > 100 ||
                $reason === "" ||
                strlen($reason) > 255
            ) {
                throw new Exception(
                    "Enter a venue and a rescheduling reason (maximum 255 characters)."
                );
            }

            // Keep the meeting within its annual plan.
            if ($meeting["PlanID"]) {

                $stmt = $conn->prepare(
                    "SELECT AcademicYear
                     FROM YearPlan
                     WHERE PlanID = ?"
                );

                if (!$stmt) {
                    throw new Exception($conn->error);
                }

                $stmt->bind_param(
                    "s",
                    $meeting["PlanID"]
                );

                $stmt->execute();
                $plan = $stmt->get_result()->fetch_assoc();
                $stmt->close();

                if (
                    $plan &&
                    (int)substr($date, 0, 4) !==
                    (int)$plan["AcademicYear"]
                ) {
                    throw new Exception(
                        "The new date must be within the meeting's annual plan year."
                    );
                }
            }

            checkVenueConflict(
                $conn,
                $date,
                $start,
                $end,
                $venue,
                $meetingId
            );

            $conn->begin_transaction();

            try {

                $stmt = $conn->prepare(
                    "UPDATE Meeting
                     SET PlannedDate = ?,
                         StartTime = ?,
                         EndTime = ?,
                         Venue = ?,
                         Meeting_Status = 'Scheduled',
                         RescheduleReason = ?
                     WHERE MeetingId = ?"
                );

                if (!$stmt) {
                    throw new Exception($conn->error);
                }

                $stmt->bind_param(
                    "ssssss",
                    $date,
                    $start,
                    $end,
                    $venue,
                    $reason,
                    $meetingId
                );

                if (!$stmt->execute()) {
                    throw new Exception($stmt->error);
                }

                $stmt->close();

                addMeetingNotification(
                    $conn,
                    $meetingId,
                    "Reschedule Alert"
                );

                $conn->commit();

            } catch (Throwable $ex) {
                $conn->rollback();
                throw $ex;
            }

            redirectAfterSave("rescheduled");
        }

        /*
        |--------------------------------------------------------------
        | CANCEL MEETING
        |--------------------------------------------------------------
        */
        if ($action === "cancel") {

            $meetingId = trim(
                (string)($_POST["meeting_id"] ?? "")
            );

            $reason = trim(
                (string)($_POST["reason"] ?? "")
            );

            $meeting = getMeetingForEdit(
                $conn,
                $meetingId,
                $role
            );

            if (in_array(
                $meeting["Meeting_Status"],
                ["Completed", "Cancelled"],
                true
            )) {
                throw new Exception(
                    "This meeting cannot be cancelled in its current status."
                );
            }

            if (
                $reason === "" ||
                strlen($reason) > 240
            ) {
                throw new Exception(
                    "Enter a cancellation reason (maximum 240 characters)."
                );
            }

            /*
             * The current schema has RescheduleReason
             * but no separate CancellationReason column.
             * The reason is retained in the existing column.
             */
            $storedReason = "Cancelled: " . $reason;

            $conn->begin_transaction();

            try {

                $stmt = $conn->prepare(
                    "UPDATE Meeting
                     SET Meeting_Status = 'Cancelled',
                         ActualDate = NULL,
                         RescheduleReason = ?
                     WHERE MeetingId = ?"
                );

                if (!$stmt) {
                    throw new Exception($conn->error);
                }

                $stmt->bind_param(
                    "ss",
                    $storedReason,
                    $meetingId
                );

                if (!$stmt->execute()) {
                    throw new Exception($stmt->error);
                }

                $stmt->close();

                addMeetingNotification(
                    $conn,
                    $meetingId,
                    "Meeting Cancellation"
                );

                $conn->commit();

            } catch (Throwable $ex) {
                $conn->rollback();
                throw $ex;
            }

            redirectAfterSave("cancelled");
        }

    } catch (Throwable $ex) {

        error_log(
            "DataVerse meetings error: " .
            $ex->getMessage()
        );

        $error = $ex->getMessage();
    }
}

/*
|--------------------------------------------------------------------------
| LOAD FILTERS AND MEETINGS
|--------------------------------------------------------------------------
*/

$years = [];
$types = [];
$meetings = [];

try {

    $result = $conn->query(
        "SELECT PlanID, AcademicYear
         FROM YearPlan
         ORDER BY AcademicYear DESC"
    );

    if (!$result) {
        throw new Exception($conn->error);
    }

    while ($row = $result->fetch_assoc()) {
        $years[] = $row;
    }

    $result = $conn->query(
        "SELECT
            TypeID,
            Name,
            ShortName,
            IsPrivate,
            CalendarColorHex
         FROM MeetingType
         ORDER BY Name"
    );

    if (!$result) {
        throw new Exception($conn->error);
    }

    while ($row = $result->fetch_assoc()) {

        /*
         * Scrutiny Board is NOT offered as a
         * scheduling option to Clerk accounts.
         */
        if (
            $isClerk &&
            $row["IsPrivate"] === "Yes"
        ) {
            continue;
        }

        $types[] = $row;
    }

    $sql = "
        SELECT
            m.MeetingId,
            m.TypeID,
            m.PlanID,
            m.PlannedDate,
            m.StartTime,
            m.EndTime,
            m.Venue,
            m.IsFixed,
            m.Meeting_Status,
            m.RescheduleReason,
            mt.Name AS MeetingTypeName,
            mt.ShortName,
            mt.IsPrivate,
            mt.CalendarColorHex,
            yp.AcademicYear
        FROM Meeting m
        INNER JOIN MeetingType mt
            ON mt.TypeID = m.TypeID
        LEFT JOIN YearPlan yp
            ON yp.PlanID = m.PlanID
        WHERE 1 = 1
    ";

    /*
     * UPDATED CLERK ACCESS:
     *
     * Clerk can now VIEW every meeting,
     * including private Scrutiny Board meetings.
     *
     * Editing restrictions are applied separately.
     */
    if ($isClerk) {

        // No extra WHERE restriction.
        // Private meetings are included for viewing.

    } elseif ($role === "SupportStaff") {

        $sql .= "
            AND mt.IsPrivate = 'No'
            AND mt.ShortName IN ('DM', 'SW')
            AND EXISTS (
                SELECT 1
                FROM Attends a
                WHERE a.MeetingId = m.MeetingId
                  AND a.UserID = ?
            )
        ";

    } elseif ($role === "StudentCoordinator") {

        $sql .= "
            AND mt.IsPrivate = 'No'
            AND mt.ShortName IN ('SC', 'CP')
            AND EXISTS (
                SELECT 1
                FROM Attends a
                WHERE a.MeetingId = m.MeetingId
                  AND a.UserID = ?
            )
        ";

    } elseif ($role === "AcademicStaff") {

        $sql .= "
            AND EXISTS (
                SELECT 1
                FROM Attends a
                WHERE a.MeetingId = m.MeetingId
                  AND a.UserID = ?
            )
        ";
    }

    $sql .= "
        ORDER BY m.PlannedDate DESC, m.StartTime ASC
    ";

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new Exception($conn->error);
    }

    if (in_array(
        $role,
        ["AcademicStaff", "SupportStaff", "StudentCoordinator"],
        true
    )) {
        $stmt->bind_param("s", $userId);
    }

    $stmt->execute();

    $result = $stmt->get_result();

    while ($row = $result->fetch_assoc()) {
        $meetings[] = $row;
    }

    $stmt->close();

} catch (Throwable $ex) {

    error_log(
        "DataVerse meeting listing: " .
        $ex->getMessage()
    );

    $error = "Unable to load meetings: " . $ex->getMessage();
}

$counts = [
    "total" => count($meetings),
    "scheduled" => 0,
    "completed" => 0,
    "cancelled" => 0
];

foreach ($meetings as $meeting) {

    $status = $meeting["Meeting_Status"];

    if (isset($counts[strtolower($status)])) {
        $counts[strtolower($status)]++;
    }
}

$navigation = [
    ["Dashboard", "dashboard.php", "◫"],
    ["Annual Planning", "annual_plan.php", "▦"],
    ["Meetings & Scheduling", "meetings.php", "▣"],
    ["Attendance & Quorum", "participation.php", "♧"],
    ["Agendas & Documents", "documents.php", "▤"],
    ["Decisions & Reports", "decisions.php", "☷"]
];

$initials = "";

foreach (explode(" ", trim($userName)) as $part) {
    if ($part !== "") {
        $initials .= strtoupper(substr($part, 0, 1));
    }
}

$initials = substr($initials, 0, 2) ?: "DV";

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">

    <meta
        name="viewport"
        content="width=device-width, initial-scale=1"
    >

    <title>DataVerse | Meetings & Scheduling</title>

    <style>
        :root {
            --navy: #102f3e;
            --navy2: #194b5c;
            --gold: #f4c45c;
            --bg: #edf3f5;
            --text: #173447;
            --muted: #708797;
            --border: #e3ebef;
            --white: #ffffff;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            background: var(--bg);
            color: var(--text);
            font-family: "Segoe UI", Arial, sans-serif;
        }

        button,
        input,
        select,
        textarea {
            font: inherit;
        }

        .sidebar {
            position: fixed;
            left: 0;
            top: 0;
            bottom: 0;
            width: 258px;
            background: var(--navy);
            padding: 28px 18px;
            color: white;
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
            padding: 14px 15px;
            margin: 3px 0;
            text-decoration: none;
            color: #d1e0e8;
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
            font-size: 19px;
            text-align: center;
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
            border-radius: 12px;
            background: var(--gold);
            color: var(--navy);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 800;
        }

        .profile-name {
            font-size: 12px;
            font-weight: 800;
        }

        .profile-role {
            color: #adc5d0;
            font-size: 11px;
            margin-top: 5px;
        }

        .signout {
            display: block;
            text-align: center;
            background: #ffffff15;
            border: 1px solid #ffffff30;
            padding: 13px;
            border-radius: 9px;
            color: white;
            text-decoration: none;
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
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 20px;
        }

        .hero h2 {
            font-size: 26px;
            margin: 8px 0;
        }

        .hero p {
            color: #d4e3e9;
            font-size: 13px;
            line-height: 1.7;
        }

        .button {
            border: 0;
            border-radius: 9px;
            padding: 11px 16px;
            background: var(--navy);
            color: white;
            cursor: pointer;
            font-size: 12px;
            font-weight: 800;
            text-decoration: none;
            display: inline-block;
        }

        .button.gold {
            background: var(--gold);
            color: var(--navy);
        }

        .button.secondary {
            background: #eaf0f3;
            color: var(--navy);
        }

        .button.danger {
            background: #fff0f0;
            color: #b83f3f;
        }

        .button.small {
            padding: 8px 10px;
            font-size: 11px;
        }

        .button:disabled {
            opacity: .45;
            cursor: not-allowed;
        }

        .stats {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 16px;
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

        .stat-number {
            color: var(--navy);
            font-size: 31px;
            font-weight: 800;
            margin-top: 13px;
        }

        .section {
            background: white;
            border: 1px solid var(--border);
            border-radius: 17px;
            padding: 25px;
            margin-bottom: 24px;
        }

        .section-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 15px;
            margin-bottom: 20px;
        }

        .section-title {
            font-size: 18px;
            font-weight: 800;
            margin: 0;
        }

        .filters {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 12px;
            margin-bottom: 22px;
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
            font-size: 13px;
        }

        label {
            display: block;
            font-size: 12px;
            font-weight: 800;
            margin-bottom: 8px;
        }

        .form-group {
            margin-bottom: 16px;
        }

        .form-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 14px;
        }

        .check-row {
            display: flex;
            align-items: center;
            gap: 9px;
            font-size: 12px;
        }

        .check-row input {
            width: auto;
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
            padding: 14px 12px;
            background: #f7fafb;
            color: #8497a3;
            font-size: 11px;
            white-space: nowrap;
        }

        td {
            padding: 15px 12px;
            border-bottom: 1px solid #edf1f3;
            font-size: 12px;
            vertical-align: middle;
        }

        .meeting-name {
            font-weight: 800;
            line-height: 1.5;
        }

        .muted {
            color: var(--muted);
            font-size: 11px;
            margin-top: 5px;
        }

        .dot {
            display: inline-block;
            width: 10px;
            height: 10px;
            border-radius: 50%;
            margin-right: 7px;
        }

        .status {
            display: inline-block;
            padding: 7px 10px;
            border-radius: 30px;
            background: #edf1f4;
            color: #657989;
            font-size: 10px;
            font-weight: 800;
        }

        .status.completed {
            background: #e5f7ed;
            color: #218455;
        }

        .status.scheduled {
            background: #e9f1fb;
            color: #376a9c;
        }

        .status.planned {
            background: #fff4dd;
            color: #a9750d;
        }

        .status.cancelled,
        .status.postponed {
            background: #fff0f0;
            color: #b65353;
        }

        .status.restricted {
            background: #f1eafd;
            color: #7754ad;
        }

        .actions {
            display: flex;
            gap: 7px;
            flex-wrap: wrap;
        }

        .success,
        .error {
            padding: 14px;
            border-radius: 10px;
            margin-bottom: 20px;
            font-size: 13px;
        }

        .success {
            background: #e5f7ed;
            color: #218455;
        }

        .error {
            background: #fff0f0;
            color: #b65353;
        }

        .modal-backdrop {
            position: fixed;
            inset: 0;
            background: #071923b8;
            display: none;
            align-items: center;
            justify-content: center;
            padding: 20px;
            z-index: 100;
        }

        .modal-backdrop.open {
            display: flex;
        }

        .modal {
            background: white;
            width: 550px;
            max-width: 100%;
            max-height: 90vh;
            overflow-y: auto;
            border-radius: 18px;
            padding: 27px;
        }

        .modal-head {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 22px;
        }

        .modal-head h2 {
            margin: 0;
            font-size: 21px;
        }

        .close {
            border: 0;
            background: #eef2f4;
            border-radius: 8px;
            padding: 7px 12px;
            font-size: 20px;
            cursor: pointer;
        }

        .hint {
            color: var(--muted);
            font-size: 12px;
            line-height: 1.7;
        }

        .empty {
            text-align: center;
            padding: 35px;
            color: var(--muted);
            font-size: 13px;
        }

        .footer {
            text-align: center;
            color: #92a1ab;
            font-size: 11px;
            margin-top: 35px;
        }

        @media (max-width: 1150px) {
            .stats {
                grid-template-columns: repeat(2, 1fr);
            }

            .filters {
                grid-template-columns: 1fr 1fr;
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
            .hero {
                flex-direction: column;
                align-items: stretch;
            }

            .stats,
            .filters,
            .form-grid {
                grid-template-columns: 1fr;
            }

            .section {
                padding: 18px;
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
            DEPARTMENT COMMUNICATION
            <br>
            MANAGEMENT SYSTEM
        </div>
    </div>

    <div class="nav-title">
        MAIN NAVIGATION
    </div>

    <nav>
        <?php foreach ($navigation as $item): ?>

            <?php
            if (
                $item[1] === "annual_plan.php" &&
                !in_array(
                    $role,
                    ["HOD", "Clerk", "AcademicStaff"],
                    true
                )
            ) {
                continue;
            }

            if (
                $item[1] === "decisions.php" &&
                !in_array(
                    $role,
                    ["HOD", "Clerk", "AcademicStaff"],
                    true
                )
            ) {
                continue;
            }
            ?>

            <a
                href="<?= e($item[1]) ?>"
                class="nav-link <?= $item[1] === 'meetings.php' ? 'active' : '' ?>"
            >
                <span class="nav-icon">
                    <?= e($item[2]) ?>
                </span>

                <?= e($item[0]) ?>
            </a>

        <?php endforeach; ?>

        <?php if ($isHod): ?>

            <a href="users.php" class="nav-link">
                <span class="nav-icon">♙</span>
                Users & Access
            </a>

        <?php endif; ?>
    </nav>

    <div class="sidebar-bottom">

        <div class="profile">
            <div class="avatar">
                <?= e($initials) ?>
            </div>

            <div>
                <div class="profile-name">
                    <?= e($userName) ?>
                </div>

                <div class="profile-role">
                    <?= e($roleNames[$role]) ?>
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

            <h1>Meetings & Scheduling</h1>

            <p class="subtitle">
                Manage department meetings, dates,
                venues and schedule changes.
            </p>
        </div>

        <div class="role-chip">
            <?= e($roleNames[$role]) ?>
        </div>

    </header>

    <?php if ($success): ?>
        <div class="success">
            ✓ <?= e($success) ?>
        </div>
    <?php endif; ?>

    <?php if ($error): ?>
        <div class="error">
            <?= e($error) ?>
        </div>
    <?php endif; ?>

    <section class="hero">

        <div>
            <div
                class="eyebrow"
                style="color:var(--gold)"
            >
                MONTHLY SCHEDULING WORKSPACE
            </div>

            <h2>Department Meeting Calendar</h2>

            <p>
                View meeting schedules, check availability,
                and manage authorized changes.
            </p>
        </div>

        <?php if ($canManage): ?>

            <button
                type="button"
                class="button gold"
                onclick="openCreate()"
            >
                + Schedule Meeting
            </button>

        <?php endif; ?>

    </section>

    <section class="stats">

        <div class="stat">
            <div class="stat-label">
                Total Meetings
            </div>

            <div class="stat-number">
                <?= e($counts["total"]) ?>
            </div>
        </div>

        <div class="stat">
            <div class="stat-label">
                Scheduled
            </div>

            <div class="stat-number">
                <?= e($counts["scheduled"]) ?>
            </div>
        </div>

        <div class="stat">
            <div class="stat-label">
                Completed
            </div>

            <div class="stat-number">
                <?= e($counts["completed"]) ?>
            </div>
        </div>

        <div class="stat">
            <div class="stat-label">
                Cancelled
            </div>

            <div class="stat-number">
                <?= e($counts["cancelled"]) ?>
            </div>
        </div>

    </section>

    <section class="section">

        <div class="section-header">
            <div>
                <h2 class="section-title">
                    Meeting Schedule
                </h2>

                <p class="subtitle">
                    Search and filter the meetings
                    available to your role.
                </p>
            </div>
        </div>

        <div class="filters">

            <input
                type="search"
                id="searchInput"
                placeholder="Search meetings..."
                oninput="filterMeetings()"
            >

            <select
                id="statusFilter"
                onchange="filterMeetings()"
            >
                <option value="">All Statuses</option>
                <option value="Scheduled">Scheduled</option>
                <option value="Planned">Planned</option>
                <option value="Completed">Completed</option>
                <option value="Cancelled">Cancelled</option>
                <option value="Postponed">Postponed</option>
            </select>

            <select
                id="yearFilter"
                onchange="filterMeetings()"
            >
                <option value="">All Years</option>

                <?php foreach ($years as $year): ?>
                    <option value="<?= e($year["AcademicYear"]) ?>">
                        <?= e($year["AcademicYear"]) ?>
                    </option>
                <?php endforeach; ?>
            </select>

        </div>

        <div class="table-wrap">

            <table id="meetingsTable">

                <thead>
                    <tr>
                        <th>Meeting</th>
                        <th>Date</th>
                        <th>Time</th>
                        <th>Venue</th>
                        <th>Type</th>
                        <th>Status</th>

                        <?php if ($canManage): ?>
                            <th>Actions</th>
                        <?php endif; ?>
                    </tr>
                </thead>

                <tbody>

                    <?php foreach ($meetings as $meeting): ?>

                        <?php
                        $status = (string)$meeting["Meeting_Status"];

                        /*
                         * NEW:
                         * Clerk may view Scrutiny Board meetings,
                         * but cannot reschedule or cancel them.
                         */
                        $isRestrictedScrutiny = (
                            $isClerk &&
                            $meeting["IsPrivate"] === "Yes"
                        );

                        $editable = $canManage &&
                            !$isRestrictedScrutiny &&
                            !in_array(
                                $status,
                                ["Completed", "Cancelled"],
                                true
                            );

                        $canReschedule = $editable &&
                            $meeting["IsFixed"] !== "Yes";

                        $data = [
                            "id" => $meeting["MeetingId"],
                            "name" => $meeting["MeetingTypeName"],
                            "date" => $meeting["PlannedDate"],
                            "start" => substr(
                                (string)$meeting["StartTime"],
                                0,
                                5
                            ),
                            "end" => substr(
                                (string)$meeting["EndTime"],
                                0,
                                5
                            ),
                            "venue" => $meeting["Venue"]
                        ];
                        ?>

                        <tr
                            data-search="<?= e(strtolower(
                                $meeting["MeetingTypeName"] . " " .
                                $meeting["MeetingId"] . " " .
                                $meeting["Venue"]
                            )) ?>"
                            data-status="<?= e($status) ?>"
                            data-year="<?= e($meeting["AcademicYear"]) ?>"
                        >

                            <td>
                                <div class="meeting-name">
                                    <span
                                        class="dot"
                                        style="background:<?= e($meeting["CalendarColorHex"]) ?>"
                                    ></span>

                                    <?= e($meeting["MeetingTypeName"]) ?>
                                </div>

                                <div class="muted">
                                    <?= e($meeting["MeetingId"]) ?>
                                    ·
                                    <?= e($meeting["ShortName"]) ?>
                                </div>
                            </td>

                            <td>
                                <?= e(prettyDate($meeting["PlannedDate"])) ?>
                            </td>

                            <td>
                                <?= e(prettyTime($meeting["StartTime"])) ?>
                                -
                                <?= e(prettyTime($meeting["EndTime"])) ?>
                            </td>

                            <td>
                                <?= e($meeting["Venue"]) ?>
                            </td>

                            <td>
                                <?php if ($meeting["IsFixed"] === "Yes"): ?>
                                    <span class="status planned">
                                        Fixed
                                    </span>
                                <?php else: ?>
                                    <span class="status">
                                        Flexible
                                    </span>
                                <?php endif; ?>
                            </td>

                            <td>
                                <span class="status <?= e(strtolower($status)) ?>">
                                    <?= e($status) ?>
                                </span>
                            </td>

                            <?php if ($canManage): ?>

                                <td>
                                    <div class="actions">

                                        <?php if ($canReschedule): ?>

                                            <button
                                                type="button"
                                                class="button small secondary"
                                                data-meeting="<?= e(json_encode($data)) ?>"
                                                onclick="openReschedule(this)"
                                            >
                                                Reschedule
                                            </button>

                                        <?php endif; ?>

                                        <?php if ($editable): ?>

                                            <button
                                                type="button"
                                                class="button small danger"
                                                data-meeting="<?= e(json_encode($data)) ?>"
                                                onclick="openCancel(this)"
                                            >
                                                Cancel
                                            </button>

                                        <?php endif; ?>

                                        <?php if (!$editable): ?>

                                            <?php if ($isRestrictedScrutiny): ?>

                                                <span class="status restricted">
                                                    View Only
                                                </span>

                                            <?php else: ?>

                                                <span class="muted">
                                                    Closed
                                                </span>

                                            <?php endif; ?>

                                        <?php endif; ?>

                                    </div>
                                </td>

                            <?php endif; ?>

                        </tr>

                    <?php endforeach; ?>

                </tbody>

            </table>

        </div>

        <?php if (empty($meetings)): ?>

            <div class="empty">
                No meetings are available for this account.
            </div>

        <?php endif; ?>

    </section>

    <div class="footer">
        DataVerse © <?= date("Y") ?>
        · Department of Computing
        · Rajarata University of Sri Lanka
    </div>

</main>

<?php if ($canManage): ?>

<!-- CREATE MODAL -->
<div
    class="modal-backdrop"
    id="createModal"
    onclick="closeModals(event)"
>

    <div
        class="modal"
        onclick="event.stopPropagation()"
    >

        <div class="modal-head">
            <h2>Schedule New Meeting</h2>

            <button
                type="button"
                class="close"
                onclick="closeModals()"
            >
                ×
            </button>
        </div>

        <form method="post" action="meetings.php">

            <input
                type="hidden"
                name="csrf"
                value="<?= e($csrf) ?>"
            >

            <input
                type="hidden"
                name="action"
                value="create"
            >

            <div class="form-group">
                <label>Meeting Type</label>

                <select name="type_id" required>
                    <option value="">
                        Select Meeting Type
                    </option>

                    <?php foreach ($types as $type): ?>

                        <option value="<?= e($type["TypeID"]) ?>">
                            <?= e($type["Name"]) ?>
                        </option>

                    <?php endforeach; ?>
                </select>
            </div>

            <div class="form-group">
                <label>Annual Plan</label>

                <select name="plan_id" required>
                    <option value="">
                        Select Academic Year
                    </option>

                    <?php foreach ($years as $year): ?>

                        <option value="<?= e($year["PlanID"]) ?>">
                            <?= e($year["AcademicYear"]) ?>
                        </option>

                    <?php endforeach; ?>
                </select>
            </div>

            <div class="form-group">
                <label>Meeting Date</label>

                <input
                    type="date"
                    name="date"
                    required
                >
            </div>

            <div class="form-grid">

                <div class="form-group">
                    <label>Start Time</label>

                    <input
                        type="time"
                        name="start"
                        value="09:00"
                        required
                    >
                </div>

                <div class="form-group">
                    <label>End Time</label>

                    <input
                        type="time"
                        name="end"
                        value="10:30"
                        required
                    >
                </div>

            </div>

            <div class="form-group">
                <label>Venue</label>

                <input
                    type="text"
                    name="venue"
                    maxlength="100"
                    placeholder="Department Boardroom"
                    required
                >
            </div>

            <div class="form-group">
                <label class="check-row">
                    <input
                        type="checkbox"
                        name="is_fixed"
                        value="1"
                    >
                    Fixed academic date
                </label>
            </div>

            <p class="hint">
                The system checks for venue conflicts.
                Fixed academic dates cannot be rescheduled.
            </p>

            <button type="submit" class="button gold">
                Save Meeting
            </button>

        </form>

    </div>

</div>

<!-- RESCHEDULE MODAL -->
<div
    class="modal-backdrop"
    id="rescheduleModal"
    onclick="closeModals(event)"
>

    <div
        class="modal"
        onclick="event.stopPropagation()"
    >

        <div class="modal-head">
            <h2>Reschedule Meeting</h2>

            <button
                type="button"
                class="close"
                onclick="closeModals()"
            >
                ×
            </button>
        </div>

        <p class="hint" id="rescheduleMeetingName"></p>

        <form method="post" action="meetings.php">

            <input
                type="hidden"
                name="csrf"
                value="<?= e($csrf) ?>"
            >

            <input
                type="hidden"
                name="action"
                value="reschedule"
            >

            <input
                type="hidden"
                name="meeting_id"
                id="rescheduleId"
            >

            <div class="form-group">
                <label>New Meeting Date</label>

                <input
                    type="date"
                    name="date"
                    id="rescheduleDate"
                    required
                >
            </div>

            <div class="form-grid">

                <div class="form-group">
                    <label>Start Time</label>

                    <input
                        type="time"
                        name="start"
                        id="rescheduleStart"
                        required
                    >
                </div>

                <div class="form-group">
                    <label>End Time</label>

                    <input
                        type="time"
                        name="end"
                        id="rescheduleEnd"
                        required
                    >
                </div>

            </div>

            <div class="form-group">
                <label>Venue</label>

                <input
                    type="text"
                    name="venue"
                    id="rescheduleVenue"
                    maxlength="100"
                    required
                >
            </div>

            <div class="form-group">
                <label>Reason for Rescheduling</label>

                <textarea
                    name="reason"
                    rows="3"
                    maxlength="255"
                    placeholder="Explain why the meeting date is changing..."
                    required
                ></textarea>
            </div>

            <button
                type="submit"
                class="button gold"
                onclick="return confirm('Confirm this meeting reschedule?')"
            >
                Confirm Reschedule
            </button>

        </form>

    </div>

</div>

<!-- CANCEL MODAL -->
<div
    class="modal-backdrop"
    id="cancelModal"
    onclick="closeModals(event)"
>

    <div
        class="modal"
        onclick="event.stopPropagation()"
    >

        <div
            class="modal-head"
        >
            <h2>Cancel Meeting</h2>

            <button
                type="button"
                class="close"
                onclick="closeModals()"
            >
                ×
            </button>
        </div>

        <p class="hint" id="cancelMeetingName"></p>

        <form method="post" action="meetings.php">

            <input
                type="hidden"
                name="csrf"
                value="<?= e($csrf) ?>"
            >

            <input
                type="hidden"
                name="action"
                value="cancel"
            >

            <input
                type="hidden"
                name="meeting_id"
                id="cancelId"
            >

            <div class="form-group">
                <label>Reason for Cancellation</label>

                <textarea
                    name="reason"
                    rows="4"
                    maxlength="240"
                    placeholder="Explain why the meeting is being cancelled..."
                    required
                ></textarea>
            </div>

            <p class="hint">
                The meeting record will remain in the database
                with the status Cancelled.
            </p>

            <button
                type="submit"
                class="button danger"
                onclick="return confirm('Are you sure you want to cancel this meeting?')"
            >
                Confirm Cancellation
            </button>

        </form>

    </div>

</div>

<?php endif; ?>

<script>
    function closeModals(event) {

        if (
            event &&
            !event.target.classList.contains("modal-backdrop")
        ) {
            return;
        }

        document.querySelectorAll(".modal-backdrop")
            .forEach(function(modal) {
                modal.classList.remove("open");
            });

        document.body.style.overflow = "";
    }

    function showModal(id) {

        closeModals();

        const modal = document.getElementById(id);

        if (modal) {
            modal.classList.add("open");
            document.body.style.overflow = "hidden";
        }
    }

    function openCreate() {
        showModal("createModal");
    }

    function meetingData(button) {
        return JSON.parse(
            button.getAttribute("data-meeting")
        );
    }

    function openReschedule(button) {

        const meeting = meetingData(button);

        document.getElementById("rescheduleId").value =
            meeting.id;

        document.getElementById("rescheduleMeetingName").textContent =
            meeting.name + " (" + meeting.id + ")";

        document.getElementById("rescheduleDate").value =
            meeting.date;

        document.getElementById("rescheduleStart").value =
            meeting.start;

        document.getElementById("rescheduleEnd").value =
            meeting.end;

        document.getElementById("rescheduleVenue").value =
            meeting.venue;

        showModal("rescheduleModal");
    }

    function openCancel(button) {

        const meeting = meetingData(button);

        document.getElementById("cancelId").value =
            meeting.id;

        document.getElementById("cancelMeetingName").textContent =
            meeting.name + " (" + meeting.id + ")";

        showModal("cancelModal");
    }

    function filterMeetings() {

        const search = document.getElementById("searchInput")
            .value.toLowerCase();

        const status = document.getElementById("statusFilter")
            .value;

        const year = document.getElementById("yearFilter")
            .value;

        document.querySelectorAll(
            "#meetingsTable tbody tr"
        ).forEach(function(row) {

            const matchesSearch =
                row.dataset.search.includes(search);

            const matchesStatus =
                !status || row.dataset.status === status;

            const matchesYear =
                !year || row.dataset.year === year;

            row.style.display =
                matchesSearch &&
                matchesStatus &&
                matchesYear
                    ? ""
                    : "none";
        });
    }

    document.addEventListener("keydown", function(event) {

        if (event.key === "Escape") {
            closeModals();
        }

    });
</script>

</body>
</html>
