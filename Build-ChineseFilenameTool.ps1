param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'ChineseFilenameTool.exe')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName Microsoft.CSharp

$source = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using Microsoft.VisualBasic;
using Microsoft.Win32;

namespace ChineseFilenameTool
{
    internal sealed class Phrase
    {
        public readonly string Simplified;
        public readonly string Traditional;

        public Phrase(string simplified, string traditional)
        {
            Simplified = simplified;
            Traditional = traditional;
        }
    }

    internal sealed class ConversionResult
    {
        public readonly List<string> Renamed = new List<string>();
        public readonly List<string> Skipped = new List<string>();
        public readonly List<string> Errors = new List<string>();
    }

    internal static class Converter
    {
        private static readonly Phrase[] Phrases = new Phrase[]
        {
            new Phrase("\u8F6F\u4EF6", "\u8EDF\u9AD4"),
            new Phrase("\u6587\u4EF6\u5939", "\u8CC7\u6599\u593E"),
            new Phrase("\u6587\u4EF6", "\u6A94\u6848"),
            new Phrase("\u7F51\u7EDC", "\u7DB2\u8DEF"),
            new Phrase("\u89C6\u9891", "\u5F71\u7247"),
            new Phrase("\u670D\u52A1\u5668", "\u4F3A\u670D\u5668"),
            new Phrase("\u6570\u636E\u5E93", "\u8CC7\u6599\u5EAB"),
            new Phrase("\u7A0B\u5E8F", "\u7A0B\u5F0F"),
            new Phrase("\u6253\u5370\u673A", "\u5370\u8868\u6A5F"),
            new Phrase("\u9F20\u6807", "\u6ED1\u9F20"),
            new Phrase("\u786C\u76D8", "\u786C\u789F"),
            new Phrase("\u5C4F\u5E55", "\u87A2\u5E55"),
            new Phrase("\u8D26\u6237", "\u5E33\u6236"),
            new Phrase("\u8D26\u53F7", "\u5E33\u865F"),
            new Phrase("\u4FE1\u606F", "\u8CC7\u8A0A")
        };

        public static string ConvertText(string text, bool toTraditional)
        {
            IEnumerable<Phrase> phrases = Phrases.OrderByDescending(p => p.Simplified.Length);
            if (toTraditional)
            {
                foreach (Phrase phrase in phrases)
                {
                    text = text.Replace(phrase.Simplified, phrase.Traditional);
                }
                return Strings.StrConv(text, VbStrConv.TraditionalChinese, 2052);
            }

            foreach (Phrase phrase in phrases.OrderByDescending(p => p.Traditional.Length))
            {
                text = text.Replace(phrase.Traditional, phrase.Simplified);
            }
            return Strings.StrConv(text, VbStrConv.SimplifiedChinese, 2052);
        }

        public static ConversionResult Rename(string[] paths, bool toTraditional)
        {
            ConversionResult result = new ConversionResult();
            foreach (string inputPath in paths)
            {
                try
                {
                    if (String.IsNullOrWhiteSpace(inputPath))
                    {
                        continue;
                    }

                    string fullPath = Path.GetFullPath(inputPath);
                    bool isDirectory = Directory.Exists(fullPath);
                    bool isFile = File.Exists(fullPath);
                    if (!isDirectory && !isFile)
                    {
                        result.Errors.Add(inputPath + " : path does not exist");
                        continue;
                    }

                    string parent;
                    string name;
                    if (isDirectory)
                    {
                        DirectoryInfo info = new DirectoryInfo(fullPath);
                        if (info.Parent == null)
                        {
                            result.Errors.Add(fullPath + " : cannot rename a filesystem root");
                            continue;
                        }
                        parent = info.Parent.FullName;
                        name = info.Name;
                    }
                    else
                    {
                        FileInfo info = new FileInfo(fullPath);
                        parent = info.DirectoryName;
                        name = info.Name;
                    }

                    string extension = isDirectory ? String.Empty : Path.GetExtension(name);
                    string baseName = extension.Length == 0
                        ? name
                        : name.Substring(0, name.Length - extension.Length);
                    string newName = ConvertText(baseName, toTraditional) + extension;

                    if (newName == name)
                    {
                        result.Skipped.Add("No change: " + name);
                        continue;
                    }

                    string targetPath = Path.Combine(parent, newName);
                    if (File.Exists(targetPath) || Directory.Exists(targetPath))
                    {
                        result.Errors.Add(name + " : target already exists");
                        continue;
                    }

                    if (isDirectory)
                    {
                        Directory.Move(fullPath, targetPath);
                    }
                    else
                    {
                        File.Move(fullPath, targetPath);
                    }
                    result.Renamed.Add(name + " -> " + newName);
                }
                catch (Exception ex)
                {
                    result.Errors.Add(inputPath + " : " + ex.Message);
                }
            }
            return result;
        }
    }

