# Windows 右鍵簡繁檔名轉換器

這是第一版 MVP，現在提供獨立的 `ChineseFilenameTool.exe`，不需要使用者另外安裝 .NET SDK、Python 或其他套件。它使用 Windows 內建的中文轉換功能，以及一組常見中文詞彙對照；不是完整 OpenCC 詞庫，但已能處理一般檔名轉換。

## 使用 EXE

雙擊 `ChineseFilenameTool.exe`，會看到兩個按鈕：

- 「安裝這個工具」：安裝檔案與資料夾的右鍵選單。
- 「刪除這個工具」：移除右鍵選單；EXE 本身請手動刪除。

安裝後，右鍵選單會直接呼叫 EXE，不再啟動 PowerShell，也不會為每個成功項目跳出提示視窗。

如果 EXE 尚未存在，可執行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-ChineseFilenameTool.ps1
```

## 安裝

在這個資料夾中按住 Shift 並按右鍵，選擇「在此處開啟 PowerShell 視窗」，執行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-ContextMenu.ps1
```

安裝後，在檔案或資料夾上按右鍵，就會看到：

- 轉換檔名為繁體中文
- 轉換檔名為簡體中文

Windows 11 如果看不到，請先按「顯示更多選項」。

右鍵選單會記住目前這個資料夾的位置，因此不要在安裝後任意搬動整個資料夾；如果搬動了，重新執行安裝腳本即可更新路徑。

## 使用方式

- 只會轉換檔名，不會轉換檔案內容。
- 檔案的副檔名會保留，例如 `.docx` 不會被轉換。
- 多選檔案時會逐項處理，會顯示每個項目的處理結果。
- 如果轉換後的名稱已經存在，該項目會跳過並提示。
- 根目錄、唯讀檔案或沒有權限的項目會顯示錯誤。

## 移除右鍵選單

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-ContextMenu.ps1
```

## 測試

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Converter.ps1
```

測試會在系統暫存資料夾建立測試檔案，完成後自動刪除。

## 後續可加功能

- 多選檔案一次轉換
- 轉換前預覽
- 復原上一次轉換
- 工作列或獨立視窗介面
- Windows 11 新版右鍵選單整合
- 更完整的 OpenCC 詞彙轉換
