/**
 * Stream Aggregator API TypeScript Interface Definitions
 * 
 * 実際のSupabaseデータベーススキーマに基づいた型定義
 * SQL Schema: contexts/sqls/*.sql
 * 
 * Created: 2025-08-07
 * Version: 1.0
 */

// =============================================================================
// Common Types
// =============================================================================

export type UUID = string;
export type ISODateTime = string;
export type Platform = 'youtube' | 'twitch' | 'kick';

// =============================================================================
// Database Entity Models (実際のDBスキーマベース)
// =============================================================================

/**
 * Users Table Entity - Supabase Auth連携ユーザー情報
 */
export interface User {
  id: UUID;
  email: string;
  username: string;
  display_name: string | null;
  is_active: boolean;
  is_admin: boolean;
  created_at: ISODateTime;
  updated_at: ISODateTime;
}

/**
 * Platforms Table Entity - サポートされる配信プラットフォーム
 */
export interface PlatformEntity {
  id: UUID;
  name: string; // 'youtube', 'twitch', 'kick'
  display_name: string;
  api_base_url: string | null;
  oauth_url: string | null;
  required_scopes: string[] | null;
  is_active: boolean;
  created_at: ISODateTime;
}

/**
 * System Settings Table Entity - システム設定
 */
export interface SystemSetting {
  id: UUID;
  key: string;
  value: string;
  description: string | null;
  is_encrypted: boolean;
  created_at: ISODateTime;
  updated_at: ISODateTime;
}

/**
 * User API Keys Table Entity - ユーザーAPIキー管理
 */
export interface UserApiKey {
  id: UUID;
  user_id: UUID;
  platform_id: UUID;
  access_token: string;
  refresh_token: string | null;
  token_expires_at: ISODateTime | null;
  is_active: boolean;
  created_at: ISODateTime;
  updated_at: ISODateTime;
  
  // Relations
  user?: User;
  platform?: PlatformEntity;
}

/**
 * Channels Table Entity - 登録されたチャンネル情報
 */
export interface Channel {
  id: UUID;
  user_id: UUID;
  platform_id: UUID;
  channel_id: string; // プラットフォーム固有のID (VARCHAR(100))
  channel_name: string;
  display_name: string | null;
  avatar_url: string | null;
  is_subscribed: boolean; // そのユーザーが登録しているか
  is_active: boolean;
  created_at: ISODateTime;
  updated_at: ISODateTime;
  
  // Relations
  user?: User;
  platform?: PlatformEntity;
  streams?: Stream[];
}

/**
 * Streams Table Entity - 配信情報
 */
export interface Stream {
  id: UUID;
  channel_id: UUID;
  platform_stream_id: string; // YouTube Video ID または Twitch Stream ID (VARCHAR(100))
  title: string;
  description: string | null;
  thumbnail_url: string | null;
  viewer_count: number;
  game_name: string | null;
  tags: string[] | null;
  started_at: ISODateTime;
  is_live: boolean;
  created_at: ISODateTime;
  updated_at: ISODateTime;
  
  // Relations
  channel?: Channel;
}

// =============================================================================
// API Request/Response Schemas
// =============================================================================

/**
 * Standard API Response Wrapper
 */
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  error?: ApiError;
  meta?: ResponseMeta;
}

export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, any>;
}

export interface ResponseMeta {
  total_count?: number;
  page?: number;
  per_page?: number;
  has_next?: boolean;
  has_prev?: boolean;
}

// =============================================================================
// Authentication Schemas (Supabase Auth ベース)
// =============================================================================

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  user: User;
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token: string;
}

export interface RegisterRequest {
  email: string;
  password: string;
  username: string;
  display_name?: string;
}

export interface RefreshTokenRequest {
  refresh_token: string;
}

/**
 * Get Current User Response - get_current_user() 関数の戻り値
 */
export interface GetCurrentUserResponse {
  id: UUID;
  email: string;
  username: string;
  display_name: string | null;
  is_admin: boolean;
}

// =============================================================================
// User Management Schemas
// =============================================================================

export interface UpdateUserRequest {
  username?: string;
  display_name?: string;
  is_active?: boolean;
}

export interface UpdateUserResponse {
  user: User;
}

// =============================================================================
// Platform Management Schemas
// =============================================================================

export interface GetPlatformsResponse {
  platforms: PlatformEntity[];
}

export interface CreatePlatformRequest {
  name: string;
  display_name: string;
  api_base_url?: string;
  oauth_url?: string;
  required_scopes?: string[];
}

// =============================================================================
// User API Key Management Schemas
// =============================================================================

export interface CreateUserApiKeyRequest {
  platform_id: UUID;
  access_token: string;
  refresh_token?: string;
  token_expires_at?: ISODateTime;
}

export interface UpdateUserApiKeyRequest {
  access_token?: string;
  refresh_token?: string;
  token_expires_at?: ISODateTime;
  is_active?: boolean;
}

export interface GetUserApiKeysQuery {
  platform_id?: UUID;
  is_active?: boolean;
}