    internal static class ToolRegistry
    {
        private static readonly string[] Roots = new string[]
        {
            "Software\\Classes\\*",
            "Software\\Classes\\Directory"
        };

        private const string TraditionalVerb = "ChineseFilenameTool.ToTraditional";
        private const string SimplifiedVerb = "ChineseFilenameTool.ToSimplified";

        public static void Install(string executablePath)
        {
            RemoveLegacyEntries();
            InstallVerb(TraditionalVerb, "\u8F49\u63DB\u6A94\u540D\u70BA\u7E41\u9AD4\u4E2D\u6587", "--to-traditional", executablePath);
            InstallVerb(SimplifiedVerb, "\u8F49\u63DB\u6A94\u540D\u70BA\u7C21\u9AD4\u4E2D\u6587", "--to-simplified", executablePath);
        }

        private static void InstallVerb(string verb, string label, string direction, string executablePath)
        {
            string command = "\"" + executablePath + "\" " + direction + " --quiet \"%1\" %*";
            foreach (string root in Roots)
            {
                using (RegistryKey menu = Registry.CurrentUser.CreateSubKey(root + "\\shell\\" + verb))
                {
                    menu.SetValue("", label, RegistryValueKind.String);
                    menu.SetValue("MultiSelectModel", "Player", RegistryValueKind.String);
                    using (RegistryKey commandKey = menu.CreateSubKey("command"))
                    {
                        commandKey.SetValue("", command, RegistryValueKind.String);
                    }
                }
            }
        }

        public static void Uninstall()
        {
            foreach (string root in Roots)
            {
                DeleteIfPresent(root + "\\shell\\" + TraditionalVerb);
                DeleteIfPresent(root + "\\shell\\" + SimplifiedVerb);
            }
            RemoveLegacyEntries();
        }

        private static void RemoveLegacyEntries()
        {
            foreach (string root in Roots)
            {
                DeleteIfPresent(root + "\\shell\\ConvertChinese.ToTraditional");
                DeleteIfPresent(root + "\\shell\\ConvertChinese.ToSimplified");
            }
        }

        private static void DeleteIfPresent(string path)
        {
            try
            {
                Registry.CurrentUser.DeleteSubKeyTree(path, false);
            }
            catch (ArgumentException)
            {
            }
        }
    }

    internal sealed class MainForm : Form
    {
        private readonly Label statusLabel;

        public MainForm()
        {
            Text = "\u7E41\u7C21\u6A94\u540D\u8F49\u63DB\u5DE5\u5177";
            ClientSize = new Size(460, 220);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;

            Label description = new Label();
            description.AutoSize = true;
            description.Location = new Point(30, 25);
            description.Text = "\u5B89\u88DD\u5F8C\uFF0C\u5728\u6A94\u6848\u6216\u8CC7\u6599\u593E\u6309\u53F3\u9375\u5373\u53EF\u4F7F\u7528\u3002";

            Button installButton = new Button();
            installButton.Text = "\u5B89\u88DD\u9019\u500B\u5DE5\u5177";
            installButton.Location = new Point(30, 75);
            installButton.Size = new Size(180, 42);
            installButton.Click += InstallButton_Click;

            Button uninstallButton = new Button();
            uninstallButton.Text = "\u522A\u9664\u9019\u500B\u5DE5\u5177";
            uninstallButton.Location = new Point(230, 75);
            uninstallButton.Size = new Size(180, 42);
            uninstallButton.Click += UninstallButton_Click;

            statusLabel = new Label();
            statusLabel.AutoSize = true;
            statusLabel.Location = new Point(30, 145);
            statusLabel.Text = "\u72C0\u614B\uFF1A\u5C1A\u672A\u64CD\u4F5C";

            Controls.Add(description);
            Controls.Add(installButton);
            Controls.Add(uninstallButton);
            Controls.Add(statusLabel);
        }

