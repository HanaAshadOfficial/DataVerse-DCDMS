
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DataVerse | Welcome</title>

    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            min-height: 100vh;
            background: #122D39;
            color: #FFFFFF;
            font-family: 'Segoe UI', Arial, sans-serif;
            overflow-x: hidden;
            display: flex;
            flex-direction: column;
            position: relative;
        }

        .circle {
            position: absolute;
            width: 550px;
            height: 550px;
            border: 1px solid rgba(175, 197, 205, 0.12);
            border-radius: 50%;
            top: -290px;
            right: -190px;
            pointer-events: none;
        }

        .circle.second {
            width: 760px;
            height: 760px;
            top: -380px;
            right: -320px;
        }

        .splash {
            flex: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
            padding: 60px 20px;
            position: relative;
            z-index: 1;
            animation: fadeIn 1s ease-out;
        }

        .diamond {
            width: 34px;
            height: 34px;
            border: 5px solid #E9BC59;
            transform: rotate(45deg);
            margin-bottom: 70px;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .diamond::after {
            content: "";
            width: 14px;
            height: 14px;
            border: 2px solid #E9BC59;
        }

        h1 {
            font-size: clamp(56px, 9vw, 88px);
            font-weight: 750;
            letter-spacing: -4px;
            margin-bottom: 22px;
        }

        .subtitle {
            color: #AFC5CD;
            font-size: 13px;
            letter-spacing: 2.5px;
            text-transform: uppercase;
            line-height: 1.8;
        }

        .gold-line {
            width: 235px;
            height: 3px;
            background: #E9BC59;
            margin: 38px auto 20px;
        }

        .tagline {
            color: #AFC5CD;
            font-size: 14px;
            margin-bottom: 36px;
        }

        .login-button {
            display: inline-block;
            background: #FFFFFF;
            color: #122D39;
            text-decoration: none;
            padding: 15px 25px;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 600;
            transition: 0.2s ease;
        }

        .login-button:hover {
            background: #E9BC59;
            transform: translateY(-2px);
        }

        footer {
            text-align: center;
            padding: 24px 15px;
            color: #AFC5CD;
            font-size: 11px;
            letter-spacing: 1.5px;
            text-transform: uppercase;
        }

        @keyframes fadeIn {
            from {
                opacity: 0;
                transform: translateY(15px);
            }

            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        @media (max-width: 600px) {
            h1 {
                letter-spacing: -2px;
            }

            .diamond {
                margin-bottom: 45px;
            }

            .subtitle {
                font-size: 11px;
                letter-spacing: 1.5px;
            }
        }
    </style>
</head>

<body>
    <div class="circle"></div>
    <div class="circle second"></div>

    <main class="splash">
        <div class="diamond"></div>

        <h1>Dataverse</h1>

        <p class="subtitle">
            Department Communication Management System
        </p>

        <div class="gold-line"></div>

        <p class="tagline">
            Connecting the department. Keeping decisions together.
        </p>

        <a class="login-button" href="login.php">
            Continue to login &rarr;
        </a>
    </main>

    <footer>
        Rajarata University of Sri Lanka · Department of Computing
    </footer>
</body>
</html>
