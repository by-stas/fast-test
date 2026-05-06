import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, Subject, catchError, map, of, shareReplay, startWith, switchMap } from 'rxjs';

import { AuthState, AuthUser } from './auth-user';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly refreshRequested$ = new Subject<void>();

  readonly state$ = this.refreshRequested$.pipe(
    startWith(undefined),
    switchMap(() => this.loadUser()),
    shareReplay({ bufferSize: 1, refCount: true })
  );

  refresh(): void {
    this.refreshRequested$.next();
  }

  private loadUser(): Observable<AuthState> {
    return this.http.get<AuthUser>('/api/me', { withCredentials: true }).pipe(
      map(user => ({
        loading: false,
        authenticated: user.isAuthenticated,
        user
      })),
      catchError(error => of({
        loading: false,
        authenticated: false,
        error: this.describeError(error)
      }))
    );
  }

  private describeError(error: unknown): string {
    if (typeof error === 'object' && error !== null && 'status' in error) {
      const status = (error as { status: number }).status;
      if (status === 401) {
        return 'Kerberos authentication did not complete. Check browser integrated authentication settings and the backend SPN.';
      }

      if (status === 403) {
        return 'The authenticated user is not authorized to access this application.';
      }

      return `Backend returned HTTP ${status}.`;
    }

    return 'Unable to contact the backend API.';
  }
}
