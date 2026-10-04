# create2_salt_probe

用固定的 CREATE2 factory、Rescue bytecode 和 `owner`，從 salt 算出合約地址，並用免費公開 RPC 查 Ethereum / Arbitrum / Base 的 native ETH。

不負責自動部署或提款。查詢失敗不會被當成「沒有餘額」。

## 需求

- [Foundry](https://book.getfoundry.sh/getting-started/installation)（`forge`、`cast`）

## 設定

```bash
cp .env.example .env
```

至少填 `OWNER`（Rescue constructor 的 EOA）。換 `OWNER`、`FACTORY` 或合約 bytecode，算出來的地址都會變。

`.env` 不要提交。

## 指令

編譯：

```bash
forge build
```

算單一 salt 的地址：

```bash
./script/compute-create2.sh
```

查 `.env` 裡 `ADDR` 的 native ETH（可選 `MAJOR_TOKENS=1` 再查 WETH/USDC/USDT）：

```bash
./script/check-balances.sh
```

從 `START_SALT` 掃到 `END_SALT`（salt 為補齊 32 bytes 的整數）：

```bash
./script/run-cycle.sh
```

結果在 `out/`：

| 檔案 | 內容 |
|---|---|
| `all.csv` | 每一圈的 `salt,address` |
| `with-native.csv` | 任一鏈 native > 0 |
| `empty.csv` | 三鏈都成功且都是 0 |
| `error.csv` | RPC 失敗，不當成 empty |

公開 RPC 掛了會試下一條。`SLEEP_SEC` 是每圈結束後的間隔，瓶頸在網路不是 GPU。

## 合約

- `src/Rescue.sol`：只有 `owner` 能把合約上的 ETH / ERC-20 / ERC-721 / ERC-1155 轉走。`owner` 在 constructor 裡，所以會進入 CREATE2 init code。
- `src/Create2Factory.sol`：可選。多數鏈可直接用 `0x4e59b44847b379578588920cA78FbF26c0B4956C`。
