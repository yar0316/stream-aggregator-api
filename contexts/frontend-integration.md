# フロントエンド統合ガイド

## 概要

Stream Aggregator フロントエンドでバックエンドAPIを統合するための実装ガイドです。現在のダミーデータから実際のAPI呼び出しへの移行手順を説明します。

## 現在の実装状況

### データフロー
- **現在**: `src/lib/dummy-data.ts` の静的データを使用
- **移行後**: バックエンドAPIからのリアルタイム取得

### 既存コンポーネント
- `src/app/page.tsx`: メイン配信一覧ページ
- `src/components/streams/StreamCard.tsx`: 配信カード表示
- `src/components/layout/Layout.tsx`: レイアウト管理

## API クライアント実装

### 1. API クライアントライブラリの作成

`src/lib/api-client.ts` を作成:

```typescript
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

class ApiClient {
  private async request<T>(
    endpoint: string, 
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'API request failed');
    }

    return response.json();
  }

  // 配信一覧取得
  async getStreams(params: {
    platform?: 'all' | 'youtube' | 'twitch';
    category?: string;
    limit?: number;
    offset?: number;
    sort?: 'viewers' | 'recent';
  } = {}): Promise<StreamsResponse> {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) {
        searchParams.append(key, value.toString());
      }
    });
    
    return this.request<StreamsResponse>(
      `/api/streams?${searchParams.toString()}`
    );
  }

  // ゲームカテゴリ一覧取得
  async getGameCategories(): Promise<GameCategoriesResponse> {
    return this.request<GameCategoriesResponse>('/api/games/categories');
  }

  // 特定ゲームの配信取得
  async getGameStreams(
    gameName: string, 
    params: PaginationParams = {}
  ): Promise<StreamsResponse> {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) {
        searchParams.append(key, value.toString());
      }
    });
    
    return this.request<StreamsResponse>(
      `/api/games/${encodeURIComponent(gameName)}/streams?${searchParams.toString()}`
    );
  }
}

export const apiClient = new ApiClient();
```

### 2. APIレスポンス型定義

`src/types/api.ts` を作成:

```typescript
export interface StreamsResponse {
  streams: Stream[];
  pagination: {
    total: number;
    limit: number;
    offset: number;
    hasMore: boolean;
  };
}

export interface GameCategoriesResponse {
  categories: {
    name: string;
    streamCount: number;
    viewerCount: number;
  }[];
}

export interface PaginationParams {
  limit?: number;
  offset?: number;
}

export interface ApiError {
  error: string;
  code?: string;
  status: number;
}
```

## React Hooks の実装

### 1. カスタムHooks作成

`src/hooks/useStreams.ts`:

```typescript
import { useState, useEffect } from 'react';
import { Stream } from '@/types/stream';
import { apiClient } from '@/lib/api-client';

interface UseStreamsParams {
  platform?: 'all' | 'youtube' | 'twitch';
  category?: string;
  autoRefresh?: boolean;
  refreshInterval?: number;
}

export function useStreams(params: UseStreamsParams = {}) {
  const [streams, setStreams] = useState<Stream[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);

  const fetchStreams = async (offset = 0) => {
    try {
      setError(null);
      const response = await apiClient.getStreams({
        ...params,
        offset,
        limit: 20
      });
      
      if (offset === 0) {
        setStreams(response.streams);
      } else {
        setStreams(prev => [...prev, ...response.streams]);
      }
      
      setHasMore(response.pagination.hasMore);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'データの取得に失敗しました');
    } finally {
      setLoading(false);
    }
  };

  const loadMore = () => {
    if (hasMore && !loading) {
      fetchStreams(streams.length);
    }
  };

  useEffect(() => {
    fetchStreams();
    
    // 自動更新の設定
    if (params.autoRefresh) {
      const interval = setInterval(() => {
        fetchStreams();
      }, params.refreshInterval || 60000); // デフォルト1分
      
      return () => clearInterval(interval);
    }
  }, [params.platform, params.category]);

  return {
    streams,
    loading,
    error,
    hasMore,
    loadMore,
    refresh: () => fetchStreams()
  };
}
```

### 2. ゲームカテゴリHook

`src/hooks/useGameCategories.ts`:

```typescript
import { useState, useEffect } from 'react';
import { apiClient } from '@/lib/api-client';

interface GameCategory {
  name: string;
  streamCount: number;
  viewerCount: number;
}

export function useGameCategories() {
  const [categories, setCategories] = useState<GameCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const response = await apiClient.getGameCategories();
        setCategories(response.categories);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'カテゴリの取得に失敗しました');
      } finally {
        setLoading(false);
      }
    };

    fetchCategories();
  }, []);

  return { categories, loading, error };
}
```

## 既存コンポーネントの更新

### 1. メインページの更新

`src/app/page.tsx` の修正:

