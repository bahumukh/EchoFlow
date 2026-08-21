using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;

namespace Echoflow.Services
{
    public class TextInserterService
    {
        public bool InsertText(string text)
        {
            try
            {
                // Set clipboard text
                System.Windows.Clipboard.SetText(text);

                // Give the OS a tiny moment to process the clipboard
                Thread.Sleep(50);

                // Simulate Ctrl+V using SendInput
                SimulateCtrlV();
                return true;
            }
            catch
            {
                return false;
            }
        }

        public void PressEnter()
        {
            var inputs = new INPUT[2];
            inputs[0].type = INPUT_KEYBOARD;
            inputs[0].u.ki.wVk = VK_RETURN;

            inputs[1].type = INPUT_KEYBOARD;
            inputs[1].u.ki.wVk = VK_RETURN;
            inputs[1].u.ki.dwFlags = KEYEVENTF_KEYUP;

            SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
        }

        private void SimulateCtrlV()
        {
            var inputs = new INPUT[4];

            // Ctrl down
            inputs[0].type = INPUT_KEYBOARD;
            inputs[0].u.ki.wVk = VK_CONTROL;

            // V down
            inputs[1].type = INPUT_KEYBOARD;
            inputs[1].u.ki.wVk = VK_V;

            // V up
            inputs[2].type = INPUT_KEYBOARD;
            inputs[2].u.ki.wVk = VK_V;
            inputs[2].u.ki.dwFlags = KEYEVENTF_KEYUP;

            // Ctrl up
            inputs[3].type = INPUT_KEYBOARD;
            inputs[3].u.ki.wVk = VK_CONTROL;
            inputs[3].u.ki.dwFlags = KEYEVENTF_KEYUP;

            SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
        }

        // Win32 API Definitions
        private const int INPUT_KEYBOARD = 1;
        private const ushort VK_CONTROL = 0x11;
        private const ushort VK_V = 0x56;
        private const ushort VK_RETURN = 0x0D;
        private const uint KEYEVENTF_KEYUP = 0x0002;

        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT
        {
            public uint type;
            public InputUnion u;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct InputUnion
        {
            [FieldOffset(0)]
            public KEYBDINPUT ki;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    }
}
