# テスト戦略・品質保証ガイド

## 概要

Stream Aggregator のテスト戦略と品質保証プロセスを定義します。単体テスト、統合テスト、E2Eテストの実装方針と、継続的な品質改善のためのプロセスを記載しています。

## テスト構成

### テストピラミッド

```
    E2E Tests (少数)
   ──────────────────
  Integration Tests (中程度)
 ─────────────────────────────
Unit Tests (多数・高速・安定)
```

### テストツール構成

- **Unit Tests**: Jest + React Testing Library
- **Integration Tests**: Jest + MSW (Mock Service Worker)  
- **E2E Tests**: Playwright
- **Visual Regression**: Chromatic (Storybook)
- **Performance Tests**: Lighthouse CI

## 単体テスト実装

### 1. テスト環境設定

#### jest.config.js
```javascript
const nextJest = require('next/jest');

const createJestConfig = nextJest({
  dir: './',
});

const customJestConfig = {
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  testEnvironment: 'jest-environment-jsdom',
  testPathIgnorePatterns: ['<rootDir>/.next/', '<rootDir>/node_modules/'],
  transform: {
    '^.+\\.(js|jsx|ts|tsx)$': ['babel-jest', { presets: ['next/babel'] }]
  },
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  collectCoverageFrom: [
    'src/**/*.{js,jsx,ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.{js,jsx,ts,tsx}',
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80, 
      lines: 80,
      statements: 80
    }
  }
};

module.exports = createJestConfig(customJestConfig);
```

#### jest.setup.js
```javascript
import '@testing-library/jest-dom';
import 'whatwg-fetch';

// ResizeObserver のモック
global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}));

// IntersectionObserver のモック
global.IntersectionObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(), 
  disconnect: jest.fn(),
}));
```

### 2. コンポーネントテスト例

#### StreamCard コンポーネントのテスト
```typescript
// src/components/streams/__tests__/StreamCard.test.tsx
import { render, screen } from '@testing-library/react';
import { StreamCard } from '../StreamCard';
import { Stream } from '@/types/stream';

const mockStream: Stream = {
  id: '1',
  title: 'Test Stream',
  channelName: 'Test Channel',
  thumbnailUrl: 'https://example.com/thumb.jpg',
  viewerCount: 1000,
  duration: '1:23:45',
  platform: 'youtube',
  category: 'Gaming',
  isLive: true,
  url: 'https://example.com/stream'
};

describe('StreamCard', () => {
  it('displays stream information correctly', () => {
    render(<StreamCard stream={mockStream} />);
    
    expect(screen.getByText('Test Stream')).toBeInTheDocument();
    expect(screen.getByText('Test Channel')).toBeInTheDocument();
    expect(screen.getByText('1,000 viewers')).toBeInTheDocument();
    expect(screen.getByText('1:23:45')).toBeInTheDocument();
    expect(screen.getByText('Gaming')).toBeInTheDocument();
  });

  it('shows live indicator when stream is live', () => {
    render(<StreamCard stream={mockStream} />);
    expect(screen.getByText('LIVE')).toBeInTheDocument();
  });

  it('applies correct platform styling', () => {
    render(<StreamCard stream={mockStream} />);
    const card = screen.getByRole('article');
    expect(card).toHaveClass('platform-youtube');
  });

  it('handles missing thumbnail gracefully', () => {
    const streamWithoutThumbnail = { ...mockStream, thumbnailUrl: '' };
    render(<StreamCard stream={streamWithoutThumbnail} />);
    
    const img = screen.getByRole('img');
    expect(img).toHaveAttribute('src', expect.stringContaining('placeholder'));
  });
});
```

### 3. カスタムHooksテスト

