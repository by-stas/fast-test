export interface AuthClaim {
  type: string;
  value: string;
}

export interface AuthUser {
  name: string | null;
  authenticationType: string | null;
  isAuthenticated: boolean;
  claims: AuthClaim[];
}

export interface AuthState {
  loading: boolean;
  authenticated: boolean;
  user?: AuthUser;
  error?: string;
}
