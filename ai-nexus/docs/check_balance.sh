#!/bin/sh
# 检查 DeepSeek API 余额；若 ≤ 0.5 元，输出警告并返回非0
# 用法: sh scripts/check_balance.sh
set -e
KEY=$(grep 'DEEPSEEK_API_KEY' "$DSH_HOME/.credentials.yaml" 2>/dev/null | sed 's/.*: *//')
if [ -z "$KEY" ]; then
  echo "❌ 未找到 API Key（$DSH_HOME/.credentials.yaml）"
  exit 2
fi
DSK="$KEY" node -e '
const key = process.env.DSK;
fetch("https://api.deepseek.com/user/balance", { headers: { "Authorization": "Bearer " + key } })
  .then(r => r.json().then(j => ({ status: r.status, body: j })))
  .then(({status, body}) => {
    if (status !== 200) { console.error("查询失败:", JSON.stringify(body)); process.exit(2); }
    for (const b of body.balance_infos || []) {
      const bal = parseFloat(b.total_balance);
      console.log("币种:", b.currency, "| 余额:", b.total_balance, "元");
      if (bal <= 0.5) {
        console.log("⚠️ 余额 ≤ 0.5 元！立即停止开发，保存进度！");
        process.exit(1);
      } else {
        console.log("✅ 余额充足，可继续开发");
        process.exit(0);
      }
    }
  })
  .catch(e => { console.error("查询失败:", e.message); process.exit(2); });
'
