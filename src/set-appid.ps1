# Tag Office Craft shortcuts with System.AppUserModel.ID = OfficeCraft.App (logic in C#)
$ErrorActionPreference='Stop'
$APPID='OfficeCraft.App'
$EXE='C:\Users\iwin\CraftOffice\OfficeCraft.exe'
$ICON=$EXE
$WORK='C:\Users\iwin\CraftOffice'
$TARGET=$EXE
$ARGS=''
$startDir = Join-Path $env:AppData 'Microsoft\Windows\Start Menu\Programs'
$paths = @((Join-Path $startDir 'Office Craft.lnk'), (Join-Path "$env:USERPROFILE\Desktop" 'Office Craft.lnk'))

$ws = New-Object -ComObject WScript.Shell
foreach($p in $paths){
  $lnk = $ws.CreateShortcut($p)
  $lnk.TargetPath=$TARGET; $lnk.Arguments=$ARGS; $lnk.WorkingDirectory=$WORK
  $lnk.IconLocation="$ICON,0"; $lnk.Description='Office Craft'; $lnk.Save()
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace OC {
  [StructLayout(LayoutKind.Sequential)]
  public struct PROPERTYKEY { public Guid fmtid; public uint pid; }
  [StructLayout(LayoutKind.Sequential)]
  public struct PROPVARIANT { public ushort vt; public ushort r1; public ushort r2; public ushort r3; public IntPtr p; public IntPtr p2; }
  [ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IPropertyStore {
    void GetCount(out uint c);
    void GetAt(uint i, out PROPERTYKEY k);
    void GetValue(ref PROPERTYKEY k, out PROPVARIANT v);
    void SetValue(ref PROPERTYKEY k, ref PROPVARIANT v);
    void Commit();
  }
  public static class AppId {
    [DllImport("shell32.dll")]
    static extern int SHGetPropertyStoreFromParsingName(
      [MarshalAs(UnmanagedType.LPWStr)] string path, IntPtr pbc, int flags,
      ref Guid riid, out IPropertyStore store);
    public static string Set(string path, string appId){
      Guid iid = new Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99");
      IPropertyStore store;
      int hr = SHGetPropertyStoreFromParsingName(path, IntPtr.Zero, 2 /*READWRITE*/, ref iid, out store);
      if(hr != 0 || store == null) return "FAIL 0x"+hr.ToString("X");
      var key = new PROPERTYKEY { fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5 };
      IntPtr s = Marshal.StringToCoTaskMemUni(appId);
      var pv = new PROPVARIANT { vt = 31 /*VT_LPWSTR*/, p = s };
      store.SetValue(ref key, ref pv);
      store.Commit();
      Marshal.FreeCoTaskMem(s);
      PROPVARIANT ov; store.GetValue(ref key, out ov);
      string val = ov.p != IntPtr.Zero ? Marshal.PtrToStringUni(ov.p) : "(none)";
      Marshal.ReleaseComObject(store);
      return val;
    }
  }
}
'@

foreach($p in $paths){
  $r = [OC.AppId]::Set($p, $APPID)
  Write-Output ("{0}  ->  readback='{1}'" -f $p, $r)
}
Write-Output 'done'
