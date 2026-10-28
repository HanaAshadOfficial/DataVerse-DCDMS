
<?php


session_start();

header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

function sendJson(int $status, array $data): void
{
    http_response_code($status);

    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES |
        JSON_INVALID_UTF8_SUBSTITUTE
    );

    exit;
}

if (
    empty($_SESSION['user_id']) ||
    empty($_SESSION['user_role'])
) {
    sendJson(401, [
        'success' => false,
        'message' => 'Session expired. Please log in again.',
        'notifications' => []
    ]);
}

require_once __DIR__ . '/config.php';

$userId = (string) $_SESSION['user_id'];
$role = (string) $_SESSION['user_role'];

$allowedRoles = [
    'HOD',
    'AcademicStaff',
    'Clerk',
    'SupportStaff',
    'StudentCoordinator'
];

if (!in_array($role, $allowedRoles, true)) {
    sendJson(403, [
        'success' => false,
        'message' => 'Unauthorized role.',
        'notifications' => []
    ]);
}

try {
    /*
     * Retrieve existing notifications.
     *
     * Only assigned participants receive notifications,
     * except the HOD, who has administrative access.
     *
     * Confidential meetings are excluded for the Clerk.
     */

    $sql = "
        SELECT
            n.NotificationID,
            n.Type,
            n.Sent_Date,
            n.MeetingId,
            mt.Name AS MeetingName,
            mt.ShortName,
            mt.IsPrivate,
            m.PlannedDate,
            m.StartTime,
            m.Meeting_Status,
            a.UserID AS AssignedUser
        FROM Notification n
        INNER JOIN Meeting m
            ON m.MeetingId = n.MeetingId
        INNER JOIN MeetingType mt
            ON mt.TypeID = m.TypeID
        LEFT JOIN Attends a
            ON a.MeetingId = m.MeetingId
            AND a.UserID = ?
        ORDER BY n.NotificationID DESC
        LIMIT 100
    ";

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new RuntimeException($conn->error);
    }

    $stmt->bind_param('s', $userId);

    if (!$stmt->execute()) {
        throw new RuntimeException($stmt->error);
    }

    $result = $stmt->get_result();
    $notifications = [];

    while ($row = $result->fetch_assoc()) {
        $isPrivate = $row['IsPrivate'] === 'Yes';
        $isAssigned = $row['AssignedUser'] !== null;
        $shortName = (string) $row['ShortName'];

        $allowed = false;

        switch ($role) {
            case 'HOD':
                $allowed = true;
                break;

            case 'Clerk':
                $allowed = !$isPrivate;
                break;

            case 'AcademicStaff':
                $allowed = $isAssigned;
                break;

            case 'SupportStaff':
                $allowed = (
                    !$isPrivate &&
                    $isAssigned &&
                    in_array($shortName, ['DM', 'SW'], true)
                );
                break;

            case 'StudentCoordinator':
                $allowed = (
                    !$isPrivate &&
                    $isAssigned &&
                    in_array($shortName, ['DM', 'SC', 'CP'], true)
                );
                break;
        }

        if (!$allowed) {
            continue;
        }

        $type = (string) $row['Type'];
        $meetingName = (string) $row['MeetingName'];

        switch ($type) {
            case 'Meeting Invitation':
                $message = 'You have been invited to ' . $meetingName . '.';
                break;

            case 'Meeting Reminder':
                $message = 'Reminder: ' . $meetingName . ' is approaching.';
                break;

            case 'Meeting Cancellation':
                $message = $meetingName . ' has been cancelled.';
                break;

            case 'Reschedule Alert':
                $message = $meetingName . ' has been rescheduled.';
                break;

            case 'Agenda Uploaded Alert':
                $message = 'An agenda is available for ' . $meetingName . '.';
                break;

            case 'Dashboard Alert':
            case 'Dashboard & Gmail Alert':
            case 'Gmail Alert':
                $message = 'There is an update about ' . $meetingName . '.';
                break;

            default:
                $message = 'There is a meeting update.';
                break;
        }

        $notifications[] = [
            'id' => (string) $row['NotificationID'],
            'type' => $type,
            'message' => $message,
            'meeting_id' => (string) $row['MeetingId'],
            'meeting_name' => $meetingName,
            'sent_date' => (string) $row['Sent_Date'],
            'planned_date' => (string) $row['PlannedDate'],
            'status' => (string) $row['Meeting_Status'],
            'url' => 'participation.php?meeting_id=' .
                rawurlencode((string) $row['MeetingId'])
        ];
    }

    $stmt->close();

    sendJson(200, [
        'success' => true,
        'notifications' => $notifications
    ]);

} catch (Throwable $e) {
    error_log(
        'DataVerse notification check error: ' .
        $e->getMessage()
    );

    sendJson(500, [
        'success' => false,
        'message' => 'Unable to load notifications.',
        'notifications' => []
    ]);
}
