import { JsonPipe } from '@angular/common';
import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';

import { AuthService } from './auth.service';
import { AuthState } from './auth-user';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [JsonPipe],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class AppComponent {
  protected readonly auth = inject(AuthService);
  protected readonly state = toSignal(this.auth.state$, {
    initialValue: { loading: true, authenticated: false } satisfies AuthState
  });
  protected readonly loading = computed(() => this.state().loading);
  protected readonly error = computed(() => this.state().error);
  protected readonly user = computed(() => this.state().user ?? null);

  protected refresh(): void {
    this.auth.refresh();
  }
}
