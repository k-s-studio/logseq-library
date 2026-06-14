需求:
- 一個 GitHub remote repo，pull 在我的所有裝置上，並可以編輯後在 push 回去
- 我的所有 Logseq 圖表被直接或間接追蹤，並且同時存在本機，而不是只能一次讀一個(例如切換分支)
- 每個 Logseq 圖表 commit 後，透過 git hook 觸發主 repo sync remote
- 每次到新的裝置只要 pull github repo 、執行一個腳本，就可以用 Logseq 開啟 Graph 編輯，並持續同步至雲端

限制:
1. Logseq 同步功能 - 支持自動commit，但行為是在**圖表目錄**裡尋找.git資料夾，或是 seperate-git-dir 的 .git 指標，找不到就無法自動commit。

理想是這樣：
/logseq-library (這個目錄，主repo，同步到github)
- /.git
- /git-hooks
- /Android-scripts
- /MyGraphA (子repo A，Logseq使用的目錄)
    - /.git
    - files...
- /MyGraphB (子repo B，Logseq使用的目錄)
    - /.git
    - files...
- ... (繼續擴充)

可能的工具：subtree, submodule, bare repo, worktree 等等