```typescript
// src/hooks/__tests__/useStreams.test.tsx
import { renderHook, waitFor } from '@testing-library/react';
import { useStreams } from '../useStreams';
import { apiClient } from '@/lib/api-client';

jest.mock('@/lib/api-client');

const mockApiClient = apiClient as jest.Mocked<typeof apiClient>;

describe('useStreams', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('fetches streams on mount', async () => {
    const mockStreams = [
      { id: '1', title: 'Stream 1', platform: 'youtube' },
      { id: '2', title: 'Stream 2', platform: 'twitch' }
    ];
    
    mockApiClient.getStreams.mockResolvedValue({
      streams: mockStreams,
      pagination: { total: 2, limit: 20, offset: 0, hasMore: false }
    });

    const { result } = renderHook(() => useStreams());

    expect(result.current.loading).toBe(true);
    
    await waitFor(() => {
      expect(result.current.loading).toBe(false);
    });

    expect(result.current.streams).toEqual(mockStreams);
    expect(mockApiClient.getStreams).toHaveBeenCalledWith({
      offset: 0,
      limit: 20
    });
  });

  it('handles API errors gracefully', async () => {
    mockApiClient.getStreams.mockRejectedValue(new Error('API Error'));

    const { result } = renderHook(() => useStreams());

    await waitFor(() => {
      expect(result.current.error).toBe('API Error');
    });

    expect(result.current.streams).toEqual([]);
    expect(result.current.loading).toBe(false);
  });
});
```

### 4. ユーティリティ関数テスト

```typescript
// src/lib/__tests__/game-utils.test.ts
import { getStreamGameCategory, filterStreamsByGame } from '../game-utils';
import { Stream } from '@/types/stream';

describe('game-utils', () => {
  describe('getStreamGameCategory', () => {
    it('extracts game from YouTube title with brackets', () => {
      const stream: Partial<Stream> = {
        platform: 'youtube',
        title: '【Apex Legends】ランク配信やります！',
        category: undefined
      };
      
      expect(getStreamGameCategory(stream as Stream)).toBe('Apex Legends');
    });

    it('uses Twitch category directly', () => {
      const stream: Partial<Stream> = {
        platform: 'twitch',
        category: 'League of Legends'
      };
      
      expect(getStreamGameCategory(stream as Stream)).toBe('League of Legends');
    });

    it('returns default for unrecognized games', () => {
      const stream: Partial<Stream> = {
        platform: 'youtube',
        title: 'Just chatting stream',
        category: undefined
      };
      
      expect(getStreamGameCategory(stream as Stream)).toBe('その他');
    });
  });

  describe('filterStreamsByGame', () => {
    const mockStreams: Stream[] = [
      { id: '1', category: 'Apex Legends' } as Stream,
      { id: '2', category: 'Minecraft' } as Stream,
      { id: '3', category: 'Apex Legends' } as Stream,
    ];

    it('filters streams by game category', () => {
      const result = filterStreamsByGame(mockStreams, 'Apex Legends');
      expect(result).toHaveLength(2);
      expect(result.every(s => s.category === 'Apex Legends')).toBe(true);
    });

    it('returns all streams for "all" category', () => {
      const result = filterStreamsByGame(mockStreams, 'all');
      expect(result).toHaveLength(3);
    });
  });
});
```

## 統合テスト実装

### 1. MSW (Mock Service Worker) セットアップ

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  // 配信データAPI
  http.get('/api/streams', ({ request }) => {
    const url = new URL(request.url);
    const platform = url.searchParams.get('platform');
    
    return HttpResponse.json({
      streams: [
        {
          id: '1',
          title: 'Test Stream 1',
          platform: platform || 'youtube',
          viewerCount: 1000,
          isLive: true
        }
      ],
      pagination: {
        total: 1,
        limit: 20,
        offset: 0,
        hasMore: false
      }
    });
  }),

  // ゲームカテゴリAPI
  http.get('/api/games/categories', () => {
    return HttpResponse.json({
      categories: [
        { name: 'Apex Legends', streamCount: 50, viewerCount: 10000 },
        { name: 'Minecraft', streamCount: 30, viewerCount: 5000 }
      ]
    });
  }),

  // OAuth コールバック
  http.post('/api/auth/twitch/callback', async ({ request }) => {
    const { code } = await request.json();
    
    if (code === 'valid_code') {
      return HttpResponse.json({
        access_token: 'mock_access_token',
        refresh_token: 'mock_refresh_token',
        expires_in: 3600,
        user: { id: '123', display_name: 'TestUser' },
        platform: 'twitch'
      });
    }
    
    return HttpResponse.json(
      { error: 'Invalid authorization code' },
      { status: 400 }
    );
  }),
];
```

```typescript
// src/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

