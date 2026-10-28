<?php
session_start();
if (isset($_SESSION['user_id'])) { header('Location: dashboard.php'); exit; }
$error = '';
$email = '';
$selectedRole = '';
$roles = [
    'HOD' => 'Head of Department (HOD)',
    'AcademicStaff' => 'Academic Staff',
    'Clerk' => 'Clerk / Convener',
    'SupportStaff' => 'Support / Technical Staff',
    'StudentCoordinator' => 'Student Coordinator'
];
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim((string)($_POST['email'] ?? ''));
    $selectedRole = trim((string)($_POST['role'] ?? ''));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || !isset($roles[$selectedRole])) {
        $error = 'Please enter a valid email and select your role.';
    } else {
        try {
            require_once __DIR__ . '/config.php';
            $stmt = $conn->prepare('SELECT UserID, Name, Email, RoleType FROM `user` WHERE Email = ? AND RoleType = ? LIMIT 1');
            if (!$stmt) { throw new RuntimeException('Could not prepare login query'); }
            $stmt->bind_param('ss', $email, $selectedRole);
            $stmt->execute();
            $user = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if ($user) {
                session_regenerate_id(true);
                $_SESSION['user_id'] = $user['UserID'];
                $_SESSION['user_name'] = $user['Name'];
                $_SESSION['user_email'] = $user['Email'];
                $_SESSION['user_role'] = $user['RoleType'];
                header('Location: dashboard.php');
                exit;
            }
            $error = 'Email and selected role do not match our records.';
        } catch (Throwable $e) {
            error_log('DataVerse login: ' . $e->getMessage());
            $error = 'Unable to connect to the database.';
        }
    }
}
function esc($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DataVerse | Sign In</title>
<style>
:root{--navy:#102f3e;--gold:#f6c65e;--muted:#7890a0;--ink:#102f3e}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;background:#eaf2f4;color:var(--ink);font-family:'Segoe UI',Arial,sans-serif;display:grid;place-items:center;padding:26px}
.shell{width:min(1180px,100%);min-height:680px;display:grid;grid-template-columns:1fr 1fr;background:#fff;border-radius:30px;overflow:hidden;box-shadow:0 18px 65px rgba(13,45,57,.12)}
.brand-panel{background:var(--navy);color:white;position:relative;padding:72px 56px;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden}
.brand-panel:before,.brand-panel:after{content:"";position:absolute;border:1px solid rgba(255,255,255,.08);width:370px;height:370px;border-radius:50%;pointer-events:none}
.brand-panel:before{right:-170px;top:-190px}.brand-panel:after{left:-180px;bottom:-290px}
.diamond{width:88px;height:88px;border:2px solid var(--gold);transform:rotate(45deg);display:grid;place-items:center;margin:24px 0 100px 23px}
.diamond span{transform:rotate(-45deg);color:var(--gold);font-size:30px;font-weight:900}
.logo{font-size:52px;font-weight:800;letter-spacing:-2px;margin:0 0 25px}.logo span{color:var(--gold)}
.brand-description{font-size:18px;line-height:2;letter-spacing:1.2px;text-transform:uppercase;max-width:360px}
.gold-line{width:118px;height:4px;background:var(--gold);margin-top:34px}
.brand-footer{border-top:1px solid rgba(255,255,255,.15);padding-top:35px;font-size:15px;line-height:2}
.form-panel{padding:70px 62px;display:flex;flex-direction:column;justify-content:center}
.eyebrow{font-size:13px;font-weight:800;letter-spacing:4px;color:#b57a00;margin:0 0 23px}
h1{font-size:38px;line-height:1.15;margin:0 0 24px;letter-spacing:-1px}
.description{font-size:16px;color:var(--muted);line-height:2;margin:0 0 37px}
label{display:block;font-size:14px;font-weight:700;margin:0 0 12px}
input,select{width:100%;height:61px;border:1px solid #d8e4ea;background:#f7fafb;border-radius:13px;padding:0 18px;font:inherit;color:var(--ink);margin-bottom:28px}
input:focus,select:focus{outline:2px solid #f6c65e;outline-offset:1px}
button{border:0;width:100%;height:63px;background:var(--gold);color:#0b2b39;font-weight:800;font-size:17px;border-radius:12px;cursor:pointer;margin-top:3px}
button:hover{background:#e9b449}
.error{background:#fff0ef;border:1px solid #fac8c4;border-radius:12px;padding:16px;color:#bb2929;font-size:14px;margin-bottom:25px}
.footnote{font-size:13px;text-align:center;color:#8ba0af;line-height:1.9;margin-top:32px}
.devnote{color:#9a740e;font-size:12px;text-align:center;margin-top:12px}
@media(max-width:850px){.shell{grid-template-columns:1fr;min-height:auto}.brand-panel{padding:30px 32px}.diamond{width:48px;height:48px;margin:0 0 18px 14px}.diamond span{font-size:19px}.logo{font-size:35px;margin:0 0 6px}.brand-description{font-size:12px;line-height:1.6}.gold-line,.brand-footer{display:none}.form-panel{padding:44px 32px}h1{font-size:30px}}
@media(max-width:420px){body{padding:12px}.form-panel{padding:35px 22px}.brand-panel{padding:25px}.shell{border-radius:20px}}
</style>
</head>
<body>
<div class="shell">
  <section class="brand-panel" aria-label="DataVerse branding">
    <div>
      <div class="diamond"><span>D</span></div>
      <div class="logo">Data<span>Verse</span></div>
      <div class="brand-description">Department Communication<br>Management System</div>
      <div class="gold-line"></div>
    </div>
    <div class="brand-footer">Department of Computing<br>Rajarata University of Sri Lanka</div>
  </section>
  <main class="form-panel">
    <p class="eyebrow">WELCOME BACK</p>
    <h1>Sign in to your account</h1>
    <p class="description">Access your department meetings, schedules, agendas and decisions.</p>
    <?php if ($error !== ''): ?><div class="error" role="alert"><?= esc($error) ?></div><?php endif; ?>
    <form action="login.php" method="post">
      <label for="email">Email Address</label>
      <input type="email" id="email" name="email" placeholder="Enter your department email" value="<?= esc($email) ?>" autocomplete="email" required>
      <label for="role">Your Role</label>
      <select id="role" name="role" required>
        <option value="">Select your role</option>
        <?php foreach ($roles as $key => $label): ?>
          <option value="<?= esc($key) ?>" <?= $selectedRole === $key ? 'selected' : '' ?>><?= esc($label) ?></option>
        <?php endforeach; ?>
      </select>
      <button type="submit">Sign In</button>
    </form>
    <p class="footnote">Authorized department personnel only.<br>Access is managed according to your assigned role.</p>
    <p class="devnote">Local development mode · Password verification temporarily disabled</p>
  </main>
</div>
</body>
</html>
