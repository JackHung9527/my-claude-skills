# My Claude Skills

個人自製的 Claude Code Skills 集合。

## Skills 列表

### auto-git-commit

自動根據專案進度與程式碼變更，產生高品質雙語（英文+中文）git commit message 並執行 commit + push。

**觸發方式：** 使用「幫我 commit」、「commit 一下」、「push 上去」、「自動 commit」等關鍵字。

### claude-md-updater

CLAUDE.md 工作總結更新器。根據使用者描述與 git log 今日紀錄，產生結構化中文總結並自動插入到專案 `CLAUDE.md` 的 `## 今日總結` 區塊。

**觸發方式：** 使用「更新 CLAUDE.md」、「寫今天的總結」、「記錄到 CLAUDE.md」等關鍵字。

### stm32-pin-planner

STM32 腳位規劃自動化工具。讀取 CubeMX `.ioc` 檔案，自動規劃腳位配置並輸出含 USER_CODE 範本的初始化程式碼。

**觸發方式：** 使用「規劃腳位」、「STM32 腳位」、「ioc 設定」、「幫我配置 GPIO」等關鍵字。

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
