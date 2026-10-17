using System;
using System.IO;
using System.Threading;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

// Office Craft native host: runs CraftTabs.ps1 in-process so the window (and taskbar
// button) belong to OfficeCraft.exe with its embedded icon - not powershell.exe.
class OfficeCraftHost {
    [STAThread]
    static void Main() {
        string scriptPath = @"C:\Users\iwin\CraftOffice\CraftTabs.ps1";
        string script = File.ReadAllText(scriptPath);
        var iss = InitialSessionState.CreateDefault();
        iss.ApartmentState = ApartmentState.STA;
        iss.ThreadOptions = PSThreadOptions.UseCurrentThread;
        iss.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
        using (var rs = RunspaceFactory.CreateRunspace(iss)) {
            rs.Open();
            using (var ps = PowerShell.Create()) {
                ps.Runspace = rs;
                ps.AddScript(script);
                try { ps.Invoke(); }
                catch (Exception ex) {
                    try { File.WriteAllText(@"C:\Users\iwin\CraftOffice\host_error.log", ex.ToString()); } catch {}
                }
            }
        }
    }
}
