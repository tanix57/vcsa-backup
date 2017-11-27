# vcsa-backup
Another VCSA Backup script using REST API written in PowerShell.
## Getting Started

These instructions will get you a copy of the script. Executing the script through 2 main functions:
* Initiate a backup of the appliance and store the file ona FTP server
* Retrieve the backups status

See deployment for notes on how to deploy on a live system.

### Prerequisites

This script was tested with PowerShell V5 and PowerShell V4.

```
PS C:\> $PSVersionTable.PSVersion

Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      14393  1770

PS C:\> $PSVersionTable.PSVersion

Major  Minor  Build  Revision
-----  -----  -----  --------
4      0      -1     -1
```

### Installing

A step by step serie.

Setup a FTP server and create creedntials for a user.
The user must have the right to upload and create directory.

Create a new directory for convenience.

```
PS C:\Users\user1> mkdir vcsa-backup


    Directory: C:\Users\user1


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
d-----       27/11/2017     08:44                vcsa-backup
```

Copy the dowloaded script (vcsa-backup.ps1) under the new directory

```
PS C:\Users\user1> copy .\Downloads\vcsa-backup.ps1 .\vcsa-backup\

PS C:\Users\user1> ls .\vcsa-backup\


    Directory: C:\Users\user1\vcsa-backup


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----       02/11/2017     17:03          17704 vcsa-backup.ps1
```

Copy the dowloaded JSON configuration file sample under the new directory. You could rename it with the appliance name for convenience, as one file is required per appliance to backup.

```
PS C:\Users\user1> copy .\Downloads\sample.json .\vcsa-backup\test-vcenter.json
PS C:\Users\user1> ls .\vcsa-backup\


    Directory: C:\Users\user1\vcsa-backup


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----       31/10/2017     16:02            249 test-vcenter.json
-a----       02/11/2017     17:03          17704 vcsa-backup.ps1
```


## Running a test

As a test, execute the script without arguments and verify the output is the following

```
PS C:\Users\user1\vcsa-backup> .\vcsa-backup.ps1
Argument -f and existing configuration file name required
USAGE: vcsa-backup.ps1
      -f|--file <configuration file name>
      -o|--operation [backup | status [-m|--mail]]
```

## Deployment

Edit the JSON configuration file copied in the Installing steps.
Basically the required information are:
* Under "vCenter" section, fill hostname or IP address of the vCenter appliance and credentials
* Under the "Transfert" section, fill hostname or IP address of the FTP server and credentials
* Under the "SMTP" section, fill the hostname or IP address of the SMTP server, a sender mail address (example vcsa.backup@noreply.yourdomain.com) and a recipient mail address (comma separated if several mail addresses are required)

## Running the script

To run a backup of an appliance, execute the script by adding the argument -f (or --file) with the configuration file name and the argument -o (or --operation) following by the keyword backup.
```
PS C:\Virtualization\VMware\vcsa-backup> .\vcsa-backup.ps1 -f .\test-vcenter.json -o backup
```

To get a backup status or sending mail with the backup status, execute the script by adding the argument -f (or --file) with the configuration file name and the argument -o (or --operation) following by the keyword status.
```
PS C:\Virtualization\VMware\vcsa-backup> .\vcsa-backup.ps1 -f .\test-venter.json -o status

ID                      Start Time               End Time                 Status    Progress %
--                      ----------               --------                 ------    ----------
20171127-130035-5705665 2017-11-25T13:01:03.667Z 2017-11-25T13:02:45.745Z SUCCEEDED        100
<....>
201702211-124430-5705665 2017-08-11T12:44:30.680Z 2017-08-11T12:45:04.856Z SUCCEEDED        100
```
If a status should be sent by mail, add -m (or --mail) argument after the status keyword.

```
PS C:\Virtualization\VMware\vcsa-backup> .\vcsa-backup.ps1 -f .\test-vcenter.json -o status -m
```
## Authors

* **Raphaël Tani**

## Acknowledgments

* I was initially inspired by this article https://www.brianjgraf.com/2016/11/18/vsphere-6-5-automate-vcsa-backup/ and would like to write my own script using REST API only. 
