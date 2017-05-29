Param(
	[string]$dbUserName,
	[string]$dbPassword,
	[string]$dbmrsuser,
	[string]$dbmrspwd,
	[string]$dbrefdatauser,
	[string]$dbrefdatapwd,
	[string]$dbprofileuser,
	[string]$dbprofilepwd
)

function writeLog {
    Param([string] $log)
    $dateAndTime = Get-Date
    "$dateAndTime : $log" | Out-File -Append C:\Informatica\Archive\scripts\createdbusers.log
}

function waitTillDatabaseIsAlive {
    $connectionString = "Data Source=localhost;Integrated Security=true;Initial Catalog=infadb;Connect Timeout=3;"
    $sqlConn = new-object ("Data.SqlClient.SqlConnection") $connectionString
    $sqlConn.Open()

    $tryCount = 0
    while($sqlConn.State -ne "Open" -And $tryCount -lt 100) {
        $dateAndTime = Get-Date
        writeLog "Attempt $tryCount"

	    Start-Sleep -s 30
	    $sqlConn.Open()
	    $tryCount++
    }

    if ($sqlConn.State -eq 'Open') {
	    $sqlConn.Close();
	    writeLog "Connection to MSSQL Server succeed"
    } else {
        writeLog "Connection to MSSQL Server failed"
        exit 255
    }
}

function executeSQLStatement {
    Param([String] $sqlStatement)

    $errorFlag = 1
    $tryCount = 0

    $error.clear()

    while($errorFlag -ne 0 -And $tryCount -lt 30) {
        sleep 1
        $tryCount++
        try {
            Invoke-Sqlcmd -ServerInstance '(local)' -Database 'infadb' -Query $sqlStatement
            $errorFlag = $error.Count
        } catch {
            $errorFlag = $error.Count
        } finally {
			if($errorFlag -ne 0) {
				writeLog "Error: $error"
				$error.clear()
			}
		}
    }

    if($errorFlag -eq 1 -And $tryCount -eq 3) {
        writeLog "User creation failed"
		exit 255
    } else {
		writeLog "Statement execution passed"
	}
}

$error.clear()
netsh advfirewall firewall add rule name="Informatica_DQ_MMSQL" dir=in action=allow profile=any localport=1433 protocol=TCP
mkdir -Path C:\Informatica\Archive\scripts 2> $null

writeLog "Creating user: $dbUserName"

$newLogin = "CREATE LOGIN " + $dbUserName +  " WITH PASSWORD = '" + ($dbPassword -replace "'","''") + "'"
$newUser = "CREATE USER " + $dbUserName + " FOR LOGIN " + $dbUserName + " WITH DEFAULT_SCHEMA = " + $dbUserName
$updateUserRole = "ALTER ROLE db_datareader ADD MEMBER " + $dbUserName + ";" + 
                        "ALTER ROLE db_datawriter ADD MEMBER " + $dbUserName + ";" + 
                        "ALTER ROLE db_ddladmin ADD MEMBER " + $dbUserName
$newSchema = "CREATE SCHEMA " + $dbUserName + " AUTHORIZATION " + $dbUserName

waitTillDatabaseIsAlive
executeSQLStatement $newLogin
executeSQLStatement $newUser
executeSQLStatement $updateUserRole
executeSQLStatement $newSchema



writeLog "Creating user for MRS: $dbmrsuser"

$newMRSLogin = "CREATE LOGIN " + $dbmrsuser +  " WITH PASSWORD = '" + ($dbmrspwd -replace "'","''") + "'"
$newMRSUser = "CREATE USER " + $dbmrsuser + " FOR LOGIN " + $dbmrsuser + " WITH DEFAULT_SCHEMA = " + $dbmrsuser
$updateMRSUserRole = "ALTER ROLE db_datareader ADD MEMBER " + $dbmrsuser + ";" + 
                        "ALTER ROLE db_datawriter ADD MEMBER " + $dbmrsuser + ";" + 
                        "ALTER ROLE db_ddladmin ADD MEMBER " + $dbmrsuser
$newMRSSchema = "CREATE SCHEMA " + $dbmrsuser + " AUTHORIZATION " + $dbmrsuser

waitTillDatabaseIsAlive
executeSQLStatement $newMRSLogin
executeSQLStatement $newMRSUser
executeSQLStatement $updateMRSUserRole
executeSQLStatement $newMRSSchema

writeLog "Creating user for Reference Data: $dbrefdatauser"

$newCMSLogin = "CREATE LOGIN " + $dbrefdatauser +  " WITH PASSWORD = '" + ($dbrefdatapwd -replace "'","''") + "'"
$newCMSUser = "CREATE USER " + $dbrefdatauser + " FOR LOGIN " + $dbrefdatauser + " WITH DEFAULT_SCHEMA = " + $dbrefdatauser
$updateCMSUserRole = "ALTER ROLE db_datareader ADD MEMBER " + $dbrefdatauser + ";" + 
                        "ALTER ROLE db_datawriter ADD MEMBER " + $dbrefdatauser + ";" + 
                        "ALTER ROLE db_ddladmin ADD MEMBER " + $dbrefdatauser
$newCMSSchema = "CREATE SCHEMA " + $dbrefdatauser + " AUTHORIZATION " + $dbrefdatauser

waitTillDatabaseIsAlive
executeSQLStatement $newCMSLogin
executeSQLStatement $newCMSUser
executeSQLStatement $updateCMSUserRole
executeSQLStatement $newCMSSchema

writeLog "Creating user for Profiling: $dbprofileuser"

$newProfileLogin = "CREATE LOGIN " + $dbprofileuser +  " WITH PASSWORD = '" + ($dbprofilepwd -replace "'","''") + "'"
$newProfileUser = "CREATE USER " + $dbprofileuser + " FOR LOGIN " + $dbprofileuser + " WITH DEFAULT_SCHEMA = " + $dbprofileuser
$updateProfileUserRole = "ALTER ROLE db_datareader ADD MEMBER " + $dbprofileuser + ";" + 
                        "ALTER ROLE db_datawriter ADD MEMBER " + $dbprofileuser + ";" + 
                        "ALTER ROLE db_ddladmin ADD MEMBER " + $dbprofileuser
$newProfileSchema = "CREATE SCHEMA " + $dbprofileuser + " AUTHORIZATION " + $dbprofileuser

waitTillDatabaseIsAlive
executeSQLStatement $newProfileLogin
executeSQLStatement $newProfileUser
executeSQLStatement $updateProfileUserRole
executeSQLStatement $newProfileSchema