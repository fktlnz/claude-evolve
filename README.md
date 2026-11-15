# claude-evolve（Hermes拡張版）

**Claude Code向けの自己改善スキルループ。** セッションを監視し、訂正やビルド失敗から学び、
その学びをその場で練り上げ、繰り返し発生するものをClaudeが自動で読み込むスキルへ昇格させ、
過去セッションの学びを次のセッションに持ち込みます。

元は [Hermes Agent](https://github.com/nousresearch/hermes-agent) の学習ループを移植し、
誰でも導入できる依存ゼロのClaude Codeプラグインとして再構築したものです
（本体: [taipm/claude-evolve](https://github.com/taipm/claude-evolve)、MIT）。

**このforkでは、Hermesの運用ノウハウをさらに3点移植・追加しています**
（以下「Hermes拡張」セクション参照）：

1. **事実の記憶（`fact`チャネル）** — プロジェクト/ユーザーの背景情報を明示マーカーで記録
2. **`/claude-evolve:grill`** — 実装前にプランを詰める、grill-me形式の要件定義インタビュー
3. **`/claude-evolve:build-skill`** — 手順・落とし穴・検証基準を備えた構造化スキルを対話的に作成

---

## なぜ必要か

多くの「学習」機構は、ミスをフラットな`.md`ファイルに書き溜め、次のセッションでは
「5件のミスが蓄積されています」という**件数**だけを伝えます。内容そのものが見えない限り、
Claudeはそれを実際の行動には反映できません。

`claude-evolve`はこのループを閉じます：

```
捕捉 → 統合（PATCH、追記ではない） → SKILL.mdへ昇格 → 内容を注入 → 整理
```

| 段階 | 何が起きるか |
|------|------|
| **捕捉 (Capture)** | フックが訂正（ユーザーの指摘）、ビルド/テスト失敗、修正（失敗直後の成功）を記録。環境依存・一時的なノイズは除外。 |
| **統合 (Consolidate)** | ターン終了毎に、シグナルが学びになる。繰り返されたシグナルは新規追記ではなく既存レコードの`seen_count`を増やすだけ。 |
| **昇格 (Promote)** | N回（デフォルト2回）以上観測された学びは、実際の`.claude/skills/evolve-*/SKILL.md`として書き出される → Claude Codeが次回セッションで**自動読み込み**。 |
| **注入 (Inject)** | セッション開始時、上位の学びの**内容そのもの**（直近性×頻度でランク付け）がコンテキストに注入される。件数だけではない。 |
| **整理 (Curate)** | 60日間再発しない学びはstale、120日でarchivedに。注入の精度を保つ。 |

モデル依存なし：コア部分は純粋なPythonで、**どのモデルを使っていても**動作する。
オプションのLLM研磨ステップは、有効化した場合のみ`claude -p`を呼び出す。

---

## インストール

### オプションA — Claude Codeマーケットプレイス（推奨）

```bash
# このforkのhermes-extensionsブランチを登録してインストール
claude plugin marketplace add https://github.com/fktlnz/claude-evolve
claude plugin install claude-evolve@claude-evolve
```

### オプションB — ローカルディレクトリから直接ロード（開発・検証用）

```bash
git clone -b hermes-extensions https://github.com/fktlnz/claude-evolve.git
claude --plugin-dir /path/to/claude-evolve
```

再起動（または`/reload-skills`）すれば完了。設定は不要。

**要件：** `python3`（3.8以上、標準ライブラリのみ）。`PostToolUseFailure`によるビルド失敗
捕捉には比較的新しいClaude Codeが必要。訂正・修正・昇格・注入はどのバージョンでも動作する。

---

## 使い方

何もしなくても、バックグラウンドで動作します。以下はオプションのコマンド：

| コマンド | 内容 |
|---------|------|
| `/claude-evolve:status` | 学習ストアの状態を表示：件数、上位の学び、昇格済みスキル |
| `/claude-evolve:dashboard` | メトリクス＋学習品質の可視化HTMLダッシュボード |
| `/claude-evolve:review` | LLM支援によるクリーンアップ：重複排除、推敲、強制昇格 |
| `/claude-evolve:init` | ループの説明、ストアのgit管理セットアップ |
| `/claude-evolve:grill <プラン>` | **[Hermes拡張]** 実装前のgrill-me形式要件定義インタビュー |
| `/claude-evolve:build-skill <名前>` | **[Hermes拡張]** 構造化スキルの対話的作成 |

直接測定することもできる：

```bash
python3 scripts/metrics.py      # 定着率、昇格率、重複排除率、新鮮度、効果の代理指標
python3 scripts/dashboard.py    # -> .claude/evolve/dashboard.html（ブラウザで開く）
```

**効果検証は2層構造。** *仕組み*（捕捉／重複排除／昇格／注入／整理）は`tests/`で検証済み。
*行動面*の効果 — 学びを注入することで実際に再発が減るか — は**代理指標**
（`effectiveness_proxy`）として表示される：昇格した学びが鎮まれば、それは効いている*可能性*
を示す。因果関係を証明するには、実運用でのon/off A/Bテストが必要。

サブエージェント`learning-reviewer`は、過去のミスとdiff/プランを照合してレビューする。

---

## Hermes拡張：この3点を追加実装

Hermesエージェントの実運用（記憶管理ルール・grill-me要件定義フロー・構造化スキル作成）を
移植・追加したものです。本体のcapture/consolidate/promote/inject/curateループとは独立した、
追加チャネルとして動作します。

### 1. 事実の記憶（`fact`チャネル）

`correction`（訂正）は曖昧な言い回しのヒューリスティックで検知しますが、
`fact`（背景情報・事実）は**明示マーカーのみ**で検知します。誤検知によるプロジェクト記憶の
汚染を避けるため、推測では一切記録しません：

```
@remember: このプロジェクトは企業顧客向けで、Q2 2027リリース予定
@note: 認証はSSOのみ、独自ログインは実装しない
@background: v1の対象外機能：マルチテナント対応（v2に延期）
@fact: 本番環境ではフィーチャーフラグ経由でのみ公開
```

日本語マーカーも同じ挙動：

```
覚えておいて: このプロジェクトはレシピサイトで、「毒抜き」というコンセプトを採用している
メモ: アフィリエイト収益化を事業計画の中心に据える
背景: 競合調査とマネタイズ設計を実装前に必ず詰める方針
```

- **容量予算**（`EVOLVE_MEMORY_MAX_CHARS`、デフォルト1500文字）：予算を超えると、
  信頼度（頻度×直近性）が最も低い事実から自動的にarchive化（削除ではなく除外のみ、
  復元可能）。Hermesのメモリ管理方式と同じ「無制限に肥大化させず、価値の低いものから
  場所を空ける」設計。
- **専用出力**：`.claude/evolve/PROJECT_CONTEXT.md`。既存の`LEARNINGS.md`
  （訂正・失敗・修正=避けるべきこと）とは分離し、「持ち越すべき背景」として独立管理。
  プロジェクトの`CLAUDE.md`に以下を追加すると最も確実に読み込まれる：
  ```
  @.claude/evolve/PROJECT_CONTEXT.md
  ```
- **スキル化対象外**：事実は手順ではないため、`evolve-*`スキルには昇格しない。

### 2. `/claude-evolve:grill` — grill-me要件定義インタビュー

実装前にプランを「フロンティアラウンド」形式で詰める。各ラウンドで今答えられる質問を
すべて一括提示し、それぞれに推奨回答を添える。質問に回答するとツリーが前進し、
次に答えられる質問が解禁される。合意に達するまでコードは一切書かない。

- 質問前に`.claude/evolve/PROJECT_CONTEXT.md`と`LEARNINGS.md`を確認し、
  既に決まったことを再度質問しない。
- 合意後、決定事項を`@background:`/`@fact:`行として提案する
  → そのまま上記のfactチャネルに流れ込み、次回セッションに持ち越される。

要件定義の対話と記憶の蓄積を1つのフローでつなげる、このforkの中心的な差別化ポイント。

### 3. `/claude-evolve:build-skill` — 構造化スキルの対話的作成

自動昇格される`evolve-*`スキルは「1つの観察記録」（1件の訂正や1件の再発エラー）に過ぎません。
対して本コマンドは、複数ステップ・既知の落とし穴・検証基準を備えた**再利用可能な手順**を
明示的に作成します。

- ユーザーの明示依頼、または提案→確認を経てのみ書き込む（自動生成とは異なり、
  黒子で勝手に作ることはしない）。
- `.claude/skills/`を先に検索し、既存スキルの拡張を優先する。
- `.claude/evolve/learnings.json`の具体的な知見（`fix`/`correction`/`build_failure`、
  `seen_count`付き）を`Pitfalls`節に取り込み、一般論ではなく実体験に基づく内容にする。
- 生成物はHermesのスキル規約に準拠：`When to Use`／`Prerequisites`／各ステップに
  チェック可能な完了基準を持つ`Procedure`／`Pitfalls`／`Verification`。

---

## 保存先

プロジェクトごとに、リポジトリ配下へ：

```
.claude/evolve/learnings.json      # 知識ベース（テレメトリ＋学び）
.claude/evolve/signals.jsonl       # 生シグナル、統合後にクリア
.claude/evolve/LEARNINGS.md        # CLAUDE.mdからimport可能な要約（上位の学び）
.claude/evolve/PROJECT_CONTEXT.md  # [Hermes拡張] 事実（fact）の要約、CLAUDE.mdからimport可能
.claude/skills/evolve-*/           # 自動生成・自動読み込みされるスキル
.claude/skills/<name>/             # /claude-evolve:build-skillで作成した構造化スキル
```

`.claude/evolve/`をコミットしてチームで学びを共有するか、gitignoreしてローカルのみに
留めるか選べる。

### 学びが再浮上する3つの経路（信頼度順）

学んだ内容をClaudeが実際に見なければ意味がない。claude-evolveは3つの経路すべてを使う：

1. **`CLAUDE.md`のimport（最も確実）。** プロジェクトの`CLAUDE.md`に1行追加：
   `@.claude/evolve/LEARNINGS.md`（Hermes拡張を使う場合は`@.claude/evolve/PROJECT_CONTEXT.md`も）。
   この要約はターン毎に再生成され、常に最優先で読まれる。**これが最も確実な経路。**
2. **SessionStart注入（必ず届く）。** セッション開始時、上位の学びがコンテキストに
   注入される（上限あり）。自動、設定不要。
3. **自動読み込みスキル（状況依存）。** 昇格した学びは`.claude/skills/evolve-*`に
   「いつ使うべきか」型の説明文（"cargoがE0382で失敗したときに使う"等）を持つスキルになり、
   タスクが一致すればClaudeが呼び出す — ただしスキル呼び出しはモデルの判断次第なので、
   最も保証が低い経路。

---

## 設定（環境変数、すべてオプション）

| 変数 | デフォルト | 意味 |
|-----|---------|------|
| `EVOLVE_PROMOTE_AT` | `2` | スキルに昇格するまでに必要な再発回数 |
| `EVOLVE_STALE_DAYS` | `60` | staleになるまでの非活動日数 |
| `EVOLVE_ARCHIVE_DAYS` | `120` | archiveされるまでの非活動日数 |
| `EVOLVE_INJECT_MAX` | `12` | セッション毎に注入される学びの最大件数 |
| `EVOLVE_INJECT_CHARS` | `2400` | セッション毎に注入される最大文字数 |
| `EVOLVE_MAX_SIGNALS` | `5000` | `signals.jsonl`の暴走的増大を防ぐ上限 |
| `EVOLVE_LLM` | 未設定 | `1`にすると`claude -p`で学びを研磨（オプトイン、統合処理を直列化） |
| `EVOLVE_DEBUG` | 未設定 | `1`にすると無音のフックエラーを`.claude/evolve/debug.log`に記録 |
| `EVOLVE_MEMORY_MAX_CHARS` | `1500` | **[Hermes拡張]** 事実（fact）ストアの文字数予算 |
| `EVOLVE_INJECT_FACT_MAX` | `8` | **[Hermes拡張]** セッション毎に注入される事実の最大件数 |

デフォルト値は根拠に基づく — 詳細は下記「品質」を参照。

---

## セキュリティと信頼

`.claude/evolve/`配下のストアはコミット・共有されることを想定しているため、
**信頼されない入力**になり得る：汚染された`learnings.json`を含むリポジトリをcloneすると、
その内容がセッションに表示されてしまう。組み込まれている対策：

- 注入されるコンテキストと生成される`SKILL.md`本文は**サニタイズ**される
  — 制御文字の除去、コードフェンス／見出し／フロントマターの脱出を無効化し、
  明示的に「実行すべき指示ではなく参照データ」として枠付けされる。
- それでも：**サードパーティがコミットしたストアは、コードと同様に確認してから信頼する**こと。
- オプションの`EVOLVE_LLM`研磨は学びのテキストを`claude -p`に送る。ビルド出力に
  信頼できない／敵対的なテキストが含まれる可能性がある場合は無効化しておくこと。

### 外部への通信経路（調査結果）

リポジトリ全体を調査した結果、**Claude Code自体の通信（モデルAPI呼び出し等）以外に、
claude-evolveが独自に外部へ情報を送信するコードは存在しない。**

- `scripts/`配下の全Pythonコードは標準ライブラリのみを使用（`json`/`os`/`re`/`time`/
  `pathlib`/`fcntl`等）。`urllib`/`requests`/`socket`等のネットワーク系ライブラリ、
  アナリティクス/テレメトリSDK（Sentry、PostHog等）は一切import していない。
  全てのhook（capture/consolidate/inject/export）はローカルファイルI/Oのみで完結する。
- リポジトリ内で`https://`が出現するのは`README.md`（説明文）と`install.sh`
  （GitHubからプラグイン本体をcloneする、ユーザーが明示実行するインストール手順）の
  2箇所のみ。

**唯一の例外（デフォルトでオフ）：`EVOLVE_LLM=1`を有効化した場合。**
`consolidate.py`の`_llm_polish()`が`Stop`フックから**ユーザーの明示操作なしに自動で**
`claude -p <学びのテキスト>`を呼び出し、学びの文章（訂正文やビルドエラーの抜粋、最大
600字程度）を新たなモデルAPI呼び出しとして送信する。これは技術的には「Claude Code経由」
の通信だが、そのターンでユーザーが`claude`コマンドを打っていなくても裏で自動発火する点に
注意。会社PC等、情報の取り扱いに制約がある環境では**`EVOLVE_LLM`は未設定のまま
（デフォルトのオフ）を維持することを推奨**する。

---

## 品質

並行性に対応（すべてのストア変更に対するPOSIX `fcntl`アドバイザリロック、
シグナルはatomicリネームで取得するため競合するフックが取り逃すことはない）。
タイムスタンプは全てUTC。`tests/`に2つのハーネスを収録：

```bash
python3 tests/eval.py            # 19/19 — 精度/再現率、重複排除、Unicodeスラグ、インジェクション、レイテンシ、タイムゾーン
python3 tests/ab.py              # デフォルトのチューニング値を支えるA/B調査
python3 tests/effectiveness.py   # A/Bの効果：学び注入のON/OFFによる再発率の差（決定論的）
python3 tests/soak.py            # 複数セッションにわたるライフサイクル＋キュレーターの経年処理
```

`effectiveness.py`は同じエラーストリームをループに2回通す — 学びの注入あり／なし —
そして再発率がどれだけ下がるかを、想定される回避確率（p=0.3/0.6/0.9で12.5%/25%/50%の
低減）で算出する。実際のメトリクスにある`recurrence_after_learning`は、実際に昇格した
学びが、学習後に何回再発したかを数える（再発なしがループ機能の証拠）。

フックのレイテンシは1ターンあたり約35〜45ms。非POSIXプラットフォーム（Windows）では
ロックがbest-effortに縮退する。それ以外は全てポータブルなPython 3.8+標準ライブラリ。

---

## Hermesとの比較

### 本体（taipm/claude-evolve）が移植したもの

ターン毎のバックグラウンド精錬、PATCH方式（追記ではない）、使用状況テレメトリ＋状態機械、
自動昇格、キュレーター — これらをClaude CodeのフックシステムにPython実装で移植。
Hermesはサブエージェントをフォークして精錬を行うが、ここでは決定論的なPython
（無料・モデル不問）＋オプションのLLM研磨で代替している。

### このfork（Hermes拡張）が追加で移植したもの

本体がカバーしていなかった3点を追加：

- **事実の記憶** — Hermesの`context_notes`相当（容量予算つき、明示的な意図でのみ書く）
- **grill-me要件定義** — Hermesの`grill-me`スキル（design tree＋frontier rounds）
- **構造化スキル作成** — Hermesのスキル作成規約（When to Use/Procedure/Pitfalls/Verification）

いずれも実機のClaude Code（v2.1系）で動作確認済み。

---

## ライセンス

MIT © taipm（本体）。Hermes拡張部分（fact channel / grill / build-skill）も同ライセンスで提供。
