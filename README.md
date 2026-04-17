# My Claude Skills

個人自製的 Claude Code Skills 集合。

## Skills 列表

### auto-git-commit

自動 Git Commit 工具。分析專案變更內容，產生高品質雙語（英文標題 + 中文描述）Conventional Commits 格式的 commit message，確認後執行 commit 並可選擇 push。支援 README 自動更新偵測。

**觸發方式：** 使用「幫我 commit」、「commit 一下」、「push 上去」、「記錄進度」、「存一下進度」等關鍵字。

### claude-md-updater

CLAUDE.md 工作總結更新器。根據使用者描述與 git log 今日紀錄，產生結構化中文總結並自動插入到專案 `CLAUDE.md` 的 `## 今日總結` 區塊。

**觸發方式：** 使用「更新 CLAUDE.md」、「寫今天的總結」、「記錄到 CLAUDE.md」等關鍵字。

### stm32-pin-planner

STM32 腳位規劃自動化工具。讀取 CubeMX 產生的空白 .ioc 檔案，根據需求規劃腳位分配，輸出填好的 .ioc 和 PinTable.xlsx。內含 USER_CODE 程式碼範本（userCode / softwareTim / global_includes）。

**觸發方式：** 使用「STM32 腳位」、「pin mapping」、「產生 ioc」、「腳位規劃」、「PinTable」等關鍵字。

### stm32-build-flash

STM32 編譯與燒錄自動化工具。針對 STM32CubeIDE Makefile 專案設計，自動編譯產生 `.elf` / `.bin` / `.hex`，並透過 `STM32_Programmer_CLI`（ST-Link）燒錄 MCU。支援 WSL / Git Bash 環境，自動偵測工具鏈路徑與 Windows 路徑轉換。

**觸發方式：** 使用「編譯 STM32」、「build STM32」、「燒錄 STM32」、「flash STM32」、「一鍵 build + flash」、「編完燒進去」等關鍵字。

### trello-worklog

Trello 工作日誌產生器。描述今天在 Claude Code 的開發工作，自動產生可直接貼到 Trello 卡片描述欄位的結構化日誌格式。

**觸發方式：** 使用「工作日誌」、「Trello 日誌」、「幫我寫日誌」等關鍵字。

### tw-stock-analyzer

台灣股市全方位分析工具。提供技術分析、基本面分析、法人籌碼分析、產業類股研究等功能。

**觸發方式：** 提到台股代號（如 2330、0050）、「台股」、「技術面」、「基本面」、「籌碼」、「法人」、「大盤」等關鍵字。

## 安裝方式

在 Claude Code 中輸入：

```
幫我安裝裡面的技能
```

Claude Code 會自動將 `.skill` 檔案解壓並安裝到 `~/.claude/commands/`，重新啟動後即可透過 `/` 選單使用。