export interface GetUserApiKeysResponse {
  api_keys: UserApiKey[];
}

// =============================================================================
// Channel Management Schemas
// =============================================================================

export interface CreateChannelRequest {
  platform_id: UUID;
  channel_id: string; // プラットフォーム固有のID
  channel_name: string;
  display_name?: string;
  avatar_url?: string;
}

export interface UpdateChannelRequest {
  channel_name?: string;
  display_name?: string;
  avatar_url?: string;
  is_subscribed?: boolean;
  is_active?: boolean;
}

export interface GetChannelsQuery {
  platform_id?: UUID;
  is_subscribed?: boolean;
  is_active?: boolean;
  page?: number;
  per_page?: number;
}

export interface GetChannelsResponse {
  channels: Channel[];
  meta: ResponseMeta;
}

// =============================================================================
// Stream Data Schemas
// =============================================================================

export interface GetStreamsQuery {
  channel_id?: UUID;
  platform_id?: UUID;
  is_live?: boolean;
  game_name?: string;
  started_after?: ISODateTime;
  started_before?: ISODateTime;
  limit?: number;
  offset?: number;
  sort_by?: 'started_at' | 'viewer_count' | 'created_at';
  sort_order?: 'asc' | 'desc';
}

export interface GetStreamsResponse {
  streams: Stream[];
  meta: ResponseMeta;
}

export interface RefreshStreamsRequest {
  channel_ids?: UUID[]; // 指定されない場合はユーザーの全登録チャンネル
  force_refresh?: boolean;
}

export interface RefreshStreamsResponse {
  refreshed_at: ISODateTime;
  total_channels_checked: number;
  total_streams_found: number;
  total_streams_updated: number;
  errors: RefreshError[];
  streams: Stream[];
}

export interface RefreshError {
  channel_id: UUID;
  platform: string;
  error_code: string;
  error_message: string;
}

// =============================================================================
// Search & Filter Schemas (全文検索インデックス対応)
// =============================================================================

export interface SearchStreamsQuery {
  query?: string; // title + description + game_name での全文検索
  platform_id?: UUID;
  game_name?: string;
  tags?: string[];
  min_viewers?: number;
  max_viewers?: number;
  is_live?: boolean;
  started_after?: ISODateTime;
  started_before?: ISODateTime;
  limit?: number;
  offset?: number;
}

export interface SearchStreamsResponse {
  streams: Stream[];
  meta: ResponseMeta;
  search_meta: {
    query: string;
    total_matches: number;
    search_time_ms: number;
  };
}

// =============================================================================
// Platform Specific Data Types
// =============================================================================

/**
 * YouTube API から取得するデータの構造
 */
export interface YouTubeChannelData {
  channel_id: string;
  title: string;
  description: string;
  thumbnail_url: string;
  subscriber_count?: number;
  custom_url?: string;
}

export interface YouTubeStreamData {
  video_id: string;
  title: string;
  description: string;
  thumbnail_url: string;
  channel_id: string;
  scheduled_start_time?: string;
  actual_start_time?: string;
  concurrent_viewers?: number;
  category_id?: string;
  tags?: string[];
}

/**
 * Twitch API から取得するデータの構造
 */
export interface TwitchChannelData {
  user_id: string;
  user_login: string;
  display_name: string;
  description: string;
  profile_image_url: string;
  view_count: number;
  broadcaster_type: string;
}

export interface TwitchStreamData {
  id: string;
  user_id: string;
  user_login: string;
  user_name: string;
  game_id: string;
  game_name: string;
  title: string;
  viewer_count: number;
  started_at: string;
  language: string;
  thumbnail_url: string;
  tag_ids?: string[];
  tags?: string[];
  is_mature: boolean;
}

// =============================================================================
// System Configuration Types
// =============================================================================

export interface AppConfig {
  app_name: string;
  app_version: string;
  environment: 'development' | 'staging' | 'production';
  api_base_url: string;
  supported_platforms: Platform[];
  pagination: {
    default_per_page: number;
    max_per_page: number;
  };
  refresh: {
    default_interval_minutes: number;
    max_channels_per_request: number;
  };
}

/**
 * System Settings からの設定値取得用
 */
export interface SystemConfig {
  youtube_client_id: string;
  youtube_client_secret: string;
  twitch_client_id: string;
  twitch_client_secret: string;
}

// =============================================================================
// Health Check & System Status
// =============================================================================

export interface HealthCheckResponse {
  status: 'healthy' | 'degraded' | 'unhealthy';
  version: string;
  timestamp: ISODateTime;
  checks: {
    database: HealthStatus;
    youtube_api: HealthStatus;
    twitch_api: HealthStatus;
    supabase_auth: HealthStatus;
  };
  uptime_seconds: number;
}

export interface HealthStatus {
  status: 'up' | 'down' | 'degraded';
  response_time_ms?: number;
  last_check_at: ISODateTime;
  error_message?: string;
}

// =============================================================================
// Error Handling Types (RLS対応)
// =============================================================================

