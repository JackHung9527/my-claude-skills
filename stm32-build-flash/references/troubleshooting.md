# 疑難排解

常見編譯與燒錄錯誤，以及建議的處理方式。

## 編譯相關

### `make: command not found`

**原因**：WSL / Git Bash 的 PATH 沒有 make，且腳本也沒找到 STM32CubeIDE 內建的 make。

**處理**：
- Ubuntu / WSL：`sudo apt install make`
- Git Bash：安裝 MSYS2 make，或把 STM32CubeIDE 的 `plugins/com.st.stm32cube.ide.mcu.externaltools.make.*/tools/bin/` 加入 PATH

### `arm-none-eabi-gcc: command not found`（from make）

**原因**：Makefile 裡寫的是相對呼叫（`arm-none-eabi-gcc` 而非絕對路徑），但 PATH 裡沒有。

**處理**：
- 把 STM32CubeIDE 的 gnu-tools bin 目錄加入 PATH，位置類似：
  `C:\ST\STM32CubeIDE_*\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.*\tools\bin`
- 或 `sudo apt install gcc-arm-none-eabi`（WSL）

### `No rule to make target 'all'`

**原因**：執行目錄不對，當前目錄的 Makefile 不是 CubeIDE 產生的那份。

**處理**：確認 `--project-dir` 指向 `<專案>/Debug/` 而不是專案根目錄。

### 編譯卡在 `undefined reference to ...`

**原因**：某個 source file 沒被加進 Makefile（CubeIDE 需要 refresh 後重建 Makefile）。

**處理**：回到 CubeIDE 裡 Clean + Build 一次讓它重新產 Makefile，然後再用這個 skill。

## 燒錄相關

### `Error: No ST-Link detected`

**原因**：ST-Link 沒接、USB 有問題、或驅動沒裝。

**處理**：
1. 確認 USB 線材是 data 線不是充電線
2. `STM32_Programmer_CLI -l` 列出偵測到的裝置（WSL 下記得先做 `usbipd` bind/attach，或直接在 Windows PowerShell 跑）
3. 裝 STM32CubeProgrammer 時應該已經裝好驅動，若沒有到 ST 官網下載 ST-Link driver

### WSL 看不到 ST-Link（但 Windows 看得到）

**原因**：WSL2 預設不直接存取 USB，而 `STM32_Programmer_CLI.exe` 是跑在 Windows 側透過 interop 被 WSL 呼叫的，所以它「看到」的是 Windows 的 USB。這通常是 OK 的。

**驗證**：在 WSL 裡跑 `STM32_Programmer_CLI.exe -l` 應該能看到 ST-Link。如果看不到，表示 Windows 側也沒抓到，去 Windows 裡查。

### `Error: Data mismatch found at address` 或 verify 失敗

**原因**：
- Flash 寫保護（Option Bytes 的 RDP / WRP）
- 燒錄 `.bin` 時起始位址錯誤（覆蓋到錯的區域）
- Flash 損壞（極少見）

**處理**：
1. 先用 `.hex` 而不是 `.bin` 再試一次（排除位址問題）
2. 檢查 Option Bytes：`STM32_Programmer_CLI -c port=SWD -ob displ`
3. 若 RDP != AA，可嘗試 regression（會清空 Flash）：`STM32_Programmer_CLI -c port=SWD -ob RDP=0xAA`（**注意：這會抹除整片 Flash**）

### `Error: Target is not responding`

**原因**：
- MCU 進入某種低功耗模式
- 程式跑進 while(1) 禁中斷，SWD 被擋
- 前一次燒錄寫壞了（bricked）

**處理**：按住 Reset 鍵後再燒錄，或用 `--hardRst` 之類的選項。腳本的呼叫已經包含 `-rst`，一般情況下夠用。若還是不行，嘗試 **Connect Under Reset**：需改用 `-c port=SWD mode=UR`，可以手動加到腳本或透過環境變數擴充（目前版本沒做成參數，有需要再加）。

### `Error: Timeout error occured during read`

**原因**：SWD 訊號品質差（線太長、接觸不良、或 MCU 供電不穩）。

**處理**：
- 縮短杜邦線
- 確認 GND 確實有接
- 降低 SWD 頻率：`STM32_Programmer_CLI -c port=SWD freq=1000`（1 MHz）

### 燒錄成功但程式沒跑

**原因**：
- 沒做 reset（但腳本已加 `-rst`，這個很少見）
- Vector table 位置不對（boot pin 錯 / RDP 切換後某些設定被清掉）
- 如果燒的是 `.bin` 且起始位址不是 `0x08000000`，但 MCU 的 BOOT0 設定預設從 `0x08000000` 開始，自然跑不到你的程式

**處理**：改燒 `.hex` 或 `.elf`，或確認 `--address` 正確。

## 路徑相關（WSL / Git Bash 特有）

### 腳本回報「找不到檔案」但檔案明明在

**原因**：WSL 路徑轉 Windows 路徑失敗，或檔案在 WSL 專屬檔案系統（例如 `/home/xxx/`、`/tmp/`），Windows 的 exe 存取不到。

**處理**：
- 把專案放在 `/mnt/c/Users/<你>/...` 下（Windows 檔案系統），確保 Windows exe 能讀到
- 或確認 `wslpath` 可用：`which wslpath`

### Git Bash 下 glob 展開失敗

**原因**：Git Bash 的 MSYS 對某些 glob pattern 會做 path mangling（路徑改寫）。

**處理**：在 Git Bash 下執行指令前設 `MSYS_NO_PATHCONV=1`，例如：
```bash
MSYS_NO_PATHCONV=1 bash scripts/stm32.sh flash firmware.hex
```