### 2. 統合テスト例

```typescript
// src/__tests__/integration/streams-api.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import { server } from '@/mocks/server';
import Home from '@/app/page';

describe('Streams API Integration', () => {
  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it('loads and displays streams from API', async () => {
    render(<Home />);
    
    expect(screen.getByText('配信データを読み込み中...')).toBeInTheDocument();
    
    await waitFor(() => {
      expect(screen.getByText('Test Stream 1')).toBeInTheDocument();
    });
    
    expect(screen.queryByText('配信データを読み込み中...')).not.toBeInTheDocument();
  });

  it('handles API errors gracefully', async () => {
    server.use(
      http.get('/api/streams', () => {
        return HttpResponse.json(
          { error: 'Server Error' },
          { status: 500 }
        );
      })
    );

    render(<Home />);
    
    await waitFor(() => {
      expect(screen.getByText(/エラー: Server Error/)).toBeInTheDocument();
    });
  });
});
```

## E2Eテスト実装

### 1. Playwright 設定

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

### 2. E2Eテスト例

```typescript
// e2e/stream-browsing.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Stream Browsing', () => {
  test('displays live streams on homepage', async ({ page }) => {
    await page.goto('/');
    
    // ページタイトル確認
    await expect(page.getByRole('heading', { name: 'ライブ配信中' })).toBeVisible();
    
    // 配信カードが表示されることを確認
    await expect(page.locator('[data-testid="stream-card"]').first()).toBeVisible();
    
    // プラットフォームフィルターが機能することを確認
    await page.click('[data-testid="platform-filter-youtube"]');
    await expect(page.locator('[data-testid="stream-card"][data-platform="youtube"]')).toBeVisible();
  });

  test('navigates to game categories', async ({ page }) => {
    await page.goto('/');
    
    // ゲームページに移動
    await page.click('[data-testid="nav-games"]');
    await expect(page.getByRole('heading', { name: 'ゲーム別配信' })).toBeVisible();
    
    // カテゴリボタンが表示されることを確認
    await expect(page.locator('[data-testid="category-button"]').first()).toBeVisible();
  });

  test('handles OAuth authentication flow', async ({ page }) => {
    await page.goto('/settings');
    
    // Twitch連携ボタンをクリック
    await page.click('[data-testid="twitch-auth-button"]');
    
    // 新しいタブで認証ページが開くことを確認
    const [authPage] = await Promise.all([
      page.waitForEvent('popup'),
      page.click('[data-testid="twitch-auth-button"]')
    ]);
    
    await expect(authPage).toHaveURL(/id\.twitch\.tv\/oauth2\/authorize/);
  });
});
```

### 3. ビジュアル回帰テスト

```typescript
// e2e/visual-regression.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Visual Regression Tests', () => {
  test('homepage layout matches design', async ({ page }) => {
    await page.goto('/');
    
    // レスポンシブデザインのテスト
    await page.setViewportSize({ width: 1920, height: 1080 });
    await expect(page).toHaveScreenshot('homepage-desktop.png');
    
    await page.setViewportSize({ width: 768, height: 1024 });
    await expect(page).toHaveScreenshot('homepage-tablet.png');
    
    await page.setViewportSize({ width: 375, height: 667 });
    await expect(page).toHaveScreenshot('homepage-mobile.png');
  });

  test('stream cards display consistently', async ({ page }) => {
    await page.goto('/');
    
    const streamCard = page.locator('[data-testid="stream-card"]').first();
    await expect(streamCard).toHaveScreenshot('stream-card.png');
  });
});
```

## パフォーマンステスト

### 1. Lighthouse CI 設定

```javascript
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: ['http://localhost:3000', 'http://localhost:3000/games'],
      numberOfRuns: 3,
    },
    assert: {
      assertions: {
        'categories:performance': ['warn', { minScore: 0.8 }],
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'categories:best-practices': ['error', { minScore: 0.9 }],
        'categories:seo': ['error', { minScore: 0.9 }],
        'largest-contentful-paint': ['warn', { maxNumericValue: 2500 }],
        'first-contentful-paint': ['warn', { maxNumericValue: 1800 }],
      }
    },
    upload: {
      target: 'lhci',
      serverBaseUrl: 'https://your-lhci-server.com',
    },
  },
};
```

