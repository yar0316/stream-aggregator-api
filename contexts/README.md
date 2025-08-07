# Stream Aggregator - 開発資料

## 概要

このディレクトリには、Stream Aggregator プロジェクトのバックエンドAPI開発と運用に関する包括的な資料が含まれています。

## 資料一覧

### 📋 [API仕様書](./api-specification.md)
バックエンドAPIの技術仕様書です。OAuth認証フロー、外部API統合、データ正規化システムの詳細な実装方針を記載しています。

**主な内容:**
- Twitch/YouTube OAuth 2.0 認証
- 配信データ取得API設計  
- ゲームカテゴリ管理システム
- エラーハンドリング・セキュリティ対策
- パフォーマンス最適化戦略

### 🔧 [フロントエンド統合ガイド](./frontend-integration.md)
現在のダミーデータからリアルタイムAPI統合への移行手順書です。React Hooks、APIクライアント、エラーハンドリングの実装方法を説明します。

**主な内容:**
- APIクライアントライブラリ設計
- カスタムReact Hooks実装
- 既存コンポーネントの更新方法
- 段階的移行チェックリスト

### 🚀 [デプロイメント・運用ガイド](./deployment-guide.md)
本番環境でのデプロイメント戦略と運用保守プロセスを定義します。Vercel、Docker、CI/CDパイプラインの設定方法を網羅します。

**主な内容:**
- Vercel/Docker デプロイメント設定
- GitHub Actions CI/CD パイプライン
- 監視・ログ・セキュリティ設定  
- インシデント対応・トラブルシューティング
- コスト最適化戦略

### 🧪 [テスト戦略・品質保証ガイド](./testing-strategy.md)
包括的なテスト戦略と品質保証プロセスを定義します。単体テストから E2E テストまでの実装方針を説明します。

**主な内容:**
- Jest + React Testing Library による単体テスト
- MSW を使用した統合テスト
- Playwright による E2E テスト
- パフォーマンス・ビジュアル回帰テスト
- 継続的品質改善プロセス

## 利用方法

### 開発者向け

1. **新規参加者**: まず `api-specification.md` でシステム全体像を把握
2. **フロントエンド開発者**: `frontend-integration.md` で統合手順を確認
3. **インフラ担当者**: `deployment-guide.md` で運用方針を理解
4. **QA担当者**: `testing-strategy.md` でテスト戦略を確認

### プロジェクト管理者向け

各資料のチェックリストを活用して、開発フェーズごとの進捗管理を行えます。

## ディレクトリ構造との関係

```
stream-aggregator/
├── contexts/           # 本ディレクトリ（開発資料）
├── src/
│   ├── app/           # Next.js App Router
│   │   └── api/       # バックエンドAPI実装
│   ├── components/    # React コンポーネント
│   ├── lib/           # ユーティリティ・データ処理
│   └── types/         # TypeScript 型定義
├── CLAUDE.md          # Claude Code 向けガイド
└── package.json       # プロジェクト設定
```

## 更新方針

- **API仕様変更時**: `api-specification.md` を先に更新
- **新機能追加時**: 対応する統合・テスト手順を資料に反映
- **運用課題発生時**: `deployment-guide.md` のトラブルシューティングに追記
- **品質問題発生時**: `testing-strategy.md` のテスト戦略を見直し

## 関連リンク

- [プロジェクトメインREADME](../README.md)
- [Claude Code ガイド](../CLAUDE.md)
- [外部API ドキュメント](https://dev.twitch.tv/docs/api/, https://developers.google.com/youtube/v3)

---

**最終更新**: 2025年1月
**管理者**: 開発チーム