        private void InstallButton_Click(object sender, EventArgs e)
        {
            try
            {
                ToolRegistry.Install(Application.ExecutablePath);
                statusLabel.Text = "\u72C0\u614B\uFF1A\u5B89\u88DD\u5B8C\u6210";
                MessageBox.Show("\u53F3\u9375\u9078\u55AE\u5DF2\u5B89\u88DD\u3002", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void UninstallButton_Click(object sender, EventArgs e)
        {
            try
            {
                ToolRegistry.Uninstall();
                statusLabel.Text = "\u72C0\u614B\uFF1A\u5DF2\u522A\u9664\u53F3\u9375\u9078\u55AE";
                MessageBox.Show("\u53F3\u9375\u9078\u55AE\u5DF2\u522A\u9664\u3002\r\n\r\nEXE \u6A94\u6848\u8ACB\u624B\u52D5\u522A\u9664\u3002", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            if (args.Length > 0 && args[0].Equals("--install", StringComparison.OrdinalIgnoreCase))
            {
                ToolRegistry.Install(Application.ExecutablePath);
                return 0;
            }
            if (args.Length > 0 && args[0].Equals("--uninstall", StringComparison.OrdinalIgnoreCase))
            {
                ToolRegistry.Uninstall();
                return 0;
            }

            if (args.Length == 0 || args[0].Equals("--ui", StringComparison.OrdinalIgnoreCase))
            {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainForm());
                return 0;
            }

            bool toTraditional = args[0].Equals("--to-traditional", StringComparison.OrdinalIgnoreCase);
            bool toSimplified = args[0].Equals("--to-simplified", StringComparison.OrdinalIgnoreCase);
            if (!toTraditional && !toSimplified)
            {
                return 2;
            }

            bool quiet = args.Any(a => a.Equals("--quiet", StringComparison.OrdinalIgnoreCase));
            string[] paths = args.Skip(1)
                .Where(a => !a.Equals("--quiet", StringComparison.OrdinalIgnoreCase))
                .Where(a => !a.Equals("%1", StringComparison.OrdinalIgnoreCase))
                .Where(a => !a.Equals("%*", StringComparison.OrdinalIgnoreCase))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
            if (paths.Length == 0)
            {
                return 2;
            }

            ConversionResult result = Converter.Rename(paths, toTraditional);
            if (quiet)
            {
                if (result.Errors.Count > 0)
                {
                    string logPath = Path.Combine(Path.GetTempPath(), "ChineseFilenameTool.log");
                    File.AppendAllText(logPath, DateTime.Now.ToString("s") + Environment.NewLine + String.Join(Environment.NewLine, result.Errors) + Environment.NewLine, Encoding.UTF8);
                }
                return result.Errors.Count == 0 ? 0 : 1;
            }

            List<string> lines = new List<string>();
            lines.Add("\u5DF2\u91CD\u65B0\u547D\u540D\uFF1A" + result.Renamed.Count);
            lines.Add("\u7121\u9700\u8B8A\u66F4\uFF1A" + result.Skipped.Count);
            lines.Add("\u932F\u8AA4\uFF1A" + result.Errors.Count);
            if (result.Errors.Count > 0)
            {
                lines.Add(String.Empty);
                lines.AddRange(result.Errors);
            }
            MessageBox.Show(String.Join(Environment.NewLine, lines), "\u6A94\u540D\u8F49\u63DB", MessageBoxButtons.OK, result.Errors.Count > 0 ? MessageBoxIcon.Warning : MessageBoxIcon.Information);
            return result.Errors.Count == 0 ? 0 : 1;
        }
    }
}
'@

$compiler = New-Object Microsoft.CSharp.CSharpCodeProvider
$parameters = New-Object System.CodeDom.Compiler.CompilerParameters
$parameters.GenerateExecutable = $true
$parameters.OutputAssembly = [System.IO.Path]::GetFullPath($OutputPath)
$parameters.CompilerOptions = '/target:winexe /platform:anycpu /optimize+'
$parameters.ReferencedAssemblies.Add('System.dll') | Out-Null
$parameters.ReferencedAssemblies.Add('System.Core.dll') | Out-Null
$parameters.ReferencedAssemblies.Add('System.Drawing.dll') | Out-Null
$parameters.ReferencedAssemblies.Add('System.Windows.Forms.dll') | Out-Null
$parameters.ReferencedAssemblies.Add('Microsoft.VisualBasic.dll') | Out-Null

$result = $compiler.CompileAssemblyFromSource($parameters, $source)
if ($result.Errors.HasErrors) {
    foreach ($error in $result.Errors) {
        Write-Error $error.ToString()
    }
    exit 1
}

Write-Host "Built: $($parameters.OutputAssembly)"
