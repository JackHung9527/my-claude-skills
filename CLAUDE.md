# My Claude Skills

個人自製的 Claude Code Skills 集合專案。

---

## 今日總結

### 2026/04/15

#### 完成項目
- 新增 claude-md-updater skill，可自動將今日工作總結寫入專案 CLAUDE.md
- 新增 auto-git-commit skill，自動產生雙語 commit message 並執行 commit + push
- 新增 stm32-pin-planner skill，STM32 腳位規劃自動化工具（含 USER_CODE 範本）
- 更新 README.md，加入所有 skills 的說明、觸發方式與安裝方式
- 更新 auto-git-commit skill 定義檔，新增 push 前詢問確認流程
- 更新 stm32-pin-planner skill 定義檔，調整為 CubeMX .ioc 讀取 + 腳位規劃輸出架構

#### 參考 commit
- `2ee5a3e` docs: update README with skills overview and usage
- `03e6bb2` feat: add auto-git-commit and stm32-pin-planner skills
- `7ce3623` chore(auto-git-commit): update skill definition
- `7b189ef` chore(stm32-pin-planner): update skill definition
