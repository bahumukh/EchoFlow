using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Echoflow.Services
{
    public class GlobalHotkeyService : IDisposable
    {
        public event Action? OnHotkeyDown;
        public event Action? OnHotkeyUp;
        public event Action? OnUndoHotkey;

        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private const int WM_KEYUP = 0x0101;
        private const int WM_SYSKEYDOWN = 0x0104;
        private const int WM_SYSKEYUP = 0x0105;

        private static LowLevelKeyboardProc? _proc;
        private static IntPtr _hookID = IntPtr.Zero;

        // Current config
        private int _dictationHotkeyCode = 0x7B; // Default F12
        private int _undoHotkeyCode = 0; // Default none

        public GlobalHotkeyService()
        {
            _proc = HookCallback;
            _hookID = SetHook(_proc);
            ReloadSettings();
        }

        public void ReloadSettings()
        {
            var settings = SettingsManager.Load();
            _dictationHotkeyCode = settings.HotkeyCode;
            _undoHotkeyCode = settings.UndoHotkeyCode;
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
            {
                int vkCode = Marshal.ReadInt32(lParam);

                // Handle Dictation Hotkey
                if (vkCode == _dictationHotkeyCode)
                {
                    if (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)
                    {
                        OnHotkeyDown?.Invoke();
                        return (IntPtr)1; // Swallow the key
                    }
                    else if (wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP)
                    {
                        OnHotkeyUp?.Invoke();
                        return (IntPtr)1; // Swallow the key
                    }
                }

                // Handle Undo Hotkey (Ctrl+Z simulation for now if _undoHotkeyCode == 1)
                if (_undoHotkeyCode == 1)
                {
                    if (vkCode == 0x5A) // Z key
                    {
                        if (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)
                        {
                            // Check if Ctrl is down
                            short ctrlState = GetAsyncKeyState(0x11); // VK_CONTROL
                            if ((ctrlState & 0x8000) != 0)
                            {
                                OnUndoHotkey?.Invoke();
                                // Let OS handle it
                            }
                        }
                    }
                }
            }
            return CallNextHookEx(_hookID, nCode, wParam, lParam);
        }

        public void Dispose()
        {
            UnhookWindowsHookEx(_hookID);
        }

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);

        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

        private static IntPtr SetHook(LowLevelKeyboardProc proc)
        {
            using (Process curProcess = Process.GetCurrentProcess())
            using (ProcessModule curModule = curProcess.MainModule!)
            {
                return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
            }
        }
    }
}
