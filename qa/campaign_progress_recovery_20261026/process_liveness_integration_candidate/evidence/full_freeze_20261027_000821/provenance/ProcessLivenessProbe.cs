// Independent QA candidate. No target mutation, privilege change, or process enumeration.
using System;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

internal static class ProcessLivenessProbe
{
    private const uint Access = 0x00101000; // SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION
    private const uint WaitObject = 0, WaitTimeout = 258, WaitFailed = 0xffffffff;
    private const string Schema = "windows_process_liveness_v1";

    [StructLayout(LayoutKind.Sequential)]
    private struct FileTime { public uint Low; public uint High; }
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetProcessTimes(IntPtr handle, out FileTime creation, out FileTime exit, out FileTime kernel, out FileTime user);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentProcessId();

    private sealed class Row
    {
        public string State = "unknown", Code = "QUERY_EXCEPTION", Creation = "", Wait = "not_queried", Error = "0";
        public bool Opened;
        public string Json(string nonce, string target)
        {
            // ASCII-only, fixed alphabetical keys. Parser requires byte-exact canonical JSON.
            return "{\"code\":\"" + Code + "\",\"creation_filetime\":\"" + Creation +
                "\",\"handle_opened\":" + (Opened ? "true" : "false") +
                ",\"nonce\":\"" + nonce + "\",\"provider_pid\":\"" + Decimal(GetCurrentProcessId()) +
                "\",\"query_utc_filetime\":\"" + DateTime.UtcNow.ToFileTimeUtc().ToString(CultureInfo.InvariantCulture) +
                "\",\"schema\":\"" + Schema + "\",\"state\":\"" + State + "\",\"target_pid\":\"" + target +
                "\",\"wait_result\":\"" + Wait + "\",\"win32_error\":\"" + Error + "\"}";
        }
    }

    private static string Decimal(uint value) { return value.ToString(CultureInfo.InvariantCulture); }
    private static string LastError() { return Decimal(unchecked((uint)Marshal.GetLastWin32Error())); }
    private static bool ValidNonce(string value)
    {
        if (value == null || value.Length != 32) return false;
        foreach (char c in value) if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
        return true;
    }

    private static Row Query(uint pid)
    {
        Row row = new Row();
        IntPtr handle = IntPtr.Zero;
        try
        {
            handle = OpenProcess(Access, false, pid);
            if (handle == IntPtr.Zero)
            {
                row.Error = LastError();
                // Same constant access/nonzero PID branch as Microsoft .NET v9 ProcessManager.
                row.State = row.Error == "87" ? "dead" : "unknown";
                row.Code = row.Error == "87" ? "PID_ABSENT_87" : "OPEN_FAILED";
                return row;
            }
            row.Opened = true;
            FileTime creation, exit, kernel, user;
            if (!GetProcessTimes(handle, out creation, out exit, out kernel, out user))
            {
                row.Code = "TIMES_FAILED"; row.Error = LastError(); return row;
            }
            ulong created = ((ulong)creation.High << 32) | creation.Low;
            if (created == 0) { row.Code = "TIMES_INVALID"; return row; }
            row.Creation = created.ToString(CultureInfo.InvariantCulture);
            uint wait = WaitForSingleObject(handle, 0);
            row.Wait = Decimal(wait);
            if (wait == WaitObject) { row.State = "dead"; row.Code = "HANDLE_SIGNALED"; }
            else if (wait == WaitTimeout) { row.State = "alive"; row.Code = "HANDLE_NONSIGNALED"; }
            else if (wait == WaitFailed) { row.Code = "WAIT_FAILED"; row.Error = LastError(); }
            else { row.Code = "WAIT_UNEXPECTED"; }
        }
        catch { row.State = "unknown"; row.Code = "QUERY_EXCEPTION"; row.Error = "0"; }
        finally
        {
            if (handle != IntPtr.Zero && !CloseHandle(handle))
            {
                row.State = "unknown"; row.Code = "CLOSE_FAILED"; row.Error = LastError();
            }
        }
        return row;
    }

    private static int Main(string[] args)
    {
        // Exactly: canonical decimal PID, lowercase 128-bit nonce, existing unique probe directory.
        uint pid;
        if (args.Length != 3 || !uint.TryParse(args[0], NumberStyles.None, CultureInfo.InvariantCulture, out pid) ||
            pid == 0 || pid > Int32.MaxValue || args[0] != Decimal(pid) || !ValidNonce(args[1])) return 64;
        if (Environment.OSVersion.Platform != PlatformID.Win32NT) return 65;
        try
        {
            string directory = Path.GetFullPath(args[2]);
            if (!Path.IsPathRooted(args[2]) || directory != args[2] || !Directory.Exists(directory) ||
                new DirectoryInfo(directory).Name != args[1] ||
                (File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0) return 64;
            string pending = Path.Combine(directory, "pending.json"), final = Path.Combine(directory, "result.json");
            // Never overwrite, delete, or claim another observation. No output on stdout/stderr.
            if (File.Exists(final)) return 73;
            using (FileStream output = new FileStream(pending, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                byte[] data = Encoding.ASCII.GetBytes(Query(pid).Json(args[1], args[0]));
                if (data.Length > 4096) return 74;
                output.Write(data, 0, data.Length);
                output.Flush(true);
            }
            File.Move(pending, final); // Same directory, no replacement of an existing final file.
            return 0;
        }
        catch { return 70; } // Incomplete/pending files are diagnostic evidence, never a result.
    }
}