### 2. カスタムパフォーマンステスト

```typescript
// src/__tests__/performance/stream-loading.test.ts
import { performance } from 'perf_hooks';

describe('Stream Loading Performance', () => {
  it('loads initial streams within acceptable time', async () => {
    const startTime = performance.now();
    
    // API呼び出しをシミュレート
    const response = await fetch('/api/streams');
    const data = await response.json();
    
    const endTime = performance.now();
    const loadTime = endTime - startTime;
    
    expect(loadTime).toBeLessThan(1000); // 1秒以内
    expect(data.streams).toBeDefined();
    expect(data.streams.length).toBeGreaterThan(0);
  });
});
```

## 品質ゲート設定

### 1. GitHub Actions での品質チェック

```yaml
# .github/workflows/quality-gate.yml
name: Quality Gate

on: [push, pull_request]

jobs:
  quality-checks:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run linting
        run: npm run lint
      
      - name: Type checking
        run: npm run type-check
      
      - name: Unit tests with coverage
        run: npm run test -- --coverage --watchAll=false
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
      
      - name: Build application
        run: npm run build
      
      - name: Run E2E tests
        run: npm run e2e:ci
        
      - name: Lighthouse CI
        run: npm run lighthouse:ci

  security-scan:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Run security audit
        run: npm audit --audit-level=moderate
      
      - name: Dependency vulnerability scan
        uses: securecodewarrior/github-action-add-sarif@v1
        with:
          sarif-file: 'security-scan-results.sarif'
```

## テストデータ管理

### 1. ファクトリパターン

```typescript
// src/test-utils/factories.ts
import { faker } from '@faker-js/faker';
import { Stream, Platform } from '@/types/stream';

export const createMockStream = (overrides?: Partial<Stream>): Stream => ({
  id: faker.string.uuid(),
  title: faker.lorem.sentence(),
  channelName: faker.internet.userName(),
  thumbnailUrl: faker.image.url(),
  viewerCount: faker.number.int({ min: 10, max: 50000 }),
  duration: `${faker.number.int({ min: 0, max: 5 })}:${faker.number.int({ min: 0, max: 59 })}:${faker.number.int({ min: 0, max: 59 })}`,
  platform: faker.helpers.arrayElement(['youtube', 'twitch'] as Platform[]),
  category: faker.helpers.arrayElement(['Apex Legends', 'Minecraft', 'VALORANT']),
  isLive: true,
  url: faker.internet.url(),
  ...overrides
});

export const createMockStreams = (count: number): Stream[] => 
  Array.from({ length: count }, () => createMockStream());
```

### 2. テストユーティリティ

```typescript
// src/test-utils/render.tsx
import { render, RenderOptions } from '@testing-library/react';
import { ReactElement } from 'react';

const AllTheProviders = ({ children }: { children: React.ReactNode }) => {
  return (
    <div>
      {children}
    </div>
  );
};

const customRender = (
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) => render(ui, { wrapper: AllTheProviders, ...options });

export * from '@testing-library/react';
export { customRender as render };
```

## 継続的品質改善

### 1. コードレビューチェックリスト

- [ ] 新機能に対応するテストが追加されている
- [ ] テストカバレッジが80%以上維持されている
- [ ] エラーハンドリングが適切に実装されている
- [ ] パフォーマンスに悪影響がない
- [ ] アクセシビリティガイドラインに準拠している
- [ ] セキュリティ脆弱性がない

### 2. 品質メトリクス監視

```typescript
// src/lib/quality-metrics.ts
export const qualityMetrics = {
  testCoverage: {
    threshold: 80,
    current: 0 // CI/CDで更新
  },
  performanceScore: {
    threshold: 80,
    current: 0 // Lighthouse CI で更新  
  },
  accessibility: {
    threshold: 90,
    current: 0 // axe-core で更新
  },
  bundleSize: {
    threshold: 1000000, // 1MB
    current: 0 // Bundle analyzer で更新
  }
};
```