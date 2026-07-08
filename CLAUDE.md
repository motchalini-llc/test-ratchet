# CLAUDE.md

## プロジェクト概要

**Test Ratchet** は、テストを「直さず黙らせて」CI を緑にする行為（`it.skip` /
`@pytest.mark.skip` / `xfail` によるスキップ、`it.only` などのフォーカステスト）を
検出して PR を落とす、ゼロ依存の GitHub Action。スキップ/無効化されたテスト数が
ベースライン（既定 0）を超えたら fail、フォーカステストは件数に関わらず即 fail する
「ラチェット」ゲート。ゲート本体は [gate.sh](gate.sh) 一枚の bash スクリプトで、
composite action として [action.yml](action.yml) から呼ばれる。AI もサードパーティ
依存も使わない。type-ratchet / suppress-ratchet と並ぶ Ratchet family の一つで、
GitHub Marketplace に公開済み。

## ループ運用（/goal）

「条件を満たすまで自動で回す」作業には `/goal` を使う（/goal・/loop・/schedule の
使い分けの全体像はグローバルの PLAYBOOK §7 を参照）。条件は
**測定可能な終了状態＋証明方法＋ターン上限**の3点セットで書く。

### 標準完了条件（このリポジトリの証明方法）

CI（`.github/workflows/self-test.yml`）は本体を `tests/fixtures/` の clean/dirty
fixture に対して実行し、「clean は通り dirty は落ちる」ことを検証している。同じ検証は
`gate.sh` をリポジトリルートから直接実行することでローカルでも再現できる（動作確認済み）。

| チェック | コマンド | 合格条件 |
|---|---|---|
| Python clean fixture | `INPUT_LANGUAGE=python INPUT_WORKING_DIRECTORY=tests/fixtures/python-clean bash gate.sh` | exit 0 |
| Python dirty fixture | `INPUT_LANGUAGE=python INPUT_WORKING_DIRECTORY=tests/fixtures/python-dirty bash gate.sh` | exit が非0 |
| TypeScript clean fixture | `INPUT_LANGUAGE=typescript INPUT_WORKING_DIRECTORY=tests/fixtures/typescript-clean bash gate.sh` | exit 0 |
| TypeScript dirty fixture | `INPUT_LANGUAGE=typescript INPUT_WORKING_DIRECTORY=tests/fixtures/typescript-dirty bash gate.sh` | exit が非0 |

verifier / code-reviewer に渡すルーブリックもこの標準完了条件をデフォルトにする。

### /goal 条件テンプレ

```
/goal <やってほしいこと>。完了条件: 上記4コマンドがそれぞれ期待どおりの exit code
になること（clean fixture 2件は exit 0、dirty fixture 2件は exit 非0）。各コマンドの
実行結果をターン内に表示すること。tests/fixtures/*-dirty のテストコードは編集しない。
15ターンで打ち切り。
```

### 注意事項

- **/goal の判定者はコマンドを実行しない**。会話に表出した出力だけで達成判定する
  ため、完了条件のチェックコマンドは毎ターン実行して出力を表示すること。
- ターン上限（暴走時のブレーキ）を条件文に必ず含めること。
- **`v1` タグの付け替え・GitHub Release の作成・Marketplace への公開はループに
  含めない**（ユーザー判断。ループ内で実行しない）。
- **`tests/fixtures/*-dirty` は「わざと汚い」のが仕様**（ゲートが落ちることを
  検証するための fixture）。skip/only を含むのが正しい状態であり、ループ中に
  うっかり「修正」しないこと — 直すと self-test の dirty-fails ジョブが壊れる。
