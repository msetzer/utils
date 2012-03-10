$assocQueryString = @'
    using System;
    using System.Text;
    using System.Runtime.InteropServices;

    namespace Win32Util
    {
        public class Win32Util
        {
            [Flags]
            private enum AssocF
            {
                Init_NoRemapCLSID = 0x1,
                Init_ByExeName = 0x2,
                Open_ByExeName = 0x2,
                Init_DefaultToStar = 0x4,
                Init_DefaultToFolder = 0x8,
                NoUserSettings = 0x10,
                NoTruncate = 0x20,
                Verify = 0x40,
                RemapRunDll = 0x80,
                NoFixUps = 0x100,
                IgnoreBaseClass = 0x200
            }

            private enum AssocStr
            {
                Command = 1,
                Executable,
                FriendlyDocName,
                FriendlyAppName,
                NoOpen,
                ShellNewValue,
                DDECommand,
                DDEIfExec,
                DDEApplication,
                DDETopic
            }

            [DllImport("Shlwapi.dll", SetLastError=true, CharSet = CharSet.Auto)]
            private static extern uint AssocQueryString(
                AssocF flags, 
                AssocStr str, 
                string pszAssoc, 
                string pszExtra,
                StringBuilder pszOut, 
                ref uint pcchOut);

            public static string GetExecutablePathForExtension(string extension)
            {
                uint len = 1024;
                StringBuilder sb = new StringBuilder((int)len);
                AssocQueryString(AssocF.Verify, AssocStr.Executable, extension, null, sb, ref len);
                return sb.ToString();
            }
        }
    }
'@

$typeExists = try { ([Win32Util.Win32Util] | get-member -static GetExecutablePathForExtension) -ne $null } catch { $False }
if (-not $typeExists)
{
    add-type -typedefinition $assocQueryString
}

#
# First try launching the supplied file directly.  If this is an executable, runas should correctly launch it.
# If it's not, this will fail because there is no runas verb for the association.
#
$file, [string]$arguments = $args
try
{
    $psi = new-object System.Diagnostics.ProcessStartInfo $file
    $psi.Arguments = $arguments
    $psi.Verb = "runas"
    $psi.WorkingDirectory = get-location
    [System.Diagnostics.Process]::Start($psi) | out-null
    return
}
catch
{
}

#
# Looks like we're trying to launch a file of some sort, pull off the extension and get the executable process for it.
#
$extension = [System.IO.Path]::GetExtension($file)
$exePath = [Win32Util.Win32Util]::GetExecutablePathForExtension($extension)
$psi = new-object System.Diagnostics.ProcessStartInfo $exePath
$psi.Arguments = [System.IO.Path]::GetFullPath($file) + " " + $arguments
$psi.Verb = "runas"
$psi.WorkingDirectory = get-location
[System.Diagnostics.Process]::Start($psi) | out-null
