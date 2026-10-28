
<?php
$host = "127.0.0.1";
$username = "root";
$password = "hana";
$database = "dcdms_db";
$port = 3306;

$conn = new mysqli($host, $username, $password, $database, $port);

if ($conn->connect_error) {
    die("Database connection failed: " . $conn->connect_error);
}
?>