```typescript
'use client';

import Layout from '@/components/layout/Layout';
import StreamCard from '@/components/streams/StreamCard';
import { useStreams } from '@/hooks/useStreams';

export default function Home() {
  const { streams, loading, error, hasMore, loadMore } = useStreams({
    platform: 'all',
    autoRefresh: true,
    refreshInterval: 120000 // 2分間隔
  });

  if (loading && streams.length === 0) {
    return (
      <Layout>
        <div className="max-w-7xl mx-auto">
          <div className="text-center text-white py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white mx-auto"></div>
            <p className="mt-2">配信データを読み込み中...</p>
          </div>
        </div>
      </Layout>
    );
  }

  if (error) {
    return (
      <Layout>
        <div className="max-w-7xl mx-auto">
          <div className="text-center text-red-400 py-8">
            <p>エラー: {error}</p>
            <button 
              onClick={() => window.location.reload()}
              className="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
            >
              再読み込み
            </button>
          </div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="max-w-7xl mx-auto">
        <h1 className="text-2xl font-bold text-white mb-6">
          ライブ配信中 ({streams.length}件)
        </h1>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {streams.map((stream) => (
            <StreamCard key={`${stream.platform}-${stream.id}`} stream={stream} />
          ))}
        </div>
        
        {hasMore && (
          <div className="text-center mt-8">
            <button
              onClick={loadMore}
              disabled={loading}
              className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
            >
              {loading ? '読み込み中...' : 'もっと見る'}
            </button>
          </div>
        )}
      </div>
    </Layout>
  );
}
```

### 2. ゲーム別ページの実装

`src/app/games/page.tsx` の更新:

```typescript
'use client';

import { useState } from 'react';
import Layout from '@/components/layout/Layout';
import StreamCard from '@/components/streams/StreamCard';
import { useGameCategories } from '@/hooks/useGameCategories';
import { useStreams } from '@/hooks/useStreams';

export default function GamesPage() {
  const [selectedGame, setSelectedGame] = useState<string>('all');
  const { categories, loading: categoriesLoading } = useGameCategories();
  const { streams, loading: streamsLoading, error } = useStreams({
    category: selectedGame === 'all' ? undefined : selectedGame,
    autoRefresh: true
  });

  return (
    <Layout>
      <div className="max-w-7xl mx-auto">
        <h1 className="text-2xl font-bold text-white mb-6">ゲーム別配信</h1>
        
        {/* ゲームカテゴリ選択 */}
        <div className="mb-6">
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setSelectedGame('all')}
              className={`px-4 py-2 rounded-lg font-medium ${
                selectedGame === 'all'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }`}
            >
              すべて
            </button>
            {categories.map((category) => (
              <button
                key={category.name}
                onClick={() => setSelectedGame(category.name)}
                className={`px-4 py-2 rounded-lg font-medium ${
                  selectedGame === category.name
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
              >
                {category.name} ({category.streamCount})
              </button>
            ))}
          </div>
        </div>

        {/* 配信一覧 */}
        {error ? (
          <div className="text-red-400 text-center py-8">
            エラー: {error}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {streams.map((stream) => (
              <StreamCard key={`${stream.platform}-${stream.id}`} stream={stream} />
            ))}
          </div>
        )}
        
        {streamsLoading && (
          <div className="text-center text-white py-4">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-white mx-auto"></div>
          </div>
        )}
      </div>
    </Layout>
  );
}
```

## エラーハンドリング実装

### グローバルエラーバウンダリ

`src/components/ErrorBoundary.tsx`:

```typescript
'use client';

import React from 'react';

interface ErrorBoundaryState {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends React.Component<
  React.PropsWithChildren<{}>,
  ErrorBoundaryState
> {
  constructor(props: React.PropsWithChildren<{}>) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-gray-950 flex items-center justify-center">
          <div className="text-center text-white">
            <h2 className="text-2xl font-bold mb-4">エラーが発生しました</h2>
            <p className="text-gray-400 mb-4">申し訳ございません。予期しないエラーが発生しました。</p>
            <button
              onClick={() => window.location.reload()}
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
            >
              ページを再読み込み
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
```

## 環境変数設定

`.env.local` ファイルに追加:

```
# API Base URL
NEXT_PUBLIC_API_URL=http://localhost:3000

# OAuth設定（既存）
TWITCH_CLIENT_ID=your_twitch_client_id
TWITCH_CLIENT_SECRET=your_twitch_client_secret
YOUTUBE_CLIENT_ID=your_youtube_client_id
YOUTUBE_CLIENT_SECRET=your_youtube_client_secret
NEXTAUTH_URL=http://localhost:3000
```

## 移行チェックリスト

### フェーズ1: 基盤整備
- [ ] API クライアント実装
- [ ] 型定義作成
- [ ] カスタムHooks実装
- [ ] エラーハンドリング設定

### フェーズ2: コンポーネント更新
- [ ] メインページの API 統合
- [ ] ゲーム別ページの API 統合
- [ ] 設定ページの認証機能統合
- [ ] ローディング・エラー状態の UI 実装

### フェーズ3: 最適化
- [ ] キャッシュ戦略実装
- [ ] 無限スクロール実装
- [ ] パフォーマンス最適化
- [ ] ユーザビリティ向上

### フェーズ4: テスト・デプロイ
- [ ] 統合テスト実施
- [ ] エラーケースのテスト
- [ ] 本番環境での動作確認
- [ ] パフォーマンス監視設定