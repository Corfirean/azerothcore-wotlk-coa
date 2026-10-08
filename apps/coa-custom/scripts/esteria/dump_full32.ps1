$p = Get-Process Ascension -ErrorAction Stop | Select-Object -First 1
"PID $($p.Id) responding=$($p.Responding) 32bit-shell=$([IntPtr]::Size -eq 4)"
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public static class Dump32 {
  [DllImport("dbghelp.dll", SetLastError=true)]
  public static extern bool MiniDumpWriteDump(IntPtr hProcess, uint pid, SafeFileHandle hFile, uint type, IntPtr e, IntPtr u, IntPtr c);
}
"@
$out = "C:\CoA-Build\esteria\hang_full.dmp"
$fs = [System.IO.File]::Create($out)
$ok = [Dump32]::MiniDumpWriteDump($p.Handle, [uint32]$p.Id, $fs.SafeFileHandle, [uint32](0x2), [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
$fs.Close()
"dump ok=$ok size=$([math]::Round((Get-Item $out).Length/1MB))MB"