export interface ValidationError {
  field: string;
  message: string;
  code: string;
}

export interface ValidationErrorResponse {
  success: false;
  error: {
    code: 'VALIDATION_ERROR';
    message: 'Request validation failed';
    details: {
      validation_errors: ValidationError[];
    };
  };
}

export interface AuthErrorResponse {
  success: false;
  error: {
    code: 'AUTH_ERROR' | 'TOKEN_EXPIRED' | 'INVALID_TOKEN' | 'INSUFFICIENT_PERMISSIONS' | 'RLS_VIOLATION';
    message: string;
    details?: {
      token_expires_at?: ISODateTime;
      required_permissions?: string[];
      user_id?: UUID;
    };
  };
}

export interface ExternalApiErrorResponse {
  success: false;
  error: {
    code: 'EXTERNAL_API_ERROR' | 'RATE_LIMITED' | 'API_UNAVAILABLE' | 'OAUTH_TOKEN_EXPIRED';
    message: string;
    details: {
      platform: Platform;
      api_error_code?: string;
      api_error_message?: string;
      retry_after_seconds?: number;
    };
  };
}

// =============================================================================
// Database Query Result Types
// =============================================================================

/**
 * JOIN クエリの結果用型（パフォーマンス最適化）
 */
export interface ChannelWithPlatform extends Channel {
  platform: PlatformEntity;
}

export interface StreamWithChannel extends Stream {
  channel: ChannelWithPlatform;
}

export interface StreamWithFullDetails extends Stream {
  channel: {
    id: UUID;
    channel_name: string;
    display_name: string | null;
    avatar_url: string | null;
    platform: {
      name: string;
      display_name: string;
    };
  };
}

// =============================================================================
// OAuth Integration Types
// =============================================================================

export interface OAuthAuthorizationRequest {
  platform: Platform;
  redirect_uri: string;
  state?: string;
}

export interface OAuthAuthorizationResponse {
  authorization_url: string;
  state: string;
}

export interface OAuthCallbackRequest {
  platform: Platform;
  code: string;
  state?: string;
}

export interface OAuthCallbackResponse {
  user_api_key: UserApiKey;
  platform_user_info: YouTubeChannelData | TwitchChannelData;
}

// =============================================================================
// Utility Types
// =============================================================================

export type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
};

export type RequiredFields<T, K extends keyof T> = T & Required<Pick<T, K>>;

export type OmitFields<T, K extends keyof T> = Omit<T, K>;

export type PickFields<T, K extends keyof T> = Pick<T, K>;

/**
 * Database Insert Type - created_at, updated_at を除外
 */
export type InsertType<T> = Omit<T, 'id' | 'created_at' | 'updated_at'>;

/**
 * Database Update Type - id, created_at, updated_at を除外してPartial化
 */
export type UpdateType<T> = Partial<Omit<T, 'id' | 'created_at' | 'updated_at'>>;

// =============================================================================
// Type Guards (実際のDBスキーマ対応)
// =============================================================================

export const isValidPlatform = (platform: string): platform is Platform => {
  return ['youtube', 'twitch', 'kick'].includes(platform);
};

export const isApiError = (response: any): response is ApiResponse & { success: false } => {
  return response && response.success === false && response.error;
};

export const isValidationError = (response: any): response is ValidationErrorResponse => {
  return isApiError(response) && response.error.code === 'VALIDATION_ERROR';
};

export const isAuthError = (response: any): response is AuthErrorResponse => {
  return isApiError(response) && [
    'AUTH_ERROR', 
    'TOKEN_EXPIRED', 
    'INVALID_TOKEN', 
    'INSUFFICIENT_PERMISSIONS',
    'RLS_VIOLATION'
  ].includes(response.error.code);
};

export const isExternalApiError = (response: any): response is ExternalApiErrorResponse => {
  return isApiError(response) && [
    'EXTERNAL_API_ERROR', 
    'RATE_LIMITED', 
    'API_UNAVAILABLE',
    'OAUTH_TOKEN_EXPIRED'
  ].includes(response.error.code);
};

export const isLiveStream = (stream: Stream): boolean => {
  return stream.is_live && !!stream.started_at;
};

export const isChannelActive = (channel: Channel): boolean => {
  return channel.is_active && channel.is_subscribed;
};

// =============================================================================
// Database Constraint Types
// =============================================================================

/**
 * UNIQUE制約に対応した型チェック
 */
export interface UniqueConstraints {
  users_email: { email: string };
  users_username: { username: string };
  user_api_keys_user_platform: { user_id: UUID; platform_id: UUID };
  channels_user_platform_channel: { user_id: UUID; platform_id: UUID; channel_id: string };
  platforms_name: { name: string };
  system_settings_key: { key: string };
}

/**
 * 外部キー制約の型安全性確保
 */
export interface ForeignKeyReferences {
  user_api_keys: { user_id: User['id']; platform_id: PlatformEntity['id'] };
  channels: { user_id: User['id']; platform_id: PlatformEntity['id'] };
  streams: { channel_id: Channel['id'] };